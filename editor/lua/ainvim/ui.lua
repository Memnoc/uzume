require("rose-pine").setup({ variant = "main" })
vim.cmd.colorscheme("rose-pine")

Snacks.setup({
  bigfile = { enabled = true },
  quickfile = { enabled = true },
  explorer = { enabled = true },
  picker = {
    enabled = true,
    sources = { explorer = { layout = { preset = "sidebar", preview = false } } },
  },
  input = { enabled = true },
  notifier = {
    enabled = true,
    style = "minimal",
    level = vim.log.levels.INFO,
    filter = function(notification)
      return notification.title == "Extras"
        or notification.title == "Editor"
        or notification.level == "warn"
        or notification.level == "error"
    end,
  },
  indent = { enabled = true, animate = { enabled = false } },
  statuscolumn = { enabled = true },
  dashboard = {
    enabled = true,
    preset = {
      header = require("ainvim.branding").header,
      keys = {
        {
          icon = " ",
          key = "f",
          desc = "Find File",
          action = function()
            Snacks.picker.files()
          end,
        },
        {
          icon = " ",
          key = "e",
          desc = "Explorer",
          action = function()
            Snacks.explorer()
          end,
        },
        { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
        {
          icon = " ",
          key = "g",
          desc = "Find Text",
          action = function()
            Snacks.picker.grep()
          end,
        },
        {
          icon = " ",
          key = "r",
          desc = "Recent Files",
          action = function()
            Snacks.picker.recent()
          end,
        },
        { icon = " ", key = "q", desc = "Quit", action = ":qa" },
      },
    },
    sections = {
      { section = "header" },
      { title = "Keymaps", section = "keys", indent = 2, padding = 1 },
      { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
      { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
    },
  },
})

require("which-key").setup({
  preset = "helix",
  spec = {
    { "<leader>a", group = "projects/windows" },
    { "<leader>b", group = "buffer" },
    { "<leader>c", group = "code" },
    { "<leader>f", group = "file/find" },
    { "<leader>g", group = "git" },
    { "<leader>gh", group = "hunks" },
    { "<leader>q", group = "quit" },
    { "<leader>s", group = "search" },
    { "<leader>u", group = "ui" },
    { "<leader>w", group = "windows" },
    { "<leader>p", group = "panes" },
    { "<leader>pg", group = "focus" },
    { "<leader>pM", group = "move" },
    { "<leader>pR", group = "resize" },
    { "<leader>x", group = "diagnostics/quickfix" },
    { "<leader><tab>", group = "tabs" },
    { "[", group = "prev" },
    { "]", group = "next" },
  },
})

require("bufferline").setup({
  options = {
    close_command = function(buf)
      Snacks.bufdelete(buf)
    end,
    right_mouse_command = function(buf)
      Snacks.bufdelete(buf)
    end,
    diagnostics = "nvim_lsp",
    always_show_bufferline = false,
    offsets = { { filetype = "snacks_layout_box" } },
  },
})
require("lualine").setup({
  options = {
    theme = "auto",
    globalstatus = true,
    disabled_filetypes = { statusline = { "snacks_dashboard" } },
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = {
      function()
        if vim.t.ainvim_unassigned then
          return "No project"
        end
        if not vim.t.ainvim_root then
          return ""
        end
        return (vim.t.ainvim_project_name or vim.fs.basename(vim.t.ainvim_root))
          .. " / "
          .. (vim.t.ainvim_name or "Editor")
      end,
      "branch",
    },
    lualine_c = {
      "diagnostics",
      {
        "filename",
        path = 1,
        fmt = function(name)
          return vim.bo.filetype == "ainvim_session" and "Project home" or name
        end,
      },
    },
    lualine_x = {
      "diff",
      {
        "filetype",
        fmt = function(name)
          return name == "ainvim_session" and "Project home" or name
        end,
      },
    },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
})
require("gitsigns").setup({
  signs = {
    add = { text = "▎" },
    change = { text = "▎" },
    delete = { text = "" },
    topdelete = { text = "" },
    changedelete = { text = "▎" },
    untracked = { text = "▎" },
  },
})
require("flash").setup()
require("mini.pairs").setup()
