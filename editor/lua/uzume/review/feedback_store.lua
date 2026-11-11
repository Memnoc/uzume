-- Immutable batches and run-scoped delivery. Hooks claim files by atomic rename.
local M = {}
local uv = vim.uv
local root = vim.fn.stdpath("state") .. "/review-feedback"
local function directory(task)
  return root .. "/" .. require("uzume.review.task_key")(task)
end
local function write(path, value)
  local parent = vim.fs.dirname(path)
  vim.fn.mkdir(parent, "p", 448)
  assert(uv.fs_chmod(parent, 448))
  local temporary = path .. "." .. uv.hrtime() .. ".tmp"
  local fd = assert(uv.fs_open(temporary, "wx", 384))
  local ok, err = pcall(function()
    local data = vim.json.encode(value)
    assert(uv.fs_write(fd, data, 0) == #data, "Could not save complete feedback")
    assert(uv.fs_fsync(fd))
  end)
  uv.fs_close(fd)
  if ok then
    ok, err = uv.fs_rename(temporary, path)
  end
  if not ok then
    uv.fs_unlink(temporary)
    error(err)
  end
end
function M.history(task)
  local result = {}
  for _, path in ipairs(vim.fn.glob(directory(task) .. "/*.json", false, true)) do
    local ok, batch = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    assert(
      ok
        and type(batch) == "table"
        and batch.version == 1
        and batch.task == task.id
        and batch.base == task.base
        and type(batch.id) == "string"
        and type(batch.run) == "string"
        and type(batch.comments) == "table",
      "Cannot read saved feedback; file retained: " .. path
    )
    result[#result + 1] = batch
  end
  table.sort(result, function(a, b)
    return a.created < b.created
  end)
  return result
end
function M.agent(task)
  local item = require("uzume.agents").instances[task.id]
  if
    item
    and item.task.project == task.project
    and item.task.base == task.base
    and vim.api.nvim_tabpage_is_valid(item.tab)
    and item.job
    and vim.fn.jobwait({ item.job }, 0)[1] == -1
  then
    return item
  end
end
local function delivery(batch, suffix)
  return batch.run .. "/feedback/" .. batch.id .. "." .. suffix .. ".json"
end
function M.status(task, batch)
  for _, status in ipairs({ "supplied", "claimed", "cancelled" }) do
    if uv.fs_stat(delivery(batch, status)) then
      return status
    end
  end
  if uv.fs_stat(delivery(batch, "pending")) then
    local agent = M.agent(task)
    return agent and agent.directory == batch.run and "queued" or "paused"
  end
  return "unpublished"
end
function M.revision(comment)
  return vim.fn.sha256(vim.json.encode({ comment.id, comment.body, comment.snapshot, comment.digest }))
end
function M.versions(task)
  local result = {}
  for _, batch in ipairs(M.history(task)) do
    local status = M.status(task, batch)
    if status ~= "cancelled" and status ~= "unpublished" then
      for _, comment in ipairs(batch.comments) do
        result[M.revision(comment)] = status
      end
    end
  end
  return result
end
function M.queue(task, comments, text)
  local agent = assert(M.agent(task), "Start this task's agent with Space ar before sending feedback")
  local history = M.history(task)
  for _, batch in ipairs(history) do
    assert(M.status(task, batch) ~= "queued", "A review is already queued. Cancel it before replacing it.")
  end
  local versions = M.versions(task)
  for _, comment in ipairs(comments) do
    local status = versions[M.revision(comment)]
    assert(not status or status == "paused", "This comment version has already been queued or supplied")
  end
  assert(#comments > 0, "No unsent comments")
  -- Retire pending copies from stopped runs before publishing to a replacement.
  -- Cancellation races with a hook claim; only the winner may proceed.
  for _, previous in ipairs(history) do
    if M.status(task, previous) == "paused" then
      M.cancel(previous)
    end
  end
  local seconds, micros = uv.gettimeofday()
  local batch = {
    version = 1,
    id = vim.fn.sha256(task.id .. uv.hrtime() .. vim.fn.getpid()):sub(1, 24),
    task = task.id,
    base = task.base,
    run = agent.directory,
    kind = agent.kind,
    created = seconds + micros / 1000000,
    comments = vim.deepcopy(comments),
    text = text,
  }
  local packet = { id = batch.id, text = text }
  assert(#vim.json.encode(packet) <= 262144, "This review is too large to send (256 KiB limit)")
  -- Save the batch first. A crash before publication leaves a visible unsent record.
  write(directory(task) .. "/" .. batch.id .. ".json", batch)
  write(delivery(batch, "pending"), packet)
  return batch
end
function M.cancel(batch)
  local ok = uv.fs_rename(delivery(batch, "pending"), delivery(batch, "cancelled"))
  assert(ok, "The hook has already claimed this review; it can no longer be cancelled")
end
function M.prompt_requested(batch)
  return uv.fs_stat(delivery(batch, "wake")) ~= nil
end
function M.request_prompt(task, batch)
  assert(M.status(task, batch) == "queued", "This review is no longer pending")
  if M.prompt_requested(batch) then
    return false
  end
  local fd = assert(uv.fs_open(delivery(batch, "wake"), "wx", 384))
  local ok, err = pcall(function()
    assert(uv.fs_write(fd, "{}", 0) == 2)
    assert(uv.fs_fsync(fd))
  end)
  uv.fs_close(fd)
  assert(ok, err)
  return true
end
return M
