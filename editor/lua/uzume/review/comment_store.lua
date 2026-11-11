-- Saved local drafts, independent of review windows and agent delivery.
local M = {}
local uv = vim.uv
local directory = vim.fn.stdpath("state") .. "/review-comments"
local function path(task)
  return directory .. "/" .. vim.fn.sha256(task.project .. "\0" .. task.id) .. ".json"
end
function M.read(task)
  local name = path(task)
  if not uv.fs_stat(name) then
    return {}
  end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(name), "\n"))
  assert(
    ok
      and type(data) == "table"
      and data.version == 1
      and data.task == task.id
      and data.base == task.base
      and type(data.comments) == "table",
    "Cannot read saved review comments; the existing file was left untouched: " .. name
  )
  for _, comment in ipairs(data.comments) do
    assert(
      type(comment.id) == "string"
        and type(comment.body) == "string"
        and type(comment.anchor) == "table"
        and type(comment.path) == "string"
        and type(comment.display) == "string"
        and type(comment.snapshot) == "string"
        and type(comment.digest) == "string",
      "Saved review comments have an invalid record: " .. name
    )
    local anchored = false
    for _, side in ipairs({ "before", "after" }) do
      local range = comment.anchor[side]
      if range then
        assert(
          type(range) == "table"
            and type(range.first) == "number"
            and type(range.last) == "number"
            and range.first >= 1
            and range.last >= range.first
            and type(range.lines) == "table"
            and #range.lines == range.last - range.first + 1,
          "Saved review comment has an invalid line range: " .. name
        )
        for _, line in ipairs(range.lines) do
          assert(type(line) == "string", "Saved review excerpt is invalid: " .. name)
        end
        anchored = true
      end
    end
    assert(anchored, "Saved review comment has no line range: " .. name)
  end
  return data.comments
end
local function write(task, comments)
  vim.fn.mkdir(directory, "p", 448)
  assert(uv.fs_chmod(directory, 448))
  local temporary = path(task) .. "." .. vim.fn.getpid() .. "." .. uv.hrtime() .. ".tmp"
  local fd = assert(uv.fs_open(temporary, "wx", 384))
  local ok, failure = pcall(function()
    local encoded = vim.json.encode({ version = 1, task = task.id, base = task.base, comments = comments })
    assert(uv.fs_write(fd, encoded, 0) == #encoded, "Could not save the complete review comment")
    assert(uv.fs_fsync(fd))
  end)
  uv.fs_close(fd)
  if ok then
    local renamed, rename_error = uv.fs_rename(temporary, path(task))
    ok, failure = renamed ~= nil, rename_error
  end
  if not ok then
    uv.fs_unlink(temporary)
    error(failure or "Could not save review comments")
  end
end
function M.save(task, comment, body)
  assert(vim.trim(body) ~= "", "Write a comment before saving")
  local comments, saved = M.read(task), vim.deepcopy(comment)
  saved.body = body
  saved.id = saved.id or vim.fn.sha256(task.id .. uv.hrtime() .. vim.fn.getpid()):sub(1, 20)
  saved.created = saved.created or os.time()
  local found = false
  for index, existing in ipairs(comments) do
    if existing.id == saved.id then
      comments[index], found = saved, true
      break
    end
  end
  if not found then
    comments[#comments + 1] = saved
  end
  write(task, comments)
  return saved
end
function M.delete(task, id)
  local comments = vim.tbl_filter(function(comment)
    return comment.id ~= id
  end, M.read(task))
  write(task, comments)
end
function M.digest(file)
  return vim.fn.sha256(vim.json.encode({ file.before, file.after, file.status, file.note or "" }))
end
function M.outdated(comment, snapshot)
  for _, file in ipairs(snapshot.files) do
    if file.path == comment.path then
      return M.digest(file) ~= comment.digest
    end
  end
  return true
end
return M
