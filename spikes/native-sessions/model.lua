-- SPIKE: small pure queries; window and process ownership live in init.lua.
local M = {}
local attention = { waiting = true, blocked = true, review = true, failed = true }

function M.attention(sessions)
  local items = {}
  for index, session in ipairs(sessions) do
    if session.alive then
      for _, pane in ipairs(session.panes) do
        local state = pane.state or {}
        if pane.kind == "agent" and attention[state.state] then
          items[#items + 1] = {
            session = index, pane = pane.id, project = session.name,
            name = pane.name, state = state.state, reason = state.reason,
            since = state.since or 0,
          }
        end
      end
    end
  end
  table.sort(items, function(a, b)
    if a.since ~= b.since then return a.since < b.since end
    if a.session ~= b.session then return a.session < b.session end
    return a.pane < b.pane
  end)
  return items
end

function M.next_session(sessions, current)
  for offset = 1, #sessions do
    local index = (current + offset - 1) % #sessions + 1
    if sessions[index].alive then return index end
  end
end

function M.clamp(value, low, high)
  return math.max(low, math.min(value, math.max(low, high)))
end

return M
