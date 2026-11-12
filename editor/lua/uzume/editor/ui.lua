local accents = {
  SnacksDashboardHeader = "iris",
  SnacksDashboardTitle = "iris",
  SnacksDashboardIcon = "iris",
  SnacksDashboardDesc = "text",
  SnacksDashboardFile = "text",
  SnacksDashboardKey = "rose",
  FloatBorder = "iris",
  FloatTitle = "iris",
  WhichKeyBorder = "iris",
  WhichKeyGroup = "iris",
}

-- These groups normally inherit cyan information colors. Brand the controls
-- themselves, keeping diagnostic colors and other themes' fallback links intact.
local accent_links = {
  NoiceCmdlineIcon = "DiagnosticSignInfo",
  NoiceCmdlineIconSearch = "DiagnosticSignWarn",
  NoiceCmdlinePrompt = "Title",
  NoiceCmdlinePopupBorder = "DiagnosticSignInfo",
  NoiceCmdlinePopupBorderSearch = "DiagnosticSignWarn",
  NoiceCmdlinePopupTitle = "DiagnosticSignInfo",
  SnacksInputIcon = "DiagnosticHint",
  SnacksInputBorder = "DiagnosticInfo",
  SnacksInputTitle = "DiagnosticInfo",
  SnacksPickerPrompt = "Special",
  SnacksPickerKeymapLhs = "Special",
  SnacksFooterDesc = "DiagnosticInfo",
}
local highlight_groups = {
  SnacksDashboardHeader = { link = "Title" },
  SnacksDashboardTitle = { link = "Title" },
  SnacksDashboardIcon = { link = "Special" },
  SnacksDashboardDesc = { link = "Special" },
  SnacksDashboardFile = { link = "Special" },
  SnacksDashboardKey = { link = "Number" },
}
for group, link in pairs(accent_links) do
  accents[group] = "iris"
  highlight_groups[group] = { link = link }
end

-- Resolve shared aliases before the Markdown colors change. Rose Pine resolves
-- empty overrides against its original highlights before calling before_highlight.
for _, group in ipairs({ "htmlLink", "VimwikiLink" }) do
  highlight_groups[group] = {}
end
for level = 1, 6 do
  accents["markdownH" .. level] = "iris"
  for _, group in ipairs({
    "htmlH" .. level,
    "VimwikiHeader" .. level,
    "NeorgHeading" .. level .. "Prefix",
    "NeorgHeading" .. level .. "Title",
  }) do
    highlight_groups[group] = {}
  end
end
local markdown_links = {
  markdownListMarker = "htmlTagName",
  markdownOrderedListMarker = "markdownListMarker",
  ["@markup.heading.markdown"] = "@markup.heading",
  ["@markup.list.markdown"] = "@markup.list",
}
for group, link in pairs(markdown_links) do
  accents[group] = "iris"
  highlight_groups[group] = { link = link }
end
local markdown_orange = {
  markdownUrl = true,
  markdownLinkText = true,
  markdownCode = true,
  mkdCode = true,
  ["@markup.link.label.markdown_inline"] = true,
  ["@markup.link.url.markdown_inline"] = true,
  ["@markup.raw.markdown_inline"] = true,
}
for group in pairs(markdown_orange) do
  -- Retain underline/italic attributes from the upstream definition.
  highlight_groups[group] = {}
end

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
  -- Register upstream fallback links so Moon and Dawn retain their look.
  highlight_groups = highlight_groups,
  before_highlight = function(group, highlight, palette)
    if require("rose-pine.config").options.variant ~= "main" then
      return
    end
    local accent = accents[group]
    if accent then
      highlight.link = nil
      highlight.fg = palette[accent]
    elseif markdown_orange[group] then
      highlight.link = nil
      highlight.fg = "#f6ad75"
      if highlight.sp then
        highlight.sp = "#f6ad75"
      end
    end
  end,
})
vim.cmd.colorscheme("rose-pine")

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
    lualine_b = {
      function()
        if vim.t.uzume_unassigned then
          return "No project"
        end
        if not vim.t.uzume_root then
          return ""
        end
        return (vim.t.uzume_project_name or vim.fs.basename(vim.t.uzume_root))
          .. " / "
          .. (vim.t.uzume_name or "Editor")
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
