-- Pane motion changes geometry only; it never owns buffers, jobs or focus.
local M = {}
local api, uv = vim.api, vim.uv
local settings = require("uzume.layout.settings")
local active
local mode = settings.load()

function M.capture(win)
  local config = api.nvim_win_get_config(win)
  local position = api.nvim_win_get_position(win)
  return {
    width = api.nvim_win_get_width(win),
    height = api.nvim_win_get_height(win),
    row = config.relative ~= "" and tonumber(config.row) or position[1],
    col = config.relative ~= "" and tonumber(config.col) or position[2],
    floating = config.relative ~= "",
    buf = api.nvim_win_get_buf(win),
  }
end

local function snapshot(run)
  if not api.nvim_win_is_valid(run.win) or (run.anchor and not api.nvim_win_is_valid(run.anchor)) then
    return
  end
  return { M.capture(run.win), run.anchor and M.capture(run.anchor) or false }
end

function M.finish(settle)
  local run = active
  if not run then
    return
  end
  active = nil
  run.timer:stop()
  run.timer:close()
  -- A native command or mouse resize may have replaced the target geometry.
  if settle ~= false and vim.deep_equal(snapshot(run), run.expected) then
    pcall(run.frame, 1)
  end
  if run.restore and api.nvim_win_is_valid(run.win) then
    run.restore()
  end
end

local function animate(win, frame, duration, anchor, restore)
  M.finish()
  if mode == "instant" or #api.nvim_list_uis() == 0 then
    return
  end
  local run = {
    win = win,
    anchor = anchor,
    frame = frame,
    restore = restore,
    timer = uv.new_timer(),
    tab = api.nvim_get_current_tabpage(),
    started = uv.hrtime(),
  }
  active = run
  local ok = pcall(frame, 0)
  run.expected = snapshot(run)
  if not ok then
    M.finish(false)
    return
  end
  run.timer:start(
    0,
    16,
    vim.schedule_wrap(function()
      if active ~= run then
        return
      end
      if not vim.deep_equal(snapshot(run), run.expected) then
        M.finish(false)
        return
      end
      if api.nvim_get_current_tabpage() ~= run.tab or api.nvim_get_current_win() ~= win then
        M.finish()
        return
      end
      local t = math.min(1, (uv.hrtime() - run.started) / (duration * 1e6))
      local success, changed = pcall(frame, t)
      run.expected = snapshot(run)
      if not success or t >= 1 then
        M.finish(success)
      end
      if changed ~= false then
        vim.cmd.redraw()
      end
    end)
  )
end

local function pulse(win)
  M.finish()
  if #api.nvim_list_uis() == 0 then
    return
  end
  local original = vim.wo[win].winhighlight
  local normal = api.nvim_get_hl(0, { name = "Normal", link = false })
  local accent = api.nvim_get_hl(0, { name = "SnacksDashboardHeader", link = false }).fg or 0xc4a7e7
  local base = normal.bg or 0x191724
  local stripped = original:gsub("NormalFloat:[^,]+,?", ""):gsub("Normal:[^,]+,?", ""):gsub(",$", "")
  vim.wo[win].winhighlight = (stripped ~= "" and stripped .. "," or "")
    .. "Normal:UzumePanePulse,NormalFloat:UzumePanePulse"
  animate(
    win,
    function(t)
      local color = 0
      for shift = 0, 2 do
        local unit = 256 ^ shift
        local a, b = math.floor(base / unit) % 256, math.floor(accent / unit) % 256
        color = color + math.floor(a + (b - a) * 0.15 * (1 - t)) * unit
      end
      api.nvim_set_hl(0, "UzumePanePulse", { fg = normal.fg, bg = color })
    end,
    180,
    nil,
    function()
      if vim.wo[win].winhighlight:find("UzumePanePulse", 1, true) then
        vim.wo[win].winhighlight = original
      end
    end
  )
end

local function transition(win, from, to, anchor, direction)
  local source = anchor and M.capture(anchor)
  local spring = mode == "spring"
  animate(win, function(t)
    local progress = spring and 1 - math.exp(-6.5 * t) * (math.cos(12 * t) + 6.5 / 12 * math.sin(12 * t))
      or 1 - (1 - t) ^ 3
    if t == 1 then
      progress = 1
    end
    local value = {}
    for _, key in ipairs({ "width", "height", "row", "col" }) do
      value[key] = math.floor(from[key] + (to[key] - from[key]) * progress + 0.5)
    end
    if to.floating then
      value.width = math.max(1, math.min(value.width, vim.o.columns - 2))
      value.height = math.max(1, math.min(value.height, vim.o.lines - 5))
      value.row = math.max(0, math.min(value.row, vim.o.lines - value.height - 3))
      value.col = math.max(0, math.min(value.col, vim.o.columns - value.width - 2))
      local current = M.capture(win)
      if
        current.width == value.width
        and current.height == value.height
        and current.row == value.row
        and current.col == value.col
      then
        return false
      end
      value.relative = "editor"
      api.nvim_win_set_config(win, value)
    elseif source then
      if direction == "right" or direction == "left" then
        local width = source.width + to.width - math.max(vim.o.winminwidth, value.width)
        if api.nvim_win_get_width(anchor) == width then
          return false
        end
        api.nvim_win_set_width(anchor, width)
      else
        local height = source.height + to.height - math.max(vim.o.winminheight, value.height)
        if api.nvim_win_get_height(anchor) == height then
          return false
        end
        api.nvim_win_set_height(anchor, height)
      end
    else
      local changed = false
      if from.width ~= to.width and api.nvim_win_get_width(win) ~= math.max(1, value.width) then
        api.nvim_win_set_width(win, math.max(1, value.width))
        changed = true
      end
      if from.height ~= to.height and api.nvim_win_get_height(win) ~= math.max(1, value.height) then
        api.nvim_win_set_height(win, math.max(1, value.height))
        changed = true
      end
      return changed
    end
  end, spring and 420 or 200, anchor)
end

function M.reveal(source, win, direction)
  if mode == "instant" then
    return
  end
  if mode == "pulse" then
    return pulse(win)
  end
  local target = M.capture(win)
  local start = vim.deepcopy(target)
  if direction == "right" or direction == "left" then
    start.width = 1
  else
    start.height = 1
  end
  transition(win, start, target, source, direction)
end

function M.change(win, before, entrance)
  if mode == "instant" then
    return
  end
  if mode == "pulse" then
    return pulse(win)
  end
  local target = M.capture(win)
  if entrance and mode == "slide" then
    before = vim.deepcopy(target)
    before.row = math.min(target.row + 4, vim.o.lines - target.height - 3)
  end
  transition(win, before, target)
end

function M.choose(value)
  settings.save(value)
  M.finish()
  mode = value
end

function M.pick()
  local descriptions = {
    slide = "Slide · directional reveal",
    instant = "Instant · no animation",
    pulse = "Pulse · brief pane highlight",
    spring = "Spring · overshoot and settle",
  }
  vim.ui.select(settings.modes, {
    prompt = "Pane animation · j/k choose · Enter save",
    format_item = function(value)
      return descriptions[value] .. (value == mode and "  ✓" or "")
    end,
    snacks = { focus = "list" },
  }, function(value)
    if not value then
      return
    end
    local ok, err = pcall(M.choose, value)
    if not ok then
      vim.notify(tostring(err), vim.log.levels.ERROR, { title = "Pane animation" })
    end
  end)
end

function M.setup()
  local group = api.nvim_create_augroup("UzumePaneMotion", { clear = true })
  api.nvim_create_autocmd({ "WinLeave", "TabLeave", "VimLeavePre", "ColorSchemePre" }, {
    group = group,
    callback = function()
      M.finish()
    end,
  })
  api.nvim_create_autocmd({ "WinClosed", "VimResized" }, {
    group = group,
    callback = function()
      M.finish()
    end,
  })
  vim.on_key(function(_, typed)
    local run = active
    if run and typed ~= "" then
      vim.schedule(function()
        if active == run then
          M.finish()
        end
      end)
    end
  end, api.nvim_create_namespace("UzumePaneMotionInput"))
  api.nvim_create_user_command("UzumeMotion", function(args)
    if args.args == "" then
      api.nvim_echo({ { "Pane animation: " .. mode } }, false, {})
    else
      M.choose(args.args)
    end
  end, {
    nargs = "?",
    complete = function()
      return settings.modes
    end,
    desc = "Show or save the pane animation mode",
  })
  vim.keymap.set("n", "<leader>uA", M.pick, { desc = "Pane Animation" })
end

return M
