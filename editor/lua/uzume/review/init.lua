-- Stable, in-memory review. Git capture is asynchronous; no source buffer is edited.
local M = {}
local api = vim.api
local script = require("uzume.core.paths").file("review/snapshot.py")
local labels = { A = "+ Added", M = "~ Modified", D = "- Deleted", T = "~ Type changed", U = "! Unmerged" }
local function footer(state)
  return (state.stale and " New changes · R refresh " or " R refresh ")
    .. "· c comment · C list"
    .. (state.comment_count and (" (" .. state.comment_count .. ")") or "")
    .. " · s send · i integrate · f files · u diff · q close "
end
local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Task review" })
end
local function update_comments(state)
  if M.current ~= state then
    return
  end
  local ok, comments = pcall(require("uzume.review.comment_store").read, state.task)
  state.comment_count = ok and #comments or nil
  for _, win in ipairs(state.views) do
    if api.nvim_win_is_valid(win) then
      api.nvim_win_set_config(win, { footer = footer(state) })
    end
  end
end
local function lines(text)
  local result = vim.split(text, "\n", { plain = true })
  if result[#result] == "" and #result > 1 then
    table.remove(result)
  end
  return result
end
local function clear(state)
  for _, win in ipairs(state.views or {}) do
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
  end
  state.views = {}
end
function M.close()
  local state = M.current
  if not state then
    return
  end
  M.current = nil
  state.closed = true
  require("uzume.review.comments").close()
  require("uzume.review.feedback").close()
  if state.timer then
    state.timer:stop()
    state.timer:close()
  end
  if state.capture_job then
    state.capture_job:kill(15)
  end
  if state.check_job then
    state.check_job:kill(15)
  end
  if state.picker then
    state.picker:close()
  end
  clear(state)
  for win, options in pairs(state.editor_diffs or {}) do
    if api.nvim_win_is_valid(win) then
      for option, value in pairs(options) do
        vim.wo[win][option] = value
      end
    end
  end
  -- Picker resume may retain callbacks; don't let them retain captured source.
  state.snapshot, state.picker = nil, nil
  if api.nvim_win_is_valid(state.origin) and api.nvim_get_current_tabpage() == state.tab then
    api.nvim_set_current_win(state.origin)
  end
end

-- Map unified rows to source lines so changing presentation keeps reading context.
local function patch_positions(file)
  local result, old, new = {}, 0, 0
  for row, line in ipairs(lines(file.patch)) do
    local a, b = line:match("^@@ %-(%d+),?%d* %+(%d+),?%d* @@")
    if a then
      old, new = tonumber(a), tonumber(b)
    elseif old > 0 or new > 0 then
      local prefix = line:sub(1, 1)
      if prefix == " " or prefix == "+" or prefix == "-" then
        result[row] = { before = prefix ~= "+" and old or nil, after = prefix ~= "-" and new or nil }
      end
      if prefix == " " or prefix == "-" then
        old = old + 1
      end
      if prefix == " " or prefix == "+" then
        new = new + 1
      end
    end
  end
  return result
end
local function remember(state)
  local win = api.nvim_get_current_win()
  if not vim.tbl_contains(state.views or {}, win) then
    return
  end
  local row = api.nvim_win_get_cursor(win)[1]
  if state.mode == "unified" then
    local position = patch_positions(state.snapshot.files[state.index])[row]
    if position then
      state.position = { side = position.after and "after" or "before", line = position.after or position.before }
    end
  else
    state.position = { side = win == state.views[1] and "before" or "after", line = row }
  end
end

function M.comment()
  local state = M.current
  if not state or not state.snapshot or not vim.tbl_contains(state.views, api.nvim_get_current_win()) then
    return notify("Select lines in a review pane first.", vim.log.levels.WARN)
  end
  local file = state.snapshot.files[state.index]
  if file.note then
    return notify("This file has no text preview to comment on.", vim.log.levels.WARN)
  end
  local first, last = api.nvim_win_get_cursor(0)[1], api.nvim_win_get_cursor(0)[1]
  local mode = api.nvim_get_mode().mode
  if mode == "\22" then
    return notify("Use a line or character selection for review comments.", vim.log.levels.WARN)
  end
  if mode == "v" or mode == "V" then
    first = vim.fn.getpos("v")[2]
    if first > last then
      first, last = last, first
    end
    api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
  end
  local selected = { before = {}, after = {} }
  if state.mode == "unified" then
    local positions = patch_positions(file)
    for row = first, last do
      local position = positions[row]
      if not position then
        return notify("Select code lines within one diff hunk, excluding headers.", vim.log.levels.WARN)
      end
      for _, side in ipairs({ "before", "after" }) do
        if position[side] then
          selected[side][#selected[side] + 1] = position[side]
        end
      end
    end
  else
    local side = api.nvim_get_current_win() == state.views[1] and "before" or "after"
    if file[side] == "" then
      return notify("This side is empty; select code on the other side.", vim.log.levels.WARN)
    end
    for row = first, last do
      selected[side][#selected[side] + 1] = row
    end
  end
  local anchor = {}
  for _, side in ipairs({ "before", "after" }) do
    local rows = selected[side]
    if #rows > 0 then
      local source = lines(file[side])
      local excerpt = {}
      for _, row in ipairs(rows) do
        excerpt[#excerpt + 1] = source[row]
      end
      anchor[side] = { first = rows[1], last = rows[#rows], lines = excerpt }
    end
  end
  require("uzume.review.comments").add(state, file, anchor, function()
    update_comments(state)
  end)
end
function M.comments()
  if not M.current or not M.current.snapshot then
    return notify("Open a task review first: Space vr.", vim.log.levels.WARN)
  end
  local state = M.current
  require("uzume.review.comments").list(state, function()
    update_comments(state)
  end)
end

function M.show(index)
  local state = M.current
  if not state or not state.snapshot then
    return
  end
  local file = state.snapshot.files[index or state.index or 1]
  if not file then
    return M.files()
  end
  state.index = index or state.index or 1
  clear(state)
  -- Native diff groups are per tab, including floating windows. Temporarily
  -- exclude existing editor comparisons and restore their options on close.
  state.editor_diffs = state.editor_diffs or {}
  for _, win in ipairs(api.nvim_tabpage_list_wins(state.tab)) do
    if vim.wo[win].diff then
      state.editor_diffs[win] =
        { diff = true, scrollbind = vim.wo[win].scrollbind, cursorbind = vim.wo[win].cursorbind }
      vim.wo[win].diff, vim.wo[win].scrollbind, vim.wo[win].cursorbind = false, false, false
    end
  end
  local width = math.max(12, vim.o.columns - 6)
  local height = math.max(3, vim.o.lines - 8)
  local split = state.mode == "split" and not file.note
  local function pane(text, title, col, pane_width, ft)
    local buf = api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden, vim.bo[buf].swapfile = "wipe", false
    vim.bo[buf].undofile, vim.bo[buf].undolevels = false, -1
    api.nvim_buf_set_lines(buf, 0, -1, false, lines(text))
    vim.bo[buf].modifiable, vim.bo[buf].readonly = false, true
    local win = api.nvim_open_win(buf, true, {
      relative = "editor",
      row = 2,
      col = col,
      width = pane_width,
      height = height,
      style = "minimal",
      border = "rounded",
      title = " " .. title .. " ",
      title_pos = "center",
      footer = footer(state),
      footer_pos = "center",
    })
    state.views[#state.views + 1] = win
    vim.wo[win].wrap, vim.wo[win].number, vim.wo[win].cursorline = false, true, true
    vim.bo[buf].filetype = ft or "text"
    for key, action in pairs({ q = M.close, f = M.files, u = M.toggle, R = M.refresh, C = M.comments, s = M.send }) do
      vim.keymap.set("n", key, action, { buffer = buf, nowait = true, desc = "Review: " .. key })
    end
    vim.keymap.set("n", "i", function()
      require("uzume.integration").open()
    end, { buffer = buf, desc = "Integrate reviewed task" })
    vim.keymap.set({ "n", "x" }, "c", M.comment, { buffer = buf, desc = "Comment on review lines" })
    vim.keymap.set("n", "<Tab>", function()
      for index, view in ipairs(state.views) do
        if view == api.nvim_get_current_win() then
          api.nvim_set_current_win(state.views[index % #state.views + 1])
          return
        end
      end
    end, { buffer = buf, desc = "Switch review side" })
    if split then
      api.nvim_win_call(win, function()
        vim.cmd.diffthis()
      end)
      vim.wo[win].foldenable = false
    end
    return win
  end
  local title = file.display .. (state.snapshot and " · snapshot" or "")
  if split then
    local half = math.floor((width - 3) / 2)
    local ft = vim.filetype.match({ filename = file.path }) or "text"
    pane(file.before, "Base " .. state.task.base:sub(1, 7) .. " · " .. title, 2, half, ft)
    pane(file.after, "Task · " .. title, half + 5, width - half - 3, ft)
  else
    pane(file.patch, (file.note and "Preview unavailable · " or "Unified · ") .. title, 2, width, "diff")
    vim.keymap.set("n", "]c", function()
      vim.fn.search("^@@", "W")
    end, { buffer = true, desc = "Next hunk" })
    vim.keymap.set("n", "[c", function()
      vim.fn.search("^@@", "bW")
    end, { buffer = true, desc = "Previous hunk" })
  end
  if state.position then
    local pos = state.position
    local win, row = state.views[#state.views], pos.line
    if split then
      win = state.views[pos.side == "before" and 1 or 2]
    else
      local distance = math.huge
      for candidate, source in pairs(patch_positions(file)) do
        if source[pos.side] and math.abs(source[pos.side] - pos.line) < distance then
          row, distance = candidate, math.abs(source[pos.side] - pos.line)
        end
      end
    end
    api.nvim_set_current_win(win)
    api.nvim_win_set_cursor(win, { math.max(1, math.min(row, api.nvim_buf_line_count(api.nvim_win_get_buf(win)))), 0 })
  end
end
function M.toggle()
  local state = M.current
  if not state or not state.snapshot then
    return
  end
  remember(state)
  state.mode = state.mode == "split" and "unified" or "split"
  M.show()
end
function M.files()
  local state = M.current
  if not state or not state.snapshot then
    return
  end
  remember(state)
  if #state.snapshot.files == 0 then
    return notify("No changes since this task started. Space vR refreshes the snapshot.")
  end
  if state.picker then
    state.picker:close()
  end
  state.picker = Snacks.picker({
    title = "Task changes · " .. state.task.label .. " · Enter review · Esc cancel",
    items = vim.tbl_map(function(file)
      return { index = file.index, path = file.path, status = file.status, text = file.text }
    end, state.snapshot.files),
    format = "text",
    preview = "none",
    layout = { preset = "select" },
    confirm = function(picker, entry)
      picker:close()
      -- Snacks closes its layout on the next tick. Replace review windows only
      -- after that cleanup, otherwise it can restore focus behind the new view.
      vim.schedule(function()
        if entry and M.current == state then
          if state.index ~= entry.index then
            state.position = nil
          end
          M.show(entry.index)
        end
      end)
    end,
  })
end
local function capture(state, refresh)
  if state.busy then
    return notify("Capturing task changes…")
  end
  state.busy = true
  state.generation = (state.generation or 0) + 1
  local origin = api.nvim_get_current_win()
  state.capture_job = vim.system(
    { "python3", script, state.task.cwd, state.task.base },
    { text = true, timeout = 30000 },
    vim.schedule_wrap(function(result)
      if M.current ~= state then
        return
      end
      state.busy = false
      state.capture_job = nil
      if result.code ~= 0 then
        return notify(vim.trim(result.stderr), vim.log.levels.ERROR)
      end
      local ok, snapshot = pcall(vim.json.decode, result.stdout)
      if not ok then
        return notify("Could not read the review snapshot.", vim.log.levels.ERROR)
      end
      if refresh and (api.nvim_get_current_win() ~= origin or api.nvim_get_current_tabpage() ~= state.tab) then
        return notify("Focus moved; the existing review was kept. Space vR refreshes when ready.")
      end
      local path = state.snapshot
        and state.snapshot.files[state.index or 1]
        and state.snapshot.files[state.index or 1].path
      state.snapshot = snapshot
      state.stale = false
      state.index = 1
      local retained = false
      for index, file in ipairs(snapshot.files) do
        file.index, file.text = index, (labels[file.status] or file.status) .. "  " .. file.display
        if file.path == path then
          state.index = index
          retained = true
        end
      end
      if not retained then
        state.position = nil
      end
      if api.nvim_get_current_win() ~= origin or api.nvim_get_current_tabpage() ~= state.tab then
        return notify("Review ready. Space vr opens the captured changes.")
      end
      if refresh and #state.views > 0 then
        if #snapshot.files == 0 then
          clear(state)
        end
        M.show()
      else
        M.files()
      end
    end)
  )
end
local function watch(state)
  state.timer = assert(vim.uv.new_timer())
  state.timer:start(
    2000,
    2000,
    vim.schedule_wrap(function()
      if
        M.current ~= state
        or state.tab ~= api.nvim_get_current_tabpage()
        or state.busy
        or state.check_job
        or state.stale
        or not state.snapshot
      then
        return
      end
      local generation = state.generation
      state.check_job = vim.system(
        { "python3", script, state.task.cwd, state.task.base, "--check" },
        { text = true, timeout = 10000 },
        vim.schedule_wrap(function(result)
          state.check_job = nil
          if M.current ~= state or result.code ~= 0 or state.busy or state.generation ~= generation then
            return
          end
          local ok, fingerprint = pcall(vim.json.decode, result.stdout)
          if ok and fingerprint ~= state.snapshot.fingerprint then
            state.stale = true
            for _, win in ipairs(state.views) do
              if api.nvim_win_is_valid(win) then
                api.nvim_win_set_config(win, { footer = footer(state) })
              end
            end
          end
        end)
      )
    end)
  )
end
function M.refresh()
  local state = M.current
  if not state then
    return M.open()
  end
  remember(state)
  capture(state, true)
end
function M.open()
  if M.current and M.current.tab == api.nvim_get_current_tabpage() then
    if M.current.snapshot then
      return M.files()
    end
    return capture(M.current)
  end
  local function start(task)
    if type(task.base) ~= "string" then
      return notify("This task has no recorded starting commit. Start a new task to review.", vim.log.levels.WARN)
    end
    if vim.fn.executable("python3") ~= 1 then
      return notify("Task review requires Python 3.", vim.log.levels.ERROR)
    end
    M.close()
    M.current = {
      task = vim.deepcopy(task),
      origin = api.nvim_get_current_win(),
      tab = api.nvim_get_current_tabpage(),
      mode = "split",
      views = {},
    }
    update_comments(M.current)
    watch(M.current)
    capture(M.current)
  end
  local task = vim.t.uzume_task
  if task then
    return start(task)
  end
  local project = require("uzume.editor.projects").current()
  local tasks = {}
  for _, window in ipairs(project and project.windows or {}) do
    if vim.t[window.tab].uzume_task then
      tasks[#tasks + 1] = vim.t[window.tab].uzume_task
    end
  end
  if #tasks == 0 then
    return notify("Open an agent task first: Space ac / aC.", vim.log.levels.WARN)
  end
  Snacks.picker.select(tasks, {
    prompt = "Review task",
    format_item = function(item)
      return item.label .. " · " .. item.branch
    end,
  }, function(item)
    if item then
      start(item)
    end
  end)
end
function M.send()
  if not M.current then
    return notify("Open a task review first: Space vr.", vim.log.levels.WARN)
  end
  require("uzume.review.feedback").open(M.current)
end
function M.setup()
  for key, mapping in pairs({
    r = { M.open, "Review Task Changes" },
    f = { M.files, "Review Files" },
    u = { M.toggle, "Toggle Unified Diff" },
    R = { M.refresh, "Refresh Review Snapshot" },
    q = { M.close, "Close Review" },
    C = { M.comments, "Review Comments" },
    s = { M.send, "Send Review Comments" },
  }) do
    vim.keymap.set("n", "<leader>v" .. key, mapping[1], { desc = mapping[2] })
  end
  vim.keymap.set({ "n", "x" }, "<leader>vc", M.comment, { desc = "Comment on Review Lines" })
  vim.keymap.set("n", "<leader>av", M.open, { desc = "Review Task Changes" })
  api.nvim_create_user_command("UzumeReview", M.open, {})
  api.nvim_create_autocmd("VimLeavePre", { callback = M.close })
  api.nvim_create_autocmd("TabClosed", {
    callback = function()
      vim.schedule(function()
        if M.current and not api.nvim_tabpage_is_valid(M.current.tab) then
          M.close()
        end
      end)
    end,
  })
  api.nvim_create_autocmd("VimResized", {
    group = api.nvim_create_augroup("uzume_review", { clear = true }),
    callback = function()
      if M.current and vim.tbl_contains(M.current.views, api.nvim_get_current_win()) then
        remember(M.current)
        M.show()
      end
    end,
  })
end
return M
