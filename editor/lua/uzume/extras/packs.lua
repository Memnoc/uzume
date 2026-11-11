-- Declarative user packs live beside (never inside) the installed configuration.
local M = { directory = vim.fn.stdpath("config") .. "-user/languages", errors = {} }
local function text(value, label)
  assert(type(value) == "string" and value ~= "" and not value:find("%c"), label .. " must be non-empty text")
end
local function list(value, label, required)
  assert(type(value) == "table" and vim.islist(value), label .. " must be an array")
  assert(not required or #value > 0, label .. " must not be empty")
  for _, item in ipairs(value) do
    text(item, label)
  end
end
local function fields(value, allowed, label)
  assert(type(value) == "table", label .. " must be an object")
  for key in pairs(value) do
    assert(vim.tbl_contains(allowed, key), label .. ": unknown field " .. tostring(key))
  end
end
function M.validate(value, id)
  assert(id:match("^[a-z][a-z0-9_-]*$"), "Filename must use lowercase letters, digits, underscores or hyphens")
  fields(
    value,
    { "version", "name", "description", "filetypes", "extensions", "servers", "formatters", "syntax", "prerequisites" },
    "Pack"
  )
  assert(value.version == 1, "Pack version must be 1")
  text(value.name, "Name")
  list(value.filetypes, "Filetypes", true)
  for _, ft in ipairs(value.filetypes) do
    assert(ft:match("^[%w_.-]+$"), "Invalid filetype: " .. ft)
  end
  if value.description then
    text(value.description, "Description")
  end
  for _, key in ipairs({ "extensions", "prerequisites" }) do
    if value[key] then
      list(value[key], key)
    end
  end
  for _, ext in ipairs(value.extensions or {}) do
    assert(ext:match("^[%w_-]+$"), "Extensions must omit the dot: " .. ext)
  end
  local tools, seen, names = {}, {}, {}
  for _, group in ipairs({ "servers", "formatters" }) do
    local specs = value[group] or {}
    assert(type(specs) == "table" and vim.islist(specs), group .. " must be an array")
    for _, spec in ipairs(specs) do
      fields(
        spec,
        { "name", "command", "args", "package", "version", group == "servers" and "config" or "stdin" },
        group
      )
      text(spec.name, "Tool name")
      assert(spec.name:match("^[%w_-]+$"), "Invalid tool name: " .. spec.name)
      assert(not names[group .. spec.name], "Duplicate " .. group .. ": " .. spec.name)
      names[group .. spec.name] = true
      text(spec.command, "Executable")
      if spec.args then
        list(spec.args, "Arguments")
      end
      if spec.config then
        fields(spec.config, { "settings", "init_options", "root_markers", "workspace_required" }, "Server config")
        for _, key in ipairs({ "settings", "init_options" }) do
          if spec.config[key] then
            assert(type(spec.config[key]) == "table", key .. " must be an object")
          end
        end
        if spec.config.root_markers then
          list(spec.config.root_markers, "Root markers", true)
        end
        if spec.config.workspace_required ~= nil then
          assert(type(spec.config.workspace_required) == "boolean", "workspace_required must be true or false")
        end
      end
      if spec.stdin ~= nil then
        assert(type(spec.stdin) == "boolean", "stdin must be true or false")
      end
      if spec.package then
        text(spec.package, "Mason package")
        text(spec.version, "Pinned tool version")
        assert(spec.package:match("^[%w_.-]+$"), "Invalid Mason package")
        assert(spec.command:match("^[%w_.+-]+$"), "Managed executable must be a name, not a path")
      else
        assert(spec.version == nil, "A pinned version needs a Mason package")
      end
      if not seen[spec.command] then
        tools[#tools + 1] = spec.command
        seen[spec.command] = true
      end
    end
  end
  if value.syntax then
    text(value.syntax, "Syntax parser")
    assert(value.syntax:match("^[%w_]+$"), "Invalid parser name")
  end
  assert(#tools > 0 or value.syntax, "Add at least one server, formatter or existing syntax parser")
  return {
    id = "user:" .. id,
    name = value.name,
    description = value.description or "User-defined language support.",
    kind = "language",
    source = "User",
    tools = tools,
    spec = value,
    path = M.directory .. "/" .. id .. ".json",
    default = false,
  }
end

function M.load(builtins)
  M.errors = {}
  local result, owners, pins, commands = {}, {}, {}, {}
  for _, entry in ipairs(builtins) do
    for _, ft in ipairs(entry.filetypes or {}) do
      owners[ft] = entry.name
    end
  end
  local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/tools.lock.json"), "\n"))
  pins = vim.deepcopy(lock.packages)
  commands = vim.deepcopy(require("uzume.extras.tool_packages"))
  for _, path in ipairs(vim.fn.glob(M.directory .. "/*.json", false, true)) do
    local ok, entry = pcall(function()
      local value = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
      local pack = M.validate(value, vim.fs.basename(path):sub(1, -6))
      -- A pack cannot silently replace an existing language or executable pin.
      local nextpins, nextcommands = vim.deepcopy(pins), vim.deepcopy(commands)
      for _, ft in ipairs(value.filetypes) do
        assert(not owners[ft], ft .. " already belongs to " .. (owners[ft] or ""))
      end
      for _, group in ipairs({ "servers", "formatters" }) do
        for _, tool in ipairs(value[group] or {}) do
          if tool.package then
            assert(
              not nextpins[tool.package] or nextpins[tool.package] == tool.version,
              "Version conflict for " .. tool.package
            )
            assert(
              not nextcommands[tool.command] or nextcommands[tool.command] == tool.package,
              "Executable conflict for " .. tool.command
            )
            nextpins[tool.package], nextcommands[tool.command] = tool.version, tool.package
          end
        end
      end
      for _, ft in ipairs(value.filetypes) do
        owners[ft] = value.name
      end
      pins, commands = nextpins, nextcommands
      return pack
    end)
    if ok then
      result[#result + 1] = entry
    else
      M.errors[#M.errors + 1] = { path = path, error = tostring(entry) }
    end
  end
  return result
end

function M.create(id, value)
  local entry = M.validate(value, id)
  vim.fn.mkdir(M.directory, "p")
  -- Exclusive creation protects an existing customization, including symlinks.
  local fd, err = vim.uv.fs_open(entry.path, "wx", 384)
  assert(fd, err)
  local ok, failure = pcall(function()
    assert(vim.uv.fs_write(fd, require("uzume.extras.create").encode(value) .. "\n", 0))
  end)
  vim.uv.fs_close(fd)
  assert(ok, failure)
  return entry.path
end
return M
