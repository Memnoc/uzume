local M = {}

-- Half-block rendering of docs/assets/uzume-logo.svg: arch, sun, then arch.
-- Each row is 11 terminal cells wide; the middle segment uses the sun color.
local logo = {
  { "  ▄█████▄  " },
  { "▄█▀     ▀█▄" },
  { "██       ██" },
  { "██ ", "▄███▄", " ██" },
  { "██ ", "█████", " ██" },
  { "   ▀▀▀▀▀   " },
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
  local height = vim.api.nvim_win_get_height(dashboard.win)
  local full = height >= 40
  local show_logo = height >= 30
  local top = height >= 30 and 3 or 2
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
  if show_logo then
    for _, parts in ipairs(logo) do
      row(parts)
    end
    row({ "" })
  end
  for _, line in ipairs(full and wordmark or { "U Z U M E" }) do
    row({ line })
  end
  return { text = text, align = "center", padding = { full and 2 or 1, top } }
end

-- Budget the whole home screen on every resize, including populated history.
-- Keep navigation and breathing room before spending rows on recent entries.
function M.home(dashboard)
  local header = M.section(dashboard)
  local rows = 1
  for _, part in ipairs(header.text) do
    if part[1] == "\n" then
      rows = rows + 1
    end
  end
  local height = vim.api.nvim_win_get_height(dashboard.win)
  local keys = #dashboard.opts.preset.keys
  local remaining = height - rows - header.padding[1] - header.padding[2] - (keys + 2) - 1
  local limit = math.min(5, math.floor((remaining - 4) / 2))
  local sections = {
    header,
    { title = "Keymaps", section = "keys", indent = 2, padding = 1 },
  }
  if limit >= 1 then
    sections[#sections + 1] = {
      icon = " ",
      title = "Recent Files",
      section = "recent_files",
      indent = 2,
      padding = 1,
      limit = limit,
    }
    sections[#sections + 1] = {
      icon = " ",
      title = "Projects",
      section = "projects",
      indent = 2,
      padding = 1,
      limit = limit,
    }
  end
  return sections
end

return M
