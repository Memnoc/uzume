local M = {}

-- Half-block rendering of docs/assets/uzume-logo.svg: arch, sun, then arch.
-- Each row is 20 terminal cells wide; the middle segment uses the sun color.
local logo = {
  { "     ▄▄██████▄▄     " },
  { "  ▄████▀▀▀▀▀▀████▄  " },
  { " ████▀        ▀████ " },
  { "███▀            ▀███" },
  { "███              ███" },
  { "███     ", "▄▄▄▄", "     ███" },
  { "███   ", "████████", "   ███" },
  { "███  ", "██████████", "  ███" },
  { "███  ", "▀▀▀▀▀▀▀▀▀▀", "  ███" },
  { "▀▀▀ ▀▀▀▀▀▀▀▀▀▀▀▀ ▀▀▀" },
}

local wordmark = {
  [[ _   _ _____ _   _ __  __ _____ ]],
  [[| | | |__  /| | | |  \/  | ____|]],
  [[| | | | / / | | | | |\/| |  _|  ]],
  [[| |_| |/ /_ | |_| | |  | | |___ ]],
  [[ \___//____| \___/|_|  |_|_____|]],
}

-- Standard highlight groups let every colorscheme supply its own logo colors.
function M.section(dashboard)
  local text = {}
  local function row(parts)
    if #text > 0 then
      text[#text + 1] = { "\n" }
    end
    local width = vim.fn.strdisplaywidth(table.concat(parts))
    local left = math.floor((31 - width) / 2)
    text[#text + 1] = { (" "):rep(left) }
    for index, part in ipairs(parts) do
      text[#text + 1] = {
        part,
        hl = index == 2 and "DiagnosticError" or "SnacksDashboardHeader",
      }
    end
    text[#text + 1] = { (" "):rep(31 - width - left) }
  end
  for _, parts in ipairs(logo) do
    row(parts)
  end
  row({ "" })
  local compact = vim.api.nvim_win_get_height(dashboard.win) < 30
  for _, line in ipairs(compact and { "U Z U M E" } or wordmark) do
    row({ line })
  end
  return { text = text, align = "center", padding = 2 }
end

return M
