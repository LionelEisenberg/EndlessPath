# Codebase State

Last updated: 2026-04-21

This document covers the architecture of the EndlessPath codebase and serves as an index to per-system documentation. Bugs, missing functionality, and tech debt are tracked in each system's own doc.

---

## Architecture Summary

The codebase follows a signal-driven, data-forward architecture with clean separation between game logic (singleton managers), UI (views + state machine), and content (Resource `.tres` files).

### Entry Point

`scenes/main/main_game/main_game.tscn` is the entry scene. Its structure:

```
MainGame (Node2D)
├── MainView (Control)
│   ├── MainViewStateMachine (Node)
│   │   ├── ZoneViewState
│   │   ├── AdventureViewState
│   │   ├── InventoryViewState
│   │   ├── CyclingViewState
│   │   ├── PathTreeViewState
│   │   └── AbilitiesViewState
│   ├── ZoneView (Control)          — default view, always present
│   │   ├── ZoneTransition          — animated zone-change overlay (PR #16)
│   │   ├── SubViewportContainer
│   │   │   └── SubViewport
│   │   │       ├── ZoneViewBackground  — decorative background (PR #14)
│   │   │       └── ZoneTilemap
│   │   ├── ZoneInfoPanel
│   │   ├── ZoneResourcePanel
│   │   ├── ZoneHeader              — zone name/info header, extracted from ZoneInfoPanel (PR #14)
│   │   └── Toolbar                 — persistent action toolbar, moved from ZoneView script to MainView scene (PR #14)
│   ├── AdventureView (Control)     — hidden, shown by state
│   ├── LogWindow
│   ├── GreyBackground (Panel)      — modal overlay
│   ├── InventoryView (Control)     — hidden, shown by state
│   ├── CyclingView (Control)       — hidden, shown by state
│   ├── PathTreeView (Control)     — hidden, shown by state (PR #20)
│   └── AbilitiesView (Control)    — hidden, shown by state (PR #22)
└── SaveTimer (Timer)               — auto-save
```

### View State Machine

`MainView` manages screen transitions via a stack-based state machine:

- **Base state** (`base_current_state`) — the primary view (Zone, Adventure)
- **State stack** (`state_stack`) — modal overlays pushed on top (Cycling, Inventory)
- **Three operations:**
  - `change_state(new_state)` — clears stack, exits old base, enters new base
  - `push_state(state)` — pushes onto stack, calls `enter()`
  - `pop_state()` — pops top, calls `exit()`
- **Current state** = top of stack if non-empty, otherwise base state
- **Transitions are signal-driven** — ActionManager emits `start_cycling`, `start_adventure`, etc. and MainView responds by changing/pushing states

Each state is a `MainViewState` node that controls visibility of its corresponding view and handles input routing.

### Singleton Managers

17 autoload singletons manage global state, loaded in dependency order via `project.godot`:

1. PersistenceManager → 2. CultivationManager → 3. EventManager → 4. CharacterManager → 5. UnlockManager → 6. ResourceManager → 7. ZoneManager → 8. ActionManager → 9. InventoryManager → 10. Dialogic → 11. DialogueManager → 12. PlayerManager → 13. LogManager → 14. CyclingManager → 15. AbilityManager → 16. PathManager → 17. QuestManager

**Communication pattern:** Singletons communicate via signals and shared state. All game-state managers hold a **live reference** to `PersistenceManager.save_game_data` (a shared `SaveGameData` Resource). Writes by one manager are immediately visible to all others. When state changes, managers emit signals that UI scenes listen to.

```
PersistenceManager (root — owns SaveGameData)
  ↑ live_save_data reference held by:
  ├── ResourceManager (madra, gold)
  ├── CultivationManager (core density, stage)
  ├── CharacterManager (attributes)
  ├── InventoryManager (inventory)
  ├── UnlockManager (unlock progression)
  ├── EventManager (event progression)
  ├── ZoneManager (zone state, progression)
  ├── PathManager (path tree state, purchases, point balance)
  ├── AbilityManager (unlocked abilities, equipped loadout)
  ├── CyclingManager (unlocked techniques, equipped technique)
  └── QuestManager (active and completed quests, step progression)

ActionManager (orchestrator)
  → emits: start_cycling, stop_cycling, start_adventure, stop_adventure, start_foraging, etc.
  ← MainView listens to these for state transitions
  ← ZoneTilemap listens for foraging events
```

### Data-Driven Design (Resource Pattern)

Content is defined via Godot's Resource system in three layers:

1. **GDScript class defines the schema** (`scripts/resource_definitions/`)
   ```gdscript
   class_name ItemDefinitionData
   extends Resource
   @export var item_id: String = ""
   @export var item_name: String = ""
   @export var icon: Texture2D
   ```

2. **`.tres` files instantiate with authored content** (`resources/`)
   ```
   script = ExtResource("item_definition_data.gd")
   item_id = "SpiritFern"
   item_name = "Spirit Fern"
   ```

3. **Managers load via preload** (`singletons/`)
   ```gdscript
   @export var _all_zone_data: ZoneDataList = preload("res://resources/zones/zone_data_list.tres")
   ```

**List containers** aggregate resources — e.g., `ZoneDataList` holds `Array[ZoneData]` with lookup methods like `get_zone_data_by_id()`. This allows loading an entire domain from a single preloaded resource.

### Scene Composition

- **Unique names** (`%NodeName`) decouple scripts from scene hierarchy — preferred over `$Path/To/Node`
- **Subscenes** package complex UI (e.g., `adventure_view.tscn` instanced into `main_game.tscn`)
- **Scripts attach** via `[ext_resource]` references in `.tscn` files

### Key Shared Components

| Component | Path | Purpose |
|-----------|------|---------|
| `ThemeConstants` | `scripts/utils/theme_constants.gd` | Centralized color palette and styling constants (PR #11) |
| `FlyingParticle` | `scenes/ui/flying_particle/flying_particle.gd` | Reusable particle effect — spawned for Madra tracking feedback and zone clicks (PR #13, reused PR #16) |
| `SystemMenuButton` | `scenes/zones/zone_resource_panel/system_menu/system_menu_button.gd` | Nav button component — single `MenuType` enum drives label, shortcut, icon, and input action (PR #10, PATH added PR #20) |
| `Atmosphere` | `scenes/atmosphere/atmosphere.gd` | Vignette shader + drifting mist + floating motes; instanced in zone and adventure views with per-scene @export tuning (PR #23) |
| `HexHoverSelector` | `scenes/tilemaps/hex_hover_selector.gd` | Animated spritesheet ring for hex tile hover; shared between zone and adventure tilemaps (PR #23) |
| `EncounterIcon` | `scenes/adventure/encounter_icon/encounter_icon.gd` | Per-type glyph renderer with visited/completed/boss-animated states; reused in both flat tile icons and floating AdventureMarker (PR #23) |
| `PathPreview` | `scenes/adventure/path_preview/path_preview.gd` | Tiled-texture Line2D route line with gradient-based fade behind the player during committed travel (PR #23) |

---

## Cross-Cutting Concerns

Issues that span multiple systems and don't belong to any single doc:

| Concern | Details | Priority |
|---------|---------|----------|
| ~~Double signal connections in view states~~ | ~~state transitions can fire twice~~ | ~~HIGH~~ *(Fixed in PR #3)* |
| ~~`ChangeVitalsEffectData` uses `mana_change`~~ | ~~Should be `madra_change`~~ | ~~LOW~~ *(Fixed in PR #6)* |
| ~~Forage timer not re-added to scene after stop~~ | ~~Timer node replaced but not added as child~~ | ~~MEDIUM~~ *(Fixed in PR #6)* |

---

## System Documentation Index

### Game Systems

| System | Doc | Summary |
|--------|-----|---------|
| Cycling | [docs/cycling/CYCLING.md](cycling/CYCLING.md) | Mouse-tracking mini-game, Madra generation, Core Density XP |
| Combat | [docs/combat/COMBAT.md](combat/COMBAT.md) | Real-time ability combat within adventures |
| Abilities | [docs/abilities/ABILITIES.md](abilities/ABILITIES.md) + [docs/abilities/ABILITIES_MATRIX.md](abilities/ABILITIES_MATRIX.md) | Ability data model, unlock/equip lifecycle, per-path stats matrix (PR #38) |
| Adventuring | [docs/adventuring/ADVENTURING.md](adventuring/ADVENTURING.md) | Procedural hex map exploration with encounters |
| Inventory | [docs/inventory/INVENTORY.md](inventory/INVENTORY.md) | Equipment grid, gear slots, materials, quest items, loot |
| Zones | [docs/zones/ZONES.md](zones/ZONES.md) | Home base hex map, action routing, unlock chains |
| Cultivation | [docs/cultivation/CULTIVATION.md](cultivation/CULTIVATION.md) | Core Density leveling, Advancement Stages, breakthrough |
| Path Progression | [docs/progression/PATH_PROGRESSION.md](progression/PATH_PROGRESSION.md) | Skill tree, path points, perk unlocks (PathManager) |

### Infrastructure

| System | Doc | Summary |
|--------|-----|---------|
| Resources | [docs/infrastructure/RESOURCES.md](infrastructure/RESOURCES.md) | Madra + Gold tracking (ResourceManager) |
| Unlocks | [docs/infrastructure/UNLOCKS.md](infrastructure/UNLOCKS.md) | Condition-based content gating (UnlockManager) |
| Events | [docs/infrastructure/EVENTS.md](infrastructure/EVENTS.md) | One-shot narrative event flags (EventManager) |
| Character | [docs/infrastructure/CHARACTER.md](infrastructure/CHARACTER.md) | Attributes, abilities, player state (CharacterManager + PlayerManager) |
| Persistence | [docs/infrastructure/PERSISTENCE.md](infrastructure/PERSISTENCE.md) | Save/load, SaveGameData schema (PersistenceManager) |
| Quests | *(undocumented)* | Multi-step quest progression driven by events + unlock conditions (QuestManager, PR #25/#26). Spec at `docs/superpowers/specs/2026-04-16-quest-system-design.md` |

### Design Documents

| Doc | System | Summary |
|-----|--------|---------|
| [breakthrough-tribulation.md](cultivation/breakthrough-tribulation.md) | Cultivation | Tribulation mini-game design for stage advancement |
| [docs/cycling/CYCLING_UI_REDESIGN.md](cycling/CYCLING_UI_REDESIGN.md) | Cycling | Cycling view UI redesign spec |
| [docs/cycling/CYCLING_UI_IMPLEMENTATION_PLAN.md](cycling/CYCLING_UI_IMPLEMENTATION_PLAN.md) | Cycling | Cycling UI implementation plan |
| [docs/inventory/EQUIPMENT_DESIGN.md](inventory/EQUIPMENT_DESIGN.md) | Inventory | Equipment system design spec |
| [docs/inventory/EQUIPMENT_IMPLEMENTATION_PLAN.md](inventory/EQUIPMENT_IMPLEMENTATION_PLAN.md) | Inventory | Equipment system implementation plan |
| [docs/infrastructure/MADRA_UNIFICATION_DESIGN.md](infrastructure/MADRA_UNIFICATION_DESIGN.md) | Infrastructure | Madra pool unification design spec |
| [docs/infrastructure/MADRA_UNIFICATION_PLAN.md](infrastructure/MADRA_UNIFICATION_PLAN.md) | Infrastructure | Madra pool unification implementation plan |

### Planned Systems (no code)

| System | Doc | Unlocks At |
|--------|-----|------------|
| Scripting | [docs/planned/SCRIPTING.md](planned/SCRIPTING.md) | Copper |
| Elixir Making | [docs/planned/ELIXIR_MAKING.md](planned/ELIXIR_MAKING.md) | Copper |
| Soulsmithing | [docs/planned/SOULSMITHING.md](planned/SOULSMITHING.md) | Iron |

### Top-Level

| Doc | Purpose |
|-----|---------|
| [GAMEPLAY_STATE.md](GAMEPLAY_STATE.md) | Current player experience, content inventory, progression blockers |
