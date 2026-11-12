-- Keep labels and action hints within terminal-cell widths, including Unicode.
local M = {}
function M.clean(value)
  return tostring(value or ""):gsub("[%c]", " ")
end
function M.fit(value, width)
  local text = M.clean(value)
  if width <= 0 then
    return ""
  end
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  while text ~= "" and vim.fn.strdisplaywidth(text .. "…") > width do
    text = vim.fn.strcharpart(text, 0, vim.fn.strchars(text) - 1)
  end
  return text .. "…"
end
function M.wrap(items, width)
  local lines, line = {}, ""
  for _, item in ipairs(items) do
    item = M.fit(item, width)
    local next_line = line == "" and item or (line .. " · " .. item)
    if line ~= "" and vim.fn.strdisplaywidth(next_line) > width then
      lines[#lines + 1], line = line, item
    else
      line = next_line
    end
  end
  if line ~= "" then
    lines[#lines + 1] = line
  end
  return lines
end
return M
