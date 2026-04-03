# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**EndlessPath** is an incremental/idle game blended with active mini-games, built in **Godot 4.5** using **GDScript**. Inspired by the "Cradle" book series, it follows a sacred artist cultivating power through a Wuxia-inspired cultivation system. Players progress through stages (Foundation, Copper, Iron, Jade), managing resources like Madra and Core Density through interconnected gameplay loops.

## Common Commands

All commands are run from the project root (`/home/lionelshnizel/EndlessPath`).

```bash
# Open in Godot editor
godot project.godot

# Run the game from CLI
godot --path . scenes/main/main_game/main_game.tscn

# Export (example: Linux)
godot --headless --export-release "Linux" build/endlesspath.x86_64
```

There is no automated test suite yet — testing is manual via the editor.

## Architecture

### Tech Stack
| Component | Details |
|-----------|---------|
| Engine | Godot 4.5 (Forward Plus / GL Compatibility) |
| Language | GDScript |
| Window | 1920x1080 |
| Entry Scene | `res://scenes/main/main_game/main_game.tscn` |
| Save File | `user://save.tres` |

### Directory Structure
| Directory | Purpose |
|-----------|---------|
| `scripts/` | GDScript source — resource definitions (`resource_definitions/`) and utilities (`utils/`) |
| `singletons/` | 12 autoload manager singletons (global game state) |
| `scenes/` | Godot `.tscn` scene files + attached scripts |
| `resources/` | `.tres` data files (abilities, zones, items, encounters, loot tables) |
| `assets/` | Art, audio, shaders, themes, fonts, UI images, Aseprite sources |
| `addons/` | Godot plugins (Dialogic, AsepriteWizard, ResourcePlus, hexagon_tilemaplayer, script-ide, godot_context_exporter) |

### Singleton Managers (`singletons/`)
These are autoloaded in `project.godot` and provide global state:

| Manager | Purpose |
|---------|---------|
| `PersistenceManager` | Save/load system with `SaveGameData` resource |
| `ResourceManager` | Tracks Madra, Core Density, and currencies |
| `CultivationManager` | Cultivation stage progression and breakthroughs |
| `InventoryManager` | Equipment and material inventory |
| `ZoneManager` | Active zone/map control |
| `UnlockManager` | Feature unlock gates |
| `EventManager` | Global event bus |
| `DialogueManager` | Dialogic integration |
| `PlayerManager` | Character/player state |
| `LogManager` | Centralized logging system |
| `ActionManager` | Action queue system |
| `CharacterManager` | Character data |
| `Dialogic` | Dialogue/narrative system (addon autoload) |

### Data-Driven Design
- Resource classes in `scripts/resource_definitions/` define data structures (e.g., `AbilityData`, `ZoneData`, `ItemData`, `EffectData`)
- Godot `.tres` files in `resources/` instantiate and configure these resources
- When modifying data structures, update both the `.gd` resource class and any `.tres` files that reference it

### View Architecture
`MainView` (class) manages view states via a `MainViewStateMachine` child node:
- `ZoneViewState` — Exploration/map view
- `CyclingViewState` — Cycling mini-game
- `InventoryViewState` — Equipment/materials
- `AdventureViewState` — Combat exploration

### Game Systems
1. **Cycling** — Mouse-following path + rhythm-clicking on a body diagram (Madra generation)
2. **Adventuring** — Node-based hex grid exploration + real-time combat
3. **Combat** — Real-time AP regeneration, learned abilities with cooldowns and costs
4. **Scripting** — Calligraphy/character tracing (planned)
5. **Elixir Making** — Multi-stage crafting (planned)
6. **Soulsmithing** — Tetris-like assembly puzzle (planned)

### Progression
- Madra: currency generated from Cycling
- Core Density: 0-100% level system
- Breakthrough mechanic with Tribulation challenge
- Cultivation stages unlock new systems

## Git Workflow

**When to commit:** After completing a feature, fixing a bug, or finishing a meaningful refactor — ask the user for confirmation before committing. Never commit without user approval.

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

## GDScript Coding Standards

**Scope**: Never modify files in `addons/`.

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
- Remove all `print()` statements — use `LogManager.log_message()` for runtime output
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

## Development Notes

### Shaders
Custom shaders live in `assets/shaders/`. Recent examples include liquid wave effects for the Madra bar and a radial fill shader for Core Density display.

### Styling / Themes
UI themes are defined in `assets/themes/` as Godot `.tres` theme resources. Custom styleboxes in `assets/styleboxes/`. Use existing theme tokens — do not introduce external UI frameworks.

### Dialogue
Dialogic addon handles narrative/dialogue. Timeline and character data in `assets/dialogue/`.

### Hex Grid
Adventure maps use the `hexagon_tilemaplayer` addon for hex-based tile rendering.

### Logging
`LogManager` singleton emits `message_logged` signals for in-game log display via `LogWindow`. Call `LogManager.log_message(bbcode)` to log. There is no log-level system — callers format their own BBCode strings.

### Key Input Bindings
- `open_inventory` / `close_inventory` — I / Escape
- `close_cycling_view` — Escape
- `center_zone_map_camera` — Space
- `dialogic_default_action` — Enter, Click, Space, X, Gamepad A

### Reference Documents
- **Game Design Document**: `Endless Path Game Design Document [v0.1].txt` in project root (detailed mechanics, progression, visual style, MVP goals)
