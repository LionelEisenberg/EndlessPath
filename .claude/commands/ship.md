---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*)
description: Review changes, commit, and summarize
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged): !`git diff HEAD`
- Recent commits: !`git log --oneline -8`

## Your task

Follow these steps in order:

1. **Review the diff** — scan for:
   - Debug artifacts or leftover print statements
   - Accidentally staged files (`.import/`, `.godot/`, user data)
   - Any obvious bugs or issues introduced by the changes

2. **Report** — give a brief 2-4 line summary of what changed and flag any concerns. If there are serious issues, stop and ask the user before committing.

3. **Stage and commit** — stage only relevant source files (`.gd`, `.tscn`, `.tres`, `.cfg`, `.md`; never `.godot/`, `*.tmp`, or user save data). Write a commit message that explains *why* the change was made, following the style of recent commits.
