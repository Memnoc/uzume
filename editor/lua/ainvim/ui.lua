local dashboard_accents = {
  SnacksDashboardHeader = "iris",
  SnacksDashboardTitle = "iris",
  SnacksDashboardIcon = "iris",
  SnacksDashboardDesc = "text",
  SnacksDashboardFile = "text",
  SnacksDashboardKey = "rose",
}

require("rose-pine").setup({
  variant = "main",
  -- A gentle mauve tint for neutral text, scoped to Rose Pine's main variant.
  palette = {
    main = {
      text = "#e0d4eb",
      subtle = "#a99ab8",
      muted = "#8b7c98",
    },
  },
  -- Register the dashboard's default links so Moon and Dawn retain their look.
  highlight_groups = {
    SnacksDashboardHeader = { link = "Title" },
    SnacksDashboardTitle = { link = "Title" },
    SnacksDashboardIcon = { link = "Special" },
    SnacksDashboardDesc = { link = "Special" },
    SnacksDashboardFile = { link = "Special" },
    SnacksDashboardKey = { link = "Number" },
  },
  before_highlight = function(group, highlight, palette)
    local accent = dashboard_accents[group]
    if accent and require("rose-pine.config").options.variant == "main" then
      highlight.link = nil
      highlight.fg = palette[accent]
    end
  end,
})
vim.cmd.colorscheme("rose-pine")

Snacks.setup({
  styles = {
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
        { icon = " ", key = "q", desc = "Quit", action = ":qa" },
      },
    },
    sections = {
      require("ainvim.branding").section,
      { title = "Keymaps", section = "keys", indent = 2, padding = 1 },
      { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
      { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
    },
  },
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
      return require("uzume.workspace_buffers").contains(buf)
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
          if vim.b.uzume_agent_label then
            return vim.b.uzume_agent_label
          end
          return vim.bo.filetype == "ainvim_session" and "Project home" or name
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
