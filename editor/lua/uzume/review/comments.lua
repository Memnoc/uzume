-- Comment composition and inspection. No agent transport lives in this module.
local M = {}
local api = vim.api
local store = require("uzume.review.comment_store")
local feedback = require("uzume.review.feedback_store")
local delivery_labels = { queued = "Queued", supplied = "Supplied", claimed = "Handoff uncertain", paused = "Paused" }
local ui = {}
local function protect(fn)
  local ok, result = pcall(fn)
  if not ok then
    vim.notify(tostring(result):gsub("^.-%.lua:%d+: ", ""), vim.log.levels.WARN, { title = "Task review" })
  end
  return ok, result
end
local function close(name)
  local window = ui[name]
  ui[name] = nil
  if window then
    local focused = window.win == api.nvim_get_current_win()
    window:close()
    if focused and window.review_origin and api.nvim_win_is_valid(window.review_origin) then
      api.nvim_set_current_win(window.review_origin)
    end
  end
end
function M.close()
  for _, name in ipairs({ "picker", "composer", "detail" }) do
    close(name)
  end
end
local function location(comment)
  local result = {}
  for _, side in ipairs({ "before", "after" }) do
    local range = comment.anchor[side]
    if range then
      result[#result + 1] = (side == "before" and "Base" or "Task")
        .. " L"
        .. range.first
        .. (range.last ~= range.first and ("–" .. range.last) or "")
    end
  end
  return table.concat(result, " → ")
end
local function window(name, text, title, footer, editable, origin)
  close(name)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden, vim.bo[buf].swapfile, vim.bo[buf].undofile = "wipe", false, false
  vim.bo[buf].filetype = editable and "uzume_review_comment" or "uzume_review_comment_detail"
  vim.bo[buf].syntax = "markdown"
  api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.bo[buf].modifiable = editable
  local win = Snacks.win({
    buf = buf,
    enter = true,
    backdrop = false,
    width = 0.72,
    height = editable and 0.35 or 0.65,
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    footer = " " .. footer .. " ",
    footer_pos = "center",
    zindex = 70,
    wo = { wrap = true, linebreak = true, number = false, relativenumber = false },
    keys = {
      q = function()
        close(name)
      end,
    },
  })
  win.review_origin = origin
  ui[name] = win
  return win
end
local function compose(state, comment, changed)
  local win = window(
    "composer",
    comment.body or "",
    "Comment · " .. comment.display .. " · " .. location(comment),
    "Ctrl-s save locally · Esc normal mode · q cancel",
    true,
    state.comment_origin
  )
  vim.keymap.set({ "n", "i" }, "<C-s>", function()
    protect(function()
      local body = table.concat(api.nvim_buf_get_lines(win.buf, 0, -1, false), "\n")
      store.save(state.task, comment, body)
      vim.cmd.stopinsert()
      close("composer")
      if changed then
        changed()
      end
    end)
  end, { buffer = win.buf, desc = "Save review comment locally" })
  vim.keymap.set({ "n", "i" }, "<C-c>", function()
    vim.cmd.stopinsert()
    close("composer")
  end, { buffer = win.buf, desc = "Cancel comment" })
  vim.cmd.startinsert()
end
function M.add(state, file, anchor, changed)
  state.comment_origin = api.nvim_get_current_win()
  compose(state, {
    path = file.path,
    display = file.display,
    anchor = anchor,
    digest = store.digest(file),
    snapshot = state.snapshot.fingerprint,
  }, changed)
end
local function inspect(state, comment, changed)
  local outdated = store.outdated(comment, state.snapshot)
  local delivery = feedback.versions(state.task)[feedback.revision(comment)]
  local text = {
    comment.display,
    location(comment),
    outdated and "OUTDATED · File differs in this review snapshot" or "Matches this review snapshot",
    delivery_labels[delivery] or "LOCAL DRAFT",
    "Edits and deletion affect this draft; queued or supplied batches keep their original copy.",
    "",
    comment.body,
    "",
    "Original snapshot excerpt (" .. comment.snapshot:sub(1, 8) .. "):",
  }
  for _, side in ipairs({ "before", "after" }) do
    local range = comment.anchor[side]
    if range then
      text[#text + 1] = ""
      text[#text + 1] = side == "before" and "Base:" or "Task:"
      vim.list_extend(text, range.lines)
    end
  end
  local win = window(
    "detail",
    table.concat(text, "\n"),
    "Review comment",
    "e edit · d delete · s send review · q back",
    false,
    state.comment_origin
  )
  vim.keymap.set("n", "s", function()
    close("detail")
    require("uzume.review").send()
  end, { buffer = win.buf, desc = "Preview review feedback" })
  vim.keymap.set("n", "e", function()
    close("detail")
    compose(state, comment, function()
      if changed then
        changed()
      end
      M.list(state, changed)
    end)
  end, { buffer = win.buf, desc = "Edit comment" })
  vim.keymap.set("n", "d", function()
    ui.picker = Snacks.picker.select(
      { "Keep comment", "Delete comment" },
      { prompt = "Delete this local comment?" },
      function(choice)
        if choice ~= "Delete comment" or state.closed then
          return
        end
        protect(function()
          store.delete(state.task, comment.id)
          close("detail")
          if changed then
            changed()
          end
          vim.schedule(function()
            M.list(state, changed)
          end)
        end)
      end
    )
  end, { buffer = win.buf, desc = "Delete comment" })
end
function M.list(state, changed)
  if state.closed then
    return
  end
  local current = api.nvim_get_current_win()
  if vim.tbl_contains(state.views, current) then
    state.comment_origin = current
  elseif not state.comment_origin or not api.nvim_win_is_valid(state.comment_origin) then
    state.comment_origin = state.views[#state.views]
  end
  protect(function()
    local comments = store.read(state.task)
    if #comments == 0 then
      return vim.notify(
        "No comments yet. Select review lines and press c.",
        vim.log.levels.INFO,
        { title = "Task review" }
      )
    end
    close("picker")
    local versions = feedback.versions(state.task)
    ui.picker = Snacks.picker({
      title = "Review comments · Enter inspect/edit · Esc back",
      items = vim.tbl_map(function(comment)
        return {
          id = comment.id,
          text = (store.outdated(comment, state.snapshot) and "! Outdated · " or "")
            .. (delivery_labels[versions[feedback.revision(comment)]] or "Draft")
            .. " · "
            .. comment.display
            .. " · "
            .. location(comment)
            .. " · "
            .. (comment.body:match("[^\n]+") or ""):gsub("%c", " "),
        }
      end, comments),
      format = "text",
      preview = "none",
      layout = { preset = "select" },
      confirm = function(picker, item)
        picker:close()
        vim.schedule(function()
          if not item or state.closed then
            return
          end
          protect(function()
            for _, comment in ipairs(store.read(state.task)) do
              if comment.id == item.id then
                inspect(state, comment, changed)
                return
              end
            end
          end)
        end)
      end,
    })
  end)
end
return M
