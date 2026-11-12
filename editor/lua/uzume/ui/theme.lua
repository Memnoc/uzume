-- Uzume's named dark theme, derived from the pinned Rose Pine renderer.
-- Configuration and palette caches are restored after rendering so choosing
-- Rose Pine later uses its own options and colors.
local M = {}

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

local colors = {
  mauve = "#c4a7e7",
  orange = "#f6ad75",
  gold = "#e7c58a",
  sage = "#b8cda4",
  rose = "#ebbcba",
  soft = "#d1bedb",
}
local syntax = {}
local roles = {
  mauve = {
    "Conditional",
    "Exception",
    "Include",
    "Keyword",
    "Repeat",
    "Statement",
    "StorageClass",
    "Define",
    "Macro",
    "PreCondit",
    "Label",
  },
  orange = { "Function" },
  gold = { "String", "Character" },
  sage = { "Type", "Structure", "Tag", "@type", "@type.builtin", "@constructor" },
  rose = {
    "Boolean",
    "Constant",
    "Number",
    "Float",
    "@constant",
    "@constant.builtin",
    "@constant.macro",
    "@variable.builtin",
  },
  soft = {
    "Operator",
    "@property",
    "@variable.member",
    "@variable.parameter",
    "@variable.parameter.builtin",
    "@parameter",
  },
}
for role, groups in pairs(roles) do
  for _, group in ipairs(groups) do
    syntax[group] = colors[role]
  end
end

local function highlight(group, value, palette)
  local accent = accents[group]
  local color = syntax[group]
  if accent then
    color = palette[accent]
  elseif markdown_orange[group] then
    color = colors.orange
    if value.sp then
      value.sp = color
    end
  elseif group == "LspInlayHint" then
    -- Muted text on the tinted hint background falls below 4.5:1.
    color = palette.subtle
  elseif group == "GitSignsNoEOLPreview" then
    color = palette.gold
  elseif group == "@keyword" or group:match("^@keyword%.") then
    color = colors.mauve
  elseif group == "@function" or group:match("^@function%.") then
    color = colors.orange
  elseif group == "@string.escape" or group == "@string.regexp" then
    color = colors.orange
  end
  if color then
    value.link = nil
    value.fg = color
  end
end

highlight_groups.GitSignsNoEOLPreview = { link = "Constant" }

function M.load()
  local config = require("rose-pine.config")
  local original_options = config.options
  local original_palette = package.loaded["rose-pine.palette"]
  config.options = vim.tbl_deep_extend("force", {}, original_options, {
    variant = "main",
    palette = { main = {
      text = "#e0d4eb",
      subtle = "#a99ab8",
      muted = "#8b7c98",
    } },
    highlight_groups = highlight_groups,
    before_highlight = highlight,
  })
  package.loaded["rose-pine.palette"] = nil
  local ok, err = xpcall(function()
    require("rose-pine").colorscheme("main")
  end, debug.traceback)
  config.options = original_options
  package.loaded["rose-pine.palette"] = original_palette
  if not ok then
    error(err)
  end
  vim.g.colors_name = "uzume"
end

return M
