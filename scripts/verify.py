"""Run lightweight, dependency-free analysis workspace checks."""
import ast
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GIT = ['git', '--no-pager', '-c', f'safe.directory={ROOT.as_posix()}', '-C', str(ROOT)]
REQUIRED = ('README.md', 'AGENTS.md', 'CHANGELOG.md', 'docs/ARCHITECTURE.md',
            'docs/OPERATIONS.md', 'docs/decisions/README.md')

def main():
    errors = []
    for name in REQUIRED:
        if not (ROOT / name).is_file():
            errors.append(f'Missing {name}')
    for path in (ROOT / 'scripts').glob('*.py'):
        try:
            ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
        except (SyntaxError, UnicodeError) as exc:
            errors.append(f'{path.name}: {exc}')
    for args in (['diff', '--check'], ['diff', '--cached', '--check']):
        if subprocess.run([*GIT, *args], cwd=ROOT).returncode:
            errors.append('Git whitespace check failed: ' + ' '.join(args))
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print('Verification passed: documentation, Python syntax, and Git whitespace.')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
