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
  local roots = {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    local directory = client.config.root_dir
    if type(directory) == "string" and (file == directory or vim.startswith(file, directory .. "/")) then
      roots[#roots + 1] = directory
    end
  end
  table.sort(roots, function(a, b)
    return #a > #b
  end)
  if roots[1] then
    return roots[1]
  end
  -- A worktree's .git is a file: vim.fs.root handles either kind of marker.
  return vim.fs.root(file, { ".git", "lua" }) or vim.fn.getcwd()
end

return M
