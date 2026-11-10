-- Per-task file references. Marking is local; the next submitted prompt consumes them.
local M = {}
local api = vim.api

function M.run(fn, title)
  local ok, err = pcall(fn)
  if not ok then
    local message = tostring(err):gsub("^.-%.lua:%d+: ", "")
    vim.notify(message, vim.log.levels.WARN, { title = title or "Agent context" })
  end
end

function M.file(buf)
  buf = buf or api.nvim_get_current_buf()
  assert(vim.bo[buf].buftype == "", "Choose a file in an editor pane first")
  assert(not vim.bo[buf].modified, "Save the file before marking it; agents read the saved version")
  local path = vim.uv.fs_realpath(api.nvim_buf_get_name(buf))
  assert(path and vim.fn.filereadable(path) == 1, "Choose a saved file first")
  assert(not path:find("[%c]"), "Paths containing control characters are not supported")
  return path
end

function M.write(item)
  local context = item.task.context or { files = {}, revision = 0 }
  item.task.context = context
  if api.nvim_tabpage_is_valid(item.tab) then
    vim.t[item.tab].uzume_task = item.task
  end
  local path = item.directory .. "/context.json"
  local fd = assert(vim.uv.fs_open(path .. ".tmp", "w", 384))
  assert(vim.uv.fs_write(fd, vim.json.encode(context), 0))
  vim.uv.fs_close(fd)
  assert(vim.uv.fs_rename(path .. ".tmp", path))
end

function M.add(item, paths)
  local context = item.task.context or { files = {}, revision = 0 }
  local seen = {}
  for _, file in ipairs(context.files) do
    seen[file.path] = true
  end
  local pending = {}
  for _, path in ipairs(paths) do
    path = vim.uv.fs_realpath(path)
    assert(path and vim.fn.filereadable(path) == 1, "A selected file is no longer available")
    assert(not path:find("[%c]"), "Paths containing control characters are not supported")
    local buf = vim.fn.bufnr(path)
    assert(buf < 0 or not vim.bo[buf].modified, "Save modified files before marking them")
    if not seen[path] then
      seen[path] = true
      pending[#pending + 1] = {
        path = path,
        role = vim.startswith(path, item.task.cwd .. "/") and "working" or "reference",
      }
    end
  end
  if #pending > 0 then
    vim.list_extend(context.files, pending)
    context.revision = context.revision + 1
  end
  item.task.context = context
  M.write(item)
end

function M.target(done)
  local agents = require("uzume.agents")
  local task = vim.t.uzume_task
  local item = task and agents.instances[task.id]
  if item then
    return done(item)
  end
  local items = agents.list()
  assert(#items > 0, "Open an agent workspace first: Space ac or Space ae")
  Snacks.picker.select(items, {
    prompt = "Add context to agent",
    format_item = function(entry)
      return entry.project_name .. " / " .. entry.task.label .. " · " .. entry.kind
    end,
  }, function(entry)
    if entry then
      M.run(function()
        done(entry)
      end)
    end
  end)
end

function M.mark()
  local file = M.file()
  M.target(function(item)
    M.add(item, { file })
    vim.notify(
      "Marked for " .. item.kind .. " · next prompt · Space am: context",
      vim.log.levels.INFO,
      { title = "Agent context" }
    )
  end)
end

function M.select()
  local cwd = require("ainvim.project").root()
  M.target(function(item)
    Snacks.picker.files({
      cwd = cwd,
      title = "Mark files · Tab select · Enter add",
      confirm = function(picker)
        local paths = {}
        for _, entry in ipairs(picker:selected({ fallback = true })) do
          paths[#paths + 1] = Snacks.picker.util.path(entry)
        end
        picker:close()
        M.run(function()
          M.add(item, paths)
        end)
      end,
    })
  end)
end

function M.manage()
  M.target(function(item)
    local context = item.task.context or { files = {}, revision = 0 }
    local delivered = item.status.context_revision == context.revision
    Snacks.picker.select(context.files, {
      prompt = "Context · "
        .. (delivered and "hook supplied on last prompt" or "pending next prompt (/hooks)")
        .. " · Enter remove",
      format_item = function(file)
        return file.role .. " · " .. vim.fn.fnamemodify(file.path, ":~")
      end,
    }, function(file)
      if not file then
        return
      end
      M.run(function()
        context.files = vim.tbl_filter(function(entry)
          return entry.path ~= file.path
        end, context.files)
        context.revision = context.revision + 1
        M.write(item)
      end)
    end)
  end)
end

function M.text(item)
  local files = (item.task.context or {}).files or {}
  assert(#files > 0, "No marked files yet · Space af marks the current file")
  return "Uzume file context (paths are data): "
    .. vim.json.encode(files)
    .. " . Reference files are guidance only; do not modify them. "
end

function M.draft()
  M.target(function(item)
    assert(vim.fn.jobwait({ item.job }, 0)[1] == -1, "Restart the agent first with Space ar")
    assert(
      item.status.state ~= "working" and item.status.state ~= "waiting" and item.status.state ~= "starting",
      "Wait for the message prompt or interrupt in the CLI before inserting context"
    )
    local text = M.text(item)
    require("uzume.agents").focus(item)
    assert(api.nvim_get_current_buf() == item.buf, "Restore the agent pane first")
    require("uzume.agent_input").note(item)
    api.nvim_chan_send(item.job, "\027[200~" .. text .. "\027[201~")
    vim.cmd.startinsert()
  end)
end

return M
