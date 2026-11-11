-- A buffer may belong to several workspaces; hiding it never unloads its edits.
local M = { seen = {} }
local api = vim.api
function M.reset(tab)
  M.seen[tab] = {}
end
function M.track()
  local tab, buf = api.nvim_get_current_tabpage(), api.nvim_get_current_buf()
  if api.nvim_win_get_config(0).relative ~= "" then
    return
  end
  M.seen[tab] = M.seen[tab] or {}
  M.seen[tab][buf] = true
end
function M.contains(buf)
  local tab = api.nvim_get_current_tabpage()
  if vim.bo[buf].buftype == "terminal" then
    return vim.b[buf].uzume_owner == tab
  end
  return (M.seen[tab] or {})[buf] == true
end
function M.setup()
  api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = api.nvim_create_augroup("uzume_workspace_buffers", { clear = true }),
    callback = M.track,
  })
  M.track()
end
return M
