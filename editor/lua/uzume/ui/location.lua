-- Window identity belongs to its checkout, not to whichever file is displayed.
local M = {}
local api, paths, text = vim.api, require("uzume.core.paths"), require("uzume.ui.text")
local branches = {}

local function refresh(root, force)
  if not root then
    return
  end
  local cached = branches[root] or {}
  branches[root] = cached
  if cached.busy or (not force and cached.checked and vim.uv.now() - cached.checked < 2000) then
    return
  end
  cached.busy = true
  local function finish(branch)
    cached.branch, cached.busy, cached.checked = branch, false, vim.uv.now()
    vim.cmd.redrawstatus()
  end
  vim.system(
    { "git", "-C", root, "symbolic-ref", "--short", "-q", "HEAD" },
    { text = true, timeout = 2000 },
    vim.schedule_wrap(function(result)
      if result.code == 0 then
        return finish(vim.trim(result.stdout))
      end
      if result.code ~= 1 then
        return finish("No Git branch")
      end
      vim.system(
        { "git", "-C", root, "rev-parse", "--short", "HEAD" },
        { text = true, timeout = 2000 },
        vim.schedule_wrap(function(head)
          finish(head.code == 0 and ("Detached " .. vim.trim(head.stdout)) or "Branch unavailable")
        end)
      )
    end)
  )
end

function M.get(tab, buf)
  tab = tab and tab ~= 0 and tab or api.nvim_get_current_tabpage()
  buf = buf or api.nvim_get_current_buf()
  local vars = vim.t[tab]
  if vars.uzume_unassigned then
    return { kind = "No project" }
  end
  local task = vars.uzume_task
  local root = (task and task.cwd) or vars.uzume_root
  if not root then
    return { kind = "No project" }
  end
  local project = vars.uzume_project_root or (task and task.project) or root
  root = paths.canonical(root)
  refresh(root)
  local file = vim.bo[buf].buftype == "" and api.nvim_buf_get_name(buf) or ""
  return {
    project = vars.uzume_project_name or vim.fs.basename(project),
    project_root = project,
    root = root,
    window = vars.uzume_name or "Editor",
    kind = vars.uzume_integration and "Integration" or task and "Task" or "Project",
    branch = branches[root].branch or "Checking branch…",
    file = file ~= "" and file or nil,
    outside = file ~= "" and not paths.contains(root, file),
  }
end

function M.statusline()
  local info = M.get()
  if not info.root then
    return info.kind
  end
  local width = math.max(24, math.floor(vim.o.columns * 0.42))
  local project = text.fit(info.project, math.max(6, math.floor(width * 0.28)))
  local label = project .. " / " .. info.kind .. " · " .. info.branch
  return text.fit(label, width):gsub("%%", "%%%%")
end

function M.warning()
  return M.get().outside and (vim.o.columns >= 120 and "Outside checkout · Space wi" or "Outside checkout") or ""
end

function M.show()
  local info = M.get()
  -- A file opened directly has not necessarily visited a project-aware action.
  -- Adopt it on this explicit command, never while rendering the statusline or
  -- when a task already owns the checkout (including external reference files).
  if not info.root and vim.bo.buftype == "" and api.nvim_buf_get_name(0) ~= "" then
    require("uzume.editor.sessions").adopt()
    info = M.get()
  end
  if not info.root then
    return vim.notify("Open a project first with Space ap, then N.", vim.log.levels.INFO, { title = "Window context" })
  end
  refresh(info.root, true)
  local window
  local function lines()
    local branch = branches[info.root].branch or "Checking branch…"
    return {
      "Project: " .. text.clean(info.project),
      "Window: " .. text.clean(info.window),
      "Checkout type: " .. info.kind,
      "Branch: " .. text.clean(branch),
      "",
      "Active checkout: " .. text.clean(info.root),
      "Project directory: " .. text.clean(info.project_root),
      "",
      "Open file: " .. text.clean(info.file or "No file in this pane"),
      info.outside and "This file is OUTSIDE the active checkout." or "",
      info.outside and "Editing changes that file; it does not switch this window's checkout." or "",
    }
  end
  window = Snacks.win({
    text = lines(),
    width = 0.8,
    height = 0.55,
    enter = true,
    border = "rounded",
    title = " Window context ",
    title_pos = "center",
    footer = " r refresh · q / Esc close ",
    footer_pos = "center",
    bo = { filetype = "uzume_location", modifiable = false, bufhidden = "wipe" },
    wo = { wrap = true, linebreak = true, number = false, relativenumber = false },
  })
  local function render()
    if not window:valid() then
      return
    end
    vim.bo[window.buf].modifiable = true
    api.nvim_buf_set_lines(window.buf, 0, -1, false, lines())
    vim.bo[window.buf].modifiable = false
  end
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function()
      window:close()
    end, { buffer = window.buf, nowait = true, desc = "Close Window Context" })
  end
  vim.keymap.set("n", "r", function()
    refresh(info.root, true)
    render()
  end, { buffer = window.buf, desc = "Refresh Window Context" })
  local timer = assert(vim.uv.new_timer())
  timer:start(
    100,
    500,
    vim.schedule_wrap(function()
      if window:valid() then
        render()
      else
        timer:stop()
        timer:close()
      end
    end)
  )
end

function M.setup()
  api.nvim_create_autocmd(
    { "TabEnter", "BufEnter", "FocusGained", "TermLeave", "DirChanged", "BufWritePost", "CursorHold" },
    {
      group = api.nvim_create_augroup("uzume_location", { clear = true }),
      callback = function()
        refresh(M.get().root)
      end,
    }
  )
end
return M
