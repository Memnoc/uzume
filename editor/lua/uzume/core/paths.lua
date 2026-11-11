-- Resolve resources from the editor marker, independently of Lua module depth.
local source = debug.getinfo(1, "S").source:sub(2)
local M = { editor = assert(vim.fs.root(source, "plugins.lock.json"), "Cannot locate the Uzume editor root") }

function M.file(relative)
  return vim.fs.joinpath(M.editor, relative)
end

-- Old absolute paths can survive a storage migration through compatibility links.
function M.canonical(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  local resolved = vim.uv.fs_realpath(path)
  if resolved then
    return resolved
  end
  local parent = vim.uv.fs_realpath(vim.fs.dirname(path))
  return parent and vim.fs.joinpath(parent, vim.fs.basename(path)) or vim.fs.normalize(path)
end

function M.same(first, second)
  local canonical = M.canonical(first)
  return canonical ~= nil and canonical == M.canonical(second)
end

function M.contains(root, path)
  root, path = M.canonical(root), M.canonical(path)
  return root ~= nil and path ~= nil and (root == path or vim.startswith(path, root .. "/"))
end

return M
