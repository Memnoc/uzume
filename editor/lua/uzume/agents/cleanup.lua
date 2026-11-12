-- Retained task management. Python verifies ownership and archives before removal.
local M = {}
local api = vim.api
local paths = require("uzume.core.paths")
local window
local function protect(fn)
  require("uzume.agents.context").run(fn, "Task cleanup")
end
local function request(project, action, values, done)
  local payload = vim.tbl_extend("force", {
    action = action,
    project = project,
    data = vim.fn.stdpath("data"),
    state = vim.fn.stdpath("state"),
  }, values or {})
  vim.system(
    { "python3", paths.file("agent/cleanup.py") },
    {
      text = true,
      stdin = vim.json.encode(payload),
      timeout = 180000,
    },
    vim.schedule_wrap(function(result)
      protect(function()
        assert(result.code == 0, vim.trim(result.stderr))
        done(vim.json.decode(result.stdout))
      end)
    end)
  )
end
local function blockers(task)
  local result = {}
  for _, tab in ipairs(api.nvim_list_tabpages()) do
    if paths.same(vim.t[tab].uzume_root, task.cwd) then
      result[#result + 1] = "Close this task's window first with Space wd (files are retained)."
      break
    end
  end
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == "" and paths.contains(task.cwd, api.nvim_buf_get_name(buf)) then
      if vim.bo[buf].modified then
        result[#result + 1] = "Save or discard unsaved task buffers yourself before removal."
        break
      elseif #vim.fn.win_findbuf(buf) > 0 then
        result[#result + 1] = "Close other panes displaying this checkout before removal."
        break
      end
    end
  end
  local review = require("uzume.review").current
  if review and paths.same(review.task.cwd, task.cwd) then
    result[#result + 1] = "Close its review first with Space vq."
  end
  return result
end
local function close()
  if window then
    window:close()
    window = nil
  end
end
local function show(title, filetype, lines, actions)
  close()
  window = Snacks.win({
    text = lines,
    enter = true,
    width = 0.82,
    height = 0.72,
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    footer = actions["?"] and " ? keys · q / Esc keep & close " or " q / Esc close ",
    footer_pos = "center",
    bo = { filetype = filetype, modifiable = false, bufhidden = "wipe" },
    wo = { wrap = true, linebreak = true, number = false, relativenumber = false },
  })
  actions.q = { close, "Close Task Details" }
  actions["<Esc>"] = actions.q
  for key, action in pairs(actions) do
    vim.keymap.set("n", key, function()
      protect(action[1])
    end, { buffer = window.buf, nowait = true, desc = action[2] })
  end
end
local function recovery(receipt)
  local task, refs = receipt.task, receipt.refs
  local target = vim.fs.dirname(task.project)
    .. "/"
    .. vim.fs.basename(task.project)
    .. "-recovered-"
    .. receipt.id:sub(1, 8)
  local quote = vim.fn.shellescape
  local commands = {
    "git -C "
      .. quote(task.project)
      .. " worktree add -b recovered/"
      .. receipt.id:sub(1, 8)
      .. " "
      .. quote(target)
      .. " "
      .. refs.head,
    "git -C " .. quote(target) .. " restore --source=" .. refs.working .. " --worktree -- .",
    "git -C " .. quote(target) .. " read-tree " .. refs.index,
  }
  show("Task recovery", "uzume_task_recovery", {
    receipt.state:upper() .. " · " .. task.branch,
    "Original checkout: " .. task.cwd,
    "",
    "A local snapshot preserves the original commit, baseline, staged and working files.",
    "Nothing was pushed. Review/feedback history is retained.",
    "",
    "To recover in a NEW directory and branch, run these commands in order:",
    "",
    commands[1],
    "",
    commands[2],
    "",
    commands[3],
    "",
    "Working snapshot: " .. refs.working,
    "Staged snapshot: " .. refs.index,
    "Original commit: " .. refs.head,
    "Task baseline: " .. refs.baseline,
    receipt.error or "",
    "Recovery refs retain Git data locally. Cleanup does not purge these archives.",
    "q / Esc close",
  }, {})
end
function M.history(project)
  project = project or assert(require("uzume.editor.projects").current(), "Open a project first").root
  request(project, "history", {}, function(items)
    if #items == 0 then
      return vim.notify("No removed task snapshots yet.", vim.log.levels.INFO, { title = "Task recovery" })
    end
    Snacks.picker.select(items, {
      prompt = "Task recovery",
      format_item = function(item)
        return item.task.branch .. " · " .. item.state .. " · " .. item.id:sub(1, 8)
      end,
    }, function(item)
      if item then
        vim.schedule(function()
          recovery(item)
        end)
      end
    end)
  end)
end
local inspect
inspect = function(project, branch)
  request(project, "inspect", { branch = branch }, function(row)
    local task = row.task
    local reasons = vim.list_extend(vim.deepcopy(row.blockers), blockers(task))
    local lines = {
      row.status .. " · " .. task.branch,
      "Checkout: " .. task.cwd,
      "Saved changes: " .. row.changes,
      "Integration destinations: " .. (#row.integrated > 0 and table.concat(row.integrated, ", ") or "None verified"),
      "",
      "q Keep task     v Review / integrate     x Remove task",
      "r Refresh      h Recovery history        ? All controls",
      "",
    }
    if #reasons > 0 then
      lines[#lines + 1] = "REMOVAL BLOCKED"
      vim.list_extend(lines, reasons)
    else
      vim.list_extend(lines, {
        "Remove deletes this checkout and local branch after saving a recovery snapshot.",
        "Staged and working contents are archived separately, including untracked files.",
        "You must type the exact branch name to confirm. Nothing is pushed.",
      })
    end
    vim.list_extend(lines, {
      "",
      "Integration recorded means this exact working snapshot was captured and its",
      "integration commit remains reachable on the listed local branch. Later edits",
      "or conflict resolutions may differ; inspect the destination when in doubt.",
    })
    local function help()
      require("uzume.ui.help").open("Task cleanup keys", {
        "q / Esc keep the task and close",
        "v review saved task changes; i in review integrates",
        "x previewed task removal, then type its exact branch name",
        "r refresh status",
        "h open recovery history",
        "Running agents, open task windows, ignored files and unfinished operations block removal.",
      })
    end
    show("Task cleanup", "uzume_task_cleanup", lines, {
      ["?"] = { help, "Task Cleanup Key Guide" },
      r = {
        function()
          inspect(project, branch)
        end,
        "Refresh Task Cleanup",
      },
      h = {
        function()
          M.history(project)
        end,
        "Task Recovery History",
      },
      v = {
        function()
          assert(
            task.baseline_known ~= false,
            "This older task has no reliable review baseline. Inspect its branch with Space ab / aB."
          )
          close()
          require("uzume.review").open(task)
        end,
        "Review Retained Task",
      },
      x = {
        function()
          local fresh = vim.list_extend(vim.deepcopy(row.blockers), blockers(task))
          assert(#fresh == 0, table.concat(fresh, "\n"))
          Snacks.input({
            prompt = "Remove task · type " .. branch,
            win = {
              footer = " Enter confirm · Esc keep ",
              footer_pos = "center",
              keys = {
                i_esc = { "<Esc>", "cancel", mode = "i", expr = false },
              },
            },
          }, function(answer)
            if not answer then
              return
            end
            protect(function()
              assert(answer == branch, "Branch name did not match. Task kept.")
              assert(#blockers(task) == 0, table.concat(blockers(task), "\n"))
              request(
                project,
                "remove",
                { branch = branch, token = row.token, confirmation = answer },
                function(receipt)
                  for _, buf in ipairs(api.nvim_list_bufs()) do
                    if
                      vim.bo[buf].buftype == ""
                      and not vim.bo[buf].modified
                      and paths.contains(task.cwd, api.nvim_buf_get_name(buf))
                    then
                      pcall(api.nvim_buf_delete, buf, {})
                    end
                  end
                  recovery(receipt)
                end
              )
            end)
          end)
        end,
        "Remove Task with Recovery Snapshot",
      },
    })
  end)
end
function M.open()
  local project = assert(require("uzume.editor.projects").current(), "Open a project first: Space ap").root
  request(project, "list", {}, function(result)
    if #result.tasks == 0 then
      return vim.notify("No retained tasks for this project.", vim.log.levels.INFO, { title = "Task cleanup" })
    end
    Snacks.picker.select(result.tasks, {
      prompt = "Retained tasks · Enter inspect",
      format_item = function(row)
        return row.task.branch .. " · " .. row.status .. (#blockers(row.task) > 0 and " · Open in editor" or "")
      end,
    }, function(row)
      if row then
        vim.schedule(function()
          inspect(project, row.task.branch)
        end)
      end
    end)
  end)
end
return M
