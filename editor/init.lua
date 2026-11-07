-- EDITOR SPIKE: independent configuration, evaluated incrementally with Memnoc.
assert(vim.fn.has("nvim-0.11") == 1, "ai-nvim needs Neovim 0.11+")
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
require("ainvim.options")
require("ainvim.packages").load()
require("ainvim.ui")
require("ainvim.keymaps")
require("ainvim.autocmds")
