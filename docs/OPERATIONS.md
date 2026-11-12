# Operations

Requires Python 3.10+ and Git. Run commands from the repository root.

Verification runs Git without a pager so publishing cannot pause at `END`. The vendored MCP addon retains its upstream format: `.gitattributes` permits trailing blank lines only under `addons/godot_mcp/`; other whitespace checks remain active. If a verification fails after staging, files remain staged for review and a later retry.

- `python scripts/verify.py`: validate documentation, Python syntax and Git whitespace checks.
- `python scripts/document.py changelog`: regenerate `CHANGELOG.md` from the current branch history.
- `python scripts/document.py decision "Title"`: create a numbered ADR draft in `docs/decisions/`.
- `python scripts/install_hooks.py`: optionally configure the repository-managed pre-commit hook for this clone. This modifies local Git configuration and affects all branches in the clone.
- `python scripts/publish.py --preview`: verify all changes and preview the proposed Conventional Commit. `python scripts/publish.py` lists all changed files and, after typing `PUBLISH`, stages, verifies, commits, and pushes the current branch to `origin`. It refuses `main`, detached HEAD, and an upstream targeting `main`.
- Commit metadata is generated using Gemini, then OpenRouter and Groq as fallbacks, using keys from environment variables or `.env` (see `.env.example`). The change context, including new text files, is sent to the provider; review the files before running even a preview. For a local-only proposal, supply both `--title "docs: describe analysis" --description "Summary."`.

Review all changed paths, staged content, and diffs before publishing: the command includes all non-ignored changes and pushes the branch. Verification does not scan for secrets. The hook is optional and can be bypassed by Git; it is not a security boundary. A branch does not isolate uncommitted files: they can follow a branch switch. Keep analysis changes committed on the analysis branch before switching, or use a separate worktree.

To inspect `main` without switching, use `git show main:path/to/file` or `git diff main...HEAD`. Confirm the editor's current scene and project before using MCP; the editor reads this working tree, not an arbitrary Git revision.
