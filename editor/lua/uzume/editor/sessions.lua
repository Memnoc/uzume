-- EDITOR SPIKE: low-level native tab/window lifecycle and snapshot compatibility.
-- Product projects/windows/panes are exposed by projects.lua and panes.lua.
local M = {}
local api = vim.api
local snapshot = vim.fn.stdpath("state") .. "/navigator/snapshot.json"
local function tabvar(tab, name)
  local ok, value = pcall(api.nvim_tabpage_get_var, tab, name)
  return ok and value or nil
end
local function editable(win)
  if not api.nvim_win_is_valid(win) then
    return false
  end
  local buf = api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == ""
    or vim.bo[buf].buftype == "terminal"
    or vim.bo[buf].filetype == "snacks_dashboard"
    or vim.bo[buf].filetype == "uzume_session"
    or vim.bo[buf].filetype == "uzume_task"
end
local function tiled_windows(tab)
  return vim.tbl_filter(function(win)
    return api.nvim_win_get_config(win).relative == ""
  end, api.nvim_tabpage_list_wins(tab))
end
function M.windows(tab)
  tab = tab == 0 and api.nvim_get_current_tabpage() or tab
  local result = {}
  for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
    if editable(win) then
      local buf = api.nvim_win_get_buf(win)
      local terminal = vim.bo[buf].buftype == "terminal"
      local file = api.nvim_buf_get_name(buf)
      result[#result + 1] = {
        win = win,
        buf = buf,
        tab = tab,
        terminal = terminal,
        name = vim.w[win].uzume_name
          or (
            terminal and (vim.b[buf].term_title or "terminal")
            or (vim.bo[buf].filetype == "snacks_dashboard" and "Dashboard")
            or (vim.bo[buf].filetype == "uzume_session" and "Project home")
            or (file ~= "" and vim.fs.basename(file) or "[New file]")
          ),
        agent = vim.b[buf].uzume_agent,
      }
    end
  end
  return result
end
function M.list()
  local result = {}
  for _, tab in ipairs(api.nvim_list_tabpages()) do
    local number = api.nvim_tabpage_get_number(tab)
    local root = tabvar(tab, "uzume_root") or vim.fn.getcwd(-1, number)
    result[#result + 1] = {
      tab = tab,
      root = root,
      name = tabvar(tab, "uzume_name") or vim.fs.basename(root),
      current = tab == api.nvim_get_current_tabpage(),
      windows = M.windows(tab),
    }
  end
  return result
end
function M.adopt()
  local tab = api.nvim_get_current_tabpage()
  if vim.t[tab].uzume_unassigned then
    if vim.bo.buftype == "" and api.nvim_buf_get_name(0) ~= "" then
      vim.t[tab].uzume_unassigned = nil
    else
      return
    end
  end
  if not tabvar(tab, "uzume_root") then
    local root = require("uzume.editor.project").root()
    api.nvim_tabpage_set_var(tab, "uzume_root", root)
    vim.cmd.tcd(vim.fn.fnameescape(root))
  end
  vim.t[tab].uzume_project_name = vim.t[tab].uzume_project_name or vim.fs.basename(vim.t[tab].uzume_root)
  vim.t[tab].uzume_name = vim.t[tab].uzume_name or "Editor"
end
function M.home()
  local tab, win, previous = api.nvim_get_current_tabpage(), api.nvim_get_current_win(), api.nvim_get_current_buf()
  local root = tabvar(tab, "uzume_root") or vim.fn.getcwd()
  local name = tabvar(tab, "uzume_name") or vim.fs.basename(root)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "uzume_session"
  vim.b[buf].snacks_main = true
  api.nvim_buf_set_lines(buf, 0, -1, false, {
    "",
    "  Project: " .. (vim.t[tab].uzume_project_name or vim.fs.basename(root)),
    "  Directory: " .. root,
    "",
    "  Window: " .. name,
    "  This is a home view, not a file to save.",
    "",
    "  Space e       Toggle file explorer (a adds a file)",
    "  Space Space   Find a file in this project",
    "  Space aw      Windows (n shell, e editor)",
    "  Space ap      Switch or manage projects",
    "  Space w       Create, switch or close windows",
    "  Space p       Split, move, resize, float or close panes",
    "  Space fn      Start a new file; Ctrl-s asks for its name",
    "",
  })
  vim.bo[buf].modifiable = false
  api.nvim_buf_set_extmark(buf, api.nvim_create_namespace("uzume.editor.session_home"), 1, 2, {
    end_row = 1,
    end_col = #("  Project: " .. (vim.t[tab].uzume_project_name or vim.fs.basename(root))),
    hl_group = "Title",
  })
  api.nvim_win_set_buf(win, buf)
  local options =
    { number = vim.wo[win].number, relativenumber = vim.wo[win].relativenumber, cursorline = vim.wo[win].cursorline }
  for option in pairs(options) do
    vim.wo[win][option] = false
  end
  api.nvim_create_autocmd("BufWinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        if api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) ~= buf then
          for option, value in pairs(options) do
            vim.wo[win][option] = value
          end
        end
      end)
    end,
  })
  if
    api.nvim_buf_is_valid(previous)
    and vim.bo[previous].buftype == ""
    and not vim.bo[previous].modified
    and api.nvim_buf_get_name(previous) == ""
    and #vim.fn.win_findbuf(previous) == 0
  then
    api.nvim_buf_delete(previous, {})
  end
  if #Snacks.picker.get({ source = "explorer" }) == 0 then
    Snacks.explorer({ cwd = root, enter = false })
  end
  api.nvim_set_current_win(win)
  return buf
end
function M.refresh_home(tab)
  for _, pane in ipairs(M.windows(tab)) do
    if vim.bo[pane.buf].filetype == "uzume_session" then
      vim.bo[pane.buf].modifiable = true
      api.nvim_buf_set_lines(pane.buf, 1, 2, false, { "  Project: " .. (vim.t[tab].uzume_project_name or "") })
      api.nvim_buf_set_lines(pane.buf, 4, 5, false, { "  Window: " .. (vim.t[tab].uzume_name or "") })
      vim.bo[pane.buf].modifiable = false
    end
  end
end
function M.create(path, opts)
  opts = opts or {}
  path = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
  assert(vim.fn.isdirectory(path) == 1, "Choose an existing project or worktree directory")
  vim.cmd.tabnew()
  require("uzume.agents.buffers").reset(api.nvim_get_current_tabpage())
  vim.cmd.tcd(vim.fn.fnameescape(path))
  api.nvim_tabpage_set_var(0, "uzume_root", path)
  vim.t.uzume_project_root = opts.project_root or path
  vim.t.uzume_task = opts.task
  api.nvim_tabpage_set_var(0, "uzume_name", opts.name or "Editor")
  vim.t.uzume_project_name = opts.project_name or vim.fs.basename(path)
  if opts.shell then
    local ok, job = pcall(vim.fn.jobstart, vim.fn.split(vim.o.shell), { term = true, cwd = path })
    if not ok or job <= 0 then
      vim.cmd.tabclose()
      error("Could not start shell: " .. tostring(job))
    end
    vim.cmd.startinsert()
  elseif not opts.empty then
    M.home()
  end
  return api.nvim_get_current_tabpage()
end
function M.jump(item)
  assert(api.nvim_tabpage_is_valid(item.tab), "Window has closed")
  api.nvim_set_current_tabpage(item.tab)
  if item.win then
    assert(api.nvim_win_is_valid(item.win), "Window has closed")
    api.nvim_set_current_win(item.win)
  else
    local focused = tabvar(item.tab, "uzume_focus")
    if focused and api.nvim_win_is_valid(focused) then
      api.nvim_set_current_win(focused)
    end
  end
end
function M.rename(item, name)
  name = vim.trim(name)
  assert(name ~= "", "A name cannot be empty")
  if item.win then
    assert(api.nvim_win_is_valid(item.win), "Window has closed")
    vim.w[item.win].uzume_name = name
  else
    api.nvim_tabpage_set_var(item.tab, "uzume_name", name)
  end
end
local function stop_terminal(buf)
  local job = vim.b[buf].terminal_job_id
  if job then
    pcall(vim.fn.jobstop, job)
  end
end
-- Native mksession preserves editor layout/cursors; terminal/options/globals are
-- excluded so restoring never launches a shell, agent, or captured option code.
function M.save()
  require("uzume.editor.panes").prepare_save()
  assert(#require("uzume.editor.projects").list() > 0, "Open a project before saving its layout")
  if M.restoring then
    return
  end
  local directory = vim.fs.dirname(snapshot)
  vim.fn.mkdir(directory, "p", 448)
  local temporary = directory .. "/layout-" .. vim.fn.getpid() .. ".vim"
  local fd = assert(vim.uv.fs_open(temporary, "w", 384))
  vim.uv.fs_close(fd)
  local previous = vim.o.sessionoptions
  vim.o.sessionoptions = "blank,curdir,tabpages,winsize,skiprtp"
  local ok, err = pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(temporary))
  vim.o.sessionoptions = previous
  if not ok then
    vim.fn.delete(temporary)
    error(err)
  end
  local metadata = {}
  for _, session in ipairs(M.list()) do
    local titles = {}
    local home = false
    for _, item in ipairs(session.windows) do
      home = home or vim.bo[item.buf].filetype == "uzume_session"
      if not item.terminal then
        titles[api.nvim_buf_get_name(item.buf)] = vim.w[item.win].uzume_name
      end
    end
    metadata[#metadata + 1] = {
      name = session.name,
      root = session.root,
      titles = titles,
      home = home,
      project_name = vim.t[session.tab].uzume_project_name,
      project_root = vim.t[session.tab].uzume_project_root,
      task = vim.t[session.tab].uzume_task,
    }
  end
  local layout = vim.fn.readfile(temporary)
  vim.fn.delete(temporary)
  -- mksession can retain a terminal in an argument list even with 'terminal'
  -- disabled. Do not persist a script that could reopen it through BufReadCmd.
  assert(
    not table.concat(layout, "\n"):find("term://", 1, true),
    "Remove terminal references from argument lists before saving"
  )
  local value = { version = 1, layout = layout, sessions = metadata }
  local staged = snapshot .. "." .. vim.fn.getpid() .. ".tmp"
  fd = assert(vim.uv.fs_open(staged, "w", 384))
  assert(vim.uv.fs_write(fd, vim.json.encode(value), 0))
  vim.uv.fs_close(fd)
  assert(vim.uv.fs_rename(staged, snapshot))
  return snapshot
end
function M.restore()
  assert(vim.fn.filereadable(snapshot) == 1, "No navigator snapshot saved yet")
  assert(#api.nvim_list_tabpages() == 1 and #tiled_windows(0) == 1, "Restore from a fresh editor with one empty window")
  local buf = api.nvim_get_current_buf()
  assert(
    not vim.bo[buf].modified
      and (
        vim.bo[buf].filetype == "snacks_dashboard" or (api.nvim_buf_get_name(buf) == "" and vim.bo[buf].buftype == "")
      ),
    "Restore from a fresh editor with one empty window"
  )
  local saved = vim.json.decode(table.concat(vim.fn.readfile(snapshot), "\n"))
  assert(saved.version == 1 and type(saved.layout) == "table", "Unrecognized navigator snapshot")
  local temporary = snapshot .. ".restore-" .. vim.fn.getpid() .. ".vim"
  local fd = assert(vim.uv.fs_open(temporary, "w", 384))
  vim.uv.fs_close(fd)
  vim.fn.writefile(saved.layout, temporary)
  M.restoring = true
  local ok, err = pcall(vim.cmd, "source " .. vim.fn.fnameescape(temporary))
  vim.fn.delete(temporary)
  if ok then
    local focused = api.nvim_get_current_win()
    local focused_tab = api.nvim_get_current_tabpage()
    for index, tab in ipairs(api.nvim_list_tabpages()) do
      local session = saved.sessions[index]
      if session then
        vim.t[tab].uzume_unassigned = nil
        api.nvim_tabpage_set_var(tab, "uzume_name", session.project_name and session.name or "Editor")
        vim.t[tab].uzume_project_name = session.project_name or session.name
        api.nvim_tabpage_set_var(tab, "uzume_root", session.root)
        vim.t[tab].uzume_project_root = session.project_root or session.root
        vim.t[tab].uzume_task = session.task
        for _, win in ipairs(M.windows(tab)) do
          vim.w[win.win].uzume_name = session.titles[api.nvim_buf_get_name(win.buf)]
        end
        local windows = M.windows(tab)
        local blank = #windows > 0
        for _, win in ipairs(windows) do
          blank = blank and api.nvim_buf_get_name(win.buf) == "" and not vim.bo[win.buf].modified and not win.terminal
        end
        if session.home and blank then
          api.nvim_set_current_win(windows[1].win)
          vim.cmd.only()
          M.home()
        end
      end
    end
    api.nvim_set_current_tabpage(focused_tab)
    if api.nvim_win_is_valid(focused) then
      api.nvim_set_current_win(focused)
    end
  end
  M.restoring = false
  assert(ok, err)
end
function M.setup()
  local group = api.nvim_create_augroup("uzume_sessions", { clear = true })
  api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      local win = api.nvim_get_current_win()
      if editable(win) then
        api.nvim_tabpage_set_var(0, "uzume_focus", win)
      end
    end,
  })
  api.nvim_create_autocmd("TermOpen", {
    group = group,
    callback = function(event)
      vim.b[event.buf].uzume_owner = api.nvim_get_current_tabpage()
    end,
  })
  api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = function()
      vim.schedule(function()
        for _, buf in ipairs(api.nvim_list_bufs()) do
          local owner = vim.b[buf].uzume_owner
          if owner and not api.nvim_tabpage_is_valid(owner) then
            stop_terminal(buf)
            vim.b[buf].uzume_owner = nil
          end
        end
      end)
    end,
  })
  api.nvim_create_user_command("AiSession", function(args)
    local ok, err = pcall(require("uzume.editor.projects").open, args.args ~= "" and args.args or vim.fn.getcwd())
    if not ok then
      vim.notify(tostring(err), vim.log.levels.ERROR)
    end
  end, { nargs = "?", complete = "dir", desc = "Compatibility alias for AiProject" })
  api.nvim_create_user_command("AiSessionRestore", function()
    local ok, err = pcall(M.restore)
    if not ok then
      vim.notify(tostring(err), vim.log.levels.WARN)
    end
  end, { desc = "Restore the saved editor layout without starting terminals" })
end
return M
