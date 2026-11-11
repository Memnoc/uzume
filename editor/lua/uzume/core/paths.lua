-- Resolve resources from the editor marker, independently of Lua module depth.
local source = debug.getinfo(1, "S").source:sub(2)
local M = { editor = assert(vim.fs.root(source, "plugins.lock.json"), "Cannot locate the Uzume editor root") }

function M.file(relative)
  return vim.fs.joinpath(M.editor, relative)
end

return M
