local paths = require("uzume.core.paths")
-- Integration is explicit and local. Git owns commit creation and conflict state.
local M = {}
local api = vim.api
local base = require("uzume.core.paths").editor
local storage = vim.fn.stdpath("state") .. "/integrations"
local window
local function protect(fn)
  require("uzume.agents.context").run(fn, "Task integration")
end
local function request(value, done)
  vim.system(
    { "python3", base .. "/review/integration.py" },
    {
      text = true,
      stdin = vim.json.encode(value),
      timeout = 180000,
    },
    vim.schedule_wrap(function(result)
      protect(function()
        assert(result.code == 0, vim.trim(result.stderr) .. "\nSpace vI reopens saved integrations.")
        done(vim.json.decode(result.stdout, { luanil = { object = true } }))
      end)
    end)
  )
end
local function saved(root)
  if not root then
    return
  end
  for _, buf in ipairs(api.nvim_list_bufs()) do
    assert(
      not (vim.bo[buf].buftype == "" and vim.bo[buf].modified and paths.contains(root, api.nvim_buf_get_name(buf))),
      "Save modified files before integrating: " .. api.nvim_buf_get_name(buf)
    )
  end
end
local function guard(task, destination)
  saved(task.cwd)
  saved(destination)
  for _, item in ipairs(require("uzume.agents").list()) do
    if not item.exited then
      assert(
        not paths.same(item.task.cwd, destination),
        "Destination belongs to a running agent. Choose a feature branch instead."
      )
      if paths.same(item.task.cwd, task.cwd) then
        local status = require("uzume.agents.input").status(item)
        assert(
          status.state == "ready" or status.state == "review",
          "Wait for this task's agent to finish before integrating."
        )
      end
    end
  end
end
function M.close()
  if window then
    window:close()
    window = nil
  end
end
local function edit(plan, path)
  saved(plan.cwd)
  M.close()
  require("uzume.review").close()
  local tab
  for _, candidate in ipairs(api.nvim_list_tabpages()) do
    if vim.t[candidate].uzume_integration and paths.same(vim.t[candidate].uzume_root, plan.cwd) then
      tab = candidate
    end
  end
  if tab then
    api.nvim_set_current_tabpage(tab)
  else
    require("uzume.editor.sessions").create(plan.cwd, {
      name = plan.branch,
      project_root = plan.project,
      project_name = vim.fs.basename(plan.project),
      empty = true,
    })
  end
  vim.t.uzume_integration = plan.record
  require("uzume.integration.conflicts").detach(api.nvim_get_current_tabpage())
  for _, win in ipairs(vim.t.uzume_resolution_wins or {}) do
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
  end
  vim.t.uzume_resolution_wins = nil
  vim.cmd.edit(vim.fn.fnameescape(plan.cwd .. "/" .. path))
  vim.cmd.diffoff()
  vim.wo.winbar = plan.state == "conflicts" and " Resolve and save · Space vi integration status · Space vI history "
    or " Integration checkout · Space vi status · Space vI history "
  vim.cmd.checktime()
end
function M.files(plan)
  local paths = #((plan or {}).conflicts or {}) > 0 and plan.conflicts or plan.paths
  Snacks.picker.select(paths, { prompt = "Integration files · " .. plan.branch }, function(path)
    if path then
      protect(function()
        edit(plan, path)
        if vim.tbl_contains(plan.conflicts or {}, path) then
          local result_win = api.nvim_get_current_win()
          request({ action = "sides", record = plan.record, path = path }, function(sides)
            if not api.nvim_win_is_valid(result_win) then
              return
            end
            local wins = {}
            for index, side in ipairs({ { "DESTINATION", sides.ours }, { "TASK CHANGES", sides.theirs } }) do
              api.nvim_set_current_win(result_win)
              vim.cmd(index == 1 and "leftabove vsplit" or "rightbelow vsplit")
              local buf = api.nvim_create_buf(false, true)
              api.nvim_win_set_buf(0, buf)
              api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(side[2], "\n", { plain = true }))
              vim.bo[buf].bufhidden = "wipe"
              vim.bo[buf].modifiable = false
              vim.bo[buf].filetype = vim.filetype.match({ filename = path }) or "text"
              vim.wo.winbar = " " .. side[1] .. " · read only "
              vim.cmd.diffthis()
              wins[#wins + 1] = api.nvim_get_current_win()
            end
            vim.t.uzume_resolution_wins = wins
            api.nvim_set_current_win(result_win)
            vim.cmd.diffthis()
            vim.wo.foldenable = false
            require("uzume.integration.conflicts").attach(result_win, wins, {
              files = function()
                M.files(plan)
              end,
              finish = function()
                guard(plan.task, plan.cwd)
                request({ action = "finish", record = plan.record }, M.show)
              end,
            })
          end)
        end
      end)
    end
  end)
end
function M.show(plan)
  M.close()
  if (plan.state == "integrated" or plan.state == "aborted") and vim.t.uzume_integration == plan.record then
    require("uzume.integration.conflicts").detach(api.nvim_get_current_tabpage(), true)
  end
  M.current = plan
  local lines = {
    plan.state:upper() .. " · Local integration",
    "Task: " .. plan.task.branch,
    "Destination: " .. plan.branch .. (plan.new and " (new branch)" or ""),
    "Starting commit: " .. plan.head:sub(1, 10) .. " · " .. plan.source_branch,
    "Checkout: " .. (plan.cwd or plan.worktree),
    "",
  }
  if plan.state == "preview" then
    vim.list_extend(lines, {
      "Apply creates one local commit with the reviewed changes below.",
      "Task files and branch are retained. Nothing is pushed.",
      "",
    })
    for _, file in ipairs(plan.files) do
      lines[#lines + 1] = file.status .. " · " .. file.display
      vim.list_extend(lines, vim.split(file.patch, "\n", { plain = true }))
    end
  elseif plan.state == "integrated" then
    vim.list_extend(lines, {
      "Commit: " .. plan.commit,
      "Ready for combined testing in " .. plan.branch .. ".",
      "Push and PR creation are separate actions.",
    })
  elseif plan.state == "aborted" then
    vim.list_extend(
      lines,
      { "Integration aborted. The destination is back at its starting commit.", "Task branch and files are retained." }
    )
  else
    vim.list_extend(lines, { "Resolve conflict files, save them, then continue.", plan.error or "", "" })
    vim.list_extend(lines, plan.conflicts or {})
  end
  local footer = plan.state == "preview" and " [a] Integrate locally · [q] Back "
    or (
      (plan.state == "conflicts" or plan.state == "paused" or plan.state == "applying")
        and " [f] Resolve files · [c] Continue · [x] Abort · [r] Refresh · [q] Back "
      or " [f] Open files · [q] Back "
    )
  window = Snacks.win({
    text = table.concat(lines, "\n"),
    enter = true,
    width = 0.85,
    height = 0.8,
    border = "rounded",
    title = " Integrate task ",
    title_pos = "center",
    footer = footer,
    footer_pos = "center",
    zindex = 85,
    bo = { filetype = "uzume_integration", modifiable = false, bufhidden = "wipe" },
    wo = { wrap = true, linebreak = true, number = false, relativenumber = false },
  })
  local function map(key, fn)
    vim.keymap.set("n", key, function()
      protect(fn)
    end, { buffer = window.buf, nowait = true })
  end
  local function mutate(action)
    guard(plan.task, plan.cwd)
    request({ action = action, record = plan.record }, function(updated)
      M.show(updated)
      if updated.state == "conflicts" then
        M.files(updated)
      end
    end)
  end
  map("q", M.close)
  map("<Esc>", M.close)
  map("r", function()
    request({ action = "status", record = plan.record }, M.show)
  end)
  if plan.state == "preview" then
    map("a", function()
      mutate("apply")
    end)
  else
    map("f", function()
      M.files(plan)
    end)
  end
  if plan.state == "conflicts" or plan.state == "paused" or plan.state == "applying" then
    map("c", function()
      mutate("finish")
    end)
    map("x", function()
      Snacks.picker.select(
        { "Keep resolving", "Abort integration and discard resolution edits" },
        { prompt = "Abort " .. plan.branch .. " integration?" },
        function(choice)
          if choice and vim.startswith(choice, "Abort") then
            protect(function()
              mutate("abort")
            end)
          end
        end
      )
    end)
  end
end
function M.open()
  protect(function()
    if vim.t.uzume_integration then
      return request({ action = "status", record = vim.t.uzume_integration }, M.show)
    end
    local review = require("uzume.review").current
    assert(review and review.snapshot, "Open a task review first: Space vr, then Space vi.")
    local task = vim.deepcopy(review.task)
    guard(task)
    vim.system(
      { "python3", base .. "/agent/branches.py", task.project },
      { text = true },
      vim.schedule_wrap(function(result)
        protect(function()
          assert(result.code == 0, vim.trim(result.stderr))
          local choices = { { text = "New feature branch…", new = true } }
          for _, entry in ipairs(vim.json.decode(result.stdout)) do
            if entry.branch ~= task.branch then
              choices[#choices + 1] = {
                text = entry.branch .. " · " .. entry.changes .. " local changes",
                branch = entry.branch,
                cwd = entry.cwd,
              }
            end
          end
          local function prepare(choice, branch)
            if not branch or vim.trim(branch) == "" then
              return
            end
            guard(task, choice.cwd)
            request({
              action = "prepare",
              task = task,
              fingerprint = review.snapshot.fingerprint,
              branch = vim.trim(branch),
              new = choice.new == true,
              storage = storage,
              worktrees = vim.fn.stdpath("data") .. "/integration-worktrees/" .. vim.fn.sha256(task.project):sub(1, 16),
            }, M.show)
          end
          Snacks.picker.select(choices, {
            prompt = "Integration destination",
            format_item = function(row)
              return row.text
            end,
          }, function(choice)
            if not choice then
              return
            end
            if choice.new then
              Snacks.input(
                { prompt = "New feature branch", win = { footer = " Enter preview · Esc cancel " } },
                function(branch)
                  protect(function()
                    prepare(choice, branch)
                  end)
                end
              )
            else
              protect(function()
                prepare(choice, choice.branch)
              end)
            end
          end)
        end)
      end)
    )
  end)
end
function M.history()
  local project = require("uzume.editor.projects").current()
  local entries = {}
  for _, path in ipairs(vim.fn.glob(storage .. "/*.json", false, true)) do
    local ok, value = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"), { luanil = { object = true } })
    end)
    if ok and project and value.project == project.root then
      entries[#entries + 1] = value
    end
  end
  Snacks.picker.select(entries, {
    prompt = "Local integrations",
    format_item = function(row)
      return row.branch .. " · " .. row.state .. " · " .. row.task.label
    end,
  }, function(plan)
    if plan then
      request({ action = "status", record = plan.record }, M.show)
    end
  end)
end
function M.setup()
  vim.keymap.set("n", "<leader>vi", M.open, { desc = "Integrate Task / Continue Integration" })
  vim.keymap.set("n", "<leader>vI", M.history, { desc = "Local Integration History" })
  api.nvim_create_user_command("UzumeIntegrate", M.open, {})
end
return M
