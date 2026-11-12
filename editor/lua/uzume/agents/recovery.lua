-- Recovery creates a new checkout; archives and existing checkouts remain intact.
local M = {}
local paths = require("uzume.core.paths")
local window, generation, restoring = nil, 0, false
local function close()
  generation = generation + 1
  if window then
    window:close()
    window = nil
  end
end
local function show(title, ft, lines, footer, actions, back)
  close()
  window = Snacks.win({
    text = lines,
    enter = true,
    width = 0.82,
    height = 0.72,
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    footer = footer,
    footer_pos = "center",
    bo = { filetype = ft, modifiable = false, bufhidden = "wipe" },
    wo = { wrap = true, linebreak = true, number = false, relativenumber = false },
    on_close = function(closed)
      if window == closed then
        generation, window = generation + 1, nil
      end
    end,
  })
  actions.q = { close, "Close Recovery View" }
  actions["<Esc>"] = back and { back, "Back to Recovery Snapshot" } or actions.q
  if back then
    actions.b = actions["<Esc>"]
  end
  for key, action in pairs(actions) do
    vim.keymap.set("n", key, function()
      require("uzume.agents.context").run(action[1], "Task recovery")
    end, { buffer = window.buf, nowait = true, desc = action[2] })
  end
end
local function run(receipt, action, values, done, failed)
  local ticket = generation
  vim.system(
    { "python3", paths.file("agent/cleanup.py") },
    {
      text = true,
      timeout = 180000,
      stdin = vim.json.encode(vim.tbl_extend("force", {
        action = action,
        project = receipt.task.project,
        archive = receipt.id,
        data = vim.fn.stdpath("data"),
        state = vim.fn.stdpath("state"),
      }, values)),
    },
    vim.schedule_wrap(function(result)
      if action == "restore" then
        restoring = false
      end
      local active = generation == ticket
      if not active and action ~= "restore" then
        return
      end
      require("uzume.agents.context").run(function()
        local ok, decoded = pcall(vim.json.decode, result.stdout)
        if result.code ~= 0 or not ok then
          local message = vim.trim(result.stderr)
          if message == "" then
            message = "Recovery could not complete. Check the attempt record before retrying."
          end
          if active then
            failed(message)
          else
            vim.notify(message, vim.log.levels.ERROR, { title = "Task recovery" })
          end
          return
        end
        done(decoded, active)
      end, "Task recovery")
    end)
  )
end
local function input(prompt, value, completion, done)
  Snacks.input({
    prompt = prompt,
    default = value,
    completion = completion,
    win = {
      footer = " Ctrl-u clear · Enter next · Esc back ",
      footer_pos = "center",
      keys = {
        i_esc = { "<Esc>", "cancel", mode = "i", expr = false },
        clear = {
          "<C-u>",
          function(win)
            vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, { "" })
            vim.api.nvim_win_set_cursor(win.win, { 1, 0 })
          end,
          mode = { "i", "n" },
          desc = "Clear Recovery Input",
        },
      },
    },
  }, function(answer)
    if answer then
      require("uzume.agents.context").run(function()
        done(vim.trim(answer))
      end, "Task recovery")
    end
  end)
end

function M.open(receipt)
  local task, refs = receipt.task, receipt.refs
  local branch = "recovered/" .. receipt.id:sub(1, 8)
  local target = vim.fs.dirname(task.project)
    .. "/"
    .. vim.fs.basename(task.project)
    .. "-recovered-"
    .. receipt.id:sub(1, 8)
  local home, configure
  local function failed(message)
    show(
      "Recovery needs attention",
      "uzume_restore_error",
      {
        message,
        "",
        "The recovery snapshot remains available.",
        "If a restore started, any partial checkout is kept at the reported path.",
        "",
        "e Edit branch / directory     Esc / b Back     q Close",
      },
      " e edit choices · Esc / b back · q close ",
      {
        e = {
          function()
            configure()
          end,
          "Edit Recovery Choices",
        },
      },
      function()
        home()
      end
    )
  end
  local function preview()
    show(
      "Check recovery destination",
      "uzume_restore_checking",
      {
        "Checking recovery snapshot and destination…",
        "Branch: " .. branch,
        "Directory: " .. target,
        "",
        "No files have been created.",
        "Esc / b Back     q Close",
      },
      " Esc / b back · q close ",
      {},
      function()
        home()
      end
    )
    run(receipt, "restore-plan", { branch = branch, target = target }, function(plan)
      branch, target = plan.branch, plan.target
      show(
        "Restore preview",
        "uzume_restore_preview",
        {
          "Snapshot: " .. task.branch .. " · " .. receipt.id:sub(1, 8),
          "New branch: " .. branch,
          "New directory: " .. target,
          "",
          "Restores the original commit, staged changes and working files, including untracked files.",
          "Existing checkouts stay as they are. The recovery snapshot is retained.",
          "After restoring, choose a recovered file in a new editor window. No agent is started.",
          "",
          "Enter Restore & open     e Edit choices     Esc / b Back     q Close",
        },
        " Enter restore & open · e edit · Esc / b back · q close ",
        {
          e = {
            function()
              configure()
            end,
            "Edit Recovery Choices",
          },
          ["<CR>"] = {
            function()
              assert(not restoring, "A recovery is already running. Wait for it to finish.")
              show("Restoring task", "uzume_restoring", {
                "Restoring to " .. branch,
                "Directory: " .. target,
                "",
                "The confirmed restore is running. Closing this view does not cancel it.",
                "If you close the view, a notification will report the result.",
              }, " q / Esc close view (restore continues) ", {})
              restoring = true
              run(
                receipt,
                "restore",
                { branch = branch, target = target, token = plan.token, confirmation = branch },
                function(result, active)
                  vim.notify(
                    "Restored " .. result.branch .. "\n" .. result.target,
                    vim.log.levels.INFO,
                    { title = "Task recovery" }
                  )
                  if not active then
                    return
                  end
                  close()
                  require("uzume.editor.sessions").create(result.target, {
                    project_root = task.project,
                    project_name = vim.fs.basename(task.project),
                    name = "Recovered · " .. result.branch,
                    empty = true,
                  })
                  Snacks.picker.files({
                    cwd = result.target,
                    title = "Recovered files · Enter open · Esc close",
                    main = { current = true },
                  })
                end,
                failed
              )
            end,
            "Restore to New Branch and Open Files",
          },
        },
        function()
          home()
        end
      )
    end, failed)
  end
  configure = function()
    assert(not restoring, "A recovery is already running. Wait for it to finish.")
    input("New recovery branch", branch, nil, function(answer)
      branch = answer
      input("New recovery directory", target, "dir", function(directory)
        target = directory
        preview()
      end)
    end)
  end
  home = function()
    local quote = vim.fn.shellescape
    show(
      "Task recovery",
      "uzume_task_recovery",
      {
        receipt.state:upper() .. " · " .. task.branch,
        "Original checkout: " .. task.cwd,
        "",
        "r Restore to a new branch     q / Esc Close",
        "",
        "Restore asks for a new branch and directory, then shows a preview before creating anything.",
        "The original commit, staged and working files are saved separately. Nothing is pushed.",
        "",
        "Manual recovery commands (choose unused names and run in order):",
        "",
        "git -C "
          .. quote(task.project)
          .. " worktree add -b "
          .. quote(branch)
          .. " "
          .. quote(target)
          .. " "
          .. refs.head,
        "",
        "git -C " .. quote(target) .. " restore --source=" .. refs.working .. " --worktree -- .",
        "",
        "git -C " .. quote(target) .. " read-tree " .. refs.index,
        "",
        "Working snapshot: " .. refs.working,
        "Staged snapshot: " .. refs.index,
        "Original commit: " .. refs.head,
        "Task baseline: " .. refs.baseline,
        "",
        "Recovery snapshots and review history remain available after restoring.",
        receipt.error or "",
      },
      " r restore to new branch · q / Esc close ",
      {
        r = { configure, "Restore Snapshot to a New Branch" },
      }
    )
  end
  home()
end
return M
