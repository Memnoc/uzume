local opt = vim.opt
opt.termguicolors = true
opt.background = "dark"
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.laststatus = 3
opt.showmode = false
opt.ruler = false
opt.mouse = "a"
opt.clipboard = vim.env.SSH_CONNECTION and "" or "unnamedplus"
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.shiftround = true
opt.smartindent = true
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "nosplit"
opt.splitright = true
opt.splitbelow = true
opt.splitkeep = "screen"
opt.scrolloff = 4
opt.sidescrolloff = 8
opt.wrap = false
opt.linebreak = true
opt.list = true
opt.conceallevel = 2
opt.fillchars = { eob = " ", fold = " ", foldopen = "", foldclose = "", foldsep = " ", diff = "╱" }
opt.foldlevel = 99
opt.foldmethod = "indent"
opt.foldtext = ""
opt.confirm = true
opt.autoread = true
opt.autowrite = false -- Source-file saves stay explicit in the agreed design.
opt.undofile = true
opt.undolevels = 10000
opt.updatetime = 200
opt.timeoutlen = 300
opt.completeopt = "menu,menuone,noselect"
opt.pumheight = 10
opt.pumblend = 10
opt.virtualedit = "block"
opt.grepprg = "rg --vimgrep"
opt.grepformat = "%f:%l:%c:%m"
opt.shortmess:append({ W = true, I = true, c = true, C = true })
opt.formatoptions = "jcroqlnt"
opt.wildmode = "longest:full,full"
vim.g.markdown_recommended_style = 0
vim.g.snacks_animate = false
vim.diagnostic.config({ virtual_text = false, severity_sort = true, float = { border = "rounded" } })
vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")
