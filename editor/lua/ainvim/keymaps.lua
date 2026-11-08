local function map(mode, lhs, rhs, desc, extra)
  vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { silent = true, desc = desc }, extra or {}))
end
local root = require("ainvim.project").root
map("n", "<leader>aw", function()
  require("ainvim.navigator").open("workspaces")
end, "Window Navigator")
map("n", "<leader>as", function()
  require("ainvim.navigator").open("sessions")
end, "Project Navigator (Alias)")
map("n", "<leader>ap", function()
  require("ainvim.navigator").open("projects")
end, "Project Navigator")
local function pick(source, project)
  return function()
    Snacks.picker[source](project and { cwd = root() } or {})
  end
end

map("n", "<leader>e", function()
  Snacks.explorer({ cwd = root() })
end, "Explorer (Root Dir)")
map("n", "<leader>E", function()
  Snacks.explorer()
end, "Explorer (cwd)")
map("n", "<leader>fe", "<leader>e", "Explorer (Root Dir)", { remap = true })
map("n", "<leader>fE", "<leader>E", "Explorer (cwd)", { remap = true })
map("n", "<leader><space>", pick("files", true), "Find Files (Root Dir)")
map("n", "<leader>ff", pick("files", true), "Find Files (Root Dir)")
map("n", "<leader>fF", pick("files"), "Find Files (cwd)")
map("n", "<leader>fg", pick("git_files", true), "Find Files (git)")
map("n", "<leader>fr", pick("recent"), "Recent Files")
map("n", "<leader>fR", function()
  Snacks.picker.recent({ filter = { cwd = true } })
end, "Recent Files (cwd)")
map("n", "<leader>fp", pick("projects"), "Projects")
map("n", "<leader>fc", function()
  Snacks.picker.files({ cwd = vim.fn.stdpath("config") })
end, "Find Config File")
map("n", "<leader>fn", "<cmd>enew<cr>", "New File")
map("n", "<leader>,", pick("buffers"), "Buffers")
map("n", "<leader>fb", pick("buffers"), "Buffers")
map("n", "<leader>/", pick("grep", true), "Grep (Root Dir)")
map("n", "<leader>sg", pick("grep", true), "Grep (Root Dir)")
map("n", "<leader>sG", pick("grep"), "Grep (cwd)")
map({ "n", "x" }, "<leader>sw", pick("grep_word", true), "Selection or Word (Root Dir)")
map("n", "<leader>sb", pick("lines"), "Buffer Lines")
map("n", "<leader>sB", pick("grep_buffers"), "Grep Open Buffers")
map("n", "<leader>:", pick("command_history"), "Command History")
map("n", "<leader>sc", pick("command_history"), "Command History")
map("n", "<leader>sC", pick("commands"), "Commands")
map("n", "<leader>sh", pick("help"), "Help Pages")
map("n", "<leader>sk", pick("keymaps"), "Keymaps")
map("n", '<leader>s"', pick("registers"), "Registers")
map("n", "<leader>sj", pick("jumps"), "Jumps")
map("n", "<leader>sm", pick("marks"), "Marks")
map("n", "<leader>sR", function()
  Snacks.picker.resume()
end, "Resume Picker")
map("n", "<leader>sd", pick("diagnostics"), "Diagnostics")
map("n", "<leader>sD", pick("diagnostics_buffer"), "Buffer Diagnostics")
map("n", "<leader>su", pick("undo"), "Undo History")
map("n", "<leader>n", pick("notifications"), "Notification History")
map("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, "Buffer Keymaps")

for key, command in pairs({
  ["<S-h>"] = "BufferLineCyclePrev",
  ["<S-l>"] = "BufferLineCycleNext",
  ["[b"] = "BufferLineCyclePrev",
  ["]b"] = "BufferLineCycleNext",
  ["[B"] = "BufferLineMovePrev",
  ["]B"] = "BufferLineMoveNext",
  ["<leader>bp"] = "BufferLineTogglePin",
  ["<leader>bj"] = "BufferLinePick",
}) do
  map("n", key, "<cmd>" .. command .. "<cr>", (command:gsub("BufferLine", "")))
end
map("n", "<leader>bb", "<cmd>e #<cr>", "Switch to Other Buffer")
map("n", "<leader>`", "<cmd>e #<cr>", "Switch to Other Buffer")
map("n", "<leader>bd", function()
  Snacks.bufdelete()
end, "Delete Buffer")
map("n", "<leader>bo", function()
  Snacks.bufdelete.other()
end, "Delete Other Buffers")
map("n", "<leader>bD", "<cmd>bd<cr>", "Delete Buffer and Window")
map("n", "<leader>qq", "<cmd>confirm qall<cr>", "Quit All")

for _, dir in ipairs({ "h", "j", "k", "l" }) do
  map({ "n", "t" }, "<C-" .. dir .. ">", "<cmd>wincmd " .. dir .. "<cr>", "Focus " .. dir)
end
local panes = require("ainvim.panes")
local projects = require("ainvim.projects")
local function window_map(key, fn, desc)
  map("n", key, function()
    panes.run(fn)
  end, desc)
end
window_map("<leader>-", function()
  panes.split("below", false)
end, "Split Editor Pane Below")
window_map("<leader>|", function()
  panes.split("right", false)
end, "Split Editor Pane Right")
window_map("<leader>ws", function()
  panes.split("below", false)
end, "Split Editor Pane Below")
window_map("<leader>wv", function()
  panes.split("right", false)
end, "Split Editor Pane Right")
window_map("<leader>wt", function()
  panes.split("below", true)
end, "Shell Pane Below")
window_map("<leader>wT", function()
  panes.split("right", true)
end, "Shell Pane Right")
window_map("<leader>wn", function()
  projects.new_window(nil, false)
end, "New Editor Window")
window_map("<leader>wN", function()
  projects.new_window(nil, true)
end, "New Shell Window")
window_map("<leader>w]", function()
  projects.cycle(1)
end, "Next Window in Project")
window_map("<leader>w[", function()
  projects.cycle(-1)
end, "Previous Window in Project")
window_map("<leader>wp", panes.pick, "Pick Visible / Hidden Pane")
window_map("<leader>wf", panes.float, "Float / Dock Pane")
window_map("<leader>wm", panes.zoom, "Fullscreen / Restore Pane")
window_map("<leader>wz", panes.hide, "Hide Pane (Keep Running)")
window_map("<leader>wr", function()
  panes.restore()
end, "Restore Last Hidden Pane")
window_map("<leader>wx", panes.swap, "Swap with Next Pane")
window_map("<leader>wo", panes.transfer, "Move Pane to Another Window")
window_map("<leader>wd", function()
  local win = vim.api.nvim_get_current_win()
  panes.confirm("Close pane? Its terminal will stop", function()
    panes.close(win)
  end)
end, "Close Pane")
window_map("<leader>wD", function()
  local tab = vim.api.nvim_get_current_tabpage()
  panes.confirm("Close window and all its panes?", function()
    projects.close({ tab = tab, kind = "window" })
  end)
end, "Close Whole Window")
for _, direction in ipairs({ "h", "j", "k", "l" }) do
  map("n", "<leader>w" .. direction, "<cmd>wincmd " .. direction .. "<cr>", "Focus Pane " .. direction)
  window_map("<leader>w" .. direction:upper(), function()
    panes.move(direction:upper())
  end, "Move Pane " .. direction:upper())
end
window_map("<leader>w>", function()
  panes.resize(5, 0)
end, "Increase Pane Width")
window_map("<leader>w<", function()
  panes.resize(-5, 0)
end, "Decrease Pane Width")
window_map("<leader>w+", function()
  panes.resize(0, 2)
end, "Increase Pane Height")
window_map("<leader>w-", function()
  panes.resize(0, -2)
end, "Decrease Pane Height")
map("n", "<leader>w=", "<cmd>wincmd =<cr>", "Equalize Tiled Panes")
map({ "n", "t" }, "<C-Left>", "<cmd>vertical resize -5<cr>", "Decrease Width")
map({ "n", "t" }, "<C-Right>", "<cmd>vertical resize +5<cr>", "Increase Width")
map("n", "<C-Up>", "<cmd>resize +2<cr>", "Increase Height")
map("n", "<C-Down>", "<cmd>resize -2<cr>", "Decrease Height")
map({ "n", "i", "x", "s" }, "<C-s>", function()
  require("ainvim.save").file()
end, "Save File")
map("n", "<Esc>", "<cmd>nohlsearch<cr>", "Clear Search Highlight")
map("x", "<", "<gv", "Indent Left")
map("x", ">", ">gv", "Indent Right")
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", "Down", { expr = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", "Up", { expr = true })
map({ "n", "x", "o" }, "s", function()
  require("flash").jump()
end, "Flash")

local function terminal(position, cwd)
  Snacks.terminal(nil, {
    cwd = cwd,
    env = { AINVIM_TERMINAL_STYLE = position }, -- Separate right/float terminal identities.
    win = {
      position = position,
      keys = {
        term_normal = {
          "<Esc>",
          function()
            vim.cmd.stopinsert()
          end,
          mode = "t",
          desc = "Leave Terminal Input",
        },
      },
    },
  })
end
map({ "n", "t" }, "<C-/>", function()
  terminal("right")
end, "Terminal (vertical)")
map({ "n", "t" }, "<C-_>", function()
  terminal("right")
end, "Terminal (vertical)")
map("n", "<leader>9", function()
  terminal("float")
end, "Terminal (floating)")
map("n", "<leader>ft", function()
  terminal("float", root())
end, "Terminal (Root Dir)")
map("n", "<leader>fT", function()
  terminal("float")
end, "Terminal (cwd)")
-- Single Escape and jk mirror the user's shell terminal mappings. Agent CLI
-- input routing remains a separate decision when agents return to this editor.
map("t", "<Esc>", [[<C-\><C-n>]], "Leave Terminal Input")
map("t", "jk", [[<C-\><C-n>]], "Leave Terminal Input")
map("t", "<C-w>", [[<C-\><C-n><C-w>]], "Terminal Window Commands")

map("n", "<leader>gs", pick("git_status", true), "Git Status")
map("n", "<leader>gd", pick("git_diff", true), "Git Diff (hunks)")
map("n", "<leader>gl", pick("git_log", true), "Git Log")
map("n", "<leader>gf", pick("git_log_file"), "Git File History")
if vim.fn.executable("lazygit") == 1 then
  map("n", "<leader>gg", function()
    Snacks.lazygit({ cwd = root() })
  end, "Lazygit (Root Dir)")
end
for key, action in pairs({
  ["<leader>ghs"] = "stage_hunk",
  ["<leader>ghr"] = "reset_hunk",
  ["<leader>ghp"] = "preview_hunk_inline",
  ["<leader>ghb"] = "blame_line",
}) do
  map("n", key, function()
    require("gitsigns")[action]()
  end, (action:gsub("_", " ")))
end
map("n", "]h", function()
  require("gitsigns").nav_hunk("next")
end, "Next Hunk")
map("n", "[h", function()
  require("gitsigns").nav_hunk("prev")
end, "Previous Hunk")
map("n", "<leader>cd", vim.diagnostic.open_float, "Line Diagnostics")
map("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, "Next Diagnostic")
map("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, "Previous Diagnostic")
map("n", "<leader>xq", function()
  vim.cmd(vim.fn.getqflist({ winid = 0 }).winid ~= 0 and "cclose" or "copen")
end, "Quickfix List")
map("n", "<leader>xl", function()
  vim.cmd(vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 and "lclose" or "lopen")
end, "Location List")
map("n", "[q", "<cmd>cprev<cr>", "Previous Quickfix")
map("n", "]q", "<cmd>cnext<cr>", "Next Quickfix")

Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
Snacks.toggle.line_number():map("<leader>ul")
Snacks.toggle.diagnostics():map("<leader>ud")
Snacks.toggle.inlay_hints():map("<leader>uh")
Snacks.toggle.indent():map("<leader>ug")
window_map("<leader>uZ", panes.zoom, "Fullscreen / Restore Pane")
Snacks.toggle.zen():map("<leader>uz")
Snacks.toggle({
  name = "Mouse",
  get = function()
    return vim.o.mouse ~= ""
  end,
  set = function(value)
    vim.o.mouse = value and "a" or ""
  end,
}):map("<leader>uM")
map("n", "<leader>uC", pick("colorschemes"), "Colorschemes")
for key, command in pairs({
  ["<leader><tab><tab>"] = "tabnew",
  ["<leader><tab>d"] = "tabclose",
  ["<leader><tab>]"] = "tabnext",
  ["<leader><tab>["] = "tabprevious",
}) do
  map("n", key, "<cmd>" .. command .. "<cr>", command)
end
