#!/usr/bin/env python3
"""User language pack startup, LSP attachment and formatting at the editor boundary."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
root = Path(tempfile.mkdtemp(prefix='uzume-languages-')).resolve()
config = root / 'config/uzume'
config.parent.mkdir()
config.symlink_to(REPO / 'editor')
data = root / 'data/uzume'
data.mkdir(parents=True)
(data / 'releases').symlink_to(Path(os.environ.get('XDG_DATA_HOME', Path.home()/'.local/share')) / 'uzume/releases')
packs = root / 'config/uzume-user/languages'
packs.mkdir(parents=True)
fixture = root / 'tools'
fixture.mkdir()
server = fixture / 'uzume-language-server'
server.write_text('''#!/usr/bin/env python3
import json, sys
while True:
    headers = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line: sys.exit(0)
        if line == b"\\r\\n": break
        key, value = line.decode().split(":", 1)
        headers[key.lower()] = value.strip()
    msg = json.loads(sys.stdin.buffer.read(int(headers['content-length'])))
    if msg.get('method') == 'exit': break
    if 'id' not in msg: continue
    result = {'capabilities': {'textDocumentSync': 1}} if msg.get('method') == 'initialize' else None
    body = json.dumps({'jsonrpc':'2.0','id':msg['id'],'result':result}).encode()
    sys.stdout.buffer.write(('Content-Length: %d\\r\\n\\r\\n' % len(body)).encode() + body)
    sys.stdout.buffer.flush()
''')
server.chmod(0o755)
formatter = fixture / 'uzume-uppercase'
formatter.write_text('#!/usr/bin/env python3\nimport sys\nsys.stdout.write(sys.stdin.read().upper())\n')
formatter.chmod(0o755)
pack = dict(version=1, name='Fixture Language', filetypes=['uzumefixture'], extensions=['uzlang'],
            servers=[dict(name='uzume_fixture', command=str(server), args=[])],
            formatters=[dict(name='uzume_uppercase', command=str(formatter), args=[], stdin=True)],
            prerequisites=['Fixture tools supplied by test'])
(packs / 'fixture.json').write_text(json.dumps(pack))
(data / 'extras.json').write_text(json.dumps({'version':1, 'enabled':dict(rust=False,lua=False,c=False,web=False,smear=False,**{'user:fixture':True})}))
(data / 'tool-settings.json').write_text('{"auto_install":false}')
sample = root / 'sample.uzlang'
sample.write_text('hello language\n')
script = root / 'check.lua'
script.write_text('''
local extras = require("uzume.editor.extras")
assert(extras.enabled("user:fixture"), "User pack was not loaded")
assert(extras.enabled("languages"), "User-only languages must load shared packages")
vim.cmd.edit(vim.fn.fnameescape(''' + json.dumps(str(sample)) + '''))
assert(vim.bo.filetype == "uzumefixture", "User filetype was not detected")
assert(vim.wait(5000, function() return #vim.lsp.get_clients({bufnr=0}) == 1 end, 20), "User LSP did not attach")
require("conform").format({async=false, timeout_ms=3000})
assert(vim.api.nvim_get_current_line() == "HELLO LANGUAGE", "User formatter did not run")
print("PASS: user-only pack enables LSP, filetype and formatter without changing core")
''')
env = dict(os.environ, NVIM_APPNAME='uzume', XDG_CONFIG_HOME=str(root/'config'), XDG_DATA_HOME=str(root/'data'),
           XDG_STATE_HOME=str(root/'state'), XDG_CACHE_HOME=str(root/'cache'))
nvim = os.environ.get('UZUME_TEST_NVIM', shutil.which('nvim'))
result = subprocess.run([nvim, '--headless', '-c', 'lua local ok,err=pcall(dofile,'+json.dumps(str(script))+'); if not ok then print(err); vim.cmd("cquit 1") end', '-c', 'qa!'], env=env, cwd=root, capture_output=True, text=True, timeout=20)
print(result.stdout + result.stderr)
print('Artifacts:', root)
assert result.returncode == 0

# Bad local definitions must stay visible for repair without breaking valid packs.
(packs / 'broken.json').write_text('{ not json')
(packs / 'collision.json').write_text(json.dumps(dict(pack, name='Other', filetypes=['uzumefixture'])))
(packs / 'pin-conflict.json').write_text(json.dumps(dict(version=1, name='Bad pin', filetypes=['badpin'],
    formatters=[dict(name='stylua',command='stylua',package='stylua',version='wrong-version')])))
(packs / 'bad-config.json').write_text(json.dumps(dict(version=1, name='Bad configuration', filetypes=['badconfig'], servers=[dict(name='fixture',command=str(server),config={'root_markers':42})])))
script.write_text('''
local extras = require("uzume.editor.extras")
local errors = require("uzume.extras.packs").errors
assert(#errors == 4, vim.inspect(errors))
assert(extras.enabled("user:fixture"), "Valid pack was lost because another pack was invalid")
assert(vim.fn.exists(":Extras") == 2, "Invalid packs broke editor startup")
print("PASS: malformed, conflicting-filetype and conflicting-pin packs are isolated")
''')
# Order determines ownership for user duplicates; keep the valid fixture first.
(packs / 'collision.json').rename(packs / 'z-collision.json')
result = subprocess.run([nvim, '--headless', '-c', 'lua local ok,err=pcall(dofile,'+json.dumps(str(script))+'); if not ok then print(err); vim.cmd("cquit 1") end', '-c', 'qa!'], env=env, cwd=root, capture_output=True, text=True, timeout=20)
print(result.stdout + result.stderr)
assert result.returncode == 0

# Disabling the same valid pack survives restart and prevents activation.
choices = json.loads((data/'extras.json').read_text())
choices['enabled']['user:fixture'] = False
(data/'extras.json').write_text(json.dumps(choices))
script.write_text('''
assert(not require("uzume.editor.extras").enabled("languages"))
vim.cmd.edit(vim.fn.fnameescape(''' + json.dumps(str(sample)) + '''))
vim.bo.filetype = "uzumefixture"
vim.wait(200)
assert(#vim.lsp.get_clients({bufnr=0}) == 0, "Disabled user pack started a server")
print("PASS: disabled user pack stays inactive on restart")
''')
result = subprocess.run([nvim, '--headless', '-c', 'lua local ok,err=pcall(dofile,'+json.dumps(str(script))+'); if not ok then print(err); vim.cmd("cquit 1") end', '-c', 'qa!'], env=env, cwd=root, capture_output=True, text=True, timeout=20)
print(result.stdout + result.stderr)
assert result.returncode == 0
