local M = {}
M.modes = { "slide", "instant", "pulse", "spring" }
local path = vim.fn.stdpath("data") .. "/pane-motion.json"

function M.load()
  if vim.fn.filereadable(path) == 0 then
    return "slide"
  end
  local ok, saved = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end)
  if ok and type(saved) == "table" and saved.version == 1 and vim.tbl_contains(M.modes, saved.mode) then
    return saved.mode
  end
  vim.schedule(function()
    vim.notify(
      "Cannot read pane-motion.json; using Slide. Choose a mode with Space uA to save a fresh preference.",
      vim.log.levels.WARN,
      { title = "Pane animation" }
    )
  end)
  return "slide"
end

function M.save(mode)
  assert(vim.tbl_contains(M.modes, mode), "Choose slide, instant, pulse or spring")
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local temporary = path .. "." .. vim.fn.getpid() .. ".tmp"
  local ok, err = pcall(function()
    assert(
      vim.fn.writefile({ vim.json.encode({ version = 1, mode = mode }) }, temporary) == 0,
      "Cannot save pane animation preference"
    )
    assert(vim.uv.fs_chmod(temporary, 384))
    assert(vim.uv.fs_rename(temporary, path))
  end)
  if not ok then
    pcall(vim.uv.fs_unlink, temporary)
    error(err)
  end
end

return M
