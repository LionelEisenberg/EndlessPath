# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**EndlessPath** is an incremental/idle game blended with active mini-games, built in **Godot 4.7** using **GDScript**. Inspired by the "Cradle" book series, it follows a sacred artist cultivating power through a Wuxia-inspired cultivation system. Players progress through stages (Foundation, Copper, Iron, Jade), managing resources like Madra and Core Density through interconnected gameplay loops. Only the Foundation stage has content today: its ending, the Tribulation, breaks through to a thin Copper stage that unlocks nothing yet. See `docs/STATE_OF_THE_GAME.md` for current status, and `docs/README.md` for the documentation index.

## Common Commands

All commands are run from the project root.

```bash
# Open in Godot editor
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" project.godot

# Run the game from CLI
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn

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

**How to run them:** `tests/run_tests.ps1` (the first test command above) splits the suite across 6 Godot processes and takes about 35 s; one process takes about 100 s. A test that depends on frame timing can fail on a busy machine, and the parallel run makes the machine busy, so before investigating a failure, rerun the failing files in one process with the command the runner prints (`-gconfig= -gtest=<files>`). The runner also fails a run when a test script runs no tests: GUT skips a script that does not parse with only a warning, and the one-process command still exits 0.

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
| `scripts/` | GDScript source: resource definitions (`resource_definitions/`), utilities (`utils/`), editor/CLI tools (`tools/`), the Tribulation's judge (`tribulation/`), and the zone action presenter base (`ui/`) |
| `singletons/` | 17 manager singletons (global game state). They are autoloads along with Dialogic, 18 in total |
| `scenes/` | Godot `.tscn` scene files + attached scripts |
| `resources/` | `.tres` data files (abilities, adventures and encounters, enemies, cycling, items, path tree, quests, the Tribulation, unlocks, zones and their loot tables) |
| `assets/` | Art (sprites, Aseprite sources, the lacquer kit in `ui/lacquer/` for the zone view, the adventure's map and frame and the Tribulation board), shaders, themes, styleboxes, fonts, dialogue data. No audio yet |
| `addons/` | Godot plugins (Dialogic, AsepriteWizard, ResourcePlus, hexagon_tilemaplayer, script-ide, godot_context_exporter, gut) |
| `tests/` | GUT tests: `unit/`, `integration/`, `label_tests/`, and `run_tests.ps1`, which runs the suite in parallel Godot processes |
| `docs/` | Game and system documentation. Start at `docs/README.md` |

### Singleton Managers (`singletons/`)
These are autoloaded in `project.godot` and provide global state:

| Manager | Purpose |
|---------|---------|
| `PersistenceManager` | Save/load system with `SaveGameData` resource (auto-saved every 5 s by `SaveTimer`) |
| `ResourceManager` | Madra and Gold, plus adventure Madra capacity/threshold. `add_madra()` never lowers a pool that sits above the cap. Core Density lives in `CultivationManager` |
| `CultivationManager` | Core Density XP and levels (capped per stage by `max_core_density_level`; XP at the cap is lost), advancement stage, path-point milestones (paid once per stage). `lose_core_density_levels()` and `advance_to_next_stage()` are the Tribulation's failure and pass |
| `InventoryManager` | Equipment (paged grid), gear and accessories, materials, consumables and the 4-slot hotbar, quest items |
| `ZoneManager` | Selected zone and per-zone progression (completions, training ticks, last idle action); the map's zones and their map states, the dev demo and hidden-zone toggles, seen actions (NEW) |
| `UnlockManager` | Feature unlock gates (condition catalog, latched unlocks) |
| `EventManager` | Persistent one-shot narrative event flags (not a general event bus) |
| `QuestManager` | Multi-step quests: active/completed quests, step advancement |
| `DialogueManager` | Dialogic integration |
| `PlayerManager` | Holds the persistent player `VitalsManager` (HP/Madra/Stamina) |
| `LogManager` | Player-facing in-game log, shown in `LogWindow`. Diagnostics use the `Log` utility |
| `ActionManager` | Lifecycle of the single current zone action (cycling, foraging, adventure, dialogue, training, merchant, Tribulation). No queue. Refuses an adventure the Madra can't fund and a Tribulation the core isn't ready for before anything stops. Resolves and resumes the zone's idle action after every session action and on arrival in a zone |
| `CharacterManager` | Player attributes (base + equipment bonuses) |
| `CyclingManager` | Cycling technique state (unlocked list, equipped technique, catalog lookups, seen techniques for the NEW seal), the running cycle's snapshot, which the cabinet and the Now tray read, and the last cycle's result, which the chest shows under the Now tray |
| `PathManager` | Path progression tree, point balance, perk aggregation. Most numeric perks are not yet read by any system |
| `AbilityManager` | Ability unlock/equip state (unlocked pool, 4-slot loadout, catalog) |
| `MerchantManager` | Merchant purchases: stock limits, gold and equipment-space checks, per-merchant ledgers in `SaveGameData.merchant_ledgers` |
| `Dialogic` | Dialogue/narrative system (addon autoload) |

### Data-Driven Design
- Resource classes in `scripts/resource_definitions/` define data structures (e.g., `AbilityData`, `ZoneData`, `EquipmentDefinitionData`, `EffectData`, `AdventureResultData`)
- Godot `.tres` files in `resources/` instantiate and configure these resources
- When modifying data structures, update both the `.gd` resource class and any `.tres` files that reference it

### Equipment System
- Single `EquipmentDefinitionData` class (no subclasses) with `attribute_bonuses: Dictionary` (AttributeType → float)
- 5 equipment slot types: `MAIN_HAND`, `OFF_HAND`, `HEAD`, `ARMOR`, `ACCESSORY`. Accessories live in a separate `equipped_accessories` dict keyed by physical slot index (0 or 1) on `InventoryData`, so any accessory item fits either of the two physical accessory slots.
- `CharacterManager._get_attribute_bonuses()` → `_get_equipment_bonuses()` sums bonuses from both `equipped_gear` and `equipped_accessories`
- Bonuses flow through `get_total_attributes_data()` into combat and downstream systems. Caveat: the player's max HP/Madra/Stamina only refresh on `base_attribute_changed`, so equipping gear doesn't update them until a base attribute changes (see `docs/infrastructure/CHARACTER.md`)
- Equipment grid: 2 unlocked pages of 36 slots (`InventoryData.SLOTS_PER_PAGE`), a category filter, and a trash slot that holds one item (see `docs/inventory/INVENTORY.md`)
- Right-click to quick equip/unequip; the description box shows the dragged item during a drag

### View Architecture
`MainView` (class) implements the state stack. Its 10 state nodes live under a script-less `MainViewStateMachine` child node:
- `ZoneViewState` — Exploration/map view (initial base state)
- `AdventureViewState` — Combat exploration (base state)
- `CyclingViewState` — Cycling board overlay with no backdrop: the board sits in the map gap and `MainView.set_cycling_mode()` turns the zone view's chest, dock and map over to it
- `InventoryViewState` — Inventory overlay (Equipment, Consumables, Materials, Journal tabs)
- `AdventureEndCardState` — Modal overlay pushed on top of `AdventureViewState` when an adventure ends
- `PathTreeViewState` — Path progression skill tree overlay
- `AbilitiesViewState` — Ability management with loadout and drag-drop equipping
- `CharacterViewState` — Character attributes overlay
- `MerchantViewState` — Merchant shop overlay (`MerchantView`), opened and closed by `ActionManager.start_merchant` / `stop_merchant`
- `TribulationViewState` — Tribulation board overlay (`TribulationView`) with no backdrop, opened and closed by `ActionManager.start_tribulation` / `stop_tribulation`: the board sits in the map gap, and `MainView.set_board_mode()` turns the dock and the map off

Menu overlays are switched via input actions (`open_inventory`, `open_abilities`, `open_character`, `open_path`), which only the current state handles. Cycling, adventure, the merchant, the Tribulation, and the end card are driven by signals instead: the state scripts connect to `ActionManager`/`AdventureView` themselves. The state machine supports `change_state` for base views and `push_state`/`pop_state` for modal overlays (e.g., end card on top of adventure view).

The `Dock` (`scenes/ui/dock/`, at the bottom centre of `ZoneView`) holds the four nav buttons, which fire the same input actions via `Input.parse_input_event()` (a press, then its release). It also decides their notifications: the Path count seal while path points are unspent, the Abilities ring while an unlocked ability is unequipped. `SystemMenuButton` (`scenes/ui/dock/system_menu_button/`) uses a `MenuType` enum that auto-configures label, shortcut, icon, and input action from a single dropdown, and exposes `set_notification()`.

The `GoalsPanel` (`scenes/ui/goals_panel/`: the first active quest's step and the Breakthrough milestone) and the `LogWindow` are `MainView` HUD boards shared by the zone and adventure views. `ZoneViewState` places them (Goals under the cultivator cabinet, the log at the bottom left) and `AdventureViewState` leaves them where they are, because the adventure's own cabinet, chest and dock stand where the zone view's stand. The merchant shop and the Tribulation hide them through `MainView.hide_hud_boards()` / `release_hud_boards()`; the menu books leave them showing under their backdrop, and cycling leaves them showing beside its board. The zone view itself (cultivator cabinet, zone chest, map) is described in `docs/zones/ZONES.md`. See `docs/infrastructure/MAIN_VIEW.md`.

`MainView` holds the zone view's cabinet, chest, dock and map SubViewport (`%CultivatorPlate`, `%ZonePanel`, `%Dock`, `%SubViewport` in `main_game.tscn`). Cycling and the Tribulation are the overlays that do not show `GreyBackground`, and both block the full log. `CyclingViewState` calls `MainView.set_cycling_mode(true)` (the chest lists the techniques, and `set_board_mode(true)` hides the dock and takes the map's input), and `MainView._ready()` hands the cabinet to the `CyclingView` so its Madra and XP pellets fly into the orbs. `TribulationViewState` calls `set_board_mode(true)` after it hides the log and the Goals board. The `TribulationView`'s root covers the screen and stops every click, judges its own mouse presses, and gets the keys from the state's `handle_input()` (`docs/cultivation/breakthrough-tribulation.md`).

`AdventureView` is built in the same frame (`scenes/adventure/adventure_view/adventure_view.tscn`): `VitalsPlate` (top left), `AdventureChest` (top right: the `RunClock`, and the `ExpeditionPage` with the Here tray, the tile's choice drawers and the Run ledger) and `TechniqueDock` (bottom centre) sit over the map and the fight and hold the pointer, so a press on a board never reaches the hexes. `AdventureView` feeds them from `AdventureTilemap`'s signals (`tile_entered`, `encounter_resolved`, `map_changed`, `walk_refused`) and binds the dock and the cabinet's buff sockets to the player's combatant for each fight. The coin layer (`AdventureMapMarkers`) takes `map_changed`, `encounter_resolved` and `boss_revealed` (which shakes the boss coin) from the tilemap itself; it is a `Node2D` at z 50 in the map's own canvas, so the character (z 100) draws over the coins. The wheel zooms the map from 1 to 2 over the map only, never over a board or during a fight. See `docs/adventuring/ADVENTURING.md`.

### Reusable UI Components (`scenes/common/` and shared scenes)
Shared components used across multiple views:
- `ItemDisplaySlot` — Read-only item icon with hover tooltip, used in end card loot and anywhere items need display
- `ItemDescriptionPanel` — Item detail panel (icon, name, type, description, effects), shared between inventory sidebar and end card tooltips
- Lacquer pieces (`scenes/common/lacquer/`) for the zone view's and the adventure view's "Lacquer and brass" look: `LacquerStripRect` (shows one frame of an orb, bead or ring strip), `LacquerRod` (stepped 2 + 2k progress rod with an end cap), `LacquerFrameOverlay` (brass or hover 9-slice frame over its parent, flashed outright), `LacquerFloater` (`scenes/common/lacquer/lacquer_floater/`, a gain rising on a lacquer token in 2 px steps). `LacquerRail` (`scenes/zones/zone_panel/lacquer_rail/`) is the brass scroll rail bound to a `ScrollContainer`, and `LacquerText` (`scripts/utils/lacquer_text.gd`) formats rates and sets decimal points in Yatra One. They go with the lacquer theme, `assets/themes/lacquer/lacquer_theme.tres` (`LabelLacquer*` and `RichTextLacquer*` variants, kit textures in `assets/ui/lacquer/`, styleboxes in `assets/styleboxes/lacquer/` such as `wrap_pad.tres`, the 1 px pad of a wrapped Label); see `docs/UI_STYLING.md`
- Adventure boards (`scenes/adventure/`, `scenes/ui/combat/`) — `VitalsPlate` (Health and Madra orbs, Stamina rod, three buff sockets; `BuffTooltip` beside it), `AdventureChest` (frame that hugs its visible `AdventureChestPage`, the `RunClock`, and the `ExpeditionPage` with its `ChoiceDrawer`s), and the technique dock (`TechniqueDock`, `TechniqueSlot` with the `lacquer_cooldown_sweep` shader, `CastTray`, `TechniqueTooltip`). Both tooltips sit on `board9.tres`. Their text wraps and the boards grow with it (the trays and the drawer faces are 9-slices; the cast tray grows upward). The pure rules are statics the tests call (`ExpeditionPage.here_line()`, `TechniqueSlot.sweep_step()`, `RunClock.format_time()`)
- `AdventureMapMarkers` (`scenes/adventure/adventure_map_markers/`) — A `Node2D` at z 50 in the map's own canvas, kept in screen space (it cancels the camera's transform on itself each frame, so its `EncounterCoin`s keep their size at any zoom) and drawn under the character. The coins mark the adventure map's tiles (glyph, carved "?", carved cleared, boss), the counterpart of the zone map's `MapMarkers`. The coin is the only scene the adventure instances from code, because its count depends on the generated map
- `AdventureRoute` (`scenes/adventure/adventure_route/`) — Lit route dots laid hex to hex through `ZoneRoute.dot_positions()` for a hovered or committed walk; the dots behind the character hide one at a time
- `Atmosphere` (`scenes/atmosphere/`) — Vignette shader + drifting mist sprites + floating mote particles; now instanced only by the adventure's fight (`AdventureCombat._setup_atmosphere()`), until the fight is reworked. The lacquer zone view and the adventure map do not use it
- `EncounterIcon` (`scenes/adventure/encounter_icon/`) — Per-type glyph renderer (combat, elite, boss, rest, treasure, trap, unknown) with a completed state and animated boss and rest-site glyphs; no longer on the map (the coins replaced it), but the editor map preview (`scripts/tools/map_preview.gd`) still uses it
- `DropTargetSlot` (`scenes/common/drop_target_slot.gd`) — Shared drag-and-drop target base with drop highlight
- Inventory chrome (`scenes/inventory/common/`) — `InventoryScrollHost` base plus `InventoryGrid`, `InventoryList`, `GridToolbar`, `SortSubBanner`, `TabBanner`, `ScrollRail`, `ItemDetailCard`, shared by the inventory tabs
- `GreyBackground` (`scenes/ui/grey_background/`) — Modal backdrop for the menu books, the merchant and the end card (cycling and the Tribulation use none); `show_with_panel()`/`hide_with_panel()` orchestrate overlay fades
- `TechniqueDrawer` (`scenes/cycling/technique_drawer/`) and `TechniqueList` (`scenes/zones/zone_panel/technique_list/`) — The zone chest's drawers for the learned cycling techniques while cycling (`ZonePanel.set_techniques_mode()`)

### Game Systems
1. **Cycling** — A lacquer board in the zone view's map gap: click the Madra Ball and keep the cursor in it as it travels a carved path on a body figure (Madra), and press the ball as it passes a cycling zone for PERFECT / GOOD / OK hits (Core Density XP). The cultivator cabinet is the readout, and the zone chest's drawers swap techniques
2. **Zones & idle actions** — Map-first lacquer zone view (zoom-2 hex map with fog, cultivator cabinet, zone chest with a Now strip and grouped activity cards, dock); foraging and training (Aura Well) idle actions, which resume after every session action, NPC dialogue, merchant shop (gold for gear and Crude Scales; look themed per zone)
3. **Adventuring** — Procedurally generated hex maps drawn like the zone map, opening at zoom 1 and zoomable to 2 with the wheel (fog tiers, veiled revealed tiles, rims, route dots, lacquer encounter coins) with a committed-destination walk, framed by a vitals cabinet, a chest (run clock, Here tray, choice drawers, Run ledger) and a technique dock; real-time combat; scroll end card with stats/loot
4. **Combat** — Real-time; abilities cost Health/Madra/Stamina (no AP pool) and have cooldowns, cast times, buffs, and interrupts; simple enemy AI
5. **Inventory** — Book-style UI: paged equipment grid, gear slots, consumables hotbar, materials, quest journal
6. **Path Progression** — Pure Madra skill tree; Path Points unlock abilities and cycling techniques
7. **Quests** — Multi-step quests driven by events and unlock conditions (Celestial Intervener questline)
8. **Tribulation** — The Foundation → Copper breakthrough: a Spirit Valley action that opens when Core Density first reaches 100 and runs the Breath of the Core, a 38 s breathing trial on a lacquer board in the map gap. Press (Space or a click) as the bright sphere shrinks across the brass ring, and hold through the last breath. `TribulationRun` judges, `TribulationView` draws it and applies the result. A pass moves the player to Copper; 4 cracks fail it and cost 5 levels
9. **Scripting** — Calligraphy/character tracing (planned)
10. **Elixir Making** — Multi-stage crafting (planned)
11. **Soulsmithing** — Tetris-like assembly puzzle (planned)

### Progression
- Madra: currency generated from Cycling (and Aura Well training)
- Core Density: an integer level capped per stage (`max_core_density_level`, 100 in Foundation and Copper). XP at the cap is lost, and a save past the cap loads at it
- Breakthrough: the Tribulation (`docs/cultivation/breakthrough-tribulation.md`). The first time Core Density reaches 100 its card appears in Spirit Valley. A pass calls `CultivationManager.advance_to_next_stage()`; a failure takes 5 levels (`lose_core_density_levels()`)
- Cultivation stages unlock new systems: planned. Foundation and a thin Copper exist, Copper unlocks nothing yet, and Foundation's systems are gated by quests and unlock conditions instead

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

**Worktrees in Godot's project list:** the SessionStart hook in `.claude/settings.json` runs `.claude/hooks/godot_project_list.ps1 sync`. It lists every live worktree in Godot's project manager through a junction in `C:\worktrees\EndlessPath-godot\` named after a one-liner of its feature, which Godot shows on the path line under the "EndlessPath" title. It drops worktrees that are gone or merged into main, and never touches the main checkout's entry. New entries are named after their branch: once you know what your session is building, rename yours to a one-liner of the feature, and again if the work changes direction:
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
- No counts of tests, scripts, scenes, resources, shaders or lines, no test run results or times, no `Last updated:` lines, no "Used by" lists.
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

UI text uses a **Label theme variant type-scale** defined in `assets/themes/pixel_theme.tres`; the zone view's panels, the adventure view's boards and the HUD boards use the lacquer theme (`assets/themes/lacquer/lacquer_theme.tres`, `LabelLacquer*` variants) on their roots instead. Before adding inline `theme_override_font_sizes` or `theme_override_colors` to a Label, read **`docs/UI_STYLING.md`** — it lists every available variant, the rule of thumb for when to use a variant vs a direct override, and copy-paste `.tscn` patterns.

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
Custom shaders (10) live in `assets/shaders/`. Notable shaders include: `liquid_wave` (a liquid orb fill; no scene uses it since the adventure's combat orbs went), `vignette` (screen-edge darkening for atmosphere), `lacquer_cooldown_sweep` (a technique icon's radial cooldown), `palette_swap` (per-menu menu book colours), `hit_flash` (combat hit feedback), and `path_connection_energy`, `path_node_border`, `path_node_keystone` (path tree). In the lacquer views, only the orbs and the cooldown sweep use shaders (`lacquer_madra_orb`, `lacquer_core_orb`, `lacquer_cooldown_sweep`: pixel-grid, kit-palette, stepped-time fills over the strip art). `lacquer_madra_orb` takes `light`, `pale` and `blue` colour uniforms that default to Madra, so the adventure's Health orb sets the crimson ramp on its own material; the sweep has one `progress` uniform in 24 whole steps. Every other fill there is a frame of a texture strip. The cycling board uses none: its groove is drawn per art pixel by `CyclingGroove`, and the ball, rings and zones are strip frames.

### Styling / Themes
UI themes are defined in `assets/themes/` as Godot `.tres` theme resources. Custom styleboxes in `assets/styleboxes/`. Use existing theme tokens — do not introduce external UI frameworks. See `docs/UI_STYLING.md` for the Label variant type-scale and usage rules.

### Dialogue
Dialogic addon handles narrative/dialogue. Timeline and character data in `assets/dialogue/`.

### Hex Grid
Both zone and adventure maps use the `hexagon_tilemaplayer` addon for hex-based tile rendering. The zone map (camera zoom 1–2, default 2) draws only the map zones (`ZoneManager.get_map_zones()`, so hidden zones such as Test Zone stay off it) with per-zone forest variants via `ZoneData.tile_variant_index`. Every other cell is fog on a second layer (`scenes/tilemaps/fog_tileset.tres`) in three tiers by hex distance to the nearest charted zone. Hex states are rim swaps, never glows: `ZoneHexMarker` draws the current zone's brass rim and an open zone's hairline (brighter on hover), and `LockedZoneOverlay` the veiled tile of a locked or uncharted zone (a thin inner rim on hover, a heavy one when its popover is pinned). Dotted `ZoneRoute`s join neighbouring zones and turn cream toward a hovered zone you can travel to. `MapMarkers`, a screen-space CanvasLayer, draws the plates, the lock and "?" glyphs, the action ring, floaters and the map popover. The adventure map draws like the zone map, at zoom 1 to 2 (`AdventureTilemap`: a `CameraZoomController` on the wheel, each run opens at 1, and the camera's offset follows the zoom to keep the current hex at screen (960, 470)): fog on the same layer and tiers around the tiles the player sees (`ZoneMapMath.fog_tier()`, out to the map's reach plus 8 cells), visited tiles from a 23-variant forest atlas (`hex_forest_atlas.png`) with deterministic-random per-tile selection, revealed tiles from its veil twin (`hex_forest_veil_atlas_ai.png`, tileset source 9), a heavier brass current rim (4 px of brass where the zone map's has 2) and a hover rim, route dots (`AdventureRoute`) and the character at 2x on even px. `AdventureMapMarkers`, a `Node2D` at z 50 under the character, draws a lacquer coin on every tile that holds something to show.

### Logging
There are two channels:
- **`Log`** (`scripts/utils/log.gd`): leveled diagnostics (INFO/DEBUG/WARN/ERROR/CRITICAL) to the console and a daily `user://logs-*.log` file.
- **`LogManager`**: the player-facing log. It emits `message_logged` signals for in-game display in `LogWindow`; call `LogManager.log_message(bbcode)`. It has no levels; callers format their own BBCode strings. It keeps the last `HISTORY_LIMIT` (200) messages (`get_history()`), which the five-line log board and the full log (L) read.

See `docs/infrastructure/LOGGING.md`.

### Aseprite MCP
`.mcp.json` registers the `aseprite` MCP server ([diivi/aseprite-mcp](https://github.com/diivi/aseprite-mcp)): 123 tools that draw, animate, inspect and export sprites by running the Steam copy of Aseprite in batch mode, so Aseprite doesn't need to be open. Pass it absolute paths: relative ones resolve against whatever directory Claude Code started the server in. Everything it writes is AI-made art, so the AI-Generated Art rules apply (`_ai` suffix, never save over the user's files).

The server lives outside the repo, cloned to `C:\Users\lione\source\repos\aseprite-mcp`; `.mcp.json` runs that clone's `.venv` Python directly, with `PYTHONPATH` pointing at the clone. The Claude desktop app is an MSIX package and redirects new `AppData` folders into its private storage, which breaks uv's default Python install, so uv keeps Python 3.13 and its cache in `C:\Users\lione\.uv` instead. To update or reinstall, from the clone:
```bash
git pull && UV_PYTHON_INSTALL_DIR='C:\Users\lione\.uv\python' UV_CACHE_DIR='C:\Users\lione\.uv\cache' uv sync --frozen
```

### Key Input Bindings
- `open_inventory` / `close_inventory` — I / I or Escape
- `open_abilities` — A; `open_character` — C; `open_path` — P (Escape, i.e. `ui_cancel`, also closes these overlays). Menu shortcuts only work from the zone view
- `toggle_log` — L: opens or closes the full log (handled by `LogWindow`, in the zone and adventure views; Escape also closes it). An open menu book, the cycling board or the Tribulation board closes the full log and blocks L
- `close_cycling_view` — Escape
- `tribulation_press` — Space or left click, the Tribulation's one input. Keys reach `TribulationView` through `TribulationViewState.handle_input()`, and its root judges mouse presses in `_gui_input()`. On the intro Space begins the run and so does a click on the board, but not a click beside it. Escape (`ui_cancel`) turns the trial down from the intro and does nothing once the run has begun
- `ability_slot_1`–`ability_slot_4` — Q / W / E / R (combat; read by `TechniqueDock` while it is bound to a fight)
- Dev panel — Ctrl+Shift+D, hard-coded in `MainGame._input`, open to anyone (see `docs/tooling/DEV_TOOLS.md`)
- `center_zone_map_camera` — Space (bound, but nothing handles it); `open_path_tree` — P (unused duplicate of `open_path`)
- `dialogic_default_action` — Enter, Click, Space, X, Gamepad A

### Reference Documents
- **Documentation index**: `docs/README.md` (every system doc, design record, and tool guide)
- **Current status and roadmap**: `docs/STATE_OF_THE_GAME.md` (one page); `docs/GAMEPLAY_STATE.md` (content inventory); `docs/CODEBASE_STATE.md` (architecture)
- **Game Design Document**: `Endless Path Game Design Document [v0.1].txt` in project root (detailed mechanics, progression, visual style, MVP goals)
