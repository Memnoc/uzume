-- EDITOR SPIKE: reproduce the supplied Drudwyn navigator surfaces with native floats.
local M = {}
local api = vim.api
local sessions = require("ainvim.sessions")
local ns = api.nvim_create_namespace("ainvim.navigator")
local groups = {
  Normal = { fg = "#e0def4", bg = "#191724" },
  Muted = { fg = "#6e6a86", bg = "#191724" },
  Selected = { fg = "#ea9a97", bg = "#191724", bold = true },
  Active = { fg = "#3e8fb0", bg = "#191724" },
  Border = { fg = "#e0def4", bg = "#191724" },
}
local function colors()
  for name, value in pairs(groups) do
    api.nvim_set_hl(0, "AiNav" .. name, value)
  end
end
local function clean(text)
  return tostring(text or ""):gsub("[%c]", " ")
end
local function fit(text, width)
  if width <= 0 then
    return ""
  end
  text = clean(text)
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  while vim.fn.strdisplaywidth(text .. "…") > width and text ~= "" do
    text = vim.fn.strcharpart(text, 0, vim.fn.strchars(text) - 1)
  end
  return text .. "…"
end
local function geometry(kind)
  kind = kind or (M.current and M.current.kind)
  local width =
    math.max(20, math.min(vim.o.columns - 4, math.floor(vim.o.columns * (kind == "sessions" and 0.85 or 0.9))))
  local height =
    math.max(16, math.min(vim.o.lines - 4, math.floor((vim.o.lines - 2) * (kind == "sessions" and 0.75 or 0.82))))
  return {
    relative = "editor",
    row = math.floor((vim.o.lines - height - 2) / 2),
    col = math.floor((vim.o.columns - width - 2) / 2),
    width = width,
    height = height,
    border = "single",
    style = "minimal",
    zindex = 80,
  }
end
local function age(since)
  local seconds = math.max(0, os.time() - (tonumber(since) or os.time()))
  if seconds >= 86400 then
    return math.floor(seconds / 86400) .. "d"
  end
  if seconds >= 3600 then
    return math.floor(seconds / 3600) .. "h"
  end
  if seconds >= 60 then
    return math.floor(seconds / 60) .. "m"
  end
  return seconds .. "s"
end
local function snapshot(kind)
  local all, entries = sessions.list(), {}
  for _, session in ipairs(all) do
    if kind == "sessions" then
      entries[#entries + 1] = {
        id = "s" .. session.tab,
        tab = session.tab,
        name = session.name,
        root = session.root,
        count = #session.windows,
        current = session.current,
      }
    else
      for index, win in ipairs(session.windows) do
        local entry = vim.tbl_extend(
          "force",
          win,
          { id = "w" .. win.win, index = index, session = session.name, root = session.root }
        )
        entries[#entries + 1] = entry
      end
    end
  end
  return all, entries
end
local function configure(win)
  vim.wo[win].winhighlight = "Normal:AiNavNormal,NormalFloat:AiNavNormal,FloatBorder:AiNavBorder,Cursor:AiNavNormal"
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  vim.wo[win].winblend = 0
end
function M.close()
  local s = M.current
  if not s then
    return
  end
  M.current = nil
  if s.timer then
    s.timer:stop()
    s.timer:close()
  end
  for _, win in ipairs({ s.input or -1, s.win, s.backdrop }) do
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
  end
  if api.nvim_win_is_valid(s.origin) then
    api.nvim_set_current_win(s.origin)
  end
end
local function selected(s)
  for _, item in ipairs(s.items or {}) do
    if item.id == s.selected then
      return item
    end
  end
end
local function draw()
  local s = M.current
  if not s or not api.nvim_win_is_valid(s.win) then
    return
  end
  local cfg = geometry()
  api.nvim_win_set_config(s.win, cfg)
  api.nvim_win_set_config(
    s.backdrop,
    { relative = "editor", row = 0, col = 0, width = vim.o.columns, height = vim.o.lines, zindex = 79 }
  )
  local width, height = cfg.width, cfg.height
  local all, entries = snapshot(s.kind)
  local items, query = {}, s.query:lower()
  for _, item in ipairs(entries) do
    local agent = type(item.agent) == "table" and item.agent or {}
    local search =
      table.concat({ item.name, item.session or "", item.root or "", agent.kind or "", agent.state or "" }, " "):lower()
    if query == "" or search:find(query, 1, true) then
      items[#items + 1] = item
    end
  end
  s.items, s.rows = items, {}
  if not selected(s) then
    s.selected = items[1] and items[1].id
  end
  local lines, highlights = {}, {}
  for i = 1, height do
    lines[i] = ""
  end
  local function put(row, col, text, group, maxwidth)
    if row < 0 or row >= height then
      return
    end
    text = fit(text, math.max(0, math.min(maxwidth or width, width - col)))
    local before = lines[row + 1]
    local padding = math.max(0, col - vim.fn.strdisplaywidth(before))
    local start = #before + padding
    lines[row + 1] = before .. string.rep(" ", padding) .. text
    highlights[#highlights + 1] = { row, start, #lines[row + 1], "AiNav" .. (group or "Normal") }
  end
  local function rule(row, group)
    put(row, 0, string.rep("─", width), group or "Border")
  end
  local title = s.kind == "sessions" and "SESSION NAVIGATOR" or "WORKSPACE NAVIGATOR"
  local agents, attention = 0, 0
  for _, item in ipairs(entries) do
    if type(item.agent) == "table" then
      agents = agents + 1
      if vim.tbl_contains({ "waiting", "blocked", "review", "failed" }, item.agent.state) then
        attention = attention + 1
      end
    end
  end
  local summary = s.kind == "sessions" and (#all .. " sessions · 1 current")
    or (#entries .. " windows · " .. agents .. " agents · " .. attention .. " need you")
  put(1, 1, title, "Selected")
  if width >= 70 then
    put(1, #title + 2, summary, "Muted")
  else
    put(2, 1, summary, "Muted")
  end
  rule(3)
  local footer = "n window  N session  j/k move  Enter "
    .. (s.kind == "sessions" and "switch" or "jump")
    .. "  r rename  x kill  s save  / filter  Esc close"
  if s.input then
    footer = "Type " .. (s.input_label or "text") .. "  Ctrl-u clear  Enter apply  Esc cancel"
  end
  local footer_rows = vim.fn.strdisplaywidth(footer) > width and 2 or 1
  local footer_top = height - footer_rows - 2
  rule(footer_top, "Muted")
  if footer_rows == 1 or s.input then
    put(footer_top + 1, 0, footer, "Muted")
  else
    put(
      footer_top + 1,
      0,
      "n window  N session  j/k move  Enter " .. (s.kind == "sessions" and "switch" or "jump"),
      "Muted"
    )
    put(footer_top + 2, 0, "r rename  x kill  s save  / filter  Esc close", "Muted")
  end
  local function render_rows(list, top, bottom, group_name)
    if group_name then
      put(top, 1, group_name)
      top = top + 1
    end
    local capacity = math.max(1, bottom - top)
    local index = 1
    for i, item in ipairs(list) do
      if item.id == s.selected then
        index = i
      end
    end
    local offset = math.max(0, index - capacity)
    if #list == 0 then
      put(top, 5, group_name == "AGENTS" and "No managed agents" or "No matches", "Muted")
    end
    for i = offset + 1, math.min(#list, offset + capacity) do
      local item, row = list[i], top + i - offset - 1
      s.rows[row + 1] = item.id
      local chosen = item.id == s.selected
      local main = (chosen or type(item.agent) == "table") and "Selected" or "Normal"
      local muted = chosen and "Selected" or "Muted"
      put(row, 0, chosen and "▶" or " ", main)
      if s.kind == "sessions" then
        put(row, 3, item.current and "●" or " ", chosen and "Selected" or "Active")
        put(row, 5, item.name, main, math.floor(width * 0.44) - 6)
        put(row, math.floor(width * 0.44), item.count .. (item.count == 1 and " window" or " windows"), muted, 12)
        put(row, math.floor(width * 0.44) + 13, item.current and "active · current" or "hidden", muted)
      else
        local agent = type(item.agent) == "table" and item.agent or nil
        put(row, 3, agent and "󰚩" or " ", main)
        put(row, 5, tostring(item.index), main, 4)
        put(row, 9, item.name, main, math.floor(width * 0.36) - 10)
        if agent then
          put(row, math.floor(width * 0.36), agent.kind or "Agent", main, 10)
          put(row, math.floor(width * 0.36) + 11, (agent.state or "unknown"):upper(), main, 13)
          put(row, math.floor(width * 0.36) + 25, age(agent.since), "Muted")
        else
          put(row, math.floor(width * 0.36), item.session, muted)
        end
      end
    end
    if #list > capacity then
      put(bottom, 1, string.format("%d–%d / %d", offset + 1, math.min(#list, offset + capacity), #list), "Muted")
    end
  end
  if s.kind == "sessions" then
    render_rows(items, 5, footer_top - 2)
  else
    local work, workers = {}, {}
    for _, item in ipairs(items) do
      table.insert(type(item.agent) == "table" and workers or work, item)
    end
    -- Navigation order follows the two visible groups, as in the screenshots.
    s.items = vim.list_extend(vim.deepcopy(work), workers)
    local middle = math.max(8, math.floor(height * 0.52))
    render_rows(work, 4, middle - 1, "WORKSPACES")
    rule(middle)
    render_rows(workers, middle + 1, footer_top - 2, "AGENTS")
  end
  if s.confirm then
    put(footer_top - 1, 1, "Kill " .. clean(s.confirm.name) .. "?  y confirm · n/Esc cancel", "Selected")
  elseif s.notice then
    put(footer_top - 1, 1, s.notice, "Muted")
  elseif s.query ~= "" then
    put(footer_top - 1, 1, "Filter: " .. s.query .. "  · Ctrl-u clear", "Muted")
  end
  vim.bo[s.buf].modifiable = true
  api.nvim_buf_set_lines(s.buf, 0, -1, false, lines)
  api.nvim_buf_clear_namespace(s.buf, ns, 0, -1)
  for _, hl in ipairs(highlights) do
    api.nvim_buf_set_extmark(s.buf, ns, hl[1], hl[2], { end_col = hl[3], hl_group = hl[4] })
  end
  vim.bo[s.buf].modifiable = false
  -- Keep the actual cursor off the selected label; the arrow carries selection.
  api.nvim_win_set_cursor(s.win, { 1, 0 })
  if s.input and api.nvim_win_is_valid(s.input) then
    api.nvim_win_set_config(
      s.input,
      { relative = "win", win = s.win, row = footer_top - 1, col = 1, width = width - 2, height = 1, zindex = 81 }
    )
  end
end
local function move(delta)
  local s = M.current
  if not s or s.confirm or #s.items == 0 then
    return
  end
  local index = 1
  for i, item in ipairs(s.items) do
    if item.id == s.selected then
      index = i
    end
  end
  s.selected = s.items[(index - 1 + delta) % #s.items + 1].id
  draw()
end
local function input(label, initial, live, done)
  local s = M.current
  if not s or s.input then
    return
  end
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "ainvim_navigator"
  s.input_label = label:lower()
  api.nvim_buf_set_lines(buf, 0, -1, false, { initial or "" })
  s.input = api.nvim_open_win(buf, true, {
    relative = "win",
    win = s.win,
    row = geometry().height - 4,
    col = 1,
    width = geometry().width - 2,
    height = 1,
    style = "minimal",
    zindex = 81,
  })
  configure(s.input)
  local function finish(cancel)
    local value = api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    local win = s.input
    s.input = nil
    vim.cmd.stopinsert()
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
    if M.current == s then
      api.nvim_set_current_win(s.win)
      s.notice = nil
      if not cancel and done then
        done(value)
      end
      draw()
    end
  end
  vim.keymap.set({ "n", "i" }, "<CR>", function()
    finish(false)
  end, { buffer = buf })
  vim.keymap.set({ "n", "i" }, "<Esc>", function()
    finish(true)
  end, { buffer = buf })
  vim.keymap.set({ "n", "i" }, "<C-u>", function()
    api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
    if live then
      live("")
    end
  end, { buffer = buf })
  api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    buffer = buf,
    callback = function()
      if live and M.current == s then
        live(api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "")
      end
    end,
  })
  s.notice = label .. " · Enter apply · Esc cancel"
  draw()
  vim.cmd.startinsert({ bang = true })
end
local function action(fn)
  local ok, err = pcall(fn)
  if not ok and M.current then
    M.current.notice = tostring(err)
    draw()
  end
end
function M.open(kind)
  if M.current then
    local previous = M.current.kind
    M.close()
    if previous == kind then
      return
    end
  end
  sessions.adopt()
  colors()
  local s = { kind = kind, origin = api.nvim_get_current_win(), query = "" }
  local background = api.nvim_create_buf(false, true)
  vim.bo[background].bufhidden = "wipe"
  s.backdrop = api.nvim_open_win(background, false, {
    relative = "editor",
    row = 0,
    col = 0,
    width = vim.o.columns,
    height = vim.o.lines,
    style = "minimal",
    focusable = false,
    zindex = 79,
  })
  configure(s.backdrop)
  s.buf = api.nvim_create_buf(false, true)
  vim.bo[s.buf].bufhidden = "wipe"
  vim.bo[s.buf].filetype = "ainvim_navigator"
  s.win = api.nvim_open_win(s.buf, true, geometry(kind))
  configure(s.win)
  M.current = s
  local _, entries = snapshot(kind)
  for _, item in ipairs(entries) do
    if kind == "sessions" and item.current or item.win == s.origin then
      s.selected = item.id
    end
  end
  local function map(key, fn)
    vim.keymap.set("n", key, fn, { buffer = s.buf, silent = true, nowait = true })
  end
  for _, key in ipairs({ "j", "<Down>" }) do
    map(key, function()
      move(1)
    end)
  end
  for _, key in ipairs({ "k", "<Up>" }) do
    map(key, function()
      move(-1)
    end)
  end
  for _, key in ipairs({ "q", "<Esc>" }) do
    map(key, function()
      if s.confirm then
        s.confirm = nil
        draw()
      else
        M.close()
      end
    end)
  end
  local function create(fn)
    M.close()
    local ok, err = pcall(fn)
    if not ok then
      M.open(kind)
      M.current.notice = tostring(err)
      draw()
    end
  end
  map("n", function()
    if s.confirm then
      s.confirm = nil
      draw()
      return
    end
    local item = selected(s) or { tab = api.nvim_get_current_tabpage() }
    create(function()
      sessions.new_window(item)
    end)
  end)
  map("N", function()
    if s.confirm then
      return
    end
    local item = selected(s)
    input("Directory", item and item.root or vim.fn.getcwd(), nil, function(path)
      if vim.trim(path) == "" then
        s.notice = "Choose an existing project or worktree directory"
        return
      end
      create(function()
        sessions.create(path)
      end)
    end)
  end)
  map("<CR>", function()
    if s.confirm then
      return
    end
    local item = selected(s)
    if item then
      M.close()
      local ok, err = pcall(sessions.jump, item)
      if not ok then
        vim.notify(err, vim.log.levels.WARN)
      end
    end
  end)
  map("/", function()
    if not s.confirm then
      input("Filter", s.query, function(value)
        s.query = value
        draw()
      end)
    end
  end)
  map("<C-u>", function()
    if not s.confirm then
      s.query = ""
      draw()
    end
  end)
  map("r", function()
    local item = selected(s)
    if item and not s.confirm then
      input("Rename", item.name, nil, function(name)
        action(function()
          sessions.rename(item, name)
        end)
      end)
    end
  end)
  map("x", function()
    if not s.confirm then
      s.confirm = selected(s)
      draw()
    end
  end)
  map("y", function()
    if not s.confirm then
      return
    end
    local target = s.confirm
    s.confirm = nil
    -- Close the overlay before window/tab mutation so it cannot become a leftover tab window.
    M.close()
    local ok, err = pcall(sessions.close, target)
    M.open(kind)
    M.current.notice = ok and "Closed; files retained" or tostring(err)
    draw()
  end)
  map("s", function()
    if not s.confirm then
      action(function()
        sessions.save()
        s.notice = "Saved locally · :AiSessionRestore from a fresh editor"
        draw()
      end)
    end
  end)
  map("<LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid == s.win and not s.confirm and s.rows[pos.line] then
      s.selected = s.rows[pos.line]
      draw()
    end
  end)
  map("<ScrollWheelDown>", function()
    move(1)
  end)
  map("<ScrollWheelUp>", function()
    move(-1)
  end)
  s.timer = vim.uv.new_timer()
  s.timer:start(
    1000,
    1000,
    vim.schedule_wrap(function()
      if M.current == s then
        draw()
      end
    end)
  )
  api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(s.win),
    once = true,
    callback = function()
      if M.current == s then
        vim.schedule(function()
          if M.current == s then
            M.close()
          end
        end)
      end
    end,
  })
  draw()
end
function M.setup()
  sessions.setup()
  api.nvim_create_user_command("AiSessions", function()
    M.open("sessions")
  end, { desc = "Session navigator" })
  api.nvim_create_user_command("AiWorkspaces", function()
    M.open("workspaces")
  end, { desc = "Workspace/window navigator" })
  api.nvim_create_autocmd("ColorScheme", { callback = colors })
  api.nvim_create_autocmd("VimResized", { callback = draw })
end
return M
