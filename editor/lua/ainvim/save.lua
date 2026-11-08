local M = {}

function M.file()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "" then
    vim.notify(
      "This view is not a file. Open a file with Space e or Space Space.",
      vim.log.levels.INFO,
      { title = "Editor" }
    )
    return
  end
  local function write(path)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
      vim.cmd.write({ args = path and { path } or {} })
    end)
    if not ok then
      vim.notify(tostring(err), vim.log.levels.ERROR, { title = "Editor" })
    end
  end
  if vim.api.nvim_buf_get_name(buf) ~= "" then
    write()
    vim.cmd.stopinsert()
    return
  end
  local directory = require("ainvim.project").root(buf)
  Snacks.input({
    prompt = "Save file as · Enter save · Esc cancel",
    default = directory .. "/",
    completion = "file",
    win = {
      keys = {
        i_esc = { "<Esc>", "cancel", mode = "i", expr = false },
        i_cr = { "<CR>", "confirm", mode = { "i", "n" }, expr = false },
        clear = {
          "<C-u>",
          function(win)
            vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, { "" })
            vim.api.nvim_win_set_cursor(win.win, { 1, 0 })
          end,
          mode = { "i", "n" },
        },
      },
    },
  }, function(path)
    if not path or vim.trim(path) == "" then
      return
    end
    path = vim.fs.normalize(vim.fn.expand(path))
    if not vim.startswith(path, "/") then
      path = directory .. "/" .. path
    end
    if vim.fn.isdirectory(path) == 1 then
      vim.notify("Choose a filename, not a directory", vim.log.levels.WARN, { title = "Editor" })
      return
    end
    if vim.uv.fs_stat(path) then
      vim.notify(
        "File already exists. Choose another name or open that file.",
        vim.log.levels.WARN,
        { title = "Editor" }
      )
      return
    end
    if vim.fn.isdirectory(vim.fs.dirname(path)) ~= 1 then
      vim.notify("The parent directory does not exist", vim.log.levels.WARN, { title = "Editor" })
      return
    end
    write(path)
    vim.cmd.stopinsert()
  end)
end

return M
