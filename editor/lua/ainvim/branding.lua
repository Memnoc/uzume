local M = {}
local decoration_ns = vim.api.nvim_create_namespace("ainvim.dashboard_corners")

local function decorate(dashboard)
  local api = vim.api
  local buf, win = dashboard.buf, dashboard.win
  if not api.nvim_buf_is_valid(buf) or not api.nvim_win_is_valid(win) then
    return
  end
  if api.nvim_win_get_buf(win) ~= buf or vim.bo[buf].filetype ~= "snacks_dashboard" then
    return
  end
  api.nvim_buf_clear_namespace(buf, decoration_ns, 0, -1)
  local width, height = api.nvim_win_get_width(win), api.nvim_win_get_height(win)
  if width < 90 or height < 28 then
    return
  end

  local count = api.nvim_buf_line_count(buf)
  local function mark(row, col, text)
    if row >= count then
      return
    end
    local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    local first = #(line:match("^%s*") or "")
    local last = vim.fn.strdisplaywidth(line:gsub("%s+$", ""))
    -- Leave content visible if a custom section extends into a margin.
    if last > col and first < col + vim.fn.strdisplaywidth(text) then
      return
    end
    api.nvim_buf_set_extmark(buf, decoration_ns, row, 0, {
      virt_text = { { text, "NonText" } },
      virt_text_pos = "overlay",
      virt_text_win_col = col,
      hl_mode = "combine",
    })
  end
  local top = dashboard.row or 0
  for index, glyph in ipairs({ "·", "┆", "│", "│", "┆", "·" }) do
    local row = top + (index - 1) * 2
    mark(row, 3, glyph)
    mark(row, width - 4, glyph)
  end
end

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
  return {
    text = text,
    align = "center",
    padding = 2,
    render = function()
      -- Snacks writes the content after rendering items; decorate it afterward.
      vim.schedule(function()
        decorate(dashboard)
      end)
    end,
  }
end

return M
