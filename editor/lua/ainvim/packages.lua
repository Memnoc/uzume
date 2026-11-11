local M = {}

function M.load()
  local lock = table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/plugins.lock.json"), "\n") .. "\n"
  local release = vim.fn.sha256(lock):sub(1, 12)
  local path = vim.fn.stdpath("data") .. "/releases/" .. release
  assert(
    vim.fn.filereadable(path .. "/.complete") == 1,
    "Uzume packages missing. Run ./setup-editor from the Uzume checkout."
  )
  local system = vim.uv.os_uname()
  local platform = system.sysname:lower() .. "-" .. system.machine:lower()
  assert(
    vim.fn.filereadable(path .. "/.platform") == 1 and vim.fn.readfile(path .. "/.platform")[1] == platform,
    "Uzume packages belong to another platform. Build them locally with ./setup-editor."
  )
  vim.opt.packpath:prepend(path)
  -- Native opt packages, installed from exact commits. Startup never updates.
  for _, plugin in ipairs(vim.json.decode(lock).plugins) do
    if not plugin.extra or require("ainvim.extras").enabled(plugin.extra) then
      vim.cmd.packadd(plugin.name)
    end
    if plugin.name == "mini.icons" then
      require("mini.icons").setup()
      require("mini.icons").mock_nvim_web_devicons()
    end
  end
  if require("ainvim.extras").enabled("languages") then
    vim.cmd.packadd("syntax")
  end
  vim.g.ainvim_release = release
end

return M
