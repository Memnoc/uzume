-- Buffer selection should visit a visible agent, not mirror it over an editor.
local M = {}
local api = vim.api

local function pane(win)
  local panes = package.loaded["ainvim.panes"]
  return api.nvim_win_get_config(win).relative == "" or (panes and panes.floats[win] ~= nil)
end

function M.setup()
  local previous, pending = {}, {}
  local restoring = false
  local group = api.nvim_create_augroup("uzume_agent_views", { clear = true })
  api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function(args)
      if not restoring then
        previous[api.nvim_get_current_win()] = args.buf
      end
    end,
  })
  api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "WinEnter" }, {
    group = group,
    callback = function()
      local win, buf = api.nvim_get_current_win(), api.nvim_get_current_buf()
      if restoring or pending[win] or not vim.b[buf].uzume_agent_id or not pane(win) then
        return
      end
      local others = vim.tbl_filter(function(other)
        -- Picker previews may intentionally display a terminal buffer too.
        return other ~= win and pane(other)
      end, vim.fn.win_findbuf(buf))
      if #others == 0 then
        return
      end
      local old = previous[win]
      pending[win] = true
      -- Docking and swapping temporarily share buffers. Let the complete layout
      -- operation finish before deciding whether this really is a duplicate.
      vim.schedule(function()
        pending[win] = nil
        if not api.nvim_win_is_valid(win) or api.nvim_win_get_buf(win) ~= buf then
          return
        end
        for _, other in ipairs(others) do
          if api.nvim_win_is_valid(other) and api.nvim_win_get_buf(other) == buf then
            local focused = api.nvim_get_current_win() == win
            if not old or old == buf or not api.nvim_buf_is_valid(old) then
              old = api.nvim_create_buf(true, false)
            end
            restoring = true
            local ok, err = pcall(api.nvim_win_set_buf, win, old)
            restoring = false
            if not ok then
              vim.notify("Unable to restore editor pane: " .. tostring(err), vim.log.levels.WARN)
              return
            end
            if focused then
              api.nvim_set_current_win(other)
            end
            return
          end
        end
      end)
    end,
  })
  api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      previous[tonumber(args.match)] = nil
    end,
  })
end

return M
