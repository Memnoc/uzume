-- Conflict choices edit one marker block in the result buffer, never a whole file.
local M = {}
local api = vim.api
local active = {}
local ns = api.nvim_create_namespace("uzume_conflict_labels")

local function blocks(buf)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local found, current = {}, nil
  for row, line in ipairs(lines) do
    local opening = line:match("^(<+) ")
    if opening and #opening >= 3 then
      assert(not current, "Nested conflict markers: edit this block manually first")
      current = { first = row, width = #opening }
    elseif current then
      if line:match("^" .. string.rep("|", current.width) .. " ") then
        assert(not current.base and not current.separator, "Malformed conflict markers")
        current.base = row
      elseif line == string.rep("=", current.width) then
        assert(not current.separator, "Malformed conflict markers")
        current.separator = row
      elseif line:sub(1, current.width + 1) == string.rep(">", current.width) .. " " then
        assert(current.separator, "Conflict is missing its separator; edit it manually")
        current.last = row
        found[#found + 1] = current
        current = nil
      end
    end
  end
  assert(not current, "Incomplete conflict markers: edit this block manually first")
  return found, lines
end

function M.detach(tab, close_sides)
  local state = active[tab]
  if not state then
    return
  end
  active[tab] = nil
  api.nvim_del_augroup_by_id(state.group)
  if api.nvim_buf_is_valid(state.buf) then
    api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  end
  for _, mapping in ipairs(state.mappings) do
    if api.nvim_buf_is_valid(mapping.buf) then
      pcall(api.nvim_buf_del_keymap, mapping.buf, "n", mapping.key)
      if mapping.previous then
        api.nvim_buf_call(mapping.buf, function()
          vim.fn.mapset("n", false, mapping.previous)
        end)
      end
    end
  end
  if api.nvim_win_is_valid(state.win) then
    vim.wo[state.win].winbar = " Integration result · Space vi status "
    if close_sides then
      api.nvim_win_call(state.win, function()
        vim.cmd.diffoff()
      end)
    end
  end
  if close_sides then
    for _, win in ipairs(state.sides) do
      if api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
      end
    end
  end
end

function M.attach(result, sides, callbacks)
  local tab = api.nvim_win_get_tabpage(result)
  M.detach(tab)
  local buf = api.nvim_win_get_buf(result)
  local state = { win = result, buf = buf, sides = sides, mappings = {} }
  active[tab] = state
  state.group = api.nvim_create_augroup("uzume_conflicts_" .. tab, { clear = true })
  local function focus()
    assert(api.nvim_win_is_valid(result) and api.nvim_win_get_buf(result) == buf, "Reopen the conflict file first")
    api.nvim_set_current_win(result)
  end
  local function refresh()
    if not api.nvim_win_is_valid(result) or not api.nvim_buf_is_valid(buf) then
      return
    end
    local ok, entries = pcall(blocks, buf)
    vim.wo[result].winbar = "%#Title# EDIT RESULT %*· "
      .. (ok and (#entries .. " left") or "check markers")
      .. " · Space vm"
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    if ok then
      for index, entry in ipairs(entries) do
        for _, label in ipairs({
          { entry.first, " DESTINATION · conflict " .. index },
          { entry.separator, " TASK CHANGES below " },
        }) do
          api.nvim_buf_set_extmark(buf, ns, label[1] - 1, 0, {
            virt_text = { { label[2], "DiagnosticWarn" } },
            virt_text_pos = "eol",
          })
        end
      end
    end
  end
  local function jump(direction)
    focus()
    local entries = blocks(buf)
    assert(#entries > 0, "No conflict markers remain. Space vS saves and finishes integration.")
    local row = api.nvim_win_get_cursor(result)[1]
    local chosen = direction == 1 and entries[1] or entries[#entries]
    if direction == 1 then
      for _, entry in ipairs(entries) do
        if entry.first > row then
          chosen = entry
          break
        end
      end
    else
      for index = #entries, 1, -1 do
        if entries[index].first < row then
          chosen = entries[index]
          break
        end
      end
    end
    api.nvim_win_set_cursor(result, { chosen.first, 0 })
    vim.cmd("normal! zvzz")
  end
  local function choose(side)
    focus()
    local entries, lines = blocks(buf)
    local row = api.nvim_win_get_cursor(result)[1]
    local selected
    for _, entry in ipairs(entries) do
      if row >= entry.first and row <= entry.last then
        selected = entry
        break
      end
    end
    assert(selected, "Move to a conflict with ]x or [x before choosing a side")
    local replacement = {}
    if side ~= "task" then
      for index = selected.first + 1, (selected.base or selected.separator) - 1 do
        replacement[#replacement + 1] = lines[index]
      end
    end
    if side ~= "destination" then
      for index = selected.separator + 1, selected.last - 1 do
        replacement[#replacement + 1] = lines[index]
      end
    end
    api.nvim_buf_set_lines(buf, selected.first - 1, selected.last, false, replacement)
    local remaining = blocks(buf)
    local position = math.min(selected.first, api.nvim_buf_line_count(buf))
    for _, entry in ipairs(remaining) do
      if entry.first >= selected.first then
        position = entry.first
        break
      end
    end
    api.nvim_win_set_cursor(result, { position, 0 })
    refresh()
  end
  local function finish()
    focus()
    assert(#blocks(buf) == 0, "Resolve the remaining conflicts first; ]x jumps to the next one")
    vim.cmd.write()
    callbacks.finish()
  end
  local actions = {
    {
      key = "<leader>vo",
      hint = "Space vo",
      label = "Use DESTINATION for this conflict",
      run = function()
        choose("destination")
      end,
    },
    {
      key = "<leader>vt",
      hint = "Space vt",
      label = "Use TASK CHANGES for this conflict",
      run = function()
        choose("task")
      end,
    },
    {
      key = "<leader>vb",
      hint = "Space vb",
      label = "Keep BOTH · destination then task",
      run = function()
        choose("both")
      end,
    },
    {
      key = "]x",
      hint = "]x",
      label = "Next conflict",
      run = function()
        jump(1)
      end,
    },
    {
      key = "[x",
      hint = "[x",
      label = "Previous conflict",
      run = function()
        jump(-1)
      end,
    },
    { key = "<leader>vf", hint = "Space vf", label = "Choose another conflict file", run = callbacks.files },
    { key = "<leader>vS", hint = "Space vS", label = "Save result and FINISH integration", run = finish },
  }
  local function protect(fn)
    require("uzume.agents.context").run(fn, "Resolve conflict")
  end
  local function menu()
    Snacks.picker.select(actions, {
      prompt = "Resolve conflict · u undoes",
      format_item = function(action)
        return string.format("%-10s %s", action.hint, action.label)
      end,
    }, function(action)
      if action then
        protect(action.run)
      end
    end)
  end
  local bindings = vim.list_extend(vim.list_slice(actions), {
    { key = "<leader>vm", label = "Conflict Actions", run = menu },
  })
  for _, win in ipairs(vim.list_extend({ result }, sides)) do
    local target = api.nvim_win_get_buf(win)
    for _, action in ipairs(bindings) do
      local previous = api.nvim_buf_call(target, function()
        return vim.fn.maparg(action.key, "n", false, true)
      end)
      state.mappings[#state.mappings + 1] =
        { buf = target, key = action.key, previous = previous.buffer == 1 and previous or nil }
      vim.keymap.set("n", action.key, function()
        protect(action.run)
      end, { buffer = target, desc = action.label })
    end
  end
  api.nvim_create_autocmd(
    { "TextChanged", "TextChangedI", "BufWritePost" },
    { group = state.group, buffer = buf, callback = refresh }
  )
  api.nvim_create_autocmd("WinClosed", {
    group = state.group,
    pattern = tostring(result),
    callback = function()
      M.detach(tab)
    end,
  })
  refresh()
  local ok, entries = pcall(blocks, buf)
  if ok and #entries > 0 then
    api.nvim_win_set_cursor(result, { entries[1].first, 0 })
  end
end
return M
