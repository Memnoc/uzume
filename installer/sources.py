"""Export exact Git commits into a private staging directory."""
import re
import subprocess
import tarfile


def export(url, commit, destination, staging, cache=None):
    if not re.fullmatch(r'[0-9a-f]{40}', commit):
        raise RuntimeError('Source pins must be full Git commit IDs: ' + commit)
    repo = cache
    available = repo and repo.is_dir() and subprocess.run(
        ['git', '-C', str(repo), 'cat-file', '-e', commit + '^{commit}'],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode == 0
    if not available:
        repo = staging / ('git-' + commit)
        if not repo.exists():
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            subprocess.run(['git', '-C', str(repo), 'fetch', '--depth=1', url, commit], check=True, timeout=180)
    archive = staging / (commit + '.tar')
    with archive.open('wb') as output:
        subprocess.run(['git', '-C', str(repo), 'archive', '--format=tar', commit], stdout=output, check=True)
    destination.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive) as package:
        package.extractall(destination, filter='data')
    archive.unlink()
