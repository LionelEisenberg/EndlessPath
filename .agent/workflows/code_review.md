---
description: Review and clean up currently staged and unstaged files according to project standards.
---

# Code Review Workflow

This workflow checks currently staged and unstaged files for code style issues and applies fixes, showing only the changes made.

## Rules

(Same as Code Cleanup)

1.  **Scope**: Ignore the `addons` folder entirely. Only process `.gd` files that are currently modified (staged or unstaged).
2.  **Function Definitions**:
    *   Ensure all functions have fully defined return types (use `-> void` if they return nothing).
    *   **Public Functions**: Must NOT start with `_`. Must have a single `##` comment block above the definition describing the function.
    *   **Private Functions**: Must start with `_`. Defined as functions called within the class but not by other nodes (includes signal connections like `_on_signal`).
3.  **Comments**:
    *   Follow the existing commenting pattern.
    *   Use `##` for documentation comments on public functions and the class itself.
4.  **Variables**:
    *   **Class Variables**: Must have explicit types (e.g., `var health: float = 100.0` instead of `var health = 100.0`).
    *   **Node Fetches**: Ensure all `onready` variables getting nodes use unique names with `%` (e.g., `%Label` instead of `$Label` or `get_node("Label")`), assuming the node has a unique name set in the scene.
5.  **Logging & Debugging**:
    *   **Remove** any `print()` statements.
    *   **Check** for `Log.debug()` calls. Review if they are necessary; if not, remove or comment them out.

## Steps

1.  **Identify Modified Files**:
    *   Run `git status --porcelain` to get a list of changed files.
    *   Parse the output to identify files with status `M` (Modified), `A` (Added), or `?` (Untracked) if relevant, but primarily focus on Modified/Added.
    *   Filter this list to include only `.gd` files and exclude `addons/`.

2.  **Process and Fix**:
    *   Iterate through each identified file.
    *   **Read** the file content.
    *   **Analyze** and **Apply Fixes** based on the rules above.
    *   If no issues are found, do **not** modify the file.

3.  **Report**:
    *   After processing all files, iterate through the list of *modified* files (files you actually changed).
    *   For each changed file, output `render_diffs(file_uri)` to show exactly what was changed.
    *   If a file from the git list was analyzed but no changes were needed, do **not** show it in the report.
