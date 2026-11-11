-- Search the editor's live mappings; opening the guide never replays a shortcut.
local M = {}

local function toggle(picker, key)
  picker.opts[key] = not picker.opts[key]
  local scope = {}
  if picker.opts.global then
    scope[#scope + 1] = "Global"
  end
  if picker.opts["local"] then
    scope[#scope + 1] = "Buffer"
  end
  picker.title = "Search Keymaps · " .. (#scope > 0 and table.concat(scope, " + ") or "No scopes selected")
  picker:find()
end

function M.open()
  local buffer = vim.api.nvim_get_current_buf()
  return Snacks.picker.keymaps({
    title = "Search Keymaps · Global + Buffer",
    main = { current = true },
    -- Filtering runs while the search input is focused. Always collect local
    -- mappings from the buffer where the user opened this guide.
    finder = function(opts)
      if not vim.api.nvim_buf_is_valid(buffer) then
        return {}
      end
      return vim.api.nvim_buf_call(buffer, function()
        return require("snacks.picker.source.vim").keymaps(opts)
      end)
    end,
    confirm = "close",
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
        width = 0.85,
        max_width = 110,
        height = 0.7,
        border = "rounded",
        title = " {title} ",
        title_pos = "center",
        footer = " C-b buffer · C-g global · Enter/Esc back ",
        footer_pos = "center",
        { win = "input", height = 1, border = "bottom", title = " Type to search · C-n/p move " },
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
