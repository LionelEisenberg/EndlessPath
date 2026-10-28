---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Bash(git branch:*)
description: Review changes, commit, and summarize
---

## Context

- Current branch: !`git branch --show-current`
- Current git status: !`git status`
- Current git diff (staged and unstaged): !`git diff HEAD`
- Recent commits: !`git log --oneline -8`

## Your task

Follow these steps in order:

1. **Review the diff** — scan for:
   - Debug artifacts or leftover print statements
   - Accidentally staged files (`.import/`, `.godot/`, user data)
   - Any obvious bugs or issues introduced by the changes
   - On a branch that is not a `docs/` branch, edits to living docs ("Keeping Docs Current" in `docs/README.md` says which docs those are, and the exceptions a feature PR may carry)

2. **Report** — give a brief 2-4 line summary of what changed and flag any concerns. If there are serious issues, stop and ask the user before committing. If living docs were edited on a feature branch, say so and leave them out of the commit: what they describe goes in the PR's `## Docs to update` list instead.

3. **Stage and commit** — stage only relevant source files (`.gd`, `.tscn`, `.tres`, `.cfg`, `.md`; never `.godot/`, `*.tmp`, or user save data). Write a commit message that explains *why* the change was made, following the style of recent commits.

4. **Docs to update** — on a feature branch, end with the lines this commit adds to the PR's `## Docs to update` list: one per living doc that owns a behaviour the commit changed, saying what changed. Write "None" when no documented behaviour changed.
