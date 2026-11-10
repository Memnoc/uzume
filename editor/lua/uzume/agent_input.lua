-- Track possible user drafts without recording their text.
local M = {}
local api = vim.api
local function current()
  if api.nvim_get_mode().mode ~= "t" then
    return
  end
  local id = vim.b.uzume_agent_id
  return id and require("uzume.agents").instances[id]
end
function M.note(item)
  local seconds, micros = vim.uv.gettimeofday()
  item.input_at = seconds + micros / 1000000
end
function M.status(item)
  local status = vim.deepcopy(item.status)
  local paths = { item.directory .. "/state.json" }
  vim.list_extend(paths, vim.fn.glob(item.directory .. "/events/*.json", false, true))
  for _, path in ipairs(paths) do
    local ok, value = pcall(function()
      return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
    end)
    if ok and type(value) == "table" and type(value.since) == "number" and value.since >= status.since then
      status = vim.tbl_extend("force", status, value)
    end
  end
  return status
end
function M.has_draft(item, status)
  return item.input_at and item.input_at > (status.prompt_submitted_at or 0) or false
end
function M.setup()
  if M.started then
    return
  end
  M.started = true
  vim.on_key(function(_, typed)
    if typed and typed:find("[%g ]") then
      local item = current()
      if item then
        M.note(item)
      end
    end
  end, api.nvim_create_namespace("uzume_agent_input"))
  local paste = vim.paste
  vim.paste = function(lines, phase)
    local item = current()
    if item then
      M.note(item)
    end
    return paste(lines, phase)
  end
end
return M
