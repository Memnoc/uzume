"""Compile pinned generated grammars and install their matching Neovim queries."""
import hashlib
import json
import os
import platform
import shlex
import subprocess
from .sources import export


def host():
    return platform.system().lower() + '-' + platform.machine().lower()


def build(spec, destination, staging, compiler):
    destination.mkdir(parents=True, exist_ok=True)
    query = spec['queries']
    source = staging / 'queries-source'
    export(query['url'], query['commit'], source, staging)
    for relative, expected in query['files'].items():
        content = (source / query['subdir'] / relative).read_bytes()
        if hashlib.sha256(content).hexdigest() != expected:
            raise RuntimeError('Pinned query checksum mismatch: ' + relative)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
    licenses = destination / 'licenses'
    licenses.mkdir()
    for path in source.glob('*LICENSE*'):
        if path.is_file():
            (licenses / ('queries-' + path.name)).write_bytes(path.read_bytes())
    sources = {}
    for entry in spec['parsers']:
        key = (entry['url'], entry['commit'])
        if key not in sources:
            source = staging / ('grammar-' + entry['commit'])
            export(entry['url'], entry['commit'], source, staging)
            sources[key] = source
        source = sources[key]
        grammar = source / entry['subdir']
        files = [grammar / 'src/parser.c']
        scanner = grammar / 'src/scanner.c'
        if scanner.is_file():
            files.append(scanner)
        target = destination / 'parser' / (entry['name'] + '.so')
        target.parent.mkdir(parents=True, exist_ok=True)
        flags = ['-dynamiclib'] if platform.system() == 'Darwin' else ['-shared', '-fPIC']
        command = shlex.split(compiler) + ['-O2', '-std=c11', *flags, '-I', str(grammar / 'src'),
                                          *map(str, files), '-o', str(target)]
        subprocess.run(command, cwd=grammar, check=True, timeout=180)
        for path in source.glob('*LICENSE*'):
            if path.is_file():
                (licenses / (entry['name'] + '-' + path.name)).write_bytes(path.read_bytes())
        print('Built ' + entry['name'] + ' @ ' + entry['commit'][:12], flush=True)


def validate(destination, spec, nvim, staging):
    # An incompatible parser/query must fail installation before activation.
    script = staging / 'validate-syntax.lua'
    script.write_text('''
local root = vim.env.UZUME_SYNTAX_ROOT
vim.opt.runtimepath:prepend(root)
local spec = vim.json.decode(vim.env.UZUME_SYNTAX_SPEC)
for _, entry in ipairs(spec.parsers) do
  vim.treesitter.language.add(entry.name, {path = root .. "/parser/" .. entry.name .. ".so"})
  local parser = vim.treesitter.get_string_parser("", entry.name)
  assert(parser:parse()[1], entry.name .. ": no parse tree")
  for _, kind in ipairs({"highlights", "injections", "folds", "indents", "locals"}) do
    assert(vim.treesitter.query.get(entry.name, kind), entry.name .. "/" .. kind .. ": missing query")
  end
end
''')
    env = dict(os.environ, UZUME_SYNTAX_ROOT=str(destination), UZUME_SYNTAX_SPEC=json.dumps(spec))
    command = [nvim, '--headless', '-u', 'NONE', '-i', 'NONE',
               '-c', 'lua local ok,err=pcall(dofile, vim.env.UZUME_SYNTAX_CHECK); if not ok then print(err); vim.cmd("cquit 1") end',
               '-c', 'qa!']
    env['UZUME_SYNTAX_CHECK'] = str(script)
    subprocess.run(command, env=env, check=True, timeout=60)
