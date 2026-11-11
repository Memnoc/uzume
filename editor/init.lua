-- EDITOR SPIKE: independent configuration, evaluated incrementally.
assert(vim.fn.has("nvim-0.11") == 1, "ai-nvim needs Neovim 0.11+")
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
require("ainvim.options")
require("ainvim.packages").load()
require("ainvim.ui")
require("ainvim.keymaps")
require("ainvim.autocmds")
require("uzume.ui.input").setup()
require("ainvim.extras").setup()
require("ainvim.languages").setup()
require("ainvim.installer").setup()
require("uzume.agents.buffers").setup()
require("ainvim.navigator").setup()
require("uzume.agents").setup()
require("uzume.review").setup()
require("uzume.integration").setup()
if require("ainvim.extras").enabled("smear") then
  require("smear_cursor").setup({
    hide_target_hack = true,
    cursor_color = "none",
    smear_terminal_mode = false,
    filetypes_disabled = { "snacks_picker_input", "snacks_picker_list", "snacks_input", "wk", "ainvim_navigator" },
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
