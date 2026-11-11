-- Git owns checkout creation. Uzume never removes task files or branches on close.
local M = {}

-- A project window can display the original checkout or another task's copy.
-- Resolve against owned checkouts, not just the active window's working dir.
function M.relative_file(project, file)
  local roots = { project.root }
  for _, window in ipairs(project.windows) do
    local task = vim.t[window.tab].uzume_task
    if task then
      roots[#roots + 1] = task.cwd
    end
  end
  local canonical = {}
  for _, root in ipairs(roots) do
    local path = vim.uv.fs_realpath(root)
    if path then
      canonical[#canonical + 1] = path
    end
  end
  -- Prefer the most specific checkout if one is nested inside another.
  table.sort(canonical, function(a, b)
    return #a > #b
  end)
  for _, root in ipairs(canonical) do
    if vim.startswith(file, root .. "/") then
      return file:sub(#root + 2), root
    end
  end
end

local function record_path(project, branch)
  return vim.fn.stdpath("data") .. "/task-branches/" .. vim.fn.sha256(project .. "\n" .. branch) .. ".json"
end

function M.retained(project, entry)
  local ok, task = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(record_path(project, entry.branch)), "\n"))
  end)
  if
    ok
    and type(task) == "table"
    and task.project == project
    and task.branch == entry.branch
    and task.cwd == entry.cwd
    and type(task.base) == "string"
  then
    return task
  end
end

function M.create(project, label, done, source, selection, branch)
  source = source or project
  local slug = label:lower():gsub("[^a-z0-9]+", "-"):gsub("^-", ""):gsub("-$", ""):sub(1, 40)
  slug = slug ~= "" and slug or "task"
  local id = slug .. "-" .. vim.fn.sha256(project .. tostring(vim.uv.hrtime()) .. vim.fn.getpid()):sub(1, 10)
  local parent = vim.fn.stdpath("data") .. "/worktrees/" .. vim.fn.sha256(project):sub(1, 16)
  vim.fn.mkdir(parent, "p", 448)
  local task =
    { id = id, label = label, project = project, cwd = parent .. "/" .. id, branch = branch or "uzume/" .. id }
  local script = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))))
    .. "/agent/create_worktree.py"
  local command = { "python3", script, source, task.cwd, task.branch }
  if selection then
    command[#command + 1] = vim.json.encode(selection)
  end
  vim.system(
    command,
    { text = true, timeout = 120000 },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        return done(
          nil,
          "Could not create task worktree: "
            .. vim.trim(result.stderr)
            .. "\nAny partial checkout is retained at "
            .. task.cwd
        )
      end
      local ok, captured = pcall(vim.json.decode, result.stdout)
      if not ok then
        return done(nil, "Could not read inherited task state; checkout retained at " .. task.cwd)
      end
      task = vim.tbl_extend("force", task, captured)
      if branch then
        local path = record_path(project, branch)
        vim.fn.mkdir(vim.fs.dirname(path), "p", 448)
        vim.fn.writefile({ vim.json.encode(task) }, path)
        vim.fn.setfperm(path, "rw-------")
      end
      done(task)
    end)
  )
end

return M
