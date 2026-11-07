local M = {}
local file = vim.fn.stdpath("data") .. "/tool-paths.json"
local ok, paths = pcall(function()
  return vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
end)
M.paths = ok and type(paths) == "table" and paths or {}

function M.find(name)
  local path = M.paths[name]
  if path and vim.fn.executable(path) == 1 then
    return path
  end
  local executable = vim.fn.exepath(name)
  return executable ~= "" and executable or nil
end

return M
