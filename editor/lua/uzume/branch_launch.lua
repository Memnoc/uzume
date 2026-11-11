-- Choose an explicit starting branch and inspect saved-state advisories before launch.
local M = {}
local api = vim.api
local script = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))))
  .. "/agent/branches.py"
local function run(fn)
  require("uzume.context").run(fn, "Uzume agents")
end
local function read(project, done)
  vim.system(
    { "python3", script, project.root },
    { text = true, timeout = 30000 },
    vim.schedule_wrap(function(result)
      run(function()
        assert(result.code == 0, vim.trim(result.stderr))
        done(vim.json.decode(result.stdout))
      end)
    end)
  )
end
local function saved(entry)
  if not entry.cwd then
    return
  end
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if
      vim.bo[buf].buftype == ""
      and vim.bo[buf].modified
      and vim.startswith(api.nvim_buf_get_name(buf), entry.cwd .. "/")
    then
      error("Save the modified buffer before launching: " .. api.nvim_buf_get_name(buf))
    end
  end
end
function M.open(kind, opts)
  opts = opts or {}
  assert(kind == "codex" or kind == "claude", "Choose Codex or Claude")
  local project = assert(require("ainvim.projects").current(), "Open a project first: Space ap")
  local file, relative, source
  if not opts.empty then
    file = require("uzume.context").file()
    relative, source = require("uzume.worktrees").relative_file(project, file)
    assert(
      relative,
      "This file is outside this project's checkouts.\nSpace ae / aE: start an empty workspace.\nSpace af: mark it as a reference."
    )
  end
  source = source or (vim.t.uzume_task or {}).cwd or project.root
  local origin = api.nvim_get_current_win()
  read(project, function(entries)
    if not api.nvim_win_is_valid(origin) or api.nvim_get_current_win() ~= origin then
      return vim.notify(
        "Launch cancelled because focus moved; choose the task branch again.",
        vim.log.levels.INFO,
        { title = "Uzume agents" }
      )
    end
    table.sort(entries, function(a, b)
      if (a.cwd == source) ~= (b.cwd == source) then
        return a.cwd == source
      end
      return a.branch < b.branch
    end)
    Snacks.picker({
      title = "Choose task branch",
      items = vim.tbl_map(function(entry)
        local problems = entry.conflicts and " · CONFLICTS" or entry.operation and (" · " .. entry.operation) or ""
        return {
          text = entry.branch .. " · " .. entry.changes .. " saved changes" .. problems,
          entry = entry,
          preview = {
            text = table.concat({
              "Ctrl-s  New task from this branch",
              "Enter   Choose new task or continue",
              "Esc     Cancel",
              "",
              "Branch: " .. entry.branch,
              "Checkout: "
                .. (entry.cwd and vim.fn.fnamemodify(entry.cwd, ":~") or "No checkout; uses committed files"),
              "Changed files: " .. entry.changes,
              "",
              "New task creates a separate branch with these saved files.",
              "Continue reopens an existing task with its edits.",
              "",
              table.concat(entry.files, "\n"),
            }, "\n"),
            ft = "text",
          },
        }
      end, entries),
      format = "text",
      preview = "preview",
      layout = { preset = "default" },
      win = {
        input = {
          footer = " Ctrl-s new task · Enter actions · Esc cancel ",
          footer_pos = "center",
          keys = { ["<c-s>"] = { "new_task", mode = { "i", "n" }, desc = "New task from selected branch" } },
        },
        list = { keys = { ["<c-s>"] = { "new_task", desc = "New task from selected branch" } } },
        preview = { wo = { wrap = true, linebreak = true, breakindent = true, number = false, relativenumber = false } },
      },
      actions = {
        new_task = function(picker)
          picker.opts.confirm(picker, picker:current(), true)
        end,
      },
      confirm = function(picker, row, new_task)
        picker:close()
        if not row then
          return
        end
        vim.schedule(function()
          run(function()
            local entry = row.entry
            assert(not entry.unavailable, "This checkout is unavailable; repair its worktree before launching")
            assert(
              not entry.conflicts and not entry.operation,
              "Resolve conflicts or finish the Git operation before launching on " .. entry.branch
            )
            saved(entry)
            local task
            for _, window in ipairs(project.windows) do
              local known = vim.t[window.tab].uzume_task
              if known and known.branch == entry.branch and known.cwd == entry.cwd then
                task = known
                break
              end
            end
            if not task and entry.cwd and entry.base then
              task = {
                id = entry.branch:sub(7),
                branch = entry.branch,
                cwd = entry.cwd,
                base = entry.base,
                project = project.root,
                label = entry.branch:sub(7),
              }
            end
            local choices = {}
            if task then
              choices[#choices + 1] = { text = "Continue this task branch · reuse its checkout", task = task }
            end
            choices[#choices + 1] = { text = "New isolated task from this branch" }
            local function launch(choice)
              if not choice then
                return
              end
              read(project, function(fresh)
                run(function()
                  assert(api.nvim_win_is_valid(origin), "Original editor pane has closed")
                  local selected
                  for _, value in ipairs(fresh) do
                    if value.branch == entry.branch then
                      selected = value
                    end
                  end
                  assert(
                    selected
                      and selected.head == entry.head
                      and selected.token == entry.token
                      and selected.cwd == entry.cwd
                      and not selected.conflicts
                      and not selected.operation,
                    "The branch changed during selection. Choose it again to inspect the latest state."
                  )
                  saved(selected)
                  api.nvim_set_current_win(origin)
                  if file then
                    assert(
                      vim.uv.fs_realpath(api.nvim_buf_get_name(0)) == file,
                      "The selected file changed; launch again from the intended file"
                    )
                  end
                  if choice.task then
                    require("uzume.agents").continue_task(choice.task, kind, relative)
                  else
                    require("uzume.agents").start(kind, { empty = opts.empty, selection = selected })
                  end
                end)
              end)
            end
            if new_task == true then
              return launch({})
            end
            Snacks.picker.select(choices, {
              prompt = entry.branch .. " · " .. entry.changes .. " saved changes",
              format_item = function(choice)
                return choice.text
              end,
            }, launch)
          end)
        end)
      end,
    })
  end)
end
return M
