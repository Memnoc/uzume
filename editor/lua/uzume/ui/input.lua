-- Compatibility for native empty-prompt Backspace on the current Neovim nightly.
-- Stable 0.11 deletes this character normally; ordinary editing stays native.
local M = {}

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("uzume_input", { clear = true }),
    pattern = { "snacks_input", "snacks_picker_input" },
    callback = function(event)
      local function backspace()
        local buf = vim.api.nvim_get_current_buf()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local line = vim.api.nvim_get_current_line()
        local first = vim.fn.strcharpart(line, 0, 1)
        if
          vim.bo[buf].buftype == "prompt"
          and vim.fn.prompt_getprompt(buf) == ""
          and cursor[1] == vim.api.nvim_buf_line_count(buf)
          and cursor[2] > 0
          and cursor[2] == #first
        then
          vim.api.nvim_buf_set_text(buf, cursor[1] - 1, 0, cursor[1] - 1, cursor[2], { "" })
          vim.api.nvim_win_set_cursor(0, { cursor[1], 0 })
        else
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<BS>", true, false, true), "ni", false)
        end
      end
      for _, key in ipairs({ "<BS>", "<C-h>" }) do
        vim.keymap.set("i", key, backspace, { buffer = event.buf, desc = "Delete previous input character" })
      end
    end,
  })
end

return M
