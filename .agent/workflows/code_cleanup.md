---
description: Clean up GDScript code according to project standards (naming, typing, comments).
---

# Code Cleanup Workflow

This workflow guides the agent through cleaning up GDScript files to match the project's coding standards.

## Rules

1.  **Scope**: Ignore the `addons` folder entirely.
2.  **Function Definitions**:
    *   Ensure all functions have fully defined return types (use `-> void` if they return nothing).
    *   **Public Functions**: Must NOT start with `_`. Must have a single `##` comment block above the definition describing the function.
    *   **Private Functions**: Must start with `_`. Defined as functions called within the class but not by other nodes (includes signal connections like `_on_signal`).
3.  **Comments**:
    *   Follow the existing commenting pattern (e.g., section headers like `#-----...`).
    *   Use `##` for documentation comments on public functions and the class itself.
4.  **Variables**:
    *   **Class Variables**: Must have explicit types (e.g., `var health: float = 100.0` instead of `var health = 100.0`).
    *   **Node Fetches**: Ensure all `onready` variables getting nodes use unique names with `%` (e.g., `%Label` instead of `$Label` or `get_node("Label")`), assuming the node has a unique name set in the scene.
5.  **Logging & Debugging**:
    *   **Remove** any `print()` statements.
    *   **Check** for `Log.debug()` calls. Review if they are necessary; if not, remove or comment them out.
6.  **Style**:
    *   Ensure uniform coding style.
    *   Be less directive in comments (avoid "TODO: Do this", prefer descriptive comments).

## Steps

1.  **Identify Files**:
    *   Search for `.gd` files in the project, excluding `addons`.
    *   *Tip*: Use `find_by_name` with `Extensions: ["gd"]` and `Excludes: ["**/addons/**"]`.

2.  **Process Files**:
    *   Iterate through the identified files.
    *   For each file:
        1.  **Read** the file content.
        2.  **Analyze** against the rules above.
        3.  **Apply Changes**:
            *   Rename functions if necessary (add/remove `_`). *Note: Be careful with signal connections defined in the editor; renaming the function might break the connection unless you update the scene or the connection code. If unsure, check if it's a signal handler.*
            *   Add missing return types.
            *   Add `##` comments to public functions.
            *   Add explicit types to variables.
            *   Convert `$` to `%` for node references.
            *   Remove `print` and handle `Log.debug`.
        4.  **Verify**: Ensure the code still parses and looks correct.

3.  **Completion**:
    *   Once all files are processed, report back to the user with a summary of changes.
