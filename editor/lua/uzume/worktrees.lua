-- Git owns checkout creation. Uzume never removes task files or branches on close.
local M = {}

local function git(root, args, done)
  local command = { "git", "-C", root }
  vim.list_extend(command, args)
  vim.system(
    command,
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        done(nil, vim.trim(result.stderr ~= "" and result.stderr or result.stdout))
      else
        done(vim.trim(result.stdout))
      end
    end)
  )
end

function M.create(project, label, done)
  git(project, { "rev-parse", "--verify", "HEAD^{commit}" }, function(base, err)
    if not base then
      return done(nil, "A task needs a Git repository with a commit: " .. err)
    end
    local slug = label:lower():gsub("[^a-z0-9]+", "-"):gsub("^-", ""):gsub("-$", ""):sub(1, 40)
    slug = slug ~= "" and slug or "task"
    local id = slug .. "-" .. vim.fn.sha256(project .. tostring(vim.uv.hrtime()) .. vim.fn.getpid()):sub(1, 10)
    local parent = vim.fn.stdpath("data") .. "/worktrees/" .. vim.fn.sha256(project):sub(1, 16)
    vim.fn.mkdir(parent, "p", 448)
    local task =
      { id = id, label = label, project = project, cwd = parent .. "/" .. id, branch = "uzume/" .. id, base = base }
    git(project, { "worktree", "add", "-b", task.branch, task.cwd, base }, function(result, failure)
      if not result then
        return done(nil, "Could not create task worktree: " .. failure)
      end
      done(task)
    end)
  end)
end

return M
