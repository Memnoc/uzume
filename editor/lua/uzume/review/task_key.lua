-- Preserve saved review identities, including on Neovim 0.11 where sha256()
-- rejects the NUL separator as a Blob. Python is already required for tasks.
local keys = {}
return function(task)
  local input = task.project .. "\0" .. task.id
  if not keys[input] then
    local ok, key = pcall(vim.fn.sha256, input)
    if not ok then
      local result = vim.system({
        "python3",
        "-c",
        "import hashlib, sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())",
      }, { stdin = input, text = true, timeout = 5000 }):wait()
      assert(result.code == 0, "Could not identify saved task review: " .. (result.stderr or ""))
      key = vim.trim(result.stdout or "")
    end
    assert(#key == 64 and key:match("^%x+$"), "Invalid saved task review identifier")
    keys[input] = key
  end
  return keys[input]
end
