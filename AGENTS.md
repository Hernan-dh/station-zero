# Agent instructions

- Keep analysis tooling, addon, and findings on the analysis branch; never merge or copy them to `main` without explicit authorization.
- Review `main` through Git without changing the working branch. Identify the commit reviewed and distinguish observations from task ideas.
- Do not alter gameplay or existing scenes while auditing. Task descriptions for Suricaterra must be written by a person.
- Update architecture and operations documentation when lasting behavior or workflows change; record non-obvious decisions as ADRs. Do not record secrets or private data.
- Run `python scripts/verify.py` before proposing a commit. Use English Conventional Commit subjects of at most 72 characters.
- Create commits or push only with explicit authorization; never force-push.
