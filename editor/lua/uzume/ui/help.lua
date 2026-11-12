-- A small, scrollable key guide for dense transient views.
local M = {}
function M.open(title, lines)
  local window = Snacks.win({
    text = lines,
    enter = true,
    width = 0.75,
    height = math.min(#lines + 1, math.max(3, vim.o.lines - 8)),
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    footer = " q / Esc back ",
    footer_pos = "center",
    zindex = 100,
    bo = { filetype = "uzume_help", modifiable = false, bufhidden = "wipe" },
    wo = { wrap = true, linebreak = true, number = false, relativenumber = false },
  })
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function()
      window:close()
    end, { buffer = window.buf, nowait = true, desc = "Close Key Guide" })
  end
end
return M
