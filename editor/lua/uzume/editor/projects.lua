-- EDITOR SPIKE: projects group native tabs (product windows); native windows are panes.
local M = { last = {} }
local api = vim.api
local native = require("uzume.editor.sessions")

local function canonical(path)
  path = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
  return vim.uv.fs_realpath(path) or path:gsub("/$", "")
end

function M.list()
  local projects, by_root = {}, {}
  for _, window in ipairs(native.list()) do
    if not vim.t[window.tab].uzume_unassigned then
      local root = canonical(vim.t[window.tab].uzume_project_root or window.root)
      local project = by_root[root]
      if not project then
        project = {
          id = root,
          root = root,
          name = vim.t[window.tab].uzume_project_name or vim.fs.basename(root),
          windows = {},
          current = false,
        }
        by_root[root] = project
        projects[#projects + 1] = project
      end
      project.windows[#project.windows + 1] = {
        id = "w" .. window.tab,
        tab = window.tab,
        root = window.root,
        project = root,
        name = window.name,
        panes = window.windows,
        current = window.current,
        agent = require("uzume.agents").window_status(window.tab),
      }
      project.current = project.current or window.current
    end
  end
  for _, project in ipairs(projects) do
    project.tab = project.windows[1].tab
    for _, window in ipairs(project.windows) do
      if window.tab == M.last[project.id] or window.current then
        project.tab = window.tab
      end
    end
  end
  return projects
end

function M.current()
  native.adopt()
  for _, project in ipairs(M.list()) do
    if project.current then
      return project
    end
  end
end

function M.jump(item)
  local tab = item.tab
  if item.kind == "project" then
    for _, project in ipairs(M.list()) do
      if project.id == item.project then
        tab = project.tab
      end
    end
  end
  native.jump({ tab = tab })
end

function M.open(path)
  path = canonical(path)
  assert(vim.fn.isdirectory(path) == 1, "Choose an existing project directory")
  for _, project in ipairs(M.list()) do
    if project.root == path then
      native.jump(project)
      return project.tab
    end
  end
  local empty = vim.t.uzume_unassigned and api.nvim_get_current_tabpage() or nil
  local tab = native.create(path, { name = "Editor", project_name = vim.fs.basename(path) })
  if empty and api.nvim_tabpage_is_valid(empty) then
    vim.cmd.tabclose(tostring(api.nvim_tabpage_get_number(empty)))
  end
  return tab
end

function M.new_window(item, shell)
  local project
  for _, candidate in ipairs(M.list()) do
    if item and candidate.id == (item.project or item.id or item.root) then
      project = candidate
    end
  end
  if item and (item.project or item.id or item.root) then
    assert(project, "Project has closed; choose it again")
  else
    project = project or M.current()
  end
  assert(project, "Open a project first: Space ap, then N")
  local used = {}
  for _, window in ipairs(project.windows) do
    used[window.name] = true
  end
  local prefix, index = shell and "Shell " or "Editor ", #project.windows + 1
  while used[prefix .. index] do
    index = index + 1
  end
  return native.create(project.root, {
    name = prefix .. index,
    project_name = project.name,
    shell = shell,
  })
end

function M.rename(item, name)
  name = vim.trim(name)
  assert(name ~= "", "A name cannot be empty")
  if item.kind == "project" then
    for _, project in ipairs(M.list()) do
      if project.id == item.project then
        for _, window in ipairs(project.windows) do
          vim.t[window.tab].uzume_project_name = name
          native.refresh_home(window.tab)
        end
      end
    end
  else
    native.rename({ tab = item.tab }, name)
    native.refresh_home(item.tab)
  end
end

-- Preflight the whole close operation before removing any windows or jobs.
function M.close(item)
  local tabs = {}
  if item.kind == "project" then
    for _, project in ipairs(M.list()) do
      if project.id == item.project then
        for _, window in ipairs(project.windows) do
          tabs[window.tab] = true
        end
      end
    end
  else
    assert(api.nvim_tabpage_is_valid(item.tab), "Window has closed")
    tabs[item.tab] = true
  end
  assert(next(tabs), "Project has closed")
  local terminals = {}
  for tab in pairs(tabs) do
    local panes = native.windows(tab)
    vim.list_extend(panes, require("uzume.editor.panes").hidden(tab))
    for _, pane in ipairs(panes) do
      assert(not vim.bo[pane.buf].modified or pane.terminal, "Save modified files before closing this target")
    end
    for _, buf in ipairs(api.nvim_list_bufs()) do
      if vim.bo[buf].buftype == "terminal" and tabs[vim.b[buf].uzume_owner] then
        terminals[buf] = true
      end
    end
    for _, pane in ipairs(panes) do
      if pane.terminal then
        terminals[pane.buf] = true
      end
    end
  end
  for buf in pairs(terminals) do
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      assert(tabs[api.nvim_win_get_tabpage(win)], "Terminal is displayed in another window; close its other view first")
    end
  end
  local survivors = false
  for _, tab in ipairs(api.nvim_list_tabpages()) do
    if not tabs[tab] then
      survivors = true
    end
  end
  if not survivors then
    vim.cmd.tabnew()
    vim.t.uzume_unassigned = true
  end
  for tab in pairs(tabs) do
    require("uzume.editor.panes").forget(tab)
    vim.cmd.tabclose(tostring(api.nvim_tabpage_get_number(tab)))
  end
  for buf in pairs(terminals) do
    local job = vim.b[buf].terminal_job_id
    if job then
      pcall(vim.fn.jobstop, job)
    end
  end
  if not survivors then
    Snacks.dashboard.open({
      win = 0,
      preset = {
        keys = {
          {
            key = "p",
            desc = "Open project · N in navigator",
            action = function()
              require("uzume.editor.navigator").open("projects")
            end,
          },
          { key = "q", desc = "Quit", action = ":qa" },
        },
      },
      sections = {
        require("uzume.editor.branding").section,
        { text = "No project open", align = "center", padding = 2 },
        { section = "keys" },
      },
    })
  end
end

function M.cycle(delta)
  local project = M.current()
  assert(project, "No project open")
  for index, window in ipairs(project.windows) do
    if window.current then
      native.jump(project.windows[(index - 1 + delta) % #project.windows + 1])
      return
    end
  end
end

function M.setup()
  api.nvim_create_autocmd("TabEnter", {
    group = api.nvim_create_augroup("uzume_projects", { clear = true }),
    callback = function()
      local root = vim.t.uzume_project_root or vim.t.uzume_root
      if root and not vim.t.uzume_unassigned then
        M.last[canonical(root)] = api.nvim_get_current_tabpage()
      end
    end,
  })
  api.nvim_create_user_command("AiProject", function(args)
    local ok, err = pcall(M.open, args.args ~= "" and args.args or vim.fn.getcwd())
    if not ok then
      vim.notify(tostring(err), vim.log.levels.ERROR)
    end
  end, { nargs = "?", complete = "dir", desc = "Open a project directory" })
end

return M
