local M = {}

function M.load()
  local lock = table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/plugins.lock.json"), "\n") .. "\n"
  local release = vim.fn.sha256(lock):sub(1, 12)
  local path = vim.fn.stdpath("data") .. "/releases/" .. release
  assert(
    vim.fn.filereadable(path .. "/.complete") == 1,
    "ai-nvim packages missing. Run ./setup-editor from the ai-nvim-editor checkout."
  )
  vim.opt.packpath:prepend(path)
  -- Native opt packages, installed from exact commits. Startup never updates.
  for _, plugin in ipairs(vim.json.decode(lock).plugins) do
    vim.cmd.packadd(plugin.name)
    if plugin.name == "mini.icons" then
      require("mini.icons").setup()
      require("mini.icons").mock_nvim_web_devicons()
    end
  end
  vim.g.ainvim_release = release
end

return M
