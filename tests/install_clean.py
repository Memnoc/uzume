#!/usr/bin/env python3
"""Opt-in network test: python3 tests/install_clean.py. No personal caches used."""
import os
from pathlib import Path
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
root = Path(tempfile.mkdtemp(prefix='uzume-clean-install-'))
env = dict(os.environ, **{f'XDG_{key}_HOME': str(root / value) for key, value in
                        [('CONFIG', 'config'), ('DATA', 'data'), ('STATE', 'state'), ('CACHE', 'cache')]})
log = root / 'install.log'
command = ['python3', str(REPO / 'setup-editor'), '--no-cache', '--register', '--bin-dir', str(root / 'bin')]
print('Artifacts:', root, flush=True)
with log.open('w') as output:
    result = subprocess.run(command, env=env, stdout=output, stderr=subprocess.STDOUT)
assert result.returncode == 0, log.read_text()[-5000:]
launcher = root / 'bin/uzume'
check = '''
local samples = {
 c = "int main(void) { return 0; }", cpp = "class Example { public: int value; };",
 html = "<div>Hello</div>", javascript = "const value = 1;", json = '{"value": 1}',
 lua = "local value = 1", rust = "fn main() {}", typescript = "const value: number = 1;",
 tsx = "const App = () => <div>Hello</div>;",
}
for lang, text in pairs(samples) do
  local parser = vim.treesitter.get_string_parser(text, lang)
  assert(not parser:parse()[1]:root():has_error(), lang .. " failed to parse")
  for _, name in ipairs({"highlights", "injections", "folds", "indents", "locals"}) do
    assert(vim.treesitter.query.get(lang, name), lang .. "/" .. name .. " query missing")
  end
end
assert(vim.fn.exists(":UzumeAgent") == 2)
assert(vim.fn.exists(":UzumeReview") == 2)
vim.cmd("qa!")
'''
script = root / 'syntax-check.lua'; script.write_text(check)
result = subprocess.run([str(launcher), '--headless', '-i', 'NONE', '-c', 'luafile ' + str(script), '-c', 'qa!'],
                        env=env, capture_output=True, text=True, timeout=60)
assert result.returncode == 0 and 'Error' not in result.stderr, result.stdout + result.stderr
print('PASS: cache-free download, source build, launcher, all nine parsers and inherited queries', flush=True)
result = subprocess.run(command, env=env, capture_output=True, text=True)
assert result.returncode == 0 and 'already installed' in result.stdout, result.stdout + result.stderr
print('PASS: repeat install reuses the completed bundle', flush=True)
print('XDG_DATA_HOME=' + str(root / 'data'), flush=True)
