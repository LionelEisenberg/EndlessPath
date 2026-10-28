# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**EndlessPath** is an incremental/idle game blended with active mini-games, built in **Godot 4.7** using **GDScript**. Inspired by the "Cradle" book series, it follows a sacred artist cultivating power through a Wuxia-inspired cultivation system. Players progress through stages (Foundation, Copper, Iron, Jade), managing resources like Madra and Core Density through interconnected gameplay loops. Only the Foundation stage has content today. See `docs/STATE_OF_THE_GAME.md` for current status, and `docs/README.md` for the documentation index.

## Common Commands

All commands are run from the project root.

```bash
# Open in Godot editor
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" project.godot

# Run the game from CLI
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn

# Run it on its own save file. A plain run (above) plays the checkout's user://save.tres, the user's real save in the main checkout (a worktree has its own copy), backs it up at boot, so agents add --save=. Options: docs/infrastructure/PERSISTENCE.md
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn -- --save=user://dev/runs/<name>.tres

# Run it in a save preset, a starting point of the story (the list: docs/tooling/DEV_TOOLS.md). The session lives in memory and never reads or writes the user's save; an agent adds --save=user://dev/runs/<name>.tres to keep the run's file
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn -- --preset=tribulation_ready

# Run the test suite in 6 Godot processes at once (-Processes N for another count)
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1

# Run the test suite in one process, to confirm a failure from the parallel run
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit

# Export (example: Linux). Requires an export preset; no export_presets.cfg is committed yet
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --export-release "Linux" build/endlesspath.x86_64
```

## Testing

The project uses **GUT v9.7.1** for unit and integration tests. Test files live in `tests/unit/` and `tests/integration/`.

**Run tests:**
- After completing any feature or bug fix, before committing
- When a bug is suspected in a system that has tests — run tests first to see if anything is already failing
- After modifying any singleton manager, resource class, or combat formula

**How to run them:** `tests/run_tests.ps1` (the first test command above) splits the suite across 6 Godot processes, several times faster than one process. A test that depends on frame timing can fail on a busy machine, and the parallel run makes the machine busy, so before investigating a failure, rerun the failing files in one process with the command the runner prints (`-gconfig= -gtest=<files>`). The runner also fails a run when a test script runs no tests: GUT skips a script that does not parse with only a warning, and the one-process command still exits 0.

**Write new tests** when adding logic to: `ResourceManager`, `CultivationManager`, `CharacterManager`, `InventoryManager`, `CombatEffectData`, `EquipmentDefinitionData`, or any new system with testable pure logic.

**Test file naming:** `tests/unit/test_<system_name>.gd`, extending `GutTest`.

If the project has never been imported in the current environment, run `--import` first to register GUT class names:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --import
```

A fresh-checkout `--import` used to rewrite `project.godot`'s `[dialogic]` `directories/dch_directory` and `directories/dtl_directory` to `{}`. The local Dialogic patch listed under GDScript Coding Standards → Scope prevents that. If `git diff project.godot` ever shows those keys emptied again, the patch was probably lost in a Dialogic upgrade: restore the file and re-apply the patch before committing.

See `docs/testing/TESTING.md` for test conventions, the coverage gaps, and why tests must call production code instead of re-implementing ("mirroring") it.

## Architecture

### Tech Stack
| Component | Details |
|-----------|---------|
| Engine | Godot 4.7, GL Compatibility renderer (`config/features` also lists "Forward Plus") |
| Language | GDScript |
| Window | 1920x1080 |
| Entry Scene | `res://scenes/main/main_game/main_game.tscn` |
| Save File | `user://save.tres` |

### Directory Structure
| Directory | Purpose |
|-----------|---------|
| `scripts/` | GDScript source: resource definitions (`resource_definitions/`), utilities (`utils/`), editor/CLI tools (`tools/`), and code that belongs to no scene |
| `singletons/` | 18 manager singletons (global game state). They are autoloads along with Dialogic, 19 in total |
| `scenes/` | Godot `.tscn` scene files + attached scripts |
| `resources/` | `.tres` data files, one folder per system |
| `assets/` | Art (sprites, Aseprite sources, the lacquer kit in `ui/lacquer/`), shaders, themes, styleboxes, fonts, dialogue data. No audio yet |
| `addons/` | Godot plugins (Dialogic, AsepriteWizard, ResourcePlus, hexagon_tilemaplayer, script-ide, godot_context_exporter, gut) |
| `tests/` | GUT tests: `unit/`, `integration/`, `label_tests/`, and `run_tests.ps1`, which runs the suite in parallel Godot processes |
| `docs/` | Game and system documentation. Start at `docs/README.md` |

### Where the architecture is described
| Topic | Doc |
|-------|-----|
| Scene tree, the view state machine, what each singleton owns, data-driven content, the key shared components | `docs/CODEBASE_STATE.md` |
| `MainView`'s states, HUD boards, cycling and board modes, input routing, keybindings, the dock, shared widgets | `docs/infrastructure/MAIN_VIEW.md` |
| The zone view and its hex map | `docs/zones/ZONES.md` |
| The adventure view, its hex map and its boards | `docs/adventuring/ADVENTURING.md` |
| Lacquer pieces, theme variants and `ThemeConstants`; the look itself | `docs/UI_STYLING.md`; `docs/STYLE_GUIDE.md` |
| Each game system | Its doc, indexed in `docs/README.md` |

Built systems: Cycling, Zones and idle actions, Adventuring, Combat, Inventory, Path Progression, Quests, the Tribulation (the Foundation → Copper breakthrough). Planned: Scripting, Elixir Making, Soulsmithing.

### Conventions
- **Data-driven:** resource classes in `scripts/resource_definitions/` define the data, and `.tres` files in `resources/` instance it. When you change a data structure, update both the `.gd` resource class and every `.tres` that uses it.
- **Views:** `MainView` holds a state stack. Base views (zone, adventure) use `change_state`; overlays use `push_state` / `pop_state`. Menu books open through input actions that only the current state handles; the other overlays are driven by `ActionManager` and `AdventureView` signals.
- **Reuse before building:** shared UI lives in `scenes/common/` (the lacquer pieces in `lacquer/`), `scenes/inventory/common/` and `scenes/ui/`. `MAIN_VIEW.md`'s shared widgets, `UI_STYLING.md` and `INVENTORY.md` describe them.

## Git Workflow

**When to commit:** Commit your own work as you go, once each logical step is done (a feature, a bug fix, a meaningful refactor, a plan task). You don't need to ask first.

**Never commit to `main`:** commit on a feature branch (a worktree's own branch counts). If you find yourself on `main`, create a branch before committing.

**Never merge:** not into `main`, not into any other branch, and not a pull request, unless the user explicitly asks.

**Before committing:**
- Run `git diff HEAD` to review all changes
- Ensure no debug artifacts or `.import` cache files are staged
- Confirm the commit message explains *why*, not just *what*

**Separate work into logical commits:**
- Each commit should represent one logical change (e.g., one feature, one bug fix, one refactor)
- Scene + script changes that are tightly coupled should be committed together
- Extraction/refactor commits should be separate from new feature commits

**Commit hygiene:**
- Stage specific files rather than `git add -A` or `git add .`
- Keep `.godot/` cache and user data out of commits (already in `.gitignore`)

Use `/ship` to review, commit, and get a summary in one step.

**Worktrees in Godot's project list:** the SessionStart hook in `.claude/settings.json` runs `.claude/hooks/godot_project_list.ps1 sync`. It lists every live worktree in Godot's project manager through a junction in `C:\worktrees\EndlessPath-godot\` named after a one-liner of its feature, which Godot shows on the path line under the "EndlessPath" title. It drops worktrees that are gone or merged into main, and never touches the main checkout's entry. It also gives every worktree but the main checkout a `user://` folder of its own, so once a session start has synced it, no worktree's build, on any branch, writes the user's real save: an `override.cfg`, kept out of git, points the worktree's game runs at `%APPDATA%\Godot\app_userdata\EndlessPath-checkouts\<worktree folder>`, which starts with a copy of the main checkout's save (`docs/infrastructure/PERSISTENCE.md`, Save file location). Its test: `powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/test_godot_project_list.ps1`. New entries are named after their branch: once you know what your session is building, rename yours to a one-liner of the feature, and again if the work changes direction:
```bash
powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/godot_project_list.ps1 label "Zone view redesign"
```
Never delete one of those junctions with `Remove-Item -Recurse`: on a junction, Windows PowerShell deletes the worktree's own files.

## Parallel Agents

Multiple Claude Code agents may run simultaneously on this codebase. Follow these rules to avoid conflicts:

- **Stay in your scope.** Only edit files related to your assigned feature or directory. Do not "fix" code outside your scope, even if it looks wrong.
- **Don't chase phantom build errors.** If you see build/parse errors in files you did NOT edit, do not try to fix them — another agent is likely mid-edit. Wait 30 seconds and retry the build before investigating.
- **Use git worktrees for risky work.** When touching shared code (singletons, resource definitions, common UI components), prefer working in a git worktree so changes can be reviewed and merged manually.
- **Don't share browser sessions.** If using browser automation, do not reuse tabs or sessions that another agent may be using.
- **Commit only your own work.** Before committing, verify with `git diff` that you are only staging files you intentionally changed. If you see unexpected modifications from another agent, leave them alone.

## Documentation

Living docs follow "Keeping Docs Current" in `docs/README.md`, because two open branches that edit the same doc line make a merge conflict. In short:
- Each fact has one home, the system doc that owns it. Other docs, this file included, link to it instead of restating it.
- No counts of tests, scripts, scenes, resources, shaders or lines, no test run results or times, no `Last updated:` lines, no "Used by" lists of a shared widget's or variant's users.
- A system doc does not list its test files, record which review changed something, or name private `_helpers()`: it names the public functions and classes.
- A doc describes `main` as it will be once the PR merges: no branch names, no "not merged", no "in flight".
- `docs/STATE_OF_THE_GAME.md`, `docs/GAMEPLAY_STATE.md` and `docs/CODEBASE_STATE.md` are refreshed at milestones, on `main`, not in feature PRs.
- Merge `main` into a branch when you need its code and once before the PR merges, not after every merge to `main`.

## AI-Generated Art

The user must be able to tell AI-made art from art they made or imported. Any image file an agent creates — PNG, or any other art (`.aseprite`, `.svg`, spritesheets, textures, icons), whether generated by a script, an image model, or drawn pixel by pixel — gets an `_ai` suffix before the extension:

- `madra_orb_ai.png`, `hex_forest_atlas_ai.png`, `boss_glyph_ai.aseprite`
- Never overwrite or edit an existing art file that lacks the `_ai` suffix: it is the user's. Write the change to a new `_ai` file next to it and point the scene/resource at that, unless the user explicitly asks to edit their file in place.
- Keep the suffix when moving or renaming the file. Drop it only when the user says they've taken the file over.
- Mention every new `_ai` file in your summary so the user can review it.

## UI Styling

UI text uses a **Label theme variant type-scale** defined in `assets/themes/pixel_theme.tres`; the lacquer views use the lacquer theme (`assets/themes/lacquer/lacquer_theme.tres`, `LabelLacquer*` variants) on their roots instead. Before adding inline `theme_override_font_sizes` or `theme_override_colors` to a Label, read **`docs/UI_STYLING.md`** — it lists every available variant, the rule of thumb for when to use a variant vs a direct override, and copy-paste `.tscn` patterns.

Before reworking or building any screen, read **`docs/STYLE_GUIDE.md`**: the game's "Lacquer and brass" look (rules, palette, components, motion, review checklist) and the backlog of screens still to move to it. One rule is standing: **no text is ever cut off.** A Label that can run long wraps, and its board grows with it; no ellipsis, no `clip_text` (rule 14 and "Long text" in the style guide, which also lists the screens that still trim).

## GDScript Coding Standards

**Scope**: Never modify files in `addons/`. Known exceptions, both in `addons/dialogic` (2.0-Alpha-19):
- Upstream's 3-line Godot 4.7 return-value fix (dialogic-godot/dialogic#2769). Alpha 20+ already includes it.
- A local 1-line fix in `DialogicResourceUtil.update_directory()` so a first import without `.godot/` no longer empties the `[dialogic]` timeline/character registry in `project.godot`. Upstream still has this bug, so re-apply the fix after any Dialogic upgrade.

### Functions
- All functions must have explicit return types (use `-> void` if no return value)
- **Public functions**: Must NOT start with `_`. Must have a `##` doc comment above the definition
- **Private functions**: Must start with `_`. Includes internal helpers and signal handlers (e.g., `_on_signal`)

### Variables
- Class variables must have explicit types: `var health: float = 100.0` not `var health = 100.0`
- Node references must use unique names with `%`: `@onready var label := %Label` not `$Label` or `get_node("Label")`

### Comments & Logging
- Use `##` for doc comments on public functions and the class itself
- Follow the existing section header pattern (e.g., `#-----...`)
- Remove all `print()` statements. Use the `Log` utility (`Log.info()`/`Log.warn()`/`Log.error()`) for diagnostic output, and `LogManager.log_message()` only for messages the player should see in the in-game log
- Review `Log.debug()` calls for necessity before leaving them in

## Commit Message Format

Use conventional commits: `<type>(<scope>): <subject>`

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

**Scope** (optional): area affected — e.g., `combat`, `ui`, `inventory`, `cycling`

**Subject**: imperative mood ("add" not "added"), no trailing period, ~50 chars max

Example: `feat(combat): implement generic cast time logic`

## Planning & Design

- Analyze features through a **game design lens**: Does it make sense for the player? Is it fun? Does it fit the game loop?
- Text in `[brackets]` within prompts or design docs = direct instructions to the agent
- When implementing from a plan, build **bottom-up** — start with the lowest-level data structures and work up
- Update the planning document as implementation progresses and after completion to reflect final reality

## GodotPrompter

This is a Godot project with GodotPrompter skills available. Before implementing any game system, you MUST check for a matching `godot-prompter:*` skill and invoke it. This applies to all agents, subagents, and sessions working in this repository.

Key skills for this project: `resource-pattern`, `state-machine`, `event-bus`, `scene-organization`, `save-load`, `inventory-system`, `ability-system`, `godot-ui`, `hud-system`, `shader-basics`, `2d-essentials`, `godot-testing`.

If a skill's pattern conflicts with a convention in this file, follow this file and mention the conflict.

For the full skill list, invoke `godot-prompter:using-godot-prompter`.

## Development Notes

### Shaders
Shaders live in `assets/shaders/`. In the lacquer views a fill is a frame of a texture strip; only the orbs and the cooldown sweep are shaders, built to the pixel-grid shader pattern in `docs/STYLE_GUIDE.md`.

### Styling / Themes
UI themes are defined in `assets/themes/` as Godot `.tres` theme resources. Custom styleboxes in `assets/styleboxes/`. Use existing theme tokens — do not introduce external UI frameworks. See `docs/UI_STYLING.md` for the Label variant type-scale and usage rules.

### Dialogue
Dialogic addon handles narrative/dialogue. Timeline and character data in `assets/dialogue/`.

### Logging
There are two channels:
- **`Log`** (`scripts/utils/log.gd`): leveled diagnostics (INFO/DEBUG/WARN/ERROR/CRITICAL) to the console and a daily `user://logs-*.log` file.
- **`LogManager`**: the player-facing log, shown in `LogWindow`. Call `LogManager.log_message(bbcode)`; it has no levels, so callers format their own BBCode strings.

See `docs/infrastructure/LOGGING.md`.

### Aseprite MCP
`.mcp.json` registers the `aseprite` MCP server ([diivi/aseprite-mcp](https://github.com/diivi/aseprite-mcp)): 123 tools that draw, animate, inspect and export sprites by running the Steam copy of Aseprite in batch mode, so Aseprite doesn't need to be open. Pass it absolute paths: relative ones resolve against whatever directory Claude Code started the server in. Everything it writes is AI-made art, so the AI-Generated Art rules apply (`_ai` suffix, never save over the user's files).

The server lives outside the repo, cloned to `C:\Users\lione\source\repos\aseprite-mcp`; `.mcp.json` runs that clone's `.venv` Python directly, with `PYTHONPATH` pointing at the clone. The Claude desktop app is an MSIX package and redirects new `AppData` folders into its private storage, which breaks uv's default Python install, so uv keeps Python 3.13 and its cache in `C:\Users\lione\.uv` instead. To update or reinstall, from the clone:
```bash
git pull && UV_PYTHON_INSTALL_DIR='C:\Users\lione\.uv\python' UV_CACHE_DIR='C:\Users\lione\.uv\cache' uv sync --frozen
```

### Key Input Bindings
Every binding, and which view handles it, is listed under Keybindings in `docs/infrastructure/MAIN_VIEW.md`. The dev panel is Ctrl+Shift+D, open to anyone (`docs/tooling/DEV_TOOLS.md`).

### Reference Documents
- **Documentation index**: `docs/README.md` (every system doc, design record, and tool guide)
- **Current status and roadmap**: `docs/STATE_OF_THE_GAME.md` (one page); `docs/GAMEPLAY_STATE.md` (content inventory); `docs/CODEBASE_STATE.md` (architecture)
- **Game Design Document**: `Endless Path Game Design Document [v0.1].txt` in project root (detailed mechanics, progression, visual style, MVP goals)
