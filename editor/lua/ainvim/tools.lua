local M = {}
local file = vim.fn.stdpath("data") .. "/tool-paths.json"
local ok, paths = pcall(function()
  return vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
end)
M.paths = ok and type(paths) == "table" and paths or {}
M.root = vim.fn.stdpath("data") .. "/mason"

function M.managed(name)
  local path = M.root .. "/bin/" .. name
  return vim.fn.executable(path) == 1 and path or nil
end

function M.find(name)
  local managed = M.managed(name)
  if managed then
    return managed
  end
  local path = M.paths[name]
  if path and vim.fn.executable(path) == 1 then
    return path
  end
  local executable = vim.fn.exepath(name)
  return executable ~= "" and executable or nil
end

function M.prettier(filename)
  local directory = vim.fs.dirname(filename)
  local bin = vim.fs.find("node_modules/.bin/prettier", { path = directory, upward = true })[1]
  return bin and vim.fn.executable(bin) == 1 and bin or M.find("prettier")
end

return M
