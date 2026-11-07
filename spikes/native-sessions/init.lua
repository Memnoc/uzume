-- THROWAWAY: native Neovim session/pane interaction, not production config.
local api, fn = vim.api, vim.fn
local source = assert(vim.env.AINVIM_SPIKE_SOURCE, "Launch this prototype with ./spike")
local root = assert(vim.env.AINVIM_SPIKE_ROOT)
local model = dofile(source .. "/model.lua")
local live = vim.env.AINVIM_REAL_CONFIG and vim.json.decode(table.concat(fn.readfile(vim.env.AINVIM_REAL_CONFIG), "\n"))
assert(fn.has("nvim-0.11") == 1, "The native-session spike needs Neovim 0.11+")

vim.g.mapleader = " "
vim.opt.termguicolors = true
vim.opt.mouse = "a"
vim.opt.mousemodel = "extend"
vim.opt.hidden = true
vim.opt.swapfile = false
vim.opt.undofile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.exrc = false
vim.opt.modeline = false
vim.opt.clipboard = ""
vim.opt.showtabline = 2
vim.opt.laststatus = 2
vim.opt.showmode = false
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.equalalways = false
vim.opt.scrolloff = 4
vim.opt.timeoutlen = 500
vim.opt.winminwidth = 8
vim.opt.winheight = 2
vim.opt.winminheight = 2

local colors = {
  Normal = { fg = "#e0def4", bg = "#191724" },
  NormalFloat = { fg = "#e0def4", bg = "#1f1d2e" },
  FloatBorder = { fg = "#9ccfd8", bg = "#1f1d2e" },
  FloatTitle = { fg = "#ebbcba", bg = "#1f1d2e", bold = true },
  WinSeparator = { fg = "#524f67" },
  StatusLine = { fg = "#e0def4", bg = "#26233a" },
  StatusLineNC = { fg = "#908caa", bg = "#1f1d2e" },
  TabLine = { fg = "#908caa", bg = "#1f1d2e" },
  TabLineSel = { fg = "#ebbcba", bg = "#403d52", bold = true },
  TabLineFill = { bg = "#191724" },
  CursorLine = { bg = "#26233a" },
  SpikeAttention = { fg = "#f6c177", bg = "#191724", bold = true },
}
for name, value in pairs(colors) do api.nvim_set_hl(0, name, value) end

local app = { sessions = {}, current = 1, quitting = false, real = live ~= nil }
_G.AiSpike = app -- Inspection surface for manual experiments over the local RPC socket.
local function valid(win) return win and api.nvim_win_is_valid(win) end
local function session() return app.sessions[app.current] end

local function pane_at(win)
  local s = session()
  if not s then return end
  if s.zoom and s.zoom.win == win then return s.zoom.pane end
  for _, p in ipairs(s.panes) do if p.win == win then return p end end
end

local function focused() return pane_at(api.nvim_get_current_win()) end

local function style(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].winbar = ""
  vim.wo[win].statusline = "%!v:lua.AiSpike.statusline()"
end

function app.statusline()
  local win = tonumber(vim.g.statusline_winid) or api.nvim_get_current_win()
  local p = pane_at(win)
  if not p then return " ai-nvim · throwaway spike" end
  local s = session()
  local mode = s.zoom and s.zoom.pane == p and "ZOOM" or (p.floating and "FLOAT" or "TILE")
  if p.kind == "agent" then
    local st = p.state or {}
    if live then
      return string.format(" %s · %s · %s %%= %s · pid %s ", p.name, mode,
        (st.state or "idle"):upper(), st.evidence or "not started", st.child or "—")
    end
    return string.format(" %s · %s · %s %%= pid %s / child %s · tick %s ",
      p.name, mode, (st.state or "starting"):upper(), st.pid or "…", st.child or "…", st.tick or 0)
  end
  return " " .. s.name .. " · EDITOR · " .. mode .. " %= SPC ? help · SPC a attention · SPC s sessions "
end

local function redraw()
  local parts = { "%#TabLineFill# ai-nvim / " .. (live and "PILOT" or "SPIKE") .. "  " }
  for index, s in ipairs(app.sessions) do
    if s.alive and api.nvim_tabpage_is_valid(s.tab) then
      local group = index == app.current and "TabLineSel" or "TabLine"
      parts[#parts + 1] = string.format("%%#%s#%%%dT %d %s %%T ", group, api.nvim_tabpage_get_number(s.tab), index, s.name)
    end
  end
  parts[#parts + 1] = "%#SpikeAttention#  " .. #model.attention(app.sessions) .. " need you [SPC a]"
  parts[#parts + 1] = "%#TabLineFill#%=" .. (vim.o.mouse == "" and " mouse OFF " or " mouse ON ")
  vim.o.tabline = table.concat(parts)
  vim.cmd("redrawstatus")
end

local function float_config(p)
  local g = p.geometry or { row = 3, col = math.floor(vim.o.columns * 0.2), width = math.floor(vim.o.columns * 0.65), height = math.floor(vim.o.lines * 0.55) }
  g.width = model.clamp(g.width, 16, vim.o.columns - 4)
  g.height = model.clamp(g.height, 3, vim.o.lines - 6)
  g.row = model.clamp(g.row, 1, vim.o.lines - g.height - 4)
  g.col = model.clamp(g.col, 0, vim.o.columns - g.width - 2)
  p.geometry = g
  return {
    relative = "editor", row = g.row, col = g.col, width = g.width, height = g.height,
    border = "rounded", title = " " .. p.name .. " · drag title / resize bottom edge ",
    title_pos = "center", zindex = 40,
  }
end

local function focus(p)
  if p and valid(p.win) then
    api.nvim_set_current_win(p.win)
    vim.cmd("stopinsert")
  end
end

function app.unzoom()
  local s = session()
  if not s or not s.zoom then return end
  local zoom = s.zoom
  s.zoom = nil
  if valid(zoom.win) then api.nvim_win_close(zoom.win, true) end
  for _, p in ipairs(s.panes) do
    if p.floating and valid(p.win) then api.nvim_win_set_config(p.win, { hide = false }) end
  end
  focus(zoom.pane)
end

function app.zoom()
  local s, p = session(), focused()
  if not s or not p then return end
  if s.zoom then app.unzoom(); redraw(); return end
  for _, other in ipairs(s.panes) do
    if other.floating and valid(other.win) then api.nvim_win_set_config(other.win, { hide = true }) end
  end
  local win = api.nvim_open_win(p.buf, true, {
    relative = "editor", row = 1, col = 0, width = math.max(1, vim.o.columns - 2),
    height = math.max(1, vim.o.lines - 5), border = "rounded",
    title = " " .. p.name .. " · ZOOM · SPC z restores layout ", zindex = 60,
  })
  s.zoom = { win = win, pane = p }
  style(win)
  redraw()
end

function app.switch(index)
  if index == nil then index = model.next_session(app.sessions, app.current) end
  local target = index and app.sessions[index]
  if not target or not target.alive then return end
  vim.cmd("stopinsert")
  app.current = index
  api.nvim_set_current_tabpage(target.tab)
  redraw()
end

function app.cycle()
  if session().zoom then app.unzoom() end
  local p = focused()
  local panes = session().panes
  for i, item in ipairs(panes) do
    if item == p then focus(panes[i % #panes + 1]); return end
  end
  focus(panes[1])
end

function app.float()
  if session().zoom then app.unzoom() end
  local p = focused()
  if not p then return end
  if p.floating then
    local anchor
    for _, other in ipairs(session().panes) do
      if other ~= p and not other.floating and valid(other.win) then anchor = other.win; break end
    end
    if not anchor then return end
    api.nvim_win_set_config(p.win, { relative = "", split = "right", win = anchor })
    p.floating = false
    vim.cmd("wincmd =")
  else
    local tiled = 0
    for _, other in ipairs(session().panes) do if not other.floating then tiled = tiled + 1 end end
    if tiled <= 1 then vim.notify("Keep one tiled pane as the session anchor."); return end
    api.nvim_win_set_config(p.win, float_config(p))
    p.floating = true
  end
  style(p.win)
  focus(p)
  redraw()
end

function app.move(direction)
  if session().zoom then app.unzoom() end
  local p = focused()
  if not p then return end
  if p.floating then
    local g = p.geometry
    g.col = g.col + (direction == "h" and -3 or direction == "l" and 3 or 0)
    g.row = g.row + (direction == "k" and -1 or direction == "j" and 1 or 0)
    api.nvim_win_set_config(p.win, float_config(p))
  else
    vim.cmd("wincmd " .. direction:upper())
  end
end

function app.resize(direction)
  if session().zoom then app.unzoom() end
  local p = focused()
  if not p then return end
  local dx = direction == "h" and -3 or direction == "l" and 3 or 0
  local dy = direction == "k" and -1 or direction == "j" and 1 or 0
  if p.floating then
    p.geometry.width = p.geometry.width + dx
    p.geometry.height = p.geometry.height + dy
    api.nvim_win_set_config(p.win, float_config(p))
  else
    if dx ~= 0 then api.nvim_win_set_width(p.win, math.max(8, api.nvim_win_get_width(p.win) + dx)) end
    if dy ~= 0 then api.nvim_win_set_height(p.win, math.max(2, api.nvim_win_get_height(p.win) + dy)) end
  end
end

function app.send(index, pane_id, command)
  if live then vim.notify("Use the agent terminal to give instructions (i enters input)."); return end
  local s = app.sessions[index]
  if not s or not s.alive then return end
  for _, p in ipairs(s.panes) do
    if p.id == pane_id and p.job and not p.exited then fn.chansend(p.job, command .. "\n") end
  end
end

local kinds = { "w", "b", "r" }
function app.trigger()
  if live then vim.notify("This pilot uses real agent signals; there are no simulated requests."); return end
  local index = model.next_session(app.sessions, app.current)
  local s = index and app.sessions[index]
  if not s then return end
  app.trigger_count = (app.trigger_count or 0) + 1
  local agents = {}
  for _, p in ipairs(s.panes) do if p.kind == "agent" and not p.exited then agents[#agents + 1] = p end end
  if #agents == 0 then return end
  local p = agents[(app.trigger_count - 1) % #agents + 1]
  app.send(index, p.id, kinds[(app.trigger_count - 1) % #kinds + 1])
  vim.notify("Simulated attention in " .. s.name .. " / " .. p.name .. ". Focus stays here.")
end

local function popup(lines, title, width)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  width = math.max(12, math.min(width, vim.o.columns - 6))
  local height = math.max(1, math.min(#lines, vim.o.lines - 7))
  local win = api.nvim_open_win(buf, true, {
    relative = "editor", row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.floor((vim.o.columns - width) / 2), width = width, height = height,
    border = "rounded", title = " " .. title .. " ", zindex = 90, style = "minimal",
  })
  vim.wo[win].cursorline = true
  local function close() if valid(win) then api.nvim_win_close(win, true) end end
  for _, key in ipairs({ "q", "<Esc>", "<leader>?" }) do vim.keymap.set("n", key, close, { buffer = buf }) end
  return buf, win, close
end

function app.attention()
  local items = model.attention(app.sessions)
  if #items == 0 then
    vim.notify(live and "No attention signals received. Inspect agent terminals if hooks are not active."
      or "Nobody needs you. Space b triggers a background request.")
    return
  end
  local lines = {}
  for _, item in ipairs(items) do
    lines[#lines + 1] = string.format(" %-7s  %-9s  %-12s  %ds · %s", item.state:upper(), item.project,
      item.name, math.max(0, os.time() - math.floor(item.since)), item.reason or "Inspect agent")
  end
  local buf, win, close = popup(lines, "Needs you · oldest first · Enter jump / q close", 105)
  local function jump()
    local item = items[api.nvim_win_get_cursor(win)[1]]
    close()
    if not item then return end
    app.switch(item.session)
    app.unzoom()
    for _, p in ipairs(session().panes) do if p.id == item.pane then focus(p) end end
  end
  vim.keymap.set("n", "<CR>", jump, { buffer = buf })
  vim.keymap.set("n", "<2-LeftMouse>", jump, { buffer = buf })
end

function app.help()
  if live then
    popup({
      " DRUDWYN PILOT · real CLIs · separate persistent worktrees",
      "",
      " Space o opens the current CLI without submitting a task",
      " Space t starts it with the prepared .ai-nvim-task.md task",
      " If already running, type: Read .ai-nvim-task.md and do the task",
      " Codex: review/enable these session status hooks via /hooks",
      " Authentication and permissions remain in the official CLI",
      "",
      " Space 1 Codex / sessions    Space 2 Claude / workspaces",
      " Space s next session       Space a attention / Enter jump",
      " Space p next pane          Space f tile/float",
      " Space z zoom/restore       Space m mouse on/off",
      " Space w h/j/k/l move       Space r h/j/k/l resize",
      " Ctrl-h/j/k/l focus         Space = balance tiles",
      " Space x terminate session  Space q quit (checks unsaved edits)",
      "",
      " Terminal: i types; Esc Esc returns to Normal for Space keys",
      " Mouse: drag separators; floating title moves, edges resize",
      " Shift-drag tiled panes to swap. Space ? opens this help.",
      "",
      " Status 'process' means lifecycle only; 'hook' is agent evidence",
      " Hidden sessions continue. Terminating stops owned processes.",
      " Worktree files persist; save editor changes with :w.",
      " This pilot has no autosave, review snapshots, or feedback queue.",
    }, "ai-nvim · Drudwyn pilot", 82)
    return
  end
  popup({
    " THROWAWAY · simulated agents only · no network or plugins",
    "",
    " Press Space, then the key(s). These work in Normal mode.",
    " Space p next pane   Space f tile/float   Space z zoom/restore",
    " Space a attention   Space s session      Space b background need",
    " Space m mouse       Space x terminate    Space ? help / close",
    "",
    " Space 1 / 2 selects a session",
    " Space w h/j/k/l moves a pane; tiled panes go to that edge",
    " Space r h/j/k/l resizes a pane",
    " Ctrl-h/j/k/l focuses adjacent native windows",
    " Space = balances tiled panes; Space q quits the spike",
    "",
    " Agent terminal: i enters typing; Esc Esc returns to Normal",
    " Then use Space shortcuts. Ordinary spaces still reach agents.",
    " Type w / b / r / c / x then Enter to change fixture state",
    " Space c continues the focused fixture from Normal mode",
    "",
    " Mouse: drag native separators to resize tiles",
    " Drag a floating title border to move; bottom/right to resize",
    " Shift-drag a tiled pane onto another pane to swap positions",
    " Click session tabs to switch; Space m disables mouse handling",
    "",
    " Status shows real PIDs, a worker PID, and heartbeat ticks",
    " Hidden sessions keep ticking; closing stops their fixtures",
    " All sample files and state are deleted when this run exits",
  }, "ai-nvim · native sessions experiment", 76)
end

function app.close(index, confirmed)
  index = index or app.current
  local s = app.sessions[index]
  if not s or not s.alive then return end
  if live then
    for _, buf in ipairs(api.nvim_list_bufs()) do
      if vim.bo[buf].modified then
        vim.notify("Save or discard modified buffers before terminating a session.", vim.log.levels.WARN)
        return
      end
    end
  end
  if not confirmed and fn.confirm("Terminate " .. s.name .. " and its " .. (live and "agents?" or "simulated agents?"), "&Cancel\n&Terminate", 1) ~= 2 then return end
  if app.current == index then app.unzoom() end
  s.alive = false
  local jobs = {}
  for _, p in ipairs(s.panes) do
    if p.job and not p.exited then jobs[#jobs + 1] = p.job; pcall(fn.jobstop, p.job) end
  end
  if #jobs > 0 then fn.jobwait(jobs, 1000) end
  local next_index = model.next_session(app.sessions, index)
  if next_index then
    app.switch(next_index)
    vim.cmd("tabclose! " .. api.nvim_tabpage_get_number(s.tab))
  elseif not app.quitting then
    vim.cmd(live and "qa" or "qa!")
  end
  if not app.quitting then redraw() end
end

function app.snapshot()
  local result = { current = app.current, mouse = vim.o.mouse, attention = model.attention(app.sessions), sessions = {} }
  for i, s in ipairs(app.sessions) do
    local copy = { name = s.name, cwd = s.cwd, alive = s.alive, tab = s.tab, panes = {}, zoom = s.zoom and s.zoom.win or nil }
    for _, p in ipairs(s.panes) do
      copy.panes[#copy.panes + 1] = { id = p.id, kind = p.kind, win = p.win, buf = p.buf, floating = p.floating,
        state = p.state, job = p.job, exited = p.exited }
    end
    result.sessions[i] = copy
  end
  return result
end

-- Native separator dragging passes through. Float borders and shift-drag swap
-- are the only mouse behaviors this spike owns.
local drag
local function mouse_start(shift)
  if vim.o.mouse == "" then return "" end
  local m = fn.getmousepos()
  if session().zoom then return "<LeftMouse>" end
  for _, p in ipairs(session().panes) do
    if p.floating and valid(p.win) then
      local g = p.geometry
      local top, left = g.row + 1, g.col + 1
      local bottom, right = top + g.height + 1, left + g.width + 1
      if m.screenrow >= top and m.screenrow <= bottom and m.screencol >= left and m.screencol <= right then
        local edge = m.screenrow == bottom or m.screencol == right
        if edge or m.screenrow == top then
          drag = { pane = p, kind = edge and "resize" or "move", row = m.screenrow, col = m.screencol, geometry = vim.deepcopy(g) }
          vim.schedule(function() focus(p) end)
          return ""
        end
      end
    end
  end
  if shift then
    local p = pane_at(m.winid)
    if p and not p.floating then drag = { pane = p, kind = "swap" }; return "" end
  end
  return "<LeftMouse>"
end

local function mouse_drag()
  if not drag then return "<LeftDrag>" end
  if drag.kind == "swap" then return "" end
  local m, d = fn.getmousepos(), drag
  local g = vim.deepcopy(d.geometry)
  if d.kind == "move" then
    g.row, g.col = g.row + m.screenrow - d.row, g.col + m.screencol - d.col
  else
    g.width, g.height = g.width + m.screencol - d.col, g.height + m.screenrow - d.row
  end
  vim.schedule(function()
    if valid(d.pane.win) then d.pane.geometry = g; api.nvim_win_set_config(d.pane.win, float_config(d.pane)) end
  end)
  return ""
end

local function mouse_release()
  if not drag then return "<LeftRelease>" end
  local d, m = drag, fn.getmousepos()
  drag = nil
  if d.kind == "swap" then
    local target = pane_at(m.winid)
    if target and target ~= d.pane and not target.floating then
      vim.schedule(function()
        local a, b = d.pane, target
        api.nvim_win_set_buf(a.win, b.buf)
        api.nvim_win_set_buf(b.win, a.buf)
        a.win, b.win = b.win, a.win
        focus(a)
        redraw()
      end)
    end
  end
  return ""
end

local function toggle_mouse()
  vim.o.mouse = vim.o.mouse == "" and "a" or ""
  drag = nil
  redraw()
end

local function bind(key, action, desc, modes)
  vim.keymap.set(modes or { "n", "t" }, key, function()
    vim.cmd("stopinsert")
    action()
  end, { silent = true, desc = desc })
end

vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Leave terminal input for Space shortcuts" })
for key, action in pairs({
  ["<leader>?"] = app.help, ["<leader>a"] = app.attention,
  ["<leader>p"] = app.cycle, ["<leader>b"] = app.trigger,
  ["<leader>f"] = app.float, ["<leader>z"] = app.zoom,
  ["<leader>s"] = function() app.switch() end, ["<leader>m"] = toggle_mouse,
  ["<leader>x"] = function() app.close() end,
  ["<leader>1"] = function() app.switch(1) end,
  ["<leader>2"] = function() app.switch(2) end,
  ["<leader>q"] = function() vim.cmd(live and "confirm qall" or "qa!") end,
  ["<leader>o"] = function() if live then app.start_agent("open") end end,
  ["<leader>t"] = function() if live then app.start_agent("task") end end,
  ["<leader>="] = function() vim.cmd("wincmd =") end,
  ["<leader>c"] = function() local p = focused(); if p then app.send(app.current, p.id, "c") end end,
}) do bind(key, action, "Spike action", "n") end
for _, direction in ipairs({ "h", "j", "k", "l" }) do
  bind("<leader>w" .. direction, function() app.move(direction) end, "Move pane", "n")
  bind("<leader>r" .. direction, function() app.resize(direction) end, "Resize pane", "n")
  bind("<C-" .. direction .. ">", function() vim.cmd("wincmd " .. direction) end, "Focus pane")
end
for _, mode in ipairs({ "n", "t" }) do
  local opts = { expr = true, silent = true, replace_keycodes = true }
  vim.keymap.set(mode, "<LeftMouse>", function() return mouse_start(false) end, opts)
  vim.keymap.set(mode, "<S-LeftMouse>", function() return mouse_start(true) end, opts)
  vim.keymap.set(mode, "<LeftDrag>", mouse_drag, opts)
  vim.keymap.set(mode, "<S-LeftDrag>", mouse_drag, opts)
  vim.keymap.set(mode, "<LeftRelease>", mouse_release, opts)
  vim.keymap.set(mode, "<S-LeftRelease>", mouse_release, opts)
end

local function create_session(index, name, task)
  if index > 1 then vim.cmd("tabnew") end
  local cwd = root .. "/" .. name
  fn.mkdir(cwd, "p")
  local s = { name = name, cwd = cwd, tab = api.nvim_get_current_tabpage(), panes = {}, alive = true }
  app.sessions[index] = s
  app.current = index
  vim.cmd("tcd " .. fn.fnameescape(cwd))
  local file = cwd .. "/example.lua"
  fn.writefile({
    "-- ai-nvim / " .. name .. " / " .. task,
    "-- THROWAWAY SAMPLE. Nothing here touches your projects.",
    "-- Space ? help | Space p pane | Space f float | Space z zoom",
    "-- Space a attention | Space s session | Space b background need",
    "-- Space m mouse | Space x terminate | Space 1/2 select session",
    "-- Space w h/j/k/l moves; Space r h/j/k/l resizes.",
    "-- Mouse: native separators resize; floating borders move/resize.",
    "-- Shift-drag tiled panes to swap. Space q exits.",
    "", "local M = {}", "",
    "-- Read here while four simulated agents work in two sessions.",
    "-- Space b: a hidden agent needs you without stealing focus.",
    "-- Space a selects it; Space c continues its work.",
    "-- In agent input: Esc Esc returns to Normal for Space shortcuts.",
    "", "function M.describe(item)", "  return item.name .. ': ' .. item.status", "end", "", "return M",
  }, file)
  vim.cmd("edit " .. fn.fnameescape(file))
  vim.bo.filetype = "lua"
  vim.cmd("syntax enable")
  s.panes[1] = { id = 1, name = "Code", kind = "editor", buf = api.nvim_get_current_buf(), win = api.nvim_get_current_win(), floating = false }
  style(s.panes[1].win)
  vim.wo.number = true
  for agent = 1, 2 do
    if agent == 1 then vim.cmd("vnew") else vim.cmd("new") end
    local p = { id = agent + 1, name = agent == 1 and "Codex fixture" or "Claude fixture", kind = "agent",
      buf = api.nvim_get_current_buf(), win = api.nvim_get_current_win(), floating = false,
      statefile = root .. "/agent-" .. index .. "-" .. agent .. ".json", state = { state = "starting" } }
    s.panes[#s.panes + 1] = p
    p.job = fn.jobstart({ vim.env.AINVIM_SPIKE_PYTHON, source .. "/fixture.py", "--token", vim.env.AINVIM_SPIKE_TOKEN,
      "--state", p.statefile, "--name", name .. "/" .. (agent == 1 and "codex" or "claude") }, {
      term = true, cwd = cwd,
      on_exit = function(_, code)
        p.exited = true
        if s.alive and not app.quitting then
          p.state.state = code == 0 and "stopped" or "failed"
          p.state.reason = "Fixture exited with code " .. code
          p.state.since = os.time()
          redraw()
        end
      end,
    })
    assert(p.job > 0, "Unable to start fixture")
    vim.bo[p.buf].bufhidden = "hide"
    style(p.win)
  end
  focus(s.panes[1])
  vim.cmd("wincmd =")
end

function app.start_agent(action)
  if not live then return end
  local s = session()
  local p = s.panes[2]
  app.unzoom()
  focus(p)
  if p.job and not p.exited then
    vim.notify("Agent already running. Press i and ask it to read .ai-nvim-task.md.")
    return
  end
  local old = p.buf
  p.buf = api.nvim_create_buf(false, true)
  api.nvim_win_set_buf(p.win, p.buf)
  pcall(api.nvim_buf_delete, old, { force = true })
  p.exited = false
  p.state = { state = "starting", evidence = "process" }
  fn.delete(p.statefile)
  p.job = fn.jobstart({ vim.env.AINVIM_SPIKE_PYTHON, source .. "/agent.py", vim.env.AINVIM_REAL_CONFIG, s.spec.id, action }, {
    term = true, cwd = s.cwd,
    on_exit = function(_, code)
      p.exited = true
      p.state = { state = code == 0 and "stopped" or "failed", evidence = "process",
        reason = "CLI exited with code " .. code .. "; inspect terminal", since = os.time() }
      if s.alive and not app.quitting then redraw() end
    end,
  })
  assert(p.job > 0, "Unable to start agent supervisor")
  vim.bo[p.buf].bufhidden = "hide"
  style(p.win)
  vim.cmd("startinsert")
end

local function create_live_session(index, spec)
  if index > 1 then vim.cmd("tabnew") end
  local s = { name = spec.name, cwd = spec.cwd, spec = spec, tab = api.nvim_get_current_tabpage(), panes = {}, alive = true }
  app.sessions[index], app.current = s, index
  vim.cmd("tcd " .. fn.fnameescape(s.cwd))
  vim.cmd("edit " .. fn.fnameescape(s.cwd .. "/" .. spec.file))
  vim.bo.filetype = "rust"
  vim.cmd("syntax enable")
  s.panes[1] = { id = 1, name = "Code", kind = "editor", buf = api.nvim_get_current_buf(), win = api.nvim_get_current_win(), floating = false }
  style(s.panes[1].win)
  vim.wo.number = true
  vim.cmd("vnew")
  local p = { id = 2, name = spec.agent, kind = "agent", buf = api.nvim_get_current_buf(), win = api.nvim_get_current_win(),
    floating = false, statefile = root .. "/agent-" .. spec.id .. ".json", state = { state = "idle" } }
  s.panes[2] = p
  vim.bo[p.buf].buftype = "nofile"
  api.nvim_buf_set_lines(p.buf, 0, -1, false, {
    "ai-nvim · Drudwyn pilot · " .. spec.agent, "", "Branch: " .. spec.branch,
    "Worktree: " .. spec.cwd, "", "Space o: open CLI (login and hook setup first)",
    "Space t: launch CLI with the prepared task", "", "Task: add Ctrl-u to clear this navigator's filter",
    "Read .ai-nvim-task.md for scope and acceptance criteria.", "", "No agent starts until you choose.",
    "Space ? shows controls. Worktree files persist after exit.",
  })
  vim.bo[p.buf].modified = false
  vim.bo[p.buf].modifiable = false
  style(p.win)
  focus(s.panes[1])
  vim.cmd("wincmd =")
end

api.nvim_create_autocmd("TabEnter", { callback = function()
  local tab = api.nvim_get_current_tabpage()
  for index, s in ipairs(app.sessions) do if s.tab == tab then app.current = index end end
  redraw()
end })

api.nvim_create_autocmd("VimResized", { callback = function()
  local s = session()
  if not s then return end
  if s.zoom then
    api.nvim_win_set_config(s.zoom.win, { width = math.max(1, vim.o.columns - 2), height = math.max(1, vim.o.lines - 5) })
  end
  for _, p in ipairs(s.panes) do
    if p.floating and valid(p.win) then api.nvim_win_set_config(p.win, float_config(p)) end
  end
end })

api.nvim_create_autocmd("VimLeavePre", { callback = function()
  app.quitting = true
  if app.timer then app.timer:stop(); app.timer:close() end
  local jobs = {}
  for _, s in ipairs(app.sessions) do
    s.alive = false
    for _, p in ipairs(s.panes) do
      if p.job and not p.exited then jobs[#jobs + 1] = p.job; pcall(fn.jobstop, p.job) end
    end
  end
  if #jobs > 0 then fn.jobwait(jobs, 1000) end
end })

vim.schedule(function()
  if live then
    for index, spec in ipairs(live.sessions) do create_live_session(index, spec) end
  else
    create_session(1, "atlas", "feature/search")
    create_session(2, "harbor", "feature/export")
  end
  app.switch(1)
  focus(session().panes[1])
  app.timer = vim.uv.new_timer()
  app.timer:start(0, 350, vim.schedule_wrap(function()
    if app.quitting then return end
    for _, s in ipairs(app.sessions) do
      if s.alive then
        for _, p in ipairs(s.panes) do
          if p.statefile and not p.exited then
            local ok, lines = pcall(fn.readfile, p.statefile)
            if ok then
              local decoded, state = pcall(vim.json.decode, table.concat(lines, "\n"))
              if decoded then p.state = state end
            end
          end
        end
      end
    end
    redraw()
  end))
  redraw()
end)
