-- One choice at a time. Generate a reviewable local pack from pinned definitions.
local M = {}
local function choose(title, values, callback)
  Snacks.picker.select(values, {
    prompt = title,
    snacks = { matcher = { fuzzy = false } },
    format_item = function(item)
      return item.label
    end,
  }, function(item)
    if item then
      local ok, err = pcall(callback, item)
      if not ok then
        vim.notify("Cannot create language pack: " .. tostring(err), vim.log.levels.ERROR)
      end
    end
  end)
end
local function pretty(value, depth)
  depth = depth or 0
  if type(value) ~= "table" then
    return vim.json.encode(value)
  end
  local array, lines = vim.islist(value), {}
  local keys = array and vim.fn.range(1, #value) or vim.tbl_keys(value)
  if not array then
    table.sort(keys)
  end
  for _, key in ipairs(keys) do
    lines[#lines + 1] = string.rep("  ", depth + 1)
      .. (array and "" or vim.json.encode(key) .. ": ")
      .. pretty(value[key], depth + 1)
  end
  local open, close = array and "[" or "{", array and "]" or "}"
  if #lines == 0 then
    return open .. close
  end
  return open .. "\n" .. table.concat(lines, ",\n") .. "\n" .. string.rep("  ", depth) .. close
end
M.encode = pretty

function M.start()
  vim.ui.input({ prompt = "Language filetype (e.g. python, go, yaml): " }, function(ft)
    if not ft then
      return
    end
    ft = vim.trim(ft)
    if not ft:match("^[a-z][a-z0-9_-]*$") then
      vim.notify("Use a Neovim filetype name, such as python or go.", vim.log.levels.WARN)
      return
    end
    local extras = require("uzume.editor.extras")
    for _, entry in ipairs(extras.catalog) do
      if vim.tbl_contains(entry.filetypes or (entry.spec and entry.spec.filetypes) or {}, ft) then
        vim.notify(ft .. " is already covered by " .. entry.name .. ". Enable it in Extras.", vim.log.levels.WARN)
        return
      end
    end
    require("uzume.editor.installer").catalog(function(registry)
      vim.cmd.packadd("nvim-lspconfig")
      vim.cmd.packadd("conform.nvim")
      local by_server, by_command = {}, {}
      for _, package in ipairs(registry) do
        if package.neovim and package.neovim.lspconfig then
          by_server[package.neovim.lspconfig] = package
        end
        for command in pairs(package.bin or {}) do
          by_command[command] = package
        end
      end
      local prerequisites = {}
      local function pin(spec, package)
        if package and package.bin and package.bin[spec.command] then
          local version = require("uzume.editor.installer").lock.packages[package.name]
            or (package.source and package.source.id or ""):match("@([^? #]+)")
          if version then
            spec.package, spec.version = package.name, version
            local source = package.source.id
            local requirement = source:find("pkg:npm/", 1, true) and "Node.js and npm on PATH"
              or source:find("pkg:pypi/", 1, true) and "Python with venv and pip support"
              or source:find("pkg:golang/", 1, true) and "Go toolchain on PATH"
              or source:find("pkg:cargo/", 1, true) and "Rust toolchain on PATH"
            if requirement then
              prerequisites[requirement] = true
            end
          end
        end
        if not spec.package then
          prerequisites[spec.command .. " installed on PATH"] = true
        end
        return spec
      end
      local servers = { { label = "No language server — formatting only" } }
      for _, file in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
        local name = vim.fs.basename(file):sub(1, -5)
        local ok, config = pcall(function()
          return vim.lsp.config[name]
        end)
        if
          ok
          and config
          and type(config.cmd) == "table"
          and type(config.cmd[1]) == "string"
          and vim.tbl_contains(config.filetypes or {}, ft)
        then
          local spec =
            pin({ name = name, command = config.cmd[1], args = vim.list_slice(config.cmd, 2) }, by_server[name])
          servers[#servers + 1] = { label = name .. (spec.package and " · Mason" or " · external"), spec = spec }
        end
      end
      table.sort(servers, function(a, b)
        return a.label < b.label
      end)
      choose("Language server for " .. ft .. " · type to filter", servers, function(selected)
        -- Prerequisites must describe only selected tools, not every candidate.
        prerequisites = {}
        if selected.spec then
          pin(selected.spec, by_server[selected.spec.name])
        end
        local formatters = { { label = "No formatter — use LSP formatting when available" } }
        for _, file in ipairs(vim.api.nvim_get_runtime_file("lua/conform/formatters/*.lua", true)) do
          local name = vim.fs.basename(file):sub(1, -5)
          local ok, definition = pcall(require, "conform.formatters." .. name)
          if ok and type(definition) == "table" and type(rawget(definition, "command")) == "string" then
            local package = by_command[definition.command]
            formatters[#formatters + 1] = {
              label = name .. (package and " · " .. table.concat(package.languages or {}, ", ") or " · external"),
              spec = { name = name, command = definition.command },
              package = package,
            }
          end
        end
        table.sort(formatters, function(a, b)
          return a.label < b.label
        end)
        choose("Formatter for " .. ft .. " · search its name or language", formatters, function(formatter)
          local value = {
            version = 1,
            name = ft:sub(1, 1):upper() .. ft:sub(2),
            description = "Local language pack. Edit settings with Ctrl-e in Extras.",
            filetypes = { ft },
            servers = selected.spec and { selected.spec } or {},
            formatters = formatter.spec and { pin(formatter.spec, formatter.package) } or {},
            prerequisites = vim.tbl_keys(prerequisites),
          }
          table.sort(value.prerequisites)
          if #value.servers == 0 and #value.formatters == 0 then
            vim.notify("Choose at least one server or formatter to create a language pack.", vim.log.levels.WARN)
            return
          end
          choose("Create " .. value.name .. " pack · enable later in Extras", {
            { label = "Create disabled pack", create = true },
            { label = "Cancel" },
          }, function(choice)
            if not choice.create then
              return
            end
            local ok, path = pcall(require("uzume.extras.packs").create, ft, value)
            if not ok then
              vim.notify(tostring(path), vim.log.levels.ERROR)
              return
            end
            local entry = require("uzume.extras.packs").validate(value, ft)
            extras.catalog[#extras.catalog + 1] = entry
            extras.active[entry.id], extras.desired[entry.id] = false, false
            require("uzume.editor.installer").register_user_packs()
            vim.notify(
              "Pack created. Enter enables it; Ctrl-s saves and installs tools. Restart to activate.",
              vim.log.levels.INFO
            )
            extras.show()
          end)
        end)
      end)
    end)
  end)
end
return M
