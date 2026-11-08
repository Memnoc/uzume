-- EDITOR SPIKE: native tab sessions and windows, no external multiplexer.
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
  return vim.bo[buf].buftype == "" or vim.bo[buf].buftype == "terminal" or vim.bo[buf].filetype == "snacks_dashboard"
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
        name = vim.w[win].ainvim_name
          or (
            terminal and (vim.b[buf].term_title or "terminal")
            or (vim.bo[buf].filetype == "snacks_dashboard" and "Dashboard")
            or (file ~= "" and vim.fs.basename(file) or "[New file]")
          ),
        agent = vim.b[buf].ainvim_agent,
      }
    end
  end
  return result
end
function M.list()
  local result = {}
  for _, tab in ipairs(api.nvim_list_tabpages()) do
    local number = api.nvim_tabpage_get_number(tab)
    local root = tabvar(tab, "ainvim_root") or vim.fn.getcwd(-1, number)
    result[#result + 1] = {
      tab = tab,
      root = root,
      name = tabvar(tab, "ainvim_name") or vim.fs.basename(root),
      current = tab == api.nvim_get_current_tabpage(),
      windows = M.windows(tab),
    }
  end
  return result
end
function M.adopt()
  local tab = api.nvim_get_current_tabpage()
  if not tabvar(tab, "ainvim_root") then
    local root = require("ainvim.project").root()
    api.nvim_tabpage_set_var(tab, "ainvim_root", root)
    vim.cmd.tcd(vim.fn.fnameescape(root))
  end
end
function M.create(path)
  path = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
  assert(vim.fn.isdirectory(path) == 1, "Choose an existing project or worktree directory")
  vim.cmd.tabnew()
  vim.cmd.tcd(vim.fn.fnameescape(path))
  api.nvim_tabpage_set_var(0, "ainvim_root", path)
  api.nvim_tabpage_set_var(0, "ainvim_name", vim.fs.basename(path))
  return api.nvim_get_current_tabpage()
end
function M.jump(item)
  assert(api.nvim_tabpage_is_valid(item.tab), "Session has closed")
  api.nvim_set_current_tabpage(item.tab)
  if item.win then
    assert(api.nvim_win_is_valid(item.win), "Window has closed")
    api.nvim_set_current_win(item.win)
  else
    local focused = tabvar(item.tab, "ainvim_focus")
    if focused and api.nvim_win_is_valid(focused) then
      api.nvim_set_current_win(focused)
    end
  end
end
function M.new_window(item)
  assert(api.nvim_tabpage_is_valid(item.tab), "Session has closed")
  local root = tabvar(item.tab, "ainvim_root") or vim.fn.getcwd(-1, api.nvim_tabpage_get_number(item.tab))
  assert(vim.fn.isdirectory(root) == 1, "Session directory no longer exists")
  local origin = api.nvim_get_current_win()
  api.nvim_set_current_tabpage(item.tab)
  local anchor = item.win
  if not anchor or not api.nvim_win_is_valid(anchor) or api.nvim_win_get_config(anchor).relative ~= "" then
    anchor = tiled_windows(item.tab)[1]
  end
  api.nvim_set_current_win(anchor)
  vim.cmd("botright vnew")
  local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  local ok, job = pcall(vim.fn.jobstart, vim.fn.split(vim.o.shell), { term = true, cwd = root })
  if not ok or job <= 0 then
    api.nvim_win_close(win, true)
    api.nvim_buf_delete(buf, { force = true })
    if api.nvim_win_is_valid(origin) then
      api.nvim_set_current_win(origin)
    end
    error("Could not start shell: " .. tostring(job))
  end
  vim.cmd.startinsert()
  return win
end
function M.rename(item, name)
  name = vim.trim(name)
  assert(name ~= "", "A name cannot be empty")
  if item.win then
    assert(api.nvim_win_is_valid(item.win), "Window has closed")
    vim.w[item.win].ainvim_name = name
  else
    api.nvim_tabpage_set_var(item.tab, "ainvim_name", name)
  end
end
local function owned_terminals(tab)
  local result = {}
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == "terminal" and vim.b[buf].ainvim_owner == tab then
      result[buf] = true
    end
  end
  for _, item in ipairs(M.windows(tab)) do
    if item.terminal then
      result[item.buf] = true
    end
  end
  return result
end
local function stop_terminal(buf)
  local job = vim.b[buf].terminal_job_id
  if job then
    pcall(vim.fn.jobstop, job)
  end
end
function M.close(item)
  assert(api.nvim_tabpage_is_valid(item.tab), "Session has closed")
  local windows = item.win and { item } or M.windows(item.tab)
  local terminals = item.win and {} or owned_terminals(item.tab)
  for _, win in ipairs(windows) do
    assert(api.nvim_win_is_valid(win.win), "Window has closed")
    assert(api.nvim_win_get_buf(win.win) == win.buf, "Window contents changed; choose the target again")
    assert(not vim.bo[win.buf].modified or win.terminal, "Save modified files before closing this target")
    if win.terminal then
      terminals[win.buf] = true
    end
  end
  for buf in pairs(terminals) do
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      assert(
        api.nvim_win_get_tabpage(win) == item.tab and (not item.win or win == item.win),
        "Terminal is displayed elsewhere; close its other view first"
      )
    end
  end
  -- Check all guards before closing a pane or stopping any job.
  if item.win then
    if
      #tiled_windows(item.tab) == 1
      and #api.nvim_list_tabpages() == 1
      and api.nvim_win_get_config(item.win).relative == ""
    then
      api.nvim_win_call(item.win, function()
        vim.cmd.enew()
      end)
    else
      api.nvim_win_close(item.win, false)
    end
  else
    if #api.nvim_list_tabpages() == 1 then
      M.create(item.root)
    end
    vim.cmd.tabclose(tostring(api.nvim_tabpage_get_number(item.tab)))
  end
  for buf in pairs(terminals) do
    stop_terminal(buf)
  end
end

-- Native mksession preserves editor layout/cursors; terminal/options/globals are
-- excluded so restoring never launches a shell, agent, or captured option code.
function M.save()
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
    for _, item in ipairs(session.windows) do
      if not item.terminal then
        titles[api.nvim_buf_get_name(item.buf)] = vim.w[item.win].ainvim_name
      end
    end
    metadata[#metadata + 1] = { name = session.name, root = session.root, titles = titles }
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
    for index, tab in ipairs(api.nvim_list_tabpages()) do
      local session = saved.sessions[index]
      if session then
        api.nvim_tabpage_set_var(tab, "ainvim_name", session.name)
        api.nvim_tabpage_set_var(tab, "ainvim_root", session.root)
        for _, win in ipairs(M.windows(tab)) do
          vim.w[win.win].ainvim_name = session.titles[api.nvim_buf_get_name(win.buf)]
        end
      end
    end
  end
  M.restoring = false
  assert(ok, err)
end
function M.setup()
  local group = api.nvim_create_augroup("ainvim_sessions", { clear = true })
  api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      local win = api.nvim_get_current_win()
      if editable(win) then
        api.nvim_tabpage_set_var(0, "ainvim_focus", win)
      end
    end,
  })
  api.nvim_create_autocmd("TermOpen", {
    group = group,
    callback = function(event)
      vim.b[event.buf].ainvim_owner = api.nvim_get_current_tabpage()
    end,
  })
  api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = function()
      vim.schedule(function()
        for _, buf in ipairs(api.nvim_list_bufs()) do
          local owner = vim.b[buf].ainvim_owner
          if owner and not api.nvim_tabpage_is_valid(owner) then
            stop_terminal(buf)
            vim.b[buf].ainvim_owner = nil
          end
        end
      end)
    end,
  })
  api.nvim_create_user_command("AiSession", function(args)
    local ok, err = pcall(M.create, args.args ~= "" and args.args or vim.fn.getcwd())
    if not ok then
      vim.notify(tostring(err), vim.log.levels.ERROR)
    end
  end, { nargs = "?", complete = "dir", desc = "Open a native session for an existing project/worktree" })
  api.nvim_create_user_command("AiSessionRestore", function()
    local ok, err = pcall(M.restore)
    if not ok then
      vim.notify(tostring(err), vim.log.levels.WARN)
    end
  end, { desc = "Restore the saved editor layout without starting terminals" })
end
return M
