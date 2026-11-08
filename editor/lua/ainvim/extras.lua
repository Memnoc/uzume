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
  local installer = require("ainvim.installer")
  local draft = vim.deepcopy(M.desired)
  local views, view = { "All", "Available", "Installed", "Enabled" }, 1
  local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/plugins.lock.json"), "\n"))
  local function items()
    local result = {}
    for _, entry in ipairs(M.catalog) do
      local lines = {
        "# " .. entry.name,
        "",
        entry.description,
        "",
        "Selected: " .. (draft[entry.id] and "Enabled" or "Disabled"),
        "Running now: " .. (M.active[entry.id] and "Enabled" or "Disabled"),
        draft[entry.id] ~= M.desired[entry.id] and "Unsaved change — Ctrl-s to save."
          or (draft[entry.id] ~= M.active[entry.id] and "Saved — restart to apply." or "No pending change."),
        "Automatic installs: " .. (installer.auto and "on" or "off") .. " (Space uI outside this menu)",
        "View: " .. views[view] .. " · Ctrl-v changes view",
        "",
        "## Tools",
      }
      local missing, managed, pending, failed = false, true, false, false
      local function describe(tool, optional)
        local status = installer.status(tool)
        if not optional then
          missing = missing or not status.path
          managed = managed and (status.state == "installed" or not status.package and status.path ~= nil)
          pending = pending or status.state == "installing"
          failed = failed or status.state == "failed"
        end
        lines[#lines + 1] = "- " .. tool .. (optional and " (optional)" or "") .. ": " .. status.state
        if status.pinned then
          lines[#lines + 1] = "  Release version: " .. status.pinned
        end
        if status.version then
          lines[#lines + 1] = "  Installed version: " .. status.version
        end
        if status.path then
          lines[#lines + 1] = "  Path: " .. status.path
        end
        if status.error then
          lines[#lines + 1] = "  Error: " .. status.error
        end
      end
      for _, tool in ipairs(entry.tools) do
        describe(tool)
      end
      for _, tool in ipairs(entry.optional or {}) do
        describe(tool, true)
      end
      if #entry.tools == 0 then
        lines[#lines + 1] = "- No external tools required."
      end
      vim.list_extend(lines, { "", "## Included plugins" })
      for _, plugin in ipairs(lock.plugins) do
        if plugin.extra == entry.id or (entry.id ~= "smear" and plugin.extra == "languages") then
          lines[#lines + 1] = "- " .. plugin.name .. " @ " .. plugin.commit:sub(1, 12)
        end
      end
      if entry.id ~= "smear" then
        lines[#lines + 1] = "- Native syntax resources (CSS/SCSS/LESS use Vim syntax)."
      end
      vim.list_extend(lines, {
        "",
        "## Controls",
        "Type: filter · Ctrl-n/p or arrows: move · Ctrl-v: change view",
        "Enter: toggle · Ctrl-s: save choices · Esc: discard draft",
        "Ctrl-r: install/retry this pack's required tools in ai-nvim storage",
        "Ctrl-g: Mason package browser, optional tools and installation logs",
        "Pack activation changes require restart. New tools attach without restart.",
        "External tools are usable but not managed by ai-nvim. Installed view shows managed packs.",
        "Installation starts immediately; Escape does not cancel downloads.",
      })
      if view == 1 or view == 2 and not managed or view == 3 and managed or view == 4 and draft[entry.id] then
        result[#result + 1] = {
          id = entry.id,
          entry = entry,
          text = entry.name,
          enabled = draft[entry.id],
          unsaved = draft[entry.id] ~= M.desired[entry.id],
          restart = draft[entry.id] ~= M.active[entry.id],
          state = pending and "installing"
            or failed and "failed"
            or managed and "installed"
            or missing and "available"
            or "external",
          preview = { text = table.concat(lines, "\n"), ft = "markdown" },
        }
      end
    end
    return result
  end
  local function refresh(picker)
    picker.opts.items = items()
    picker.title = "Extras · " .. views[view]
    picker:find()
  end
  local function keys(mode)
    return {
      ["<C-s>"] = { "save_extras", mode = mode },
      ["<Esc>"] = { "close", mode = mode },
      ["<C-r>"] = { "install_pack", mode = mode },
      ["<C-g>"] = { "mason_tools", mode = mode },
      ["<C-v>"] = { "cycle_view", mode = mode },
    }
  end
  local autocmd
  Snacks.picker({
    title = "Extras · All",
    items = items(),
    preview = "preview",
    layout = function()
      local wide = vim.o.columns >= 120
      return {
        layout = {
          box = "vertical",
          width = 0.9,
          height = 0.85,
          border = "rounded",
          title = " {title} · ✓ enabled · ○ disabled ",
          title_pos = "center",
          footer = " Enter toggle · C-s save · C-r install · C-g tools · Esc cancel ",
          footer_pos = "center",
          {
            win = "input",
            height = 1,
            border = "bottom",
            title = " Type filter · Ctrl-n/p move · Ctrl-v view ",
            title_pos = "left",
          },
          {
            box = wide and "horizontal" or "vertical",
            { win = "list", border = "none", height = not wide and 6 or nil },
            { win = "preview", title = " Details ", border = wide and "left" or "top", width = wide and 0.5 or nil },
          },
        },
      }
    end,
    format = function(item)
      return {
        { item.enabled and "✓ " or "○ ", item.enabled and "DiagnosticOk" or "Comment" },
        { item.text },
        { "  · " .. item.state, item.state == "failed" and "DiagnosticError" or "Comment" },
        { item.unsaved and "  * unsaved" or "", "DiagnosticWarn" },
        { item.restart and "  ↻ restart" or "", "DiagnosticInfo" },
      }
    end,
    confirm = function(picker, item)
      if item then
        draft[item.id] = not draft[item.id]
        refresh(picker)
      end
    end,
    actions = {
      save_extras = function(picker)
        local newly_enabled = {}
        for _, entry in ipairs(M.catalog) do
          if draft[entry.id] and not M.desired[entry.id] then
            newly_enabled[#newly_enabled + 1] = entry
          end
        end
        M.apply(draft)
        picker:close()
        for _, entry in ipairs(newly_enabled) do
          installer.install_pack(entry)
        end
      end,
      install_pack = function(picker)
        local item = picker:current()
        if item then
          installer.install_pack(item.entry, true)
          refresh(picker)
        end
      end,
      mason_tools = function(picker)
        picker:close()
        installer.show_mason()
      end,
      cycle_view = function(picker)
        view = view % #views + 1
        refresh(picker)
      end,
    },
    on_show = function(picker)
      autocmd = vim.api.nvim_create_autocmd("User", {
        pattern = "AiNvimToolsChanged",
        callback = function()
          vim.schedule(function()
            if not picker.closed then
              refresh(picker)
            end
          end)
        end,
      })
    end,
    on_close = function()
      if autocmd then
        vim.api.nvim_del_autocmd(autocmd)
      end
    end,
    win = { input = { keys = keys({ "i", "n" }) }, list = { keys = keys("n") }, preview = { keys = keys("n") } },
  })
end

function M.setup()
  vim.api.nvim_create_user_command("Extras", M.show, { desc = "Manage optional editor features" })
  vim.keymap.set("n", "<leader>l", M.show, { desc = "Extras", silent = true })
end

return M
