vim.cmd.colorscheme(vim.g.uzume_colorscheme or "uzume")

Snacks.setup({
  styles = {
    dashboard = { wo = { scrolloff = 0 } },
    notification = {
      border = "rounded",
      wo = { wrap = true, linebreak = true, winblend = 0 },
    },
    notification_history = { wo = { wrap = true, linebreak = true } },
  },
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
    style = "compact",
    timeout = 7000,
    width = { min = 40, max = 0.45 },
    level = vim.log.levels.INFO,
    filter = function(notification)
      return notification.title == "Agent context"
        or notification.title == "Extras"
        or notification.title == "Editor"
        or notification.title == "Task review"
        or notification.level == "warn"
        or notification.level == "error"
    end,
  },
  indent = { enabled = true, animate = { enabled = false } },
  statuscolumn = { enabled = true },
  dashboard = {
    enabled = true,
    preset = {
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
        { icon = " ", key = "k", desc = "Search Keymaps", action = require("uzume.ui.keymaps").open },
        { icon = " ", key = "q", desc = "Quit", action = ":qa" },
      },
    },
    sections = require("uzume.editor.branding").home,
  },
})

-- Neovim can retain a scrolled viewport when a dashboard shrinks on resize.
vim.api.nvim_create_autocmd("User", {
  pattern = "SnacksDashboardUpdatePost",
  group = vim.api.nvim_create_augroup("UzumeDashboardViewport", { clear = true }),
  callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if
        vim.bo[buf].filetype == "snacks_dashboard"
        and vim.api.nvim_buf_line_count(buf) <= vim.api.nvim_win_get_height(win)
      then
        vim.api.nvim_win_call(win, function()
          vim.fn.winrestview({ topline = 1, leftcol = 0, skipcol = 0 })
        end)
      end
    end
  end,
})

require("which-key").setup({
  preset = "helix",
  spec = {
    { "<leader>a", group = "agents/projects" },
    { "<leader>b", group = "buffer" },
    { "<leader>c", group = "code" },
    { "<leader>f", group = "file/find" },
    { "<leader>g", group = "git" },
    { "<leader>gh", group = "hunks" },
    { "<leader>q", group = "quit" },
    { "<leader>s", group = "search" },
    { "<leader>u", group = "ui" },
    { "<leader>v", group = "review" },
    { "<leader>w", group = "windows" },
    { "<leader>p", group = "panes" },
    { "<leader>pg", group = "focus" },
    { "<leader>pM", group = "move" },
    { "<leader>pN", group = "new shell" },
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
    custom_filter = function(buf)
      return require("uzume.agents.buffers").contains(buf)
    end,
    diagnostics = "nvim_lsp",
    get_element_icon = function(element)
      local buf = vim.fn.bufnr(element.path)
      if buf == -1 then
        return
      end
      local kind = vim.b[buf].uzume_agent_kind
      if kind == "claude" then
        return "✳", "MiniIconsOrange"
      elseif kind == "codex" then
        return ">_", "MiniIconsAzure"
      end
      -- Returning nil keeps the normal file/shell icon provider.
    end,
    name_formatter = function(buffer)
      return vim.b[buffer.bufnr].uzume_agent_label or buffer.name
    end,
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
    lualine_b = { require("uzume.ui.location").statusline },
    lualine_c = {
      {
        require("uzume.ui.location").warning,
        color = function()
          local color = vim.api.nvim_get_hl(0, { name = "DiagnosticWarn", link = false }).fg
          return { fg = color and string.format("#%06x", color) or nil }
        end,
      },
      "diagnostics",
      {
        "filename",
        path = 1,
        fmt = function(name)
          if vim.b.uzume_agent_label then
            return vim.b.uzume_agent_label
          end
          return vim.bo.filetype == "uzume_session" and "Project home" or name
        end,
      },
    },
    lualine_x = {
      function()
        return require("uzume.agents").summary()
      end,
      "diff",
      {
        "filetype",
        fmt = function(name)
          return name == "uzume_session" and "Project home" or name
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
