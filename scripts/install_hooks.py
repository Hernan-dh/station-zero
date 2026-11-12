"""Opt in to the repository-managed hooks for this clone."""
import stat
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
hook = ROOT / '.githooks' / 'pre-commit'
hook.chmod(hook.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
subprocess.run(['git', '-c', f'safe.directory={ROOT.as_posix()}', '-C', str(ROOT),
                'config', '--local', 'core.hooksPath', '.githooks'], check=True)
print('Hooks enabled for this clone.')
