"""Coordinate supervised CLI/integration use with explicit task checkout removal."""
from contextlib import contextmanager
import fcntl
import hashlib
import os
from pathlib import Path
import subprocess

@contextmanager
def lease(cwd, exclusive=False):
    cwd = Path(cwd).resolve()
    env = {k:v for k,v in os.environ.items() if not k.startswith('GIT_')}
    result = subprocess.run(['git','-C',str(cwd),'rev-parse','--git-common-dir'],
                            env=env,text=True,capture_output=True,timeout=10)
    if result.returncode:
        raise ValueError('Task checkout is unavailable: '+str(cwd))
    common = Path(result.stdout.strip())
    if not common.is_absolute(): common=cwd/common
    directory=common.resolve()/'uzume-task-locks'
    directory.mkdir(mode=0o700,exist_ok=True)
    path=directory/(hashlib.sha256(os.fsencode(cwd)).hexdigest()+'.lock')
    fd=os.open(path,os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
    try:
        try:
            fcntl.flock(fd,(fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH)|fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('Task is busy: stop its agent or wait for integration/cleanup to finish.') from None
        yield
    finally:
        os.close(fd)
