local M = {}
M.catalog = {
  {
    id = "rust",
    name = "Rust",
    description = "rust-analyzer navigation, completion, diagnostics; rustfmt; Rust syntax.",
    tools = { "rust-analyzer", "rustfmt" },
  },
  {
    id = "lua",
    name = "Lua / Neovim",
    description = "Lua language server, Neovim API completion, StyLua and Lua syntax.",
    tools = { "lua-language-server", "stylua" },
  },
  {
    id = "c",
    name = "C / C++",
    description = "clangd navigation, completion, diagnostics and formatting. Uses your project's compile_commands.json when available.",
    tools = { "clangd" },
  },
  {
    id = "web",
    name = "TypeScript / React / HTML / CSS",
    description = "JavaScript, TypeScript, JSX/TSX, HTML, CSS/SCSS/LESS and JSON. Completion, imports, diagnostics, Prettier, tag closing. ESLint uses project configuration; Tailwind and Emmet attach when available.",
    tools = {
      "vtsls",
      "vscode-html-language-server",
      "vscode-css-language-server",
      "vscode-json-language-server",
      "prettier",
    },
    optional = { "vscode-eslint-language-server", "tailwindcss-language-server", "emmet-ls" },
  },
  {
    id = "smear",
    name = "Smear Cursor",
    description = "The cursor animation from your LazyVim setup. Space ua toggles it for this run; Extras controls whether it loads on restart.",
    tools = {},
  },
}
local path = vim.fn.stdpath("data") .. "/extras.json"
M.active = {}
for _, entry in ipairs(M.catalog) do
  M.active[entry.id] = true
end
if vim.fn.filereadable(path) == 1 then
  local ok, saved = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end)
  if ok and type(saved) == "table" and saved.version == 1 and type(saved.enabled) == "table" then
    for id in pairs(M.active) do
      if type(saved.enabled[id]) == "boolean" then
        M.active[id] = saved.enabled[id]
      end
    end
  else
    vim.schedule(function()
      vim.notify("Cannot read Extras preferences; using defaults. Inspect " .. path, vim.log.levels.WARN)
    end)
  end
end
M.desired = vim.deepcopy(M.active)

function M.enabled(id)
  if id == "languages" then
    return M.active.rust or M.active.lua or M.active.c or M.active.web
  end
  return M.active[id] == true
end

function M.apply(values)
  local enabled = {}
  for _, entry in ipairs(M.catalog) do
    assert(type(values[entry.id]) == "boolean", "Missing Extras choice: " .. entry.id)
    enabled[entry.id] = values[entry.id]
  end
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local temp = path .. "." .. vim.fn.getpid() .. ".tmp"
  assert(vim.fn.writefile({ vim.json.encode({ version = 1, enabled = enabled }) }, temp) == 0, "Cannot save Extras")
  local renamed, err = vim.uv.fs_rename(temp, path)
  assert(renamed, err)
  M.desired = vim.deepcopy(enabled)
  vim.notify("Extras saved. Restart ai-nvim to apply changes.", vim.log.levels.WARN)
end

function M.show()
  local draft = vim.deepcopy(M.desired)
  local function items()
    local result = {}
    for _, entry in ipairs(M.catalog) do
      local lines = { "# " .. entry.name, "", entry.description, "", "## Tools" }
      local missing = false
      for _, tool in ipairs(entry.tools) do
        local location = require("ainvim.tools").find(tool)
        missing = missing or not location
        lines[#lines + 1] = "- " .. tool .. ": " .. (location or "missing")
      end
      for _, tool in ipairs(entry.optional or {}) do
        lines[#lines + 1] = "- " .. tool .. " (optional): " .. (require("ainvim.tools").find(tool) or "not installed")
      end
      if #entry.tools == 0 then
        lines[#lines + 1] = "- Included in the pinned plugin bundle."
      end
      vim.list_extend(lines, {
        "",
        "Enter: toggle  ·  Ctrl-s: save  ·  Esc: close",
        "Changes take effect on restart. No tools are downloaded by this menu.",
      })
      result[#result + 1] = {
        id = entry.id,
        text = entry.name,
        label = (draft[entry.id] and "[on]  " or "[off] ")
          .. entry.name
          .. (draft[entry.id] ~= M.active[entry.id] and "  (restart)" or "")
          .. (missing and "  · missing tools" or ""),
        preview = { text = table.concat(lines, "\n"), ft = "markdown" },
      }
    end
    return result
  end
  Snacks.picker({
    title = "Extras · Enter toggle · Ctrl-s save",
    items = items(),
    preview = "preview",
    layout = { preset = "default" },
    format = function(item)
      return { { item.label } }
    end,
    confirm = function(picker, item)
      if not item then
        return
      end
      draft[item.id] = not draft[item.id]
      picker.opts.items = items()
      picker:find()
    end,
    actions = {
      save_extras = function(picker)
        M.apply(draft)
        picker:close()
      end,
    },
    win = {
      input = { keys = { ["<C-s>"] = { "save_extras", mode = { "i", "n" } } } },
      list = { keys = { ["<C-s>"] = "save_extras" } },
    },
  })
end

function M.setup()
  vim.api.nvim_create_user_command("Extras", M.show, { desc = "Manage optional editor features" })
  vim.keymap.set("n", "<leader>l", M.show, { desc = "Extras", silent = true })
end

return M
