-- Noice owns only the command line and its completion menu. Snacks owns notices.
local M = {}
function M.setup()
  require("noice").setup({
    cmdline = {
      enabled = true,
      view = "cmdline_popup",
      format = { cmdline = { icon = "❯", title = " Command " } },
    },
    messages = { enabled = false },
    notify = { enabled = false },
    popupmenu = { enabled = true, backend = "nui" },
    lsp = {
      progress = { enabled = false },
      hover = { enabled = false },
      signature = { enabled = false },
      message = { enabled = false },
    },
    views = {
      cmdline_popup = {
        position = { row = "12%", col = "50%" },
        size = { width = "80%", min_width = 1, max_width = 100, height = "auto" },
        border = { style = "rounded", padding = { 0, 1 } },
        win_options = {
          winhighlight = {
            Normal = "NormalFloat",
            FloatBorder = "FloatBorder",
            FloatTitle = "Title",
          },
        },
      },
      popupmenu = { border = { style = "rounded" } },
    },
  })
end
return M
