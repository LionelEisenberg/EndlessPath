---
description: Workflow for committing changes to main with standardized messages and logical separation.
---

1. **Analyze Status**
   - Run `git status` to identify pending changes.
   - Review the diffs of modified files if necessary to understand the context.

2. **Logical Grouping (Iterative)**
   - **Goal**: Each commit should represent a single logical unit of work.
   - If the changes cover multiple distinct areas (e.g., a UI fix and a backend feature), you MUST separate them.
   - **Action**:
     - Identify the first logical group of files.
     - distinct: Use `git add <file_path>` for specific files.
     - mixed in file: Use `git add -p` to stage specific hunks if a file contains changes for multiple logic groups.
     - If all changes belong to one logic group, use `git add .`.

3. **Commit Message Generation**
   - Craft a commit message for the *staged* changes using the following rules (derived from project history and best practices):
     - **Format**: `<type>(<scope>): <subject>`
     - **Types**:
       - `feat`: A new feature
       - `fix`: A bug fix
       - `docs`: Documentation only changes
       - `style`: Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
       - `refactor`: A code change that neither fixes a bug nor adds a feature
       - `perf`: A code change that improves performance
       - `test`: Adding missing tests or correcting existing tests
       - `chore`: Changes to the build process or auxiliary tools/libraries locations
     - **Scope**: (Optional) The specific part of the codebase affected (e.g., `combat`, `ui`, `inventory`).
     - **Subject**:
       - Use the imperative mood ("add" not "added", "fix" not "fixes").
       - No period at the end.
       - Max 50 characters ideally, but keep it concise.
       - Example: `feat(combat): implement generic cast time logic`
   - **Verification**: Ensure the message accurately reflects the *staged* changes.

4. **Execute Commit**
   - Present the proposed commit message to the user or run the command if you are confident and in a trusted mode.
   - Run: `git commit -m "<your_message>"`

5. **Loop**
   - Repeat steps 2-4 until `git status` shows no more modifications to be committed.

6. **Push**
   - Once all changes are committed, run: `git push origin main`