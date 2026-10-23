# Codebase State

Last updated: 2026-10-23 (the lacquer cycling view on `feat/cycling-view-styleguide-ea3170`, not merged)

This document covers the architecture of the EndlessPath codebase and the technical concerns that span several systems. The other entry points are:
- [README.md](README.md): index of every doc.
- [STATE_OF_THE_GAME.md](STATE_OF_THE_GAME.md): one-page status and roadmap.
- [GAMEPLAY_STATE.md](GAMEPLAY_STATE.md): the player's view and content inventory.

Bugs, missing functionality and tech debt for a single system live in that system's doc, under **Work Remaining**.

---

## At a Glance

| | |
|---|---|
| Engine | Godot 4.7, GDScript, GL Compatibility renderer (`config/features` also lists "Forward Plus") |
| Code | ~26.9k lines of game GDScript and ~20.3k lines of tests; 139 scenes; 102 authored `.tres` resources; 15 shaders (all counted on the cycling view branch on 2026-10-23) |
| Autoloads | 18: 17 manager singletons in `singletons/`, plus Dialogic |
| Tests | GUT 9.7.1. 118 scripts and 1583 tests, all passing on 2026-10-23 with Godot 4.7.2. See [TESTING.md](testing/TESTING.md) |
| History | 709 commits and 43 merged PRs, from 2025-10-26 to 2026-06-01 |
| In flight | Unmerged branch `feat/infallible-chaum-58f8ad`: in-combat consumables, 20 commits, no PR. Unmerged branch `feat/cycling-view-styleguide-ea3170`: the lacquer cycling view, built 2026-10-22 and 23 |

---

## Architecture Summary

The codebase is signal-driven and data-forward. Its three layers are kept separate:
- **Game logic:** singleton managers.
- **UI:** views, switched by a state machine.
- **Content:** `Resource` `.tres` files.

### Entry Point

`scenes/main/main_game/main_game.tscn` is the only runtime scene. Abridged:

```
MainGame (Node2D)                 main_game.gd: Ctrl+Shift+D dev hotkey, log print level
├── MainView (Control)            main_view.gd: state stack + input routing
│   ├── MainViewStateMachine      9 state nodes (no script)
│   ├── ZoneView                  base view: ZoneTransition, SubViewport (ZoneTilemap: map, fog, MapMarkers),
│   │                             CultivatorPlate, ZonePanel (zone chest), Dock
│   ├── AdventureView             adventure map + combat
│   ├── LogWindow, GoalsPanel     HUD boards (z 1), placed by the base state, hidden under the shop
│   ├── QuestToast                z 10
│   ├── GreyBackground            modal backdrop (z 2)
│   ├── PathTreeView, AdventureEndCard, InventoryView, AbilitiesView, CharacterView, CyclingView (z 3)
│   └── DevPasswordModal, DevPanel                                                            (z 10)
└── SaveTimer                     5 s auto-save → PersistenceManager.save_data()
```

The full tree, HUD placement and z-order are in [MAIN_VIEW.md](infrastructure/MAIN_VIEW.md).

### View State Machine

`MainView` keeps a **base state** (`ZoneViewState` or `AdventureViewState`) and a **stack of overlay states**:
- **Overlays:** `InventoryViewState`, `CyclingViewState`, `PathTreeViewState`, `AbilitiesViewState`, `CharacterViewState`, `MerchantViewState`, `AdventureEndCardState`. The merchant hides the HUD boards while open (`MainView.hide_hud_boards()`); the menu books and the end card leave them under the backdrop. Cycling has no backdrop: its board sits in the map gap, and `MainView.set_cycling_mode()` turns the zone view's chest, dock and map over to it.
- **Operations:** `change_state()` swaps the base and clears the stack, `push_state()` opens an overlay, and `pop_state()` closes it.
- **Input:** only the current state receives it, through `_unhandled_input` → `handle_input()`.

Menu overlays open from keyboard actions (I/A/C/P) or the zone view's `Dock`, whose `SystemMenuButton`s fire the same actions via `Input.parse_input_event()`. L opens the full log in either base view (not under a menu book or while cycling). Cycling, the merchant shop, adventure and the end card are driven by signals: the **state scripts** connect to `ActionManager` and `AdventureView` themselves, and `MainView` connects to nothing. Details and the keybinding table: [MAIN_VIEW.md](infrastructure/MAIN_VIEW.md).

### Singleton Managers

The 18 autoloads, in `project.godot` load order:

| # | Autoload | Owns | Doc |
|---|---|---|---|
| 1 | `PersistenceManager` | Loads/saves `SaveGameData` (`user://save.tres`); `save_data_reset` signal | [PERSISTENCE](infrastructure/PERSISTENCE.md) |
| 2 | `CultivationManager` | Core Density XP and level, advancement stage, path-point milestones | [CULTIVATION](cultivation/CULTIVATION.md) |
| 3 | `EventManager` | Persistent one-shot event flags (not a general event bus) | [EVENTS](infrastructure/EVENTS.md) |
| 4 | `CharacterManager` | Base attributes; totals including equipment bonuses | [CHARACTER](infrastructure/CHARACTER.md) |
| 5 | `UnlockManager` | Unlock-condition catalog and latched unlocks | [UNLOCKS](infrastructure/UNLOCKS.md) |
| 6 | `ResourceManager` | Madra and Gold; adventure Madra capacity and threshold | [RESOURCES](infrastructure/RESOURCES.md) |
| 7 | `ZoneManager` | Selected zone, per-zone progression (completions, training ticks, last idle action), map zones and map states, seen actions | [ZONES](zones/ZONES.md) |
| 8 | `ActionManager` | The single current zone action and its lifecycle signals (no queue); resolves and resumes the zone's idle action | [ZONES](zones/ZONES.md) |
| 9 | `InventoryManager` | Equipment (paged), gear, materials, consumables and hotbar, quest items | [INVENTORY](inventory/INVENTORY.md) |
| 10 | `Dialogic` | Dialogue addon (2.0-Alpha-19) | [DIALOGUE](infrastructure/DIALOGUE.md) |
| 11 | `DialogueManager` | Dialogic wrapper; `dialogue_ended` | [DIALOGUE](infrastructure/DIALOGUE.md) |
| 12 | `PlayerManager` | The persistent player `VitalsManager` (HP/Madra/Stamina) | [CHARACTER](infrastructure/CHARACTER.md) |
| 13 | `LogManager` | Player-facing in-game log (`message_logged`, a 200-line history) | [LOGGING](infrastructure/LOGGING.md) |
| 14 | `CyclingManager` | Unlocked/equipped cycling techniques, technique catalog, seen techniques (the NEW seal), snapshot of the running cycle (read by the cabinet and the Now tray), the last cycle's result (read by the chest) | [CYCLING](cycling/CYCLING.md) |
| 15 | `AbilityManager` | Unlocked abilities, 4-slot loadout, ability catalog | [ABILITIES](abilities/ABILITIES.md) |
| 16 | `PathManager` | Path tree, point balance, purchases, perk aggregation (`PathEffectsSummary`) | [PATH_PROGRESSION](progression/PATH_PROGRESSION.md) |
| 17 | `QuestManager` | Active/completed quests and step advancement | [QUESTS](progression/QUESTS.md) |
| 18 | `MerchantManager` | Merchant purchases: stock limits, gold and equipment-space checks, per-merchant ledgers | [FOUNDATION_PLAYTHROUGH](progression/FOUNDATION_PLAYTHROUGH.md#beat-4-merchant-shop-implemented) |

**Shared save state:** every game-state manager holds a **live reference** to `PersistenceManager.save_game_data`, a single `SaveGameData` resource. A write by one manager is immediately visible to the others. On reset, `PersistenceManager.save_data_reset` tells each manager to re-bind and refresh. Field ownership is listed in [PERSISTENCE.md](infrastructure/PERSISTENCE.md).

**Signals out:** when state changes, managers emit signals (`madra_changed`, `inventory_changed`, `condition_unlocked`, `quest_step_advanced`, …), and UI scenes and other managers react. Two signals carry most of the progression: `UnlockManager.condition_unlocked` gates zones, actions and quest steps, and `EventManager.event_triggered` records narrative moments. Authoring rules are in [QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md](progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md).

**Effects:** rewards and side effects are data. `EffectData` subclasses (award item, loot, resource, attribute or path point; change vitals; start quest; trigger event) hang off zone actions, encounter choices, quests and consumables ([EFFECTS.md](infrastructure/EFFECTS.md)).

### Data-Driven Design (Resource Pattern)

Content is defined in three layers.

1. **A GDScript class defines the schema** (`scripts/resource_definitions/`):
   ```gdscript
   class_name MaterialDefinitionData
   extends ItemDefinitionData
   @export var source_zone_ids: Array[String] = []
   ```

2. **`.tres` files instantiate it with authored content** (`resources/`), e.g. `resources/items/materials/spirit_fern.tres`:
   ```
   script = ExtResource("..._material_definition_data.gd")
   item_id = "SpiritFern"
   item_name = "Spirit Fern"
   source_zone_ids = Array[String](["SpiritValley"])
   ```

3. **Managers preload a list resource** that holds a whole domain:
   ```gdscript
   @export var _all_zone_data: ZoneDataList = preload("res://resources/zones/zone_data_list.tres")
   ```

Catalog lists are hand-maintained: `ability_list.tres`, `cycling_technique_list.tres`, `path_tree_list.tres`, `quest_list.tres`, `unlock_condition_list.tres` and `zone_data_list.tres`. **A new resource only takes effect once it is added to its list.** For example, an unlock condition missing from `unlock_condition_list.tres` can never latch. Equipment `.tres` files are generated from the tables in [ITEMS.md](inventory/ITEMS.md) by `scripts/tools/items_md_to_resources.gd`.

### Scene Composition

- **Unique names** (`%NodeName`) decouple scripts from the scene hierarchy. Use them instead of `$Path/To/Node`.
- **Subscenes** package complex UI, e.g. `adventure_view.tscn` is instanced into `main_game.tscn`.
- **No UI nodes in code:** UI structure lives in `.tscn` files, and scripts only set data.
- **Label styling:** text uses the Label theme-variant type scale in `pixel_theme.tres`; the zone view's panels and the HUD boards use `lacquer_theme.tres` and its `LabelLacquer*` variants ([UI_STYLING.md](UI_STYLING.md)).

### Key Shared Components

| Component | Path | Purpose |
|-----------|------|---------|
| `Log` | `scripts/utils/log.gd` | Leveled diagnostic logging to console and file. `LogManager` is the player-facing log ([LOGGING.md](infrastructure/LOGGING.md)) |
| `ThemeConstants` | `scripts/utils/theme_constants.gd` | Colour constants for code-side styling |
| `GreyBackground` | `scenes/ui/grey_background/` | Modal backdrop with `show_with_panel()` / `hide_with_panel()` fade orchestration |
| `SystemMenuButton` | `scenes/ui/dock/system_menu_button/system_menu_button.gd` | Dock nav button. Its `MenuType` enum drives label, shortcut, icon and input action; `set_notification()` shows the ring and count seal |
| Lacquer pieces | `scenes/common/lacquer/`, `scenes/zones/zone_panel/lacquer_rail/`, `scripts/utils/lacquer_text.gd` | `LacquerStripRect` (strip frames), `LacquerRod` (stepped rod), `LacquerFrameOverlay` (brass or hover frame, flashed), `LacquerFloater` (a gain rising on a token), `LacquerRail` (scroll rail) and `LacquerText`, for the zone view and the HUD boards ([UI_STYLING.md](UI_STYLING.md)) |
| `MadraPellet` | `scenes/zones/zone_transition/` | Opaque pellet that flies along a curve in 2 px steps. The adventure drain's pellets and the cycling view's Madra and XP pellets (`set_texture()` for the tier colours) |
| `FloatingText` | `scenes/ui/floating_text/` | Rising, fading label. Used by the combat resource bars and orbs |
| `Atmosphere` | `scenes/atmosphere/` | Vignette shader, drifting mist and floating motes. Used in the adventure view, tuned per scene with `@export` |
| `HexHoverSelector` | `scenes/tilemaps/hex_hover_selector.gd` | Animated ring that snaps to the hovered hex. Used by the adventure tilemap; the zone map swaps hex rims instead |
| `EncounterIcon` | `scenes/adventure/encounter_icon/` | Glyph for each encounter type (animated boss and rest glyphs). Used by tile icons and the floating `AdventureMarker` |
| `PathPreview` | `scenes/adventure/path_preview/` | Tiled-texture `Line2D` route, with a gradient fade behind the player during committed travel |
| `ItemDisplaySlot` / `ItemDescriptionPanel` | `scenes/common/` | Read-only item icon with tooltip, and the item detail panel |
| `DropTargetSlot` | `scenes/common/drop_target_slot.gd` | Shared drag-and-drop target base, with drop highlight |
| `InventoryScrollHost` and inventory chrome | `scenes/inventory/common/` | `InventoryGrid`, `InventoryList`, `GridToolbar`, `SortSubBanner`, `TabBanner`, `ScrollRail` and `ItemDetailCard`, shared by the inventory tabs ([INVENTORY.md](inventory/INVENTORY.md)) |

---

## Cross-Cutting Concerns

These issues span several systems, so no single system doc owns them. The detailed items are in the linked docs.

| Concern | Details | Priority |
|---|---|---|
| **Modifiers nobody reads** | `PathManager` aggregates 7 numeric perk types into `PathEffectsSummary`, but no production code reads it. Other values are exported and never read: cycling action modifiers and foraging `madra_cost_per_second`. Player max vitals ignore equipment changes until a base attribute changes. See [PATH_PROGRESSION](progression/PATH_PROGRESSION.md), [CYCLING](cycling/CYCLING.md), [ZONES](zones/ZONES.md), [CHARACTER](infrastructure/CHARACTER.md) | HIGH |
| **Missing stage data hangs the game** | `CultivationManager.add_core_density_xp()` loops forever if the current stage has no `AdvancementStageResource`, because `get_xp_for_next_level()` returns 0. `ResourceManager.add_madra()` likewise clamps Madra to 0. Guard both before adding any stage past Foundation. See [CULTIVATION](cultivation/CULTIVATION.md) | HIGH (blocks Copper) |
| **Save robustness** | Saves have no version field, and two schema changes have already broken old saves. The only migration is `SaveGameData.migrate()`, which moves listed zone ids (Test Zone → Spirit Valley) before `verify()`. A failed `verify()` (e.g. a renamed zone id) or an unreadable file silently replaces the whole save. Nothing saves on quit, and wiping a save requires editing `reset_save_data` in the script. See [PERSISTENCE](infrastructure/PERSISTENCE.md) | HIGH (before any public build) |
| **Mirror tests** | About 114 tests in 5 files re-implement the logic they check instead of calling it: `test_resource_manager`, `test_cultivation_manager`, `test_character_manager`, `test_adventure_flow`, `test_adventure_combat_count`. ResourceManager, CultivationManager and CharacterManager are effectively untested. See [TESTING](testing/TESTING.md) | HIGH |
| **Untyped ids** | Event ids, condition ids and unlock targets are strings, and no test checks that every gate's condition is registered, that every quest step's event has a producer, or that every path unlock id resolves. See [UNLOCKS](infrastructure/UNLOCKS.md), [EVENTS](infrastructure/EVENTS.md) | MEDIUM |
| **Modal backdrop** | Found by code reading: after Path, Abilities or Character closes, `GreyBackground.self_modulate.a` stays 0. Later Inventory and end-card overlays then show an invisible but click-blocking backdrop. See [MAIN_VIEW](infrastructure/MAIN_VIEW.md) | MEDIUM |
| **Tooling gotchas** | The first headless `--import` in a fresh checkout rewrote `project.godot`'s `[dialogic]` directory registry to `{}`, so revert it before committing. Editor, exported builds and GUT runs share one `user://` dir (save file, logs, dev password file). Green test runs print SCRIPT ERRORs and 24 Dialogic orphans. See [TESTING](testing/TESTING.md), [DEV_TOOLS](tooling/DEV_TOOLS.md) | MEDIUM |
| **Shipping gaps** | No `export_presets.cfg`, no CI, and no audio assets or audio code | MEDIUM |

---

## Documentation

Every system doc, design record and tool guide is indexed in [docs/README.md](README.md). Historical specs and plans, with their shipped status, are indexed in [superpowers/README.md](superpowers/README.md).
