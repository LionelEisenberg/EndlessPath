# Developer Tools
Last updated: 2026-10-22

## Overview

| Tool | Where | How to use | Purpose |
|------|-------|------------|---------|
| Dev Panel | `scenes/ui/dev_panel/` (in `main_game.tscn`) | Ctrl+Shift+D in game | Change Madra/Gold, CD XP, path points and unlocks; force combat wins; end adventures as a victory or defeat; reveal adventure maps; show the demo and hidden zones on the zone map |
| Map Preview | `scenes/tools/map_preview.tscn` + `scripts/tools/map_preview.gd` | Open in the editor and press **Generate** in the Inspector | Preview procedural adventure maps without running the game |
| UID generator | `scripts/tools/generate_uid.gd` | Headless `-s` script | Print fresh `uid://` strings for hand-written `.tscn`/`.tres` |
| Items generator | `scripts/tools/items_md_to_resources.gd`, `items_md_parser.gd` | Headless `-s` script | Generate equipment `.tres` files from `docs/inventory/ITEMS.md`. Documented in [ITEMS.md](../inventory/ITEMS.md). |
| Label testing scene | `tests/label_tests/label_testing_scene.tscn` | Open and run the scene (F6) | Visual comparison of Label theme variants. See [UI_STYLING.md](../UI_STYLING.md#label-testing-scene). |
| GUT test runner | `addons/gut/` | CLI or the GUT editor panel | Unit and integration tests. See [TESTING.md](../testing/TESTING.md). |
| Debug switches | Various exports | Edit in the Inspector or in code | See [Other debug switches](#other-debug-switches) |

## Dev Panel

A floating panel shipped in the game binary, open to anyone who presses the hotkey (no password; exported builds included). It calls existing singleton APIs, so its changes go through the same signals as gameplay and are written to `user://save.tres` by the 5 s autosave (`SaveTimer` in `main_game.tscn`). Reloading does not undo them.

### Opening it

```
Ctrl+Shift+D (MainGame._input)
  └─ panel visible → hide panel
  └─ panel hidden  → DevPanel.open()
```

Until 2026-10-23 the hotkey did nothing unless `user://dev_password.txt` existed, and then asked for its contents in a `DevPasswordModal`. Both are gone; an old `dev_password.txt` is now ignored.

### Scene structure

```
DevPanel (PanelContainer, min width 340, mouse Stop)   dev_panel.gd (class DevPanel)
└── VBoxContainer
    ├── TitleBar (PanelContainer: drag handle) → TitleLabel "Dev Panel", CloseButton "×"
    ├── "RESOURCES"   → MadraRow (MadraSpin, MadraApply), GoldRow (GoldSpin, GoldApply)
    ├── "CULTIVATION" → XpRow (XpSpin, XpApply), PointsRow (PointsSpin, PointsApply)
    ├── "UNLOCKS"     → ConditionRow (ConditionOption, ConditionApply "Trigger"), UnlockCyclingButton
    ├── "COMBAT"      → ForceWinButton
    ├── "ADVENTURE"   → ShowWholeMapCheck (CheckButton), ExitAdventureRow (ExitVictoryButton, ExitDefeatButton)
    └── "ZONES"       → DemoZonesCheck, HiddenZonesCheck (CheckButtons)
```

Both scenes are children of `MainView` at z 10. `main_game.tscn` places the panel at (0, 0). Dragging the title bar moves it, and the position survives close/re-open within a session. The × button hides the panel.

### Controls

Every action writes a `[DEV]` line (magenta tag) to the in-game log through `LogManager.log_message()`.

| Section | Control | Calls | Effect on game state |
|---------|---------|-------|----------------------|
| Resources | Madra (`MadraSpin`, 0 to 1,000,000, `allow_greater`) + Apply | `ResourceManager.set_madra(v)` | Sets Madra to `max(0, v)` and emits `madra_changed`. Not clamped to max Madra, so it can exceed orb capacity. Unlock conditions re-evaluate. |
| Resources | Gold (`GoldSpin`, 0 to 1,000,000, `allow_greater`) + Apply | `ResourceManager.set_gold(v)` | Sets gold to `max(0, v)` and emits `gold_changed`, which updates the cultivator cabinet's gold row and re-evaluates unlocks. |
| Cultivation | Add CD XP (`XpSpin`, 0 to 1,000,000, `allow_greater`) + Apply | `CultivationManager.add_core_density_xp(v)` | Normal XP path: loops level-ups, emits `core_density_level_updated` per level, and awards path points every 10 levels (1 per milestone at Foundation). The loop has no cap at level 100. |
| Cultivation | Path Points (`PointsSpin`, 0 to 1000, integer) + Apply | `PathManager.add_points(int(v))` | Adds to the path point balance and emits `points_changed`. |
| Unlocks | Condition (`ConditionOption`) + Trigger | `UnlockManager.force_unlock_condition(id)` | Appends the id to `unlock_progression.unlocked_condition_ids` and emits `condition_unlocked(id)`. Idempotent. The dropdown is filled once in `_ready()` from `UnlockManager.unlock_condition_list.list`, skipping null or empty ids. |
| Unlocks | Unlock All Cycling Techniques | `CyclingManager.unlock_technique(id)` for every entry in `CyclingManager._technique_catalog.cycling_techniques` | Unlocks every catalog technique and emits `technique_unlocked` for newly unlocked ones. Idempotent. |
| Combat | Force-Win Current Combat | `AdventureView.force_win_combat()` | Only shown while `AdventureView.is_in_combat`; `_process()` polls it every frame while the panel is visible. Emits `AdventureCombat.trigger_combat_end(true, 0)`, which ends the fight as a win with 0 gold. |
| Adventure | Show Whole Map (toggle) | `AdventureView.set_show_whole_map(pressed)` → `AdventureTilemap.set_dev_reveal_all()` | Visual only: hides the fog rect, removes fog veils and shows every encounter icon. The visited/highlight dictionaries, stats and encounter resolution are unchanged. The flag stays on `AdventureTilemap` across adventures until toggled off. |
| Adventure | Exit: Victory / Defeat | `AdventureView.force_end_adventure(victory)` | Only shown while an adventure runs (`AdventureView.is_adventure_running()`, polled like Force-Win). Victory takes the boss-win path: `ActionManager.stop_action(true)` with `_pending_victory` set, so the adventure's success effects run, the zone completion counts and the victory end card shows. Defeat calls `stop_action(false)`: failure effects and a "You retreated from the adventure" end card. Works on the map or mid-fight. |
| Zones | Demo zones (locked, uncharted) (toggle) | `ZoneManager.set_demo_zones_visible(pressed)` | Adds the two demo zones in `resources/zones/dev/` to the zone map: a locked Advancement Zone north-east of Spirit Valley and an Uncharted hex due north of Spirit Valley, beyond it, with their plates, glyphs, popovers and routes. They are loaded outside `zone_data_list.tres`, never enter the save, and are gone on the next launch. Emits `map_zones_changed`. |
| Zones | Show hidden zones (Test Zone) (toggle) | `ZoneManager.set_hidden_zones_visible(pressed)` | Draws the zones marked `hidden_on_map` (Test Zone, west of Spirit Valley). Once it is unlocked you can travel there. Emits `map_zones_changed`. The flag is not saved and resets on the next launch; a save standing in Test Zone moves back to Spirit Valley on load (`SaveGameData.migrate()`). |

Caveats:

- **Force-Win skips victory side effects.** It bypasses `AdventureCombat._on_enemy_health_changed()`, so the gold reward and `EventManager.trigger_event("q_first_steps_enemy_defeated")` never run.
- **Exit: Victory skips the boss's own rewards.** The boss encounter's `success_effects` and the fight's gold never run, only the adventure action's. Exiting mid-fight first closes the fight as a loss (a "Combat Defeat..." log line; no encounter has failure effects today).
- **Forced conditions only satisfy some systems.** Zone and zone-action gates check `UnlockManager.are_unlock_conditions_met()`, so they accept forced ids. Quest steps (`QuestManager`), encounter choices and encounter eligibility call `UnlockConditionData.evaluate()` directly and ignore them. The underlying event is not triggered either.

## Map Preview

An editor-only `@tool` scene for checking procedural adventure layouts without launching the game. Design: [2026-04-23-map-preview-tool-design.md](../superpowers/specs/2026-04-23-map-preview-tool-design.md).

### How to run

1. Open `scenes/tools/map_preview.tscn` in the Godot editor.
2. Select the `MapPreview` root node. In the Inspector, set `adventure_data` (the scene defaults to `resources/adventure/data/shallow_woods.tres`) and `seed_value`.
3. Press **Generate**, or **Clear** to wipe the preview. Both are `@export_tool_button`s and need Godot 4.4 or later.

`_generate()` and `_clear()` return immediately outside the editor (`Engine.is_editor_hint()`), so the scene does nothing at runtime or from the CLI.

### What it does

| Step | Detail |
|------|--------|
| Validate | Runs `adventure_data.validate()`. Each error is `push_error`ed and generation aborts. A null `adventure_data` gives a warning. |
| Seed | `seed_value != 0` seeds the global RNG with that value. `0` mints a fresh `randi()` seed and shows it. |
| Generate | Calls `_preview_tile_map._on_tileset_changed()` so the addon's hex conversions work in the editor, then runs `AdventureMapGenerator` (`set_adventure_data()`, `set_tile_map()`, `generate_adventure_map()`). In the editor `AdventureEncounter.is_eligible()` always returns true, so the preview shows the full potential map, not the player-gated subset. |
| Render | Paints each tile with forest atlas source `8`, variant `HexForestAtlas.pick(coord)`. Each non-NoOp encounter whose type is not `NONE` gets an `EncounterIcon` (`configure_for_type()`) and an `encounter_id` label (`scenes/tools/encounter_id_label.tscn`). A yellow "START" marker sits at cube `(0, 0, 0)`. |
| Stats | `StatsLabel` (top-left `CanvasLayer`): `N tiles · combat · elite · boss · rest · treasure · trap · walk · seed`. "combat" counts `COMBAT_REGULAR` + `COMBAT_AMBUSH`; "walk" counts NoOp tiles. |

To keep a layout you like, copy the seed from the stats label into `seed_value`.

Icons and id labels are spawned without an owner, so they are not saved. Painted tiles and the stats text are saved. The committed scene holds a 28-tile Shallow Woods snapshot (8 combat, 4 elite, 1 boss, 2 rest, 13 walk, seed 1216432660), and reopening it shows those tiles without icons until you press Generate.

## UID Generator

`scripts/tools/generate_uid.gd` extends `SceneTree` and prints five fresh UIDs (`ResourceUID.id_to_text(ResourceUID.create_id())`), then quits. Use it when authoring `.tscn`/`.tres` files by hand.

```bash
"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s scripts/tools/generate_uid.gd
```

Output: five lines of the form `uid://...`.

## Items Generator

`scripts/tools/items_md_to_resources.gd` (with the parser `scripts/tools/items_md_parser.gd`, tested by `tests/unit/test_items_md_parser.gd`) turns the equipment tables in `docs/inventory/ITEMS.md` into `.tres` files. Usage and schema are documented in [ITEMS.md](../inventory/ITEMS.md).

## Other debug switches

| Switch | Location | Current value | Effect |
|--------|----------|---------------|--------|
| `reset_save_data` | `PersistenceManager` (`@export` on a script autoload, so edit it in code) | `false` | When `true`, resets and saves a fresh `SaveGameData` on every launch |
| `log_print_level` | `MainGame` (`main_game.gd` export, set in `main_game.tscn`) | `0` (`Log.Event.INFO`) | Lowest `Log` event printed to the console. Every event is also written to `user://logs-<YYYY-MM-DD>.log`, which is truncated on each launch. See [LOGGING.md](../infrastructure/LOGGING.md). |
| `is_debug_mode` | Player `CharacterBody2D` (`scenes/characters/main_character/character_body_2d.gd`) | `true` in `character_body_2d.tscn`; overridden to `false` in `zone_tilemap.tscn` and `adventure_tilemap.tscn` | When `true`, left-clicking anywhere walks the character to the cursor |
| `preview_message` | `QuestToast` | `""` | Plays the message once when the scene runs alone (F6); skips `QuestManager` wiring |

## Editor Plugins

| Addon | Version (`plugin.cfg`) | Enabled in `project.godot` | Use |
|-------|------------------------|----------------------------|-----|
| `AsepriteWizard` | 9.6.0 | Yes | Imports `.aseprite` sources |
| `ResourcePlus` | 0.1.0 | Yes | Resource editing helpers |
| `dialogic` | 2.0-Alpha-19 (Godot 4.4+) | Yes | Dialogue; also the `Dialogic` autoload. Carries two local patches, listed in `CLAUDE.md` |
| `godot_context_exporter` | 1.0 | Yes | Exports scripts and scene trees to a single text file |
| `gut` | 9.7.1 | Yes | Test framework ([TESTING.md](../testing/TESTING.md)) |
| `hexagon_tilemaplayer` | 2.5.2 | No | Its runtime classes (`HexagonTileMapLayer`) are used by both maps |
| `script-ide` | 2.0.2 | No (disabled in `39f1817`) | Script editor tabs and outline |

## Mockup Preview Servers

`.claude/launch.json` defines two static servers for design mockups:

| Name | Command | Serves |
|------|---------|--------|
| `zone-mockup` | `npx serve mockups -l 3456 --no-clipboard` | `mockups/`, which is gitignored and absent from a fresh checkout |
| `inventory-redesign` | `python -m http.server 3789 --directory docs/superpowers/mockups/inventory-redesign` | Inventory redesign mockup |

## Integration Points

| System | Connection |
|--------|------------|
| MainGame | Owns the Ctrl+Shift+D gate and `_dev_unlocked` |
| ResourceManager | `set_madra()`, `set_gold()` |
| CultivationManager | `add_core_density_xp()` |
| PathManager | `add_points()` |
| UnlockManager | `unlock_condition_list` (dropdown), `force_unlock_condition()` (dev-only wrapper) |
| CyclingManager | `_technique_catalog` (private read), `unlock_technique()` |
| AdventureView / AdventureTilemap | `is_in_combat`, `force_win_combat()`, `set_show_whole_map()` → `set_dev_reveal_all()` |
| LogManager | `[DEV]` audit lines |
| AdventureMapGenerator / HexForestAtlas / EncounterIcon | Reused by Map Preview |

## Key Files

| File | Purpose |
|------|---------|
| `scenes/main/main_game/main_game.gd` | Ctrl+Shift+D hotkey |
| `scenes/ui/dev_panel/dev_panel.gd` / `.tscn` | `DevPanel` controls and drag |
| `singletons/unlock_manager/unlock_manager.gd` | `force_unlock_condition()` |
| `scenes/adventure/adventure_view/adventure_view.gd` | `force_win_combat()`, `force_end_adventure()`, `set_show_whole_map()` |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` | `set_dev_reveal_all()`, `_dev_reveal_all` rendering paths |
| `scripts/tools/map_preview.gd`, `scenes/tools/map_preview.tscn`, `scenes/tools/encounter_id_label.tscn` | Map Preview |
| `scripts/tools/generate_uid.gd` | UID generator |
| `scripts/tools/items_md_to_resources.gd`, `scripts/tools/items_md_parser.gd` | Items generator |
| `tests/unit/test_unlock_manager.gd` | `force_unlock_condition()` tests (3) |

## Work Remaining

### Bugs

- `[MEDIUM]` Force-Win can't advance combat-gated quest steps. `AdventureView.force_win_combat()` emits `trigger_combat_end(true, 0)` directly instead of going through `AdventureCombat._on_enemy_health_changed()`. As a result `q_first_steps_enemy_defeated` never fires, so the Foundation Beat 2 step can't be advanced with Force-Win, and the fight awards no gold.

### Missing Functionality

- `[MEDIUM]` No tests cover the panel's actions or the hotkey gate. The spec's planned `test_dev_panel_actions.gd` integration test was never written; only `force_unlock_condition()` and the two Zones toggles are tested.
- `[LOW]` "Trigger" for a condition does not help with quest steps, encounter choices or encounter eligibility, which evaluate conditions themselves. It also does not trigger the backing event.
- `[LOW]` The spec's v2 list is not started: system unlocks, stage change, item grants, ability unlock/equip, technique equip, zone teleport, combat vitals controls, quest controls, save wipe/force-save/reload, path point respec.
- `[LOW]` Map Preview has none of the follow-ups the spec mentions: no batch statistics mode (NG3) and no overlays such as MST edges or distance labels (G5).

### UI

- `[LOW]` The spec's `HSeparator`s between panel sections are missing.
- `[LOW]` "Unlock All Cycling Techniques" logs the catalog size, not the number of newly unlocked techniques.

### Tech Debt

- `[LOW]` `DevPanel._get_adventure_view()` uses the absolute path `MainGame/MainView/AdventureView`, and `_on_unlock_all_cycling()` reads the private `CyclingManager._technique_catalog`.
- `[LOW]` `dev_panel.tscn` has a hand-written placeholder UID (`uid://dev_panel_001`). `main_game.tscn` references it by path only. `generate_uid.gd` can produce real ones.
- `[LOW]` Pressing Generate in Map Preview and then saving rewrites the committed snapshot in `scenes/tools/map_preview.tscn` (`tile_map_data` and stats text), which makes noisy diffs.
- `[LOW]` `generate_uid.gd` has no doc comment and a fixed count of 5.
- `[LOW]` The `zone-mockup` launch configuration serves `mockups/`, which is gitignored and not present in the repository.
