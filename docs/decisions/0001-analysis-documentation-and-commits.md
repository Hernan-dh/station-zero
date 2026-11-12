# Keep analysis documentation and commit tooling on the analysis branch

Date: 2026-11-11
Status: accepted

## Context

Station Zero implementations on main are reviewed as potential Suricaterra tasks. Editor integration and audit tooling should not become part of those implementations by accident.

## Decision

Keep analysis documentation and tooling on the analysis branch. Generate changelogs and ADR drafts locally, share verification with an optional Git hook and CI, and use the portfolio publication workflow with confirmation. Refuse publication from or to main through the helper.

## Consequences

Reviews can identify the exact revision under examination. Working tree changes still need a commit or a separate worktree before switching branches. The helper cannot prevent direct Git commands or merges; branch separation remains a workflow responsibility.
