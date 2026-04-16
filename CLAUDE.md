# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**EndlessPath** is an incremental/idle game blended with active mini-games, built in **Godot 4.5** using **GDScript**. Inspired by the "Cradle" book series, it follows a sacred artist cultivating power through a Wuxia-inspired cultivation system. Players progress through stages (Foundation, Copper, Iron, Jade), managing resources like Madra and Core Density through interconnected gameplay loops.

## Common Commands

All commands are run from the project root.

```bash
# Open in Godot editor
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" project.godot

# Run the game from CLI
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn

# Run the test suite
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit

# Export (example: Linux)
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --export-release "Linux" build/endlesspath.x86_64
```

## Testing

The project uses **GUT v9.6.0** for unit and integration tests. Test files live in `tests/unit/` and `tests/integration/`.

**Run tests:**
- After completing any feature or bug fix, before committing
- When a bug is suspected in a system that has tests — run tests first to see if anything is already failing
- After modifying any singleton manager, resource class, or combat formula

**Write new tests** when adding logic to: `ResourceManager`, `CultivationManager`, `CharacterManager`, `InventoryManager`, `CombatEffectData`, `EquipmentDefinitionData`, or any new system with testable pure logic.

**Test file naming:** `tests/unit/test_<system_name>.gd`, extending `GutTest`.

If the project has never been imported in the current environment, run `--import` first to register GUT class names:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

## Architecture

### Tech Stack
| Component | Details |
|-----------|---------|
| Engine | Godot 4.6 (Forward Plus / GL Compatibility) |
| Language | GDScript |
| Window | 1920x1080 |
| Entry Scene | `res://scenes/main/main_game/main_game.tscn` |
| Save File | `user://save.tres` |

### Directory Structure
| Directory | Purpose |
|-----------|---------|
| `scripts/` | GDScript source — resource definitions (`resource_definitions/`) and utilities (`utils/`) |
| `singletons/` | 16 autoload manager singletons (global game state) |
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
| `CyclingManager` | Cycling technique state (unlocked list, equipped technique, catalog lookups) |
| `PathManager` | Path progression tree, point balance, perk effects |
| `AbilityManager` | Ability unlock/equip state (unlocked pool, 4-slot loadout, catalog lookups) |
| `Dialogic` | Dialogue/narrative system (addon autoload) |

### Data-Driven Design
- Resource classes in `scripts/resource_definitions/` define data structures (e.g., `AbilityData`, `ZoneData`, `EquipmentDefinitionData`, `EffectData`, `AdventureResultData`)
- Godot `.tres` files in `resources/` instantiate and configure these resources
- When modifying data structures, update both the `.gd` resource class and any `.tres` files that reference it

### Equipment System
- Single `EquipmentDefinitionData` class (no subclasses) with `attribute_bonuses: Dictionary` (AttributeType → float)
- 6 equipment slots: `MAIN_HAND`, `OFF_HAND`, `HEAD`, `ARMOR`, `ACCESSORY_1`, `ACCESSORY_2`
- `CharacterManager._get_attribute_bonuses()` → `_get_equipment_bonuses()` sums equipped gear bonuses
- Bonuses flow through `get_total_attributes_data()` into combat, vitals, and all downstream systems
- Right-click to quick equip/unequip; tooltip persists during drag

### View Architecture
`MainView` (class) manages view states via a `MainViewStateMachine` child node:
- `ZoneViewState` — Exploration/map view
- `CyclingViewState` — Cycling mini-game
- `InventoryViewState` — Equipment/materials
- `AdventureViewState` — Combat exploration
- `AdventureEndCardState` — Modal overlay pushed on top of `AdventureViewState` when an adventure ends
- `PathTreeViewState` — Path progression skill tree overlay
- `AbilitiesViewState` — Ability management with loadout and drag-drop equipping

Views are switched via input actions (e.g., `open_inventory`) handled by the current state. The state machine supports `push_state`/`pop_state` for modal overlays (e.g., end card on top of adventure view). The `SystemMenu` in the `ZoneResourcePanel` provides nav buttons that fire these same input actions via `Input.parse_input_event()`. `SystemMenuButton` uses a `MenuType` enum that auto-configures label, shortcut, icon, and input action from a single dropdown.

### Reusable UI Components (`scenes/common/` and shared scenes)
Shared components used across multiple views:
- `ItemDisplaySlot` — Read-only item icon with hover tooltip, used in end card loot and anywhere items need display
- `ItemDescriptionPanel` — Item detail panel (icon, name, type, description, effects), shared between inventory sidebar and end card tooltips
- `Atmosphere` (`scenes/atmosphere/`) — Vignette shader + drifting mist sprites + floating mote particles; instanced in both zone and adventure views with per-scene `@export` tuning
- `HexHoverSelector` (`scenes/tilemaps/`) — Animated spritesheet ring that snaps to the hovered hex tile; shared between zone and adventure tilemaps
- `EncounterIcon` (`scenes/adventure/encounter_icon/`) — Per-type glyph renderer (combat, elite, boss, rest, treasure, trap, unknown) with visited/completed states and animated boss skull; reused inside both flat tile icons and the floating `AdventureMarker`
- `PathPreview` (`scenes/adventure/path_preview/`) — Tiled-texture `Line2D` showing the route from player to target; supports gradient-based fade that hides the section behind the player during committed travel

### Game Systems
1. **Cycling** — Mouse-following path + rhythm-clicking on a body diagram (Madra generation)
2. **Adventuring** — Hex grid exploration with fog-of-war (shader + FogVeilSprite smoke overlays), per-type encounter icons, floating AdventureMarker, tiled-texture path preview with committed-destination system (gradient fade behind player), real-time combat, scroll end card with stats/loot
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

## Parallel Agents

Multiple Claude Code agents may run simultaneously on this codebase. Follow these rules to avoid conflicts:

- **Stay in your scope.** Only edit files related to your assigned feature or directory. Do not "fix" code outside your scope, even if it looks wrong.
- **Don't chase phantom build errors.** If you see build/parse errors in files you did NOT edit, do not try to fix them — another agent is likely mid-edit. Wait 30 seconds and retry the build before investigating.
- **Use git worktrees for risky work.** When touching shared code (singletons, resource definitions, common UI components), prefer working in a git worktree so changes can be reviewed and merged manually.
- **Don't share browser sessions.** If using browser automation, do not reuse tabs or sessions that another agent may be using.
- **Commit only your own work.** Before committing, verify with `git diff` that you are only staging files you intentionally changed. If you see unexpected modifications from another agent, leave them alone.

## UI Styling

UI text uses a **Label theme variant type-scale** defined in `assets/themes/pixel_theme.tres`. Before adding inline `theme_override_font_sizes` or `theme_override_colors` to a Label, read **`docs/UI_STYLING.md`** — it lists every available variant, the rule of thumb for when to use a variant vs a direct override, and copy-paste `.tscn` patterns.

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
Custom shaders live in `assets/shaders/`. Notable shaders include: `liquid_wave` (Madra bar fill), `core_density_fill` (radial density display), `vignette` (screen-edge darkening for atmosphere), `fog_of_war` (per-tile clear zones with zoom-scaled radius), `flowing_path` (animated brightness wave for zone glowing paths), `tile_aura` (pulsing color overlay for zone hover), and `path_connection_energy` (animated pulses along path tree connections).

### Styling / Themes
UI themes are defined in `assets/themes/` as Godot `.tres` theme resources. Custom styleboxes in `assets/styleboxes/`. Use existing theme tokens — do not introduce external UI frameworks. See `docs/UI_STYLING.md` for the Label variant type-scale and usage rules.

### Dialogue
Dialogic addon handles narrative/dialogue. Timeline and character data in `assets/dialogue/`.

### Hex Grid
Both zone and adventure maps use the `hexagon_tilemaplayer` addon for hex-based tile rendering. The zone map renders per-zone forest variants via `ZoneData.tile_variant_index`. The adventure map uses a 23-variant forest atlas (`hex_forest_atlas.png`) with deterministic-random per-tile selection. Hover feedback uses a shared `HexHoverSelector` animated spritesheet. Zone connections between unlocked tiles are drawn with `GlowingPath` (Line2D + flowing shader). Locked zones are overlaid with `LockedZoneOverlay` (grey hex + lock icon with shake-on-click).

### Logging
`LogManager` singleton emits `message_logged` signals for in-game log display via `LogWindow`. Call `LogManager.log_message(bbcode)` to log. There is no log-level system — callers format their own BBCode strings.

### Key Input Bindings
- `open_inventory` / `close_inventory` — I / Escape
- `close_cycling_view` — Escape
- `center_zone_map_camera` — Space
- `dialogic_default_action` — Enter, Click, Space, X, Gamepad A

### Reference Documents
- **Game Design Document**: `Endless Path Game Design Document [v0.1].txt` in project root (detailed mechanics, progression, visual style, MVP goals)
