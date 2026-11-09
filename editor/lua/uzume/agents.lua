-- Task ownership and UI live here; process supervision stays outside Neovim.
local M = { instances = {} }
local api = vim.api
local attention = { waiting = true, review = true, failed = true }
local supervisor = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))))
  .. "/agent/supervisor.py"

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Uzume agents" })
end

local function read(path)
  local ok, value = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end)
  return ok and type(value) == "table" and value or nil
end

local function alive(item)
  return item.job and vim.fn.jobwait({ item.job }, 0)[1] == -1
end

function M.window_status(tab)
  for _, item in pairs(M.instances) do
    if item.tab == tab then
      return vim.tbl_extend("force", item.status, { kind = item.kind })
    end
  end
end

function M.list()
  local result = {}
  for _, item in pairs(M.instances) do
    if api.nvim_tabpage_is_valid(item.tab) then
      result[#result + 1] = item
    end
  end
  table.sort(result, function(a, b)
    if not not attention[a.status.state] ~= not not attention[b.status.state] then
      return attention[a.status.state] or false
    end
    return a.status.since < b.status.since
  end)
  return result
end

function M.summary()
  local count, needs = 0, 0
  for _, item in ipairs(M.list()) do
    count = count + 1
    needs = needs + (attention[item.status.state] and 1 or 0)
  end
  local summary = count > 0 and ("Agents " .. count .. (needs > 0 and " · " .. needs .. " need you" or "")) or ""
  local task = vim.t.uzume_task
  local item = task and M.instances[task.id]
  local context = item and item.task.context
  if context and #context.files > 0 then
    summary = summary
      .. " · Files "
      .. #context.files
      .. (item.status.context_revision == context.revision and " supplied" or " pending")
  end
  return summary
end

function M.focus(item)
  assert(api.nvim_tabpage_is_valid(item.tab), "Task window has closed")
  api.nvim_set_current_tabpage(item.tab)
  for _, pane in ipairs(require("ainvim.panes").hidden(item.tab)) do
    if pane.buf == item.buf then
      require("ainvim.panes").restore(pane)
      return
    end
  end
  for _, win in ipairs(api.nvim_tabpage_list_wins(item.tab)) do
    if api.nvim_win_get_buf(win) == item.buf then
      api.nvim_set_current_win(win)
      return
    end
  end
  notify("Agent pane closed; Space ar starts a fresh CLI in this task's worktree")
end

function M.pick()
  local items = M.list()
  if #items == 0 then
    return notify("No agents yet · Space ac: Codex · Space aC: Claude")
  end
  Snacks.picker.select(items, {
    prompt = "Agents · Enter focus · Esc cancel",
    format_item = function(item)
      local age = math.max(0, os.time() - math.floor(item.status.since))
      return string.format(
        "%s / %s · %s · %s (%ds) · %s",
        item.project_name,
        item.task.label,
        item.kind,
        item.status.state,
        age,
        item.status.reason
      )
    end,
  }, function(item)
    if item then
      require("ainvim.panes").run(function()
        M.focus(item)
      end)
    end
  end)
end

local function dependencies(kind)
  assert(kind == "codex" or kind == "claude", "Choose Codex or Claude")
  local executable, python = vim.fn.exepath(kind), vim.fn.exepath("python3")
  assert(executable ~= "", "Install " .. kind .. " and log in using its official CLI")
  assert(python ~= "", "Agent supervision requires Python 3")
  assert(vim.fn.executable("git") == 1, "Task worktrees require Git")
  return executable, python
end

local function launch(task, tab, project_name, kind)
  local executable, python = dependencies(kind)
  local run = task.id .. "-" .. tostring(vim.uv.hrtime())
  local directory = vim.fn.stdpath("state") .. "/agents/" .. run
  vim.fn.mkdir(directory, "p", 448)
  local fd = assert(vim.uv.fs_open(directory .. "/launch.json", "w", 384))
  assert(vim.uv.fs_write(fd, vim.json.encode({ kind = kind, executable = executable, cwd = task.cwd }), 0))
  vim.uv.fs_close(fd)
  vim.cmd("botright vnew")
  local buf = api.nvim_get_current_buf()
  local item = {
    task = task,
    tab = tab,
    buf = buf,
    kind = kind,
    project_name = project_name,
    directory = directory,
    status = { state = "starting", reason = "Starting CLI", since = os.time() },
  }
  require("uzume.context").write(item)
  local job = vim.fn.jobstart({ python, supervisor, directory }, {
    term = true,
    cwd = task.cwd,
    on_exit = function(_, code)
      vim.schedule(function()
        item.exited = true
        item.status = read(directory .. "/state.json")
          or {
            state = code == 0 and "stopped" or "failed",
            since = os.time(),
            reason = "CLI exited; inspect terminal output",
          }
        if item.status.state ~= "stopped" and item.status.state ~= "failed" then
          item.status = {
            state = code == 0 and "stopped" or "failed",
            since = os.time(),
            reason = "Agent terminal closed; files retained",
          }
        end
        if item.status.state == "failed" and api.nvim_tabpage_is_valid(tab) then
          notify(item.task.label .. ": agent exited with an error; inspect its terminal", vim.log.levels.WARN)
        elseif item.status.state == "stopped" and vim.v.exiting == vim.NIL then
          require("ainvim.panes").remove_exited_terminal(buf)
        end
      end)
    end,
  })
  assert(job > 0, "Could not start agent supervisor; worktree retained at " .. task.cwd)
  item.job = job
  M.instances[task.id] = item
  vim.b[buf].uzume_agent_id = task.id
  vim.b[buf].uzume_agent_kind = kind
  vim.b[buf].uzume_agent_label = (kind == "codex" and "Codex" or "Claude") .. " · " .. task.label
  vim.b[buf].ainvim_owner = tab
  vim.bo[buf].bufhidden = "hide"
  vim.w.ainvim_name = kind .. " · " .. task.label
  -- Single Escape/jk/C-w belong to the CLI. Double Escape enters editor mode.
  for _, key in ipairs({ "<Esc>", "jk", "<C-w>" }) do
    vim.keymap.set("t", key, key, { buffer = buf, nowait = key ~= "<Esc>" })
  end
  vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { buffer = buf, desc = "Agent: editor controls" })
  vim.cmd.startinsert()
  return item
end

function M.start(kind, opts, done)
  dependencies(kind)
  opts = opts or {}
  assert(type(opts) == "table", "Use :UzumeAgent codex or :UzumeAgent codex empty; enter instructions in the CLI")
  local project = assert(require("ainvim.projects").current(), "Open a project first: Space ap")
  local file, relative
  if not opts.empty then
    file = require("uzume.context").file()
    relative = assert(
      require("uzume.worktrees").relative_file(project, file),
      "This file is outside this project's checkouts.\n\n"
        .. "Space ae / aE: start an empty Codex / Claude workspace.\n"
        .. "Space af: mark the file as a reference for that agent.\n"
        .. "Space ap: open the file's own project instead."
    )
  end
  local label = file and vim.fs.basename(file) or (kind == "codex" and "Codex workspace" or "Claude workspace")
  local origin = api.nvim_get_current_win()
  require("uzume.worktrees").create(project.root, label, function(task, err)
    if not task then
      notify(err, vim.log.levels.ERROR)
      if done then
        done(nil, err)
      end
      return
    end
    local present = false
    for _, candidate in ipairs(require("ainvim.projects").list()) do
      present = present or candidate.id == project.id
    end
    if not present then
      local message = "Project closed during task creation; checkout retained at " .. task.cwd
      notify(message, vim.log.levels.WARN)
      if done then
        done(nil, message)
      end
      return
    end
    task.kind = kind
    local previous = api.nvim_get_current_win()
    local ok, result = pcall(function()
      local tab = require("ainvim.sessions").create(task.cwd, {
        name = label,
        project_name = project.name,
        project_root = project.root,
        task = task,
        empty = true,
      })
      local editor = require("uzume.task_editor").create(task)
      local selected = relative and (task.cwd .. "/" .. relative) or nil
      if selected and vim.fn.filereadable(selected) == 1 then
        vim.cmd.edit(vim.fn.fnameescape(selected))
      elseif selected then
        notify("This file is absent from committed HEAD; use the picker to choose a task file", vim.log.levels.WARN)
      end
      local item = launch(task, tab, project.name, kind)
      if selected and vim.fn.filereadable(selected) == 1 then
        require("uzume.context").add(item, { selected })
      elseif previous == origin then
        require("uzume.task_editor").pick(editor, task)
      end
      return item
    end)
    if previous ~= origin and api.nvim_win_is_valid(previous) then
      vim.cmd.stopinsert()
      api.nvim_set_current_win(previous)
    end
    if not ok then
      notify(tostring(result) .. "\nWorktree retained: " .. task.cwd, vim.log.levels.ERROR)
    else
      notify("Task ready: " .. label .. " · branch " .. task.branch)
    end
    if done then
      done(ok and result or nil, not ok and tostring(result) or nil)
    end
  end)
end

function M.restart()
  local task = assert(vim.t.uzume_task, "Select an existing AI task window first")
  local previous = M.instances[task.id]
  assert(not previous or not alive(previous), "This task already has a running agent")
  if previous and api.nvim_buf_is_valid(previous.buf) then
    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
      if api.nvim_win_get_buf(win) == previous.buf then
        api.nvim_set_current_win(win)
        require("ainvim.panes").close(win)
        break
      end
    end
  end
  return launch(task, api.nvim_get_current_tabpage(), vim.t.ainvim_project_name, task.kind)
end

local function poll()
  for _, item in pairs(M.instances) do
    if not api.nvim_tabpage_is_valid(item.tab) or not api.nvim_buf_is_valid(item.buf) then
      if alive(item) then
        pcall(vim.fn.jobstop, item.job)
      end
    elseif not item.exited then
      local status = read(item.directory .. "/state.json")
      if status and type(status.state) == "string" and type(status.since) == "number" then
        if status.state ~= item.status.state and attention[status.state] then
          notify(item.project_name .. " / " .. item.task.label .. ": " .. status.reason .. " · Space aa")
        end
        item.status = status
      end
    end
  end
end

function M.setup()
  require("uzume.agent_views").setup()
  local group = api.nvim_create_augroup("uzume_agents", { clear = true })
  local timer = assert(vim.uv.new_timer())
  timer:start(500, 500, vim.schedule_wrap(poll))
  api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      timer:stop()
      timer:close()
      local jobs = {}
      for _, item in pairs(M.instances) do
        if alive(item) then
          jobs[#jobs + 1] = item.job
          pcall(vim.fn.jobstop, item.job)
        end
      end
      if #jobs > 0 then
        vim.fn.jobwait(jobs, 1500)
      end
    end,
  })
  local function map(key, fn, desc)
    vim.keymap.set("n", "<leader>a" .. key, function()
      require("uzume.context").run(fn, desc)
    end, { desc = desc })
  end
  map("c", function()
    M.start("codex")
  end, "Codex with Current File")
  map("C", function()
    M.start("claude")
  end, "Claude with Current File")
  map("a", M.pick, "Agents / Attention")
  map("e", function()
    M.start("codex", { empty = true })
  end, "Empty Codex Workspace")
  map("E", function()
    M.start("claude", { empty = true })
  end, "Empty Claude Workspace")
  map("f", require("uzume.context").mark, "Mark Current File for Agent")
  map("F", require("uzume.context").select, "Mark Multiple Files")
  map("m", require("uzume.context").manage, "Marked Context / Remove File")
  map("d", require("uzume.context").draft, "Insert Marked Context in Prompt")
  map("r", M.restart, "Restart Task CLI (Fresh Conversation)")
  api.nvim_create_user_command("UzumeAgent", function(args)
    require("uzume.context").run(function()
      assert(
        #args.fargs == 1 or (#args.fargs == 2 and args.fargs[2] == "empty"),
        "Use :UzumeAgent codex [empty] or :UzumeAgent claude [empty]"
      )
      M.start(args.fargs[1], { empty = args.fargs[2] == "empty" })
    end)
  end, {
    nargs = "+",
    complete = function()
      return { "codex", "claude" }
    end,
  })
end

return M
