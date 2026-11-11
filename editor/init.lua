-- Uzume: independent editor configuration.
assert(vim.fn.has("nvim-0.11") == 1, "Uzume needs Neovim 0.11+")
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
require("uzume.editor.options")
require("uzume.editor.packages").load()
require("uzume.editor.ui")
require("uzume.editor.keymaps")
require("uzume.editor.autocmds")
require("uzume.ui.input").setup()
require("uzume.ui.commandline").setup()
require("uzume.editor.extras").setup()
require("uzume.editor.languages").setup()
require("uzume.editor.installer").setup()
require("uzume.agents.buffers").setup()
require("uzume.editor.navigator").setup()
require("uzume.agents").setup()
require("uzume.review").setup()
require("uzume.integration").setup()
if require("uzume.editor.extras").enabled("smear") then
  require("smear_cursor").setup({
    hide_target_hack = true,
    cursor_color = "none",
    smear_terminal_mode = false,
    filetypes_disabled = { "snacks_picker_input", "snacks_picker_list", "snacks_input", "wk", "uzume_navigator" },
  })
  Snacks.toggle({
    name = "Smear Cursor",
    get = function()
      return require("smear_cursor").enabled
    end,
    set = function(value)
      require("smear_cursor").enabled = value
    end,
  }):map("<leader>ua")
end
