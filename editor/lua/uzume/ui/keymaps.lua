-- Search live mappings and explicitly run a Normal-mode action in its source pane.
local M = {}

local modes = {
  n = "Normal",
  i = "Insert",
  v = "Visual/Sel",
  x = "Visual",
  s = "Select",
  o = "Operator",
  c = "Command",
  t = "Terminal",
}

local function shortcut(lhs)
  local key = Snacks.util.normkey(lhs):gsub("<([^>]+)>", function(token)
    if token:lower() == "lt" then
      return "<"
    end
    return token:gsub("^C%-", "Ctrl-") .. " "
  end)
  return vim.trim(key)
end

local function format(item, picker)
  local align = Snacks.picker.util.align
  -- Snacks prepends a selection cell. Leave one trailing cell too so the
  -- mode label cannot be clipped at the right edge.
  local width = picker.list.win:dim().width - 2
  local key_width = math.min(18, math.floor(width * 0.28))
  local mode_width = 10
  return {
    { align(item.shortcut, key_width, { truncate = true }), "SnacksPickerKeymapLhs" },
    { "  " },
    { align(item.description, math.max(1, width - key_width - mode_width - 4), { truncate = true }) },
    { "  " .. (modes[item.item.mode] or item.item.mode), "Comment" },
  }
end

local function toggle(picker, key)
  picker.opts[key] = not picker.opts[key]
  local scope = {}
  if picker.opts.global then
    scope[#scope + 1] = "Global"
  end
  if picker.opts["local"] then
    scope[#scope + 1] = "Buffer"
  end
  picker.title = #scope == 2 and "Shortcuts" or "Shortcuts · " .. (#scope > 0 and scope[1] or "No scopes selected")
  picker:find()
end

local function execute(picker, item, window, buffer)
  if not item then
    return
  end
  local mapping = item.item
  if mapping.mode ~= "n" and mapping.mode ~= " " and mapping.mode ~= "" then
    vim.notify(
      "Use this shortcut in " .. (modes[mapping.mode] or mapping.mode) .. " mode. Enter runs Normal-mode actions.",
      vim.log.levels.INFO,
      { title = "Shortcuts" }
    )
    return
  end
  picker:norm(function()
    if not vim.api.nvim_win_is_valid(window) or vim.api.nvim_win_get_buf(window) ~= buffer then
      vim.notify(
        "The original pane has changed. Reopen Shortcuts from the pane you want to use.",
        vim.log.levels.WARN,
        { title = "Shortcuts" }
      )
      return
    end
    local active = vim.api.nvim_buf_call(buffer, function()
      return vim.fn.maparg(mapping.lhs, "n", false, true)
    end)
    if
      active.callback ~= mapping.callback
      or active.rhs ~= mapping.rhs
      or active.expr ~= mapping.expr
      or active.noremap ~= mapping.noremap
      or (active.buffer ~= 0) ~= (mapping.buffer ~= 0)
    then
      vim.notify(
        "This shortcut has changed or is overridden in this buffer. Reopen Shortcuts to refresh it.",
        vim.log.levels.INFO,
        { title = "Shortcuts" }
      )
      return
    end
    picker:close()
    -- Let the input window finish closing before replaying the real mapping.
    -- Native dispatch preserves expression mappings and existing confirmations.
    vim.schedule(function()
      if
        vim.api.nvim_win_is_valid(window)
        and vim.api.nvim_win_get_buf(window) == buffer
        and vim.api.nvim_get_mode().mode:sub(1, 1) == "n"
      then
        vim.api.nvim_set_current_win(window)
        local keys = vim.api.nvim_replace_termcodes(mapping.lhs, true, false, true)
        vim.api.nvim_feedkeys(keys, "m", false)
      end
    end)
  end)
end

function M.open()
  local buffer = vim.api.nvim_get_current_buf()
  local window = vim.api.nvim_get_current_win()
  return Snacks.picker.keymaps({
    title = "Shortcuts",
    format = format,
    -- Match consecutive characters within each term, in any term order.
    -- Fuzzy letters across columns made "swap" match "Toggle Wrap".
    matcher = { fuzzy = false, filename_bonus = false, file_pos = false },
    main = { current = true },
    -- Filtering runs while the search input is focused. Always collect local
    -- mappings from the buffer where the user opened this guide.
    finder = function(opts)
      if not vim.api.nvim_buf_is_valid(buffer) then
        return {}
      end
      return vim.api.nvim_buf_call(buffer, function()
        local items = require("snacks.picker.source.vim").keymaps(opts)
        for _, item in ipairs(items) do
          item.shortcut = shortcut(item.item.lhs)
          item.description = item.item.desc or "Custom mapping (no description)"
          if item.description == "vim.lsp.buf.selection_range(vim.v.count1)" then
            item.description = "Expand Selection"
          elseif item.description == "vim.lsp.buf.selection_range(-vim.v.count1)" then
            item.description = "Shrink Selection"
          end
          -- Only search what the guide presents, not callback paths or code.
          item.text = item.shortcut .. " " .. item.description .. " " .. (modes[item.item.mode] or item.item.mode)
        end
        return items
      end)
    end,
    confirm = function(picker, item)
      execute(picker, item, window, buffer)
    end,
    actions = {
      clear_query = function(picker)
        picker.input:set("", "")
      end,
      toggle_buffer = function(picker)
        toggle(picker, "local")
      end,
      toggle_global = function(picker)
        toggle(picker, "global")
      end,
    },
    layout = {
      preview = false,
      layout = {
        box = "vertical",
        width = 0.75,
        max_width = 90,
        height = 0.6,
        max_height = 22,
        border = "rounded",
        title = " {title} ",
        title_pos = "center",
        footer = " Enter run · Esc close · C-b/C-g scopes ",
        footer_pos = "center",
        { win = "input", height = 1, border = "bottom", title = "" },
        { win = "list", border = "none" },
      },
    },
    win = {
      input = {
        keys = {
          ["<C-u>"] = { "clear_query", mode = { "n", "i" }, desc = "Clear Search" },
          ["<C-b>"] = { "toggle_buffer", mode = { "n", "i" } },
          ["<C-g>"] = { "toggle_global", mode = { "n", "i" } },
          ["<Esc>"] = { "close", mode = { "n", "i" } },
        },
      },
    },
  })
end

return M
