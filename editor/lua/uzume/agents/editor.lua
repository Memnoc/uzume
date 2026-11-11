-- A task begins with file selection in its editor pane, beside the live CLI.
local M = {}
local api = vim.api

function M.create(task)
  local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
  vim.bo[buf].buftype, vim.bo[buf].bufhidden = "nofile", "wipe"
  vim.bo[buf].filetype = "uzume_task"
  api.nvim_buf_set_name(buf, "uzume://task/" .. task.id .. "/Choose a file")
  vim.b[buf].snacks_main = true
  vim.bo[buf].modifiable = false
  local options = {
    number = vim.wo[win].number,
    relativenumber = vim.wo[win].relativenumber,
    cursorline = vim.wo[win].cursorline,
  }
  for option in pairs(options) do
    vim.wo[win][option] = false
  end
  api.nvim_create_autocmd("BufWinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        if api.nvim_win_is_valid(win) and api.nvim_win_get_buf(win) ~= buf then
          for option, value in pairs(options) do
            vim.wo[win][option] = value
          end
        end
      end)
    end,
  })
  return win
end

function M.pick(win, task)
  if not api.nvim_win_is_valid(win) then
    return
  end
  vim.cmd.stopinsert()
  api.nvim_set_current_win(win)
  return Snacks.picker.files({
    cwd = task.cwd,
    title = "Choose a file",
    main = { current = true },
    layout = {
      preview = false,
      layout = {
        box = "vertical",
        relative = "win",
        win = win,
        width = 0,
        height = 0,
        row = 0,
        col = 0,
        border = "rounded",
        title = " Choose a file · Enter open · Esc cancel ",
        { win = "input", height = 1, border = "bottom" },
        { win = "list" },
      },
    },
  })
end

return M
