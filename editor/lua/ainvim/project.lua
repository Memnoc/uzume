local M = {}

function M.root(buf)
  if not buf then
    for _, picker in ipairs(Snacks.picker.get()) do
      if picker:is_focused() then
        return picker:cwd()
      end
    end
  end
  buf = buf or vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  if vim.bo[buf].buftype ~= "" or file == "" then
    return vim.fn.getcwd()
  end
  -- A worktree's .git is a file: vim.fs.root handles either kind of marker.
  return vim.fs.root(file, { ".git", "lua" }) or vim.fn.getcwd()
end

return M
