local M = {}
local extras = require("uzume.editor.extras")
local tools = require("uzume.editor.tools")
M.servers = {}

local function server(name, executable, args, config)
  M.servers[name] = { executable = executable, args = args or {}, config = config or {} }
end

function M.refresh()
  for name, spec in pairs(M.servers) do
    local path = tools.find(spec.executable)
    if path and spec.path ~= path then
      local config = vim.deepcopy(spec.config)
      config.cmd = vim.list_extend({ path }, spec.args)
      vim.lsp.config(name, config)
      vim.lsp.enable(name)
      spec.path = path
    end
  end
end

function M.setup()
  if not extras.enabled("languages") then
    return
  end
  -- Keep a default for new buffers and request hints after capability registration.
  vim.lsp.inlay_hint.enable(true)
  Snacks.util.lsp.on({ method = "textDocument/inlayHint" }, function(buf)
    if
      vim.api.nvim_buf_is_valid(buf)
      and vim.bo[buf].buftype == ""
      and vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
    then
      vim.lsp.inlay_hint.enable(true, { bufnr = buf })
    end
  end)
  local cmp = require("cmp")
  cmp.setup({
    enabled = function()
      return vim.bo.buftype == ""
    end,
    snippet = {
      expand = function(args)
        vim.snippet.expand(args.body)
      end,
    },
    completion = { completeopt = "menu,menuone,noinsert" },
    preselect = cmp.PreselectMode.Item,
    mapping = cmp.mapping.preset.insert({
      ["<C-Space>"] = cmp.mapping.complete(),
      ["<C-n>"] = cmp.mapping.select_next_item(),
      ["<C-p>"] = cmp.mapping.select_prev_item(),
      ["<C-b>"] = cmp.mapping.scroll_docs(-4),
      ["<C-f>"] = cmp.mapping.scroll_docs(4),
      ["<CR>"] = cmp.mapping.confirm({ select = true }),
      ["<C-y>"] = cmp.mapping.confirm({ select = true }),
      ["<C-e>"] = cmp.mapping.abort(),
      ["<Tab>"] = cmp.mapping(function(fallback)
        if vim.snippet.active({ direction = 1 }) then
          vim.snippet.jump(1)
        else
          fallback()
        end
      end, { "i", "s" }),
      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if vim.snippet.active({ direction = -1 }) then
          vim.snippet.jump(-1)
        else
          fallback()
        end
      end, { "i", "s" }),
    }),
    sources = cmp.config.sources({ { name = "nvim_lsp" }, { name = "path" } }, { { name = "buffer" } }),
    window = { documentation = cmp.config.window.bordered() },
  })
  vim.lsp.config("*", { capabilities = require("cmp_nvim_lsp").default_capabilities() })
  local formatters, syntax = {}, {}
  if extras.enabled("rust") then
    server("rust_analyzer", "rust-analyzer")
    formatters.rust, syntax.rust = { "rustfmt" }, true
  end
  if extras.enabled("lua") then
    require("lazydev").setup()
    server("lua_ls", "lua-language-server", {}, {
      settings = {
        Lua = {
          runtime = { version = "LuaJIT" },
          diagnostics = { globals = { "vim" } },
          workspace = { checkThirdParty = false },
        },
      },
    })
    formatters.lua, syntax.lua = { "stylua" }, true
  end
  if extras.enabled("c") then
    server("clangd", "clangd", { "--background-index", "--clang-tidy" })
    syntax.c, syntax.cpp = true, true -- Formatting uses clangd's built-in formatter.
  end
  if extras.enabled("web") then
    vim.treesitter.language.register("tsx", "typescriptreact")
    vim.treesitter.language.register("javascript", "javascriptreact")
    server("vtsls", "vtsls", { "--stdio" }, {
      root_dir = function(buf, on_dir)
        if vim.fs.root(buf, { "deno.json", "deno.jsonc" }) then
          return
        end
        on_dir(vim.fs.root(buf, {
          "package-lock.json",
          "pnpm-lock.yaml",
          "yarn.lock",
          "bun.lock",
          "tsconfig.json",
          "jsconfig.json",
          "package.json",
          ".git",
        }) or vim.fs.dirname(vim.api.nvim_buf_get_name(buf)))
      end,
      settings = {
        vtsls = { autoUseWorkspaceTsdk = true },
        typescript = { suggest = { completeFunctionCalls = true }, updateImportsOnFileMove = { enabled = "always" } },
        javascript = { updateImportsOnFileMove = { enabled = "always" } },
      },
    })
    server("html", "vscode-html-language-server", { "--stdio" })
    server("cssls", "vscode-css-language-server", { "--stdio" })
    server("jsonls", "vscode-json-language-server", { "--stdio" })
    server("eslint", "vscode-eslint-language-server", { "--stdio" })
    server("tailwindcss", "tailwindcss-language-server", { "--stdio" })
    server("emmet_ls", "emmet-ls", { "--stdio" })
    for _, ft in ipairs({
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
      "html",
      "css",
      "scss",
      "less",
      "json",
      "jsonc",
    }) do
      formatters[ft] = { "prettier" }
    end
    for _, ft in ipairs({ "javascript", "javascriptreact", "typescript", "typescriptreact", "html", "json" }) do
      syntax[ft] = true
    end
    require("nvim-ts-autotag").setup()
  end

  local custom_formatters = {}
  for _, entry in ipairs(extras.catalog) do
    if entry.spec and extras.enabled(entry.id) then
      local spec = entry.spec
      local extensions = {}
      for _, ext in ipairs(spec.extensions or {}) do
        extensions[ext] = spec.filetypes[1]
      end
      vim.filetype.add({ extension = extensions })
      for _, item in ipairs(spec.servers or {}) do
        local ok, base = pcall(function()
          return vim.lsp.config[item.name]
        end)
        local config = vim.tbl_deep_extend(
          "force",
          {},
          ok and base or {},
          item.config or {},
          { filetypes = spec.filetypes, name = item.name }
        )
        local name = "uzume_" .. entry.id:sub(6) .. "_" .. item.name
        server(name, item.command, item.args, config)
      end
      local chain = {}
      for _, item in ipairs(spec.formatters or {}) do
        local name = "uzume_" .. entry.id:sub(6) .. "_" .. item.name
        local ok, definition = pcall(require, "conform.formatters." .. item.name)
        definition = ok and type(definition) == "table" and vim.deepcopy(definition) or { stdin = true }
        definition.inherit = false
        definition.command = function()
          return tools.find(item.command) or item.command
        end
        if item.args then
          definition.args = item.args
        end
        if item.stdin ~= nil then
          definition.stdin = item.stdin
        end
        custom_formatters[name] = definition
        chain[#chain + 1] = name
      end
      for _, ft in ipairs(spec.filetypes) do
        if #chain > 0 then
          formatters[ft] = chain
        end
        if spec.syntax then
          vim.treesitter.language.register(spec.syntax, ft)
          syntax[ft] = true
        end
      end
    end
  end
  vim.g.uzume_autoformat = true
  require("conform").setup({
    formatters_by_ft = formatters,
    formatters = vim.tbl_extend("force", custom_formatters, {
      rustfmt = {
        command = function()
          return tools.find("rustfmt") or "rustfmt"
        end,
      },
      stylua = {
        command = function()
          return tools.find("stylua") or "stylua"
        end,
      },
      prettier = {
        command = function(_, ctx)
          return tools.prettier(ctx.filename) or "prettier"
        end,
      },
    }),
    format_on_save = function(buf)
      if vim.g.uzume_autoformat and vim.b[buf].uzume_autoformat ~= false then
        return { timeout_ms = 2000, lsp_format = "fallback" }
      end
    end,
  })
  vim.keymap.set({ "n", "x" }, "<leader>cf", function()
    require("conform").format({ async = true, lsp_format = "fallback" })
  end, { desc = "Format" })
  Snacks.toggle({
    name = "Format on Save",
    get = function()
      return vim.g.uzume_autoformat
    end,
    set = function(value)
      vim.g.uzume_autoformat = value
    end,
  }):map("<leader>uf")
  Snacks.toggle({
    name = "Format on Save (buffer)",
    get = function()
      return vim.b.uzume_autoformat ~= false
    end,
    set = function(value)
      vim.b.uzume_autoformat = value
    end,
  }):map("<leader>uF")
  local group = vim.api.nvim_create_augroup("uzume_languages", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(event)
      if syntax[event.match] and vim.bo[event.buf].buftype == "" then
        local ok, err = pcall(vim.treesitter.start, event.buf)
        if not ok then
          vim.notify("Syntax parser unavailable: " .. tostring(err), vim.log.levels.WARN)
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(event)
      local function map(key, action, desc)
        vim.keymap.set("n", key, action, { buffer = event.buf, desc = desc })
      end
      map("gd", function()
        Snacks.picker.lsp_definitions()
      end, "Goto Definition")
      map("gr", function()
        Snacks.picker.lsp_references()
      end, "References")
      map("gI", function()
        Snacks.picker.lsp_implementations()
      end, "Goto Implementation")
      map("gy", function()
        Snacks.picker.lsp_type_definitions()
      end, "Goto Type Definition")
      map("K", vim.lsp.buf.hover, "Hover")
      map("gK", vim.lsp.buf.signature_help, "Signature Help")
      map("<leader>cr", vim.lsp.buf.rename, "Rename Symbol")
      map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
      map("<leader>cs", function()
        Snacks.picker.lsp_symbols()
      end, "Document Symbols")
      map("<leader>ss", function()
        Snacks.picker.lsp_symbols()
      end, "Document Symbols")
      map("<leader>sS", function()
        Snacks.picker.lsp_workspace_symbols()
      end, "Workspace Symbols")
      vim.keymap.set("x", "<leader>ca", vim.lsp.buf.code_action, { buffer = event.buf, desc = "Code Action" })
    end,
  })
  M.refresh()
end

return M
