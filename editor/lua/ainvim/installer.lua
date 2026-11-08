-- EDITOR SPIKE: file-triggered, curated tool installation through pinned Mason.
local M = { pending = {}, failures = {} }
local tools = require("ainvim.tools")
local data = vim.fn.stdpath("data")
local function read(path, fallback)
  local ok, value = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end)
  return ok and type(value) == "table" and value or fallback
end
local function write(path, value)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local temp = path .. "." .. vim.fn.getpid() .. ".tmp"
  assert(vim.fn.writefile({ vim.json.encode(value) }, temp) == 0, "Cannot save tool preferences")
  assert(vim.uv.fs_rename(temp, path))
end
M.lock = read(vim.fn.stdpath("config") .. "/tools.lock.json", {})
M.failures = read(data .. "/tool-failures.json", {})
M.auto = read(data .. "/tool-settings.json", {}).auto_install ~= false
M.packages = {
  ["rust-analyzer"] = "rust-analyzer",
  ["lua-language-server"] = "lua-language-server",
  stylua = "stylua",
  clangd = "clangd",
  vtsls = "vtsls",
  ["vscode-html-language-server"] = "html-lsp",
  ["vscode-css-language-server"] = "css-lsp",
  ["vscode-json-language-server"] = "json-lsp",
  ["vscode-eslint-language-server"] = "eslint-lsp",
  prettier = "prettier",
  ["tailwindcss-language-server"] = "tailwindcss-language-server",
  ["emmet-ls"] = "emmet-ls",
}
-- Only these filetypes trigger installs. Optional integrations remain explicit.
M.filetypes = {
  rust = { "rust", "rust-analyzer", "rustfmt" },
  lua = { "lua", "lua-language-server", "stylua" },
  c = { "c", "clangd" },
  cpp = { "c", "clangd" },
  javascript = { "web", "vtsls", "prettier" },
  javascriptreact = { "web", "vtsls", "prettier" },
  typescript = { "web", "vtsls", "prettier" },
  typescriptreact = { "web", "vtsls", "prettier" },
  html = { "web", "vscode-html-language-server", "prettier" },
  css = { "web", "vscode-css-language-server", "prettier" },
  scss = { "web", "vscode-css-language-server", "prettier" },
  less = { "web", "vscode-css-language-server", "prettier" },
  json = { "web", "vscode-json-language-server", "prettier" },
  jsonc = { "web", "vscode-json-language-server", "prettier" },
}
local function changed()
  vim.api.nvim_exec_autocmds("User", { pattern = "AiNvimToolsChanged", modeline = false })
end
local function notice(message, level)
  Snacks.notify(message, { title = "Extras", level = level or vim.log.levels.INFO })
end
local function registry_valid()
  local path = tools.root .. "/registries/github/mason-org/mason-registry/registry.json"
  return vim.fn.filereadable(path) == 1
    and vim.fn.sha256(table.concat(vim.fn.readfile(path, "b"), "\n")) == M.lock.registry.sha256
end
local waiters
local function registry_ready(callback)
  if waiters then
    waiters[#waiters + 1] = callback
    return
  end
  if registry_valid() then
    callback(true)
    return
  end
  waiters = { callback }
  require("mason-registry").update(vim.schedule_wrap(function(ok)
    local callbacks = waiters
    waiters = nil
    ok = ok and registry_valid()
    for _, done in ipairs(callbacks) do
      done(ok)
    end
  end))
end

function M.status(name)
  local package = M.packages[name]
  local path = tools.find(name)
  local state = M.pending[name] and "installing"
    or tools.managed(name) and "installed"
    or M.failures[name] and "failed"
    or path and "external"
    or package and "available"
    or "toolchain required"
  local version
  if package and tools.managed(name) then
    local receipt = read(tools.root .. "/packages/" .. package .. "/mason-receipt.json", {})
    local source = receipt.source or receipt.primary_source or {}
    version = source.id and source.id:match("@([^@]+)$")
  end
  return {
    state = state,
    path = path,
    package = package,
    version = version,
    pinned = package and M.lock.packages[package],
    error = M.failures[name],
  }
end

function M.ensure(name, explicit)
  if M.pending[name] then
    return
  end
  if (tools.find(name) and not explicit) or tools.managed(name) then
    if M.failures[name] then
      M.failures[name] = nil
      write(data .. "/tool-failures.json", M.failures)
      changed()
    end
    return
  end
  if M.failures[name] and not explicit then
    return -- Failed automatic installs require an explicit retry, including across restarts.
  end
  local function finish(ok, err)
    M.pending[name] = nil
    M.failures[name] = not ok and tostring(err) or nil
    write(data .. "/tool-failures.json", M.failures)
    if ok then
      require("ainvim.languages").refresh()
      notice(name .. " installed; available to open files.")
    else
      notice(
        name .. ": " .. tostring(err) .. "\nSpace l → Ctrl-r to retry; Ctrl-g for Mason logs.",
        vim.log.levels.WARN
      )
    end
    changed()
  end
  local package = M.packages[name]
  if not package then
    if not tools.find(name) then
      finish(false, "Install rustfmt with your Rust toolchain: rustup component add rustfmt")
    end
    return
  end
  M.pending[name], M.failures[name] = true, nil
  changed()
  notice("Installing " .. name .. " @ " .. M.lock.packages[package])
  registry_ready(function(ok)
    if not ok then
      finish(false, "Pinned Mason registry unavailable or checksum mismatch")
      return
    end
    local success, err = pcall(function()
      local pkg = require("mason-registry").get_package(package)
      if pkg:is_installing() then
        finish(false, "Installation already running in Mason; wait for it to finish")
        return
      end
      pkg:install(
        { version = M.lock.packages[package] },
        vim.schedule_wrap(function(installed, result)
          finish(installed and tools.managed(name) ~= nil, installed and "Installed executable was not found" or result)
        end)
      )
    end)
    if not success then
      finish(false, err)
    end
  end)
end

function M.install_pack(entry, explicit)
  for _, name in ipairs(entry.tools) do
    M.ensure(name, explicit)
  end
end

function M.for_buffer(buf)
  if not M.auto or not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
    return
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" or name:match("^%a[%w+.-]*://") then
    return
  end
  local spec = M.filetypes[vim.bo[buf].filetype]
  local extras = require("ainvim.extras")
  if not spec or not extras.enabled(spec[1]) or not extras.desired[spec[1]] then
    return
  end
  for i = 2, #spec do
    if spec[i] ~= "prettier" or not tools.prettier(name) then
      M.ensure(spec[i])
    end
  end
end

function M.show_mason()
  registry_ready(function(ok)
    if ok then
      require("mason.ui").open()
    else
      notice("Pinned Mason registry unavailable; retry when online.", vim.log.levels.WARN)
    end
  end)
end

function M.setup()
  require("mason").setup({
    install_root_dir = tools.root,
    PATH = "skip",
    registries = { M.lock.registry.source },
    system_registries = {},
    registry_cache = { refresh = false },
    firewall = { enabled = false, auto_managed = false },
    ui = { border = "rounded", check_outdated_packages_on_open = false },
    max_concurrent_installers = 4,
  })
  -- Bootstrap only the pinned registry even on a first-run :Mason request.
  vim.api.nvim_create_user_command("Mason", M.show_mason, { desc = "Browse tools from the pinned Mason registry" })
  local function set_auto(value)
    M.auto = value
    write(data .. "/tool-settings.json", { auto_install = value })
    notice("Automatic tool installation " .. (value and "enabled" or "disabled"))
    if value then
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        M.for_buffer(buf)
      end
    end
  end
  Snacks.toggle({
    name = "Automatic Tool Installation",
    get = function()
      return M.auto
    end,
    set = set_auto,
  }):map("<leader>uI")
  vim.api.nvim_create_user_command("ExtrasAutoInstall", function()
    set_auto(not M.auto)
  end, { desc = "Toggle automatic tool installation" })
  local group = vim.api.nvim_create_augroup("ainvim_tool_install", { clear = true })
  vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
    group = group,
    callback = function(event)
      vim.schedule(function()
        require("ainvim.languages").refresh()
        M.for_buffer(event.buf)
      end)
    end,
  })
  -- Covers packages installed manually through :Mason too.
  require("mason-registry"):on(
    "package:install:success",
    vim.schedule_wrap(function(pkg)
      for name, package in pairs(M.packages) do
        if package == pkg.name then
          M.failures[name] = nil
        end
      end
      write(data .. "/tool-failures.json", M.failures)
      require("ainvim.languages").refresh()
      changed()
    end)
  )
  vim.schedule(function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      M.for_buffer(buf)
    end
  end)
end
return M
