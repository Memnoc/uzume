-- Plain project chat: one CLI per checkout and kind, no task branch or worktree.
-- The editor file last focused before each prompt is supplied by the hook.
local M = { chats = {} }
local api = vim.api
local supervisor = require("uzume.core.paths").file("agent/supervisor.py")

local function alive(chat)
  return chat.job and vim.fn.jobwait({ chat.job }, 0)[1] == -1 and api.nvim_buf_is_valid(chat.buf)
end

local function write(chat)
  local path = chat.directory .. "/context.json"
  local fd = assert(vim.uv.fs_open(path .. ".tmp", "w", 384))
  assert(vim.uv.fs_write(fd, vim.json.encode({ files = {}, revision = 0, focus = chat.focus }), 0))
  vim.uv.fs_close(fd)
  assert(vim.uv.fs_rename(path .. ".tmp", path))
end

-- Remember a saved, named file in this checkout as the chat's current file.
local function track(win)
  local buf = api.nvim_win_get_buf(win)
  local name = api.nvim_buf_get_name(buf)
  if vim.bo[buf].buftype ~= "" or name == "" or api.nvim_win_get_config(win).relative ~= "" then
    return
  end
  local path = vim.uv.fs_realpath(name)
  if not path then
    return
  end
  local line = api.nvim_win_get_cursor(win)[1]
  for _, chat in pairs(M.chats) do
    if alive(chat) and require("uzume.core.paths").contains(chat.cwd, path) then
      chat.focus = { path = path, line = line, modified = vim.bo[buf].modified or nil }
      pcall(write, chat)
    end
  end
end

local function open_split()
  vim.cmd("botright vsplit")
  api.nvim_win_set_width(0, math.max(60, math.floor(vim.o.columns * 0.4)))
end

-- Starts in the current window so the PTY gets the visible pane's size.
local function start(kind, cwd)
  local executable, python = vim.fn.exepath(kind), vim.fn.exepath("python3")
  assert(executable ~= "", "Install " .. kind .. " and log in using its official CLI")
  assert(python ~= "", "Agent chat requires Python 3")
  local directory = vim.fn.stdpath("state") .. "/agents/chat-" .. kind .. "-" .. tostring(vim.uv.hrtime())
  vim.fn.mkdir(directory, "p", 448)
  local fd = assert(vim.uv.fs_open(directory .. "/launch.json", "w", 384))
  assert(vim.uv.fs_write(fd, vim.json.encode({ kind = kind, executable = executable, cwd = cwd }), 0))
  vim.uv.fs_close(fd)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_win_set_buf(0, buf)
  local chat = { kind = kind, cwd = cwd, buf = buf, directory = directory }
  chat.job = vim.fn.jobstart({ python, supervisor, directory }, {
    term = true,
    cwd = cwd,
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 and vim.v.exiting == vim.NIL then
          require("uzume.editor.panes").remove_exited_terminal(buf)
        end
      end)
    end,
  })
  assert(chat.job > 0, "Could not start agent chat")
  local name = kind == "codex" and "Codex" or "Claude"
  vim.b[buf].uzume_agent_kind = kind
  vim.b[buf].uzume_agent_label = name .. " chat · " .. vim.fs.basename(cwd)
  vim.bo[buf].bufhidden = "hide"
  for _, key in ipairs({ "<Esc>", "jk", "<C-w>" }) do
    vim.keymap.set("t", key, key, { buffer = buf, nowait = key ~= "<Esc>" })
  end
  vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { buffer = buf, desc = "Chat: editor controls" })
  vim.keymap.set("n", "q", function()
    M.toggle(kind)
  end, { buffer = buf, desc = "Chat: hide" })
  return chat
end

function M.toggle(kind)
  local win = api.nvim_get_current_win()
  local current = api.nvim_get_current_buf()
  for _, chat in pairs(M.chats) do
    if chat.buf == current and chat.kind == kind then
      -- Hiding keeps the conversation running; showing it again resumes.
      if #api.nvim_tabpage_list_wins(0) > 1 then
        api.nvim_win_close(win, false)
      end
      return
    end
  end
  local cwd = require("uzume.editor.project").root()
  local key = kind .. "\0" .. cwd
  local chat = M.chats[key]
  track(win)
  if chat and alive(chat) then
    -- One visible view per chat: move it into this product Window.
    for _, other in ipairs(vim.fn.win_findbuf(chat.buf)) do
      if api.nvim_win_get_tabpage(other) == api.nvim_get_current_tabpage() then
        api.nvim_set_current_win(other)
        return vim.cmd.startinsert()
      end
      pcall(api.nvim_win_close, other, false)
    end
    vim.b[chat.buf].uzume_owner = api.nvim_get_current_tabpage()
    open_split()
    api.nvim_win_set_buf(0, chat.buf)
  else
    open_split()
    chat = start(kind, cwd)
    M.chats[key] = chat
    track(win)
    if not chat.focus then
      write(chat)
    end
  end
  vim.w.uzume_name = vim.b[chat.buf].uzume_agent_label
  vim.cmd.startinsert()
end

function M.setup()
  api.nvim_create_autocmd("WinLeave", {
    group = api.nvim_create_augroup("uzume_agent_chat", { clear = true }),
    callback = function()
      if next(M.chats) then
        track(api.nvim_get_current_win())
      end
    end,
  })
end

return M
