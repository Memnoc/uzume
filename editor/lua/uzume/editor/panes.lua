-- EDITOR SPIKE: native pane layout operations inside a product window (tab).
-- Floats keep a placeholder in their original tile so docking/zoom restores the layout.
local M = { floats = {}, hidden_by_tab = {}, serial = 0 }
local api = vim.api
local native = require("uzume.editor.sessions")
local motion = require("uzume.layout.motion")

local function view(win)
  return api.nvim_win_call(win, vim.fn.winsaveview)
end
local function restore_view(win, saved)
  api.nvim_win_call(win, function()
    vim.fn.winrestview(saved)
  end)
end
local function tiled(tab)
  return vim.tbl_filter(function(win)
    return api.nvim_win_get_config(win).relative == ""
  end, api.nvim_tabpage_list_wins(tab))
end
local function current()
  local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  assert(vim.bo[buf].buftype == "" or vim.bo[buf].buftype == "terminal", "Open a file or shell pane first")
  return win, buf
end
local function name(win, buf)
  return vim.w[win].uzume_name
    or (
      vim.bo[buf].buftype == "terminal" and (vim.b[buf].term_title or "Shell")
      or (api.nvim_buf_get_name(buf) ~= "" and vim.fs.basename(api.nvim_buf_get_name(buf)) or "New file")
    )
end
local function placeholder(text)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "uzume_slot"
  api.nvim_buf_set_lines(buf, 0, -1, false, { "", "  " .. text, "  Space pp: panes · Space pr: restore hidden pane" })
  vim.bo[buf].modifiable = false
  return buf
end
local function rect(full)
  local width = math.max(10, math.floor(vim.o.columns * (full and 1 or 0.75)) - 2)
  local height = math.max(3, math.floor((vim.o.lines - 3) * (full and 1 or 0.75)) - 2)
  return {
    relative = "editor",
    row = full and 0 or math.floor((vim.o.lines - height - 3) / 2),
    col = full and 0 or math.floor((vim.o.columns - width - 2) / 2),
    width = width,
    height = height,
    border = "single",
    zindex = full and 60 or 50,
  }
end
local function clamp(config)
  config.width = math.max(10, math.min(config.width, vim.o.columns - 2))
  config.height = math.max(3, math.min(config.height, vim.o.lines - 5))
  config.row = math.max(0, math.min(tonumber(config.row), vim.o.lines - config.height - 3))
  config.col = math.max(0, math.min(tonumber(config.col), vim.o.columns - config.width - 2))
  return config
end

function M.hidden(tab)
  local result = {}
  for _, pane in ipairs(M.hidden_by_tab[tab] or {}) do
    if api.nvim_buf_is_valid(pane.buf) then
      result[#result + 1] = pane
    end
  end
  M.hidden_by_tab[tab] = result
  return result
end

function M.split(direction, shell)
  motion.finish()
  local project = require("uzume.editor.projects").current()
  assert(project, "Open a project first: Space ap, then N")
  local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  if M.floats[win] then
    win = M.dock(win)
    buf = api.nvim_win_get_buf(win)
  end
  local config = api.nvim_win_get_config(win)
  assert(config.relative == "", "Choose an editor or shell pane, not a popup")
  assert(
    vim.bo[buf].buftype == ""
      or vim.bo[buf].buftype == "terminal"
      or vim.bo[buf].filetype == "uzume_session"
      or vim.bo[buf].filetype == "uzume_slot"
      or vim.bo[buf].filetype == "uzume_task",
    "Choose an editor pane first"
  )
  local fresh = shell or vim.bo[buf].buftype ~= ""
  vim.cmd("belowright " .. (direction == "right" and (fresh and "vnew" or "vsplit") or (fresh and "new" or "split")))
  if shell then
    local created, newbuf = api.nvim_get_current_win(), api.nvim_get_current_buf()
    local ok, job =
      pcall(vim.fn.jobstart, vim.fn.split(vim.o.shell), { term = true, cwd = vim.t.uzume_root or project.root })
    if not ok or job <= 0 then
      api.nvim_win_close(created, true)
      api.nvim_buf_delete(newbuf, { force = true })
      api.nvim_set_current_win(win)
      error("Could not start shell: " .. tostring(job))
    end
    vim.cmd.startinsert()
  end
  motion.reveal(win, api.nvim_get_current_win(), direction)
end

function M.float()
  motion.finish()
  local win, buf = current()
  if M.floats[win] then
    return M.dock(win)
  end
  assert(api.nvim_win_get_config(win).relative == "", "This popup is managed by another tool")
  local before = motion.capture(win)
  local saved, title = view(win), name(win, buf)
  vim.bo[buf].bufhidden = "hide"
  local old = { number = vim.wo[win].number, relativenumber = vim.wo[win].relativenumber }
  api.nvim_win_set_buf(win, placeholder("Floating pane: " .. title))
  vim.wo[win].number, vim.wo[win].relativenumber = false, false
  local config = rect(false)
  config.title = " " .. title .. " · drag top / resize bottom-right "
  local floating = api.nvim_open_win(buf, true, config)
  vim.wo[floating].number, vim.wo[floating].relativenumber = old.number, old.relativenumber
  vim.w[floating].uzume_name = vim.w[win].uzume_name
  M.floats[floating] = { slot = win, tab = api.nvim_get_current_tabpage(), options = old }
  restore_view(floating, saved)
  motion.change(floating, before, true)
  return floating
end

function M.dock(win)
  motion.finish()
  win = win or api.nvim_get_current_win()
  local state = assert(M.floats[win], "Pane is already tiled")
  local buf, saved = api.nvim_win_get_buf(win), view(win)
  local slot = state.slot
  if not api.nvim_win_is_valid(slot) then
    slot = api.nvim_open_win(buf, false, { split = "right", win = tiled(state.tab)[1] })
  else
    api.nvim_win_set_buf(slot, buf)
  end
  vim.w[slot].uzume_name = vim.w[win].uzume_name
  for option, value in pairs(state.options) do
    vim.wo[slot][option] = value
  end
  M.floats[win] = nil
  api.nvim_win_close(win, false)
  api.nvim_set_current_win(slot)
  restore_view(slot, saved)
  return slot
end

function M.zoom()
  motion.finish()
  local win = current()
  local before = motion.capture(win)
  local state = M.floats[win]
  if state and state.zoom then
    local zoom = state.zoom
    state.zoom = nil
    if zoom.tiled then
      return M.dock(win)
    end
    api.nvim_win_set_config(win, zoom.config)
    motion.change(win, before)
    return
  end
  local was_tiled = not state
  if was_tiled then
    win = M.float()
    motion.finish()
    state = M.floats[win]
  end
  state.zoom = { tiled = was_tiled, config = api.nvim_win_get_config(win) }
  api.nvim_win_set_config(win, rect(true))
  motion.change(win, before)
end

function M.move(direction)
  motion.finish()
  local win = current()
  local before = motion.capture(win)
  if M.floats[win] then
    assert(not M.floats[win].zoom, "Leave fullscreen before moving the pane")
    local config = api.nvim_win_get_config(win)
    config.row = tonumber(config.row) + (direction == "J" and 2 or direction == "K" and -2 or 0)
    config.col = tonumber(config.col) + (direction == "L" and 4 or direction == "H" and -4 or 0)
    api.nvim_win_set_config(win, clamp(config))
    motion.change(win, before)
  else
    vim.cmd.wincmd(direction)
  end
end

function M.resize(width, height)
  motion.finish()
  local win = current()
  local before = motion.capture(win)
  if M.floats[win] then
    assert(not M.floats[win].zoom, "Leave fullscreen before resizing the pane")
    local config = api.nvim_win_get_config(win)
    config.width, config.height = config.width + width, config.height + height
    api.nvim_win_set_config(win, clamp(config))
  else
    if width ~= 0 then
      api.nvim_win_set_width(win, math.max(1, api.nvim_win_get_width(win) + width))
    end
    if height ~= 0 then
      api.nvim_win_set_height(win, math.max(1, api.nvim_win_get_height(win) + height))
    end
  end
  motion.change(win, before)
end

function M.swap()
  motion.finish()
  local win, buf = current()
  local panes = native.windows(api.nvim_get_current_tabpage())
  assert(#panes > 1, "Create another pane first")
  local next_win
  for index, pane in ipairs(panes) do
    if pane.win == win then
      next_win = panes[index % #panes + 1].win
    end
  end
  assert(next_win, "Select a managed pane")
  local other, first_view, second_view = api.nvim_win_get_buf(next_win), view(win), view(next_win)
  vim.bo[buf].bufhidden, vim.bo[other].bufhidden = "hide", "hide"
  local title = vim.w[win].uzume_name
  api.nvim_win_set_buf(win, other)
  api.nvim_win_set_buf(next_win, buf)
  vim.w[win].uzume_name, vim.w[next_win].uzume_name = vim.w[next_win].uzume_name, title
  restore_view(win, second_view)
  restore_view(next_win, first_view)
end

function M.hide()
  motion.finish()
  local win, buf = current()
  local tab = api.nvim_get_current_tabpage()
  local saved = view(win)
  local floating = M.floats[win] and api.nvim_win_get_config(win) or nil
  if M.floats[win] then
    win = M.dock(win)
  end
  M.serial = M.serial + 1
  local pane = {
    id = M.serial,
    tab = tab,
    buf = buf,
    name = name(win, buf),
    view = saved,
    terminal = vim.bo[buf].buftype == "terminal",
    floating = floating,
    hidden = true,
  }
  vim.bo[buf].bufhidden = "hide"
  if #native.windows(tab) == 1 then
    api.nvim_win_set_buf(win, placeholder("All panes hidden"))
    pane.slot = win
  else
    api.nvim_win_close(win, false)
  end
  local hidden = M.hidden(tab)
  hidden[#hidden + 1] = pane
  M.hidden_by_tab[tab] = hidden
end

function M.restore(pane)
  motion.finish()
  local tab = api.nvim_get_current_tabpage()
  local hidden = M.hidden(tab)
  pane = pane or hidden[#hidden]
  assert(pane and api.nvim_buf_is_valid(pane.buf), "No hidden pane in this window")
  local win = pane.slot
  if win and api.nvim_win_is_valid(win) and vim.bo[api.nvim_win_get_buf(win)].filetype == "uzume_slot" then
    api.nvim_win_set_buf(win, pane.buf)
  else
    win = api.nvim_open_win(pane.buf, false, { split = "right", win = tiled(tab)[1] })
  end
  vim.w[win].uzume_name = pane.name
  M.hidden_by_tab[tab] = vim.tbl_filter(function(item)
    return item.id ~= pane.id
  end, hidden)
  api.nvim_set_current_win(win)
  restore_view(win, pane.view)
  if pane.floating then
    win = M.float()
    motion.finish()
    local before = motion.capture(win)
    api.nvim_win_set_config(win, clamp(pane.floating))
    motion.change(win, before, true)
  end
  return win
end

function M.close(win)
  motion.finish()
  win = win or api.nvim_get_current_win()
  local buf = api.nvim_win_get_buf(win)
  local terminal = vim.bo[buf].buftype == "terminal"
  assert(not vim.bo[buf].modified or terminal, "Save modified files before closing this pane")
  if terminal then
    assert(#vim.fn.win_findbuf(buf) == 1, "Terminal has another visible view; close it first")
    for tab in pairs(M.hidden_by_tab) do
      for _, pane in ipairs(M.hidden(tab)) do
        assert(pane.buf ~= buf, "Terminal also has a hidden view; restore it first")
      end
    end
  end
  if M.floats[win] then
    win = M.dock(win)
  end
  local tab = api.nvim_win_get_tabpage(win)
  if #native.windows(tab) == 1 then
    api.nvim_set_current_win(win)
    api.nvim_win_set_buf(win, api.nvim_create_buf(true, false))
    native.home()
  else
    api.nvim_win_close(win, false)
  end
  if terminal and vim.b[buf].terminal_job_id then
    pcall(vim.fn.jobstop, vim.b[buf].terminal_job_id)
  end
end

-- Process exit is not a user navigation action: clean up without switching tabs.
function M.remove_exited_terminal(buf)
  motion.finish()
  if not api.nvim_buf_is_valid(buf) then
    return
  end
  assert(vim.bo[buf].buftype == "terminal", "Expected an exited terminal")
  local slots = {}
  for win, state in pairs(M.floats) do
    if api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) == buf then
      slots[#slots + 1] = state.slot
      M.floats[win] = nil
    end
  end
  for tab, hidden in pairs(M.hidden_by_tab) do
    M.hidden_by_tab[tab] = vim.tbl_filter(function(pane)
      if pane.buf == buf then
        if pane.slot then
          slots[#slots + 1] = pane.slot
        end
        return false
      end
      return true
    end, hidden)
  end
  local function remove(win)
    if not api.nvim_win_is_valid(win) then
      return
    end
    local tab = api.nvim_win_get_tabpage(win)
    if api.nvim_win_get_config(win).relative == "" and #tiled(tab) == 1 then
      -- Neovim needs a tiled editor window even if the agent was its last pane.
      api.nvim_win_set_buf(win, api.nvim_create_buf(true, false))
      vim.w[win].uzume_name = nil
    else
      api.nvim_win_close(win, true)
    end
  end
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    remove(win)
  end
  for _, win in ipairs(slots) do
    if api.nvim_win_is_valid(win) and vim.bo[api.nvim_win_get_buf(win)].filetype == "uzume_slot" then
      remove(win)
    end
  end
  api.nvim_buf_delete(buf, { force = true })
end

function M.pick()
  local tab = api.nvim_get_current_tabpage()
  local items = native.windows(tab)
  vim.list_extend(items, M.hidden(tab))
  Snacks.picker.select(items, {
    prompt = "Panes · Enter focus/restore",
    format_item = function(item)
      return (item.hidden and "Hidden · " or "Visible · ") .. item.name
    end,
  }, function(item)
    if not item then
      return
    end
    M.run(function()
      assert(api.nvim_tabpage_is_valid(tab), "Window has closed")
      api.nvim_set_current_tabpage(tab)
      if item.hidden then
        M.restore(item)
      else
        api.nvim_set_current_win(item.win)
      end
    end)
  end)
end

function M.transfer()
  motion.finish()
  local win, buf = current()
  assert(not vim.b[buf].uzume_agent_id, "Agent panes belong to their task window; move or float them within it")
  local project = require("uzume.editor.projects").current()
  local choices = vim.tbl_filter(function(window)
    return not window.current
  end, project.windows)
  assert(#choices > 0, "Create another window in this project first")
  local origin_tab = api.nvim_get_current_tabpage()
  Snacks.picker.select(choices, {
    prompt = "Move pane to window",
    format_item = function(item)
      return item.name
    end,
  }, function(target)
    if not target then
      return
    end
    M.run(function()
      assert(api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) == buf, "Pane changed; choose it again")
      assert(api.nvim_tabpage_is_valid(target.tab), "Destination closed")
      if vim.bo[buf].buftype == "terminal" then
        assert(#vim.fn.win_findbuf(buf) == 1, "Terminal is shared; close its other view first")
      end
      api.nvim_set_current_tabpage(origin_tab)
      if M.floats[win] then
        win = M.dock(win)
      end
      local saved, title = view(win), name(win, buf)
      vim.bo[buf].bufhidden = "hide"
      api.nvim_set_current_tabpage(target.tab)
      local destination = api.nvim_open_win(buf, true, { split = "right", win = tiled(target.tab)[1] })
      vim.w[destination].uzume_name = title
      if vim.bo[buf].buftype == "terminal" then
        vim.b[buf].uzume_owner = target.tab
      end
      if #native.windows(origin_tab) == 1 then
        api.nvim_win_set_buf(win, placeholder("Pane moved to " .. target.name))
      else
        api.nvim_win_close(win, false)
      end
      restore_view(destination, saved)
    end)
  end)
end

function M.forget(tab)
  motion.finish()
  M.hidden_by_tab[tab] = nil
  for win, state in pairs(M.floats) do
    if state.tab == tab then
      M.floats[win] = nil
    end
  end
end
function M.prepare_save()
  motion.finish()
  assert(not next(M.floats), "Dock floating/fullscreen panes before saving the layout")
  for tab in pairs(M.hidden_by_tab) do
    assert(#M.hidden(tab) == 0, "Restore hidden panes before saving the layout")
  end
end
function M.run(fn)
  local ok, err = pcall(fn)
  if not ok then
    vim.notify(tostring(err), vim.log.levels.WARN, { title = "Windows" })
  end
end
function M.confirm(prompt, fn)
  Snacks.picker.select({ "Close", "Cancel" }, { prompt = prompt }, function(choice)
    if choice == "Close" then
      M.run(fn)
    end
  end)
end

function M.setup()
  motion.setup()
  local group = api.nvim_create_augroup("uzume_panes", { clear = true })
  api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      for win, state in pairs(M.floats) do
        if api.nvim_win_is_valid(win) then
          api.nvim_win_set_config(win, state.zoom and rect(true) or clamp(api.nvim_win_get_config(win)))
        end
      end
    end,
  })
  api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(event)
      M.floats[tonumber(event.match)] = nil
    end,
  })
  api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = function()
      for tab in pairs(M.hidden_by_tab) do
        if not api.nvim_tabpage_is_valid(tab) then
          M.forget(tab)
        end
      end
    end,
  })
  -- Preserve native mouse handling except on the borders of our own floats.
  for _, key in ipairs({ "<LeftMouse>", "<LeftDrag>", "<LeftRelease>" }) do
    vim.keymap.set({ "n", "i", "t" }, key, function()
      if vim.o.mouse == "" then
        M.drag = nil
        return ""
      end
      local pos = vim.fn.getmousepos()
      if key == "<LeftMouse>" then
        local state = M.floats[pos.winid]
        if not state or state.zoom then
          return key
        end
        local config = api.nvim_win_get_config(pos.winid)
        local top, left = tonumber(config.row) + 1, tonumber(config.col) + 1
        local bottom, right = top + config.height + 1, left + config.width + 1
        local edge = pos.screenrow == bottom or pos.screencol == right
        if pos.screenrow ~= top and not edge then
          return key
        end
        M.drag = { win = pos.winid, config = config, row = pos.screenrow, col = pos.screencol, resize = edge }
        return ""
      end
      local drag = M.drag
      if not drag then
        return key
      end
      if key == "<LeftRelease>" then
        M.drag = nil
        return ""
      end
      local config = vim.deepcopy(drag.config)
      local dr, dc = pos.screenrow - drag.row, pos.screencol - drag.col
      if drag.resize then
        config.width, config.height = config.width + dc, config.height + dr
      else
        config.row, config.col = tonumber(config.row) + dr, tonumber(config.col) + dc
      end
      vim.schedule(function()
        if api.nvim_win_is_valid(drag.win) then
          api.nvim_win_set_config(drag.win, clamp(config))
        end
      end)
      return ""
    end, { expr = true, silent = true })
  end
end
return M
