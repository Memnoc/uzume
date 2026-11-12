-- Discovered by lualine's auto theme only while :colorscheme uzume is active.
local colors = {
  base = "#191724",
  surface = "#1f1d2e",
  overlay = "#26233a",
  text = "#e0d4eb",
  subtle = "#a99ab8",
  mauve = "#c4a7e7",
  sage = "#b8cda4",
  orange = "#f6ad75",
  gold = "#e7c58a",
  rose = "#ebbcba",
}
local function mode(accent)
  return {
    a = { fg = colors.base, bg = accent, gui = "bold" },
    b = { fg = accent, bg = colors.overlay },
    c = { fg = colors.text, bg = colors.surface },
  }
end
return {
  normal = mode(colors.mauve),
  insert = mode(colors.sage),
  visual = mode(colors.orange),
  replace = mode(colors.rose),
  command = mode(colors.gold),
  terminal = mode(colors.mauve),
  inactive = {
    a = { fg = colors.subtle, bg = colors.surface },
    b = { fg = colors.subtle, bg = colors.surface },
    c = { fg = colors.subtle, bg = colors.surface },
  },
}
