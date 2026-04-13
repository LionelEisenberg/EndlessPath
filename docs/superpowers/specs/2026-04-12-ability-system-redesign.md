# Ability System Redesign

Enhance AbilityData with Madra type and source tracking, create an AbilityManager singleton for unlock/equip state, wire PathManager ability unlocks, and build a dedicated AbilitiesView for managing equipped abilities.

## 1. AbilityData Enhancements

Add two new enums and properties to the existing `AbilityData` class (`scripts/resource_definitions/abilities/ability_data.gd`):

```gdscript
enum MadraType { NONE, PURE }
enum AbilitySource { INNATE, PATH }

@export_group("Classification")
@export var madra_type: MadraType = MadraType.NONE
@export var ability_source: AbilitySource = AbilitySource.INNATE
```

- `MadraType` is a separate axis from `CombatEffectData.DamageType`. DamageType controls damage formula (defense calculations). MadraType describes the ability's identity/flavor — displayed in UI, available for future type-matchup mechanics.
- `AbilitySource` tracks lifecycle: INNATE abilities persist forever, PATH abilities are tied to path tree purchases and reset with path changes.
- `MadraType.NONE` for physical/non-Madra abilities (Basic Strike, Enforce). `MadraType.PURE` for Pure Madra abilities (Empty Palm, Power Font).

Update `_to_string()` to include MadraType and AbilitySource.

### Existing ability .tres updates

| Ability | madra_type | ability_source | Notes |
|---------|-----------|---------------|-------|
| basic_strike | NONE | INNATE | Always available, included in default save |
| empty_palm | PURE | PATH | Unlocked via path tree node |
| enforce | NONE | INNATE | Always available, included in default save |
| power_font | PURE | PATH | Unlocked via path tree node |

`ability_source` reflects the intended unlock source. INNATE abilities (basic_strike, enforce) are included in the default `unlocked_ability_ids` in SaveGameData. PATH abilities must be unlocked via path tree purchases. Existing path nodes will need UNLOCK_ABILITY effects added for empty_palm and power_font (or new nodes created).

## 2. AbilityManager Singleton

New singleton at `singletons/ability_manager/ability_manager.gd`. Follows the CyclingManager pattern exactly.

### Catalog

New resource class `AbilityListData` (`scripts/resource_definitions/abilities/ability_list_data.gd`):

```gdscript
class_name AbilityListData
extends Resource

@export var abilities: Array[AbilityData] = []
```

One catalog `.tres` file (`resources/abilities/ability_list.tres`) listing all abilities. AbilityManager preloads it and builds `_abilities_by_id: Dictionary` at `_ready()` for O(1) lookups.

### State

Stored in `SaveGameData`:

```gdscript
@export var unlocked_ability_ids: Array[String] = ["basic_strike", "enforce"]
@export var equipped_ability_ids: Array[String] = ["basic_strike", "enforce"]
```

Default: player starts with Basic Strike and Enforce unlocked and equipped (both INNATE abilities). PATH-sourced abilities (empty_palm, power_font) are unlocked via path tree purchases.

### Signals

```gdscript
signal ability_unlocked(ability: AbilityData)
signal equipped_abilities_changed()
```

### Public API

```gdscript
func get_unlocked_abilities() -> Array[AbilityData]
func get_equipped_abilities() -> Array[AbilityData]
func unlock_ability(ability_id: String) -> void        # Idempotent
func equip_ability(ability_id: String) -> bool          # Fails if not unlocked or slots full
func unequip_ability(ability_id: String) -> void
func is_ability_unlocked(ability_id: String) -> bool
func is_ability_equipped(ability_id: String) -> bool
func get_max_slots() -> int                             # Returns 4 (constant for now)
```

### Slot enforcement

`equip_ability()` checks `equipped_ability_ids.size() < get_max_slots()` before allowing. Returns `false` if full. Validates ability is unlocked before equipping.

### Save/load

Holds `_live_save_data: SaveGameData` reference from `PersistenceManager.save_game_data`. Listens to `PersistenceManager.save_data_reset` to refresh reference. Changes to the arrays on `_live_save_data` are persisted automatically by PersistenceManager.

## 3. PathManager Integration

### Ability unlock wiring

In `PathManager._apply_effect()`, the `UNLOCK_ABILITY` case currently appends to `_cached_effects.unlocked_abilities`. Add a direct call to AbilityManager:

```gdscript
PathNodeEffectData.EffectType.UNLOCK_ABILITY:
    if not _cached_effects.unlocked_abilities.has(effect.string_value):
        _cached_effects.unlocked_abilities.append(effect.string_value)
    if AbilityManager:
        AbilityManager.unlock_ability(effect.string_value)
```

Same pattern as `UNLOCK_CYCLING_TECHNIQUE` → `CyclingManager.unlock_technique()`.

### string_value format change

Change `UNLOCK_ABILITY` string_value from resource paths (`"res://resources/abilities/empty_palm.tres"`) to ability IDs (`"empty_palm"`). Consistent with how `UNLOCK_CYCLING_TECHNIQUE` uses technique IDs. The AbilityManager catalog handles ID → resource mapping.

Update the Pure Madra path `.tres` file (`resources/path_progression/pure_madra/pure_madra_tree.tres`) — the "madra_strike" node's UNLOCK_ABILITY effect string_value should be an ability ID.

### PathEffectsSummary

`PathEffectsSummary.unlocked_abilities` stays as-is for effect aggregation. AbilityManager becomes the authoritative source of unlock state.

## 4. Combat Integration

### Replace CharacterManager.get_equipped_abilities()

In `adventure_combat.gd` line 107:

```gdscript
# Before:
player_data.abilities = CharacterManager.get_equipped_abilities()

# After:
player_data.abilities = AbilityManager.get_equipped_abilities()
```

Delete `CharacterManager.get_equipped_abilities()` — it was a hardcoded placeholder returning 4 fixed abilities.

## 5. SaveGameData Changes

Add new section between Cycling Manager and Path Progression:

```gdscript
#-----------------------------------------------------------------------------
# ABILITY MANAGER
#-----------------------------------------------------------------------------

@export var unlocked_ability_ids: Array[String] = ["basic_strike", "enforce"]
@export var equipped_ability_ids: Array[String] = ["basic_strike", "enforce"]
```

In `reset()`:

```gdscript
# Ability Manager
unlocked_ability_ids = ["basic_strike", "enforce"]
equipped_ability_ids = ["basic_strike", "enforce"]
```

Add both fields to `_to_string()`.

## 6. AbilitiesView UI

### Layout: Equipped Sidebar + Expandable Cards + Filter Bar

Based on the approved mockup (Option D with filter bar):

**Structure:**
- Full-screen overlay panel (like PathTreeView) with grey background
- Header: "ABILITIES" title + subtitle
- Left sidebar (100px): Vertical equipped loadout — 4 slots showing equipped ability icons. Clicking a slot scrolls to that ability in the list.
- Main area: Filter/sort bar at top, scrollable card list below

**Filter bar:**
- Filter toggles (mutually exclusive pills): All / Offensive / Buff / Equipped. Active filter is gold-filled, rest are outlined. Default: All.
  - "Offensive" = abilities with `target_type != SELF` (deals damage/affects enemies)
  - "Buff" = abilities with `target_type == SELF` (self-targeting buffs/enhancements)
  - "Equipped" = only abilities currently in equipped slots
- Sort dropdown: "Equipped First" (default), "Name A-Z", "Madra Cost", "Cooldown". Equipped First groups equipped abilities at top, then alphabetical within groups.

**Ability cards:**
- Collapsed: Icon (40x40), ability name, Madra type badge (if not NONE), cost summary, cooldown, source badge (Innate/Path), equipped dot (green)
- Expanded (click to toggle, one at a time): Shows description, full stat breakdown (type, target, cast time, Madra type), and equip/unequip button
- Selected card: gold border + highlight background

**Equip/unequip interaction:**
- Expand a card → click EQUIP button → ability added to equipped list (if slots available)
- Expand an equipped card → click UNEQUIP button → ability removed from equipped list
- Button text: "EQUIP" (gold) when not equipped, "UNEQUIP" (red) when equipped
- If slots full and clicking EQUIP: button disabled with "SLOTS FULL" text

### Styling

Use the existing pixel art theme (`.tres` theme resources in `assets/themes/`) and its theme type variations rather than setting theme overrides on individual nodes. This keeps the AbilitiesView visually consistent with other views and avoids per-node style duplication. Only add theme overrides when no existing variation covers the need.

### View state

New `AbilitiesViewState` (`scenes/abilities/abilities_view_state.gd`), following `PathTreeViewState` pattern:

```gdscript
class_name AbilitiesViewState
extends MainViewState

func enter() -> void:
    scene_root.grey_background.visible = true
    scene_root.abilities_view.visible = true

func exit() -> void:
    scene_root.abilities_view.visible = false
    scene_root.grey_background.visible = false

func handle_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_abilities"):
        scene_root.pop_state()
```

### MainView changes

Add to `main_view.gd`:
- `@onready var abilities_view: Control = %AbilitiesView`
- `@onready var abilities_view_state: MainViewState = %MainViewStateMachine/AbilitiesViewState`
- `abilities_view_state.scene_root = self` in `_ready()`

### ZoneViewState changes

Add to `zone_view_state.gd` `handle_input()`:

```gdscript
elif event.is_action_pressed("open_abilities"):
    scene_root.push_state(scene_root.abilities_view_state)
```

### Scene structure

New scene `scenes/abilities/abilities_view.tscn`:

```
AbilitiesView (PanelContainer)
├── VBoxContainer
│   ├── Header (HBoxContainer)
│   │   ├── TitleBlock (VBoxContainer) — "ABILITIES" + subtitle
│   │   └── SlotCounter (Label) — "3 / 4"
│   └── Body (HBoxContainer)
│       ├── LoadoutSidebar (VBoxContainer, 100px fixed)
│       │   ├── LoadoutLabel — "LOADOUT"
│       │   ├── EquipSlot x4 (TextureRect + Label)
│       │   └── SlotCountLabel
│       ├── BodyDivider (VSeparator)
│       └── MainContent (VBoxContainer, flex)
│           ├── FilterBar (HBoxContainer)
│           │   ├── FilterToggles (HBoxContainer) — All/Offensive/Buff/Equipped
│           │   └── SortDropdown (OptionButton)
│           └── ScrollContainer
│               └── CardList (VBoxContainer)
│                   └── AbilityCard x N (instantiated per ability)
```

New reusable component `scenes/abilities/ability_card/ability_card.tscn`:

```
AbilityCard (PanelContainer)
├── VBoxContainer
│   ├── CollapsedRow (HBoxContainer) — icon, name, badges, equipped dot
│   └── ExpandedDetails (VBoxContainer, initially hidden)
│       ├── Description (Label)
│       ├── StatsRow (HBoxContainer)
│       └── EquipButton (Button)
```

## 7. Autoload & Input Registration

### project.godot changes

- Add `AbilityManager` autoload (after CyclingManager)
- Add `open_abilities` input action mapped to key `A`

## 8. Testing

### test_ability_manager.gd

| Test | Validates |
|------|-----------|
| test_unlock_ability | Adds to unlocked list, emits signal |
| test_unlock_idempotent | Duplicate unlock is no-op |
| test_unlock_unknown_id | Logs error, does not crash |
| test_equip_ability | Adds to equipped list, emits signal |
| test_equip_requires_unlock | Cannot equip locked ability |
| test_equip_slot_limit | Cannot exceed 4 equipped abilities |
| test_unequip_ability | Removes from equipped list |
| test_unequip_not_equipped | No-op, no crash |
| test_get_equipped_abilities | Returns AbilityData array from equipped IDs |
| test_get_unlocked_abilities | Returns AbilityData array from unlocked IDs |
| test_save_data_reset | Refreshes internal reference on reset |

### Existing test updates

- `test_path_manager.gd`: Update `test_ability_unlock_tracked` to verify AbilityManager.unlock_ability() is called (if AbilityManager autoload is available in test context)

## Files Summary

### Modified

| File | Change |
|------|--------|
| `scripts/resource_definitions/abilities/ability_data.gd` | Add MadraType, AbilitySource enums + properties |
| `singletons/persistence_manager/save_game_data.gd` | Add ability manager section |
| `singletons/character_manager/character_manager.gd` | Delete get_equipped_abilities() |
| `singletons/path_manager/path_manager.gd` | Wire UNLOCK_ABILITY to AbilityManager |
| `scenes/combat/adventure_combat/adventure_combat.gd` | Use AbilityManager.get_equipped_abilities() |
| `scenes/ui/main_view/main_view.gd` | Add abilities_view + abilities_view_state refs |
| `scenes/ui/main_view/states/zone_view_state.gd` | Handle open_abilities input |
| `resources/abilities/basic_strike.tres` | Add madra_type, ability_source |
| `resources/abilities/empty_palm.tres` | Add madra_type, ability_source |
| `resources/abilities/enforce.tres` | Add madra_type, ability_source |
| `resources/abilities/power_font.tres` | Add madra_type, ability_source |
| `resources/path_progression/pure_madra/pure_madra_tree.tres` | Change UNLOCK_ABILITY string_value to ability IDs |
| `project.godot` | Add AbilityManager autoload, open_abilities input action |
| `scenes/main/main_game/main_game.tscn` | Add AbilitiesView + AbilitiesViewState nodes |

### Created

| File | Purpose |
|------|---------|
| `scripts/resource_definitions/abilities/ability_list_data.gd` | Catalog resource class |
| `resources/abilities/ability_list.tres` | Catalog instance listing all abilities |
| `singletons/ability_manager/ability_manager.gd` | AbilityManager singleton |
| `scenes/abilities/abilities_view.gd` | AbilitiesView scene script |
| `scenes/abilities/abilities_view.tscn` | AbilitiesView scene |
| `scenes/abilities/abilities_view_state.gd` | View state for MainView state machine |
| `scenes/abilities/ability_card/ability_card.gd` | Expandable ability card component |
| `scenes/abilities/ability_card/ability_card.tscn` | Ability card scene |
| `tests/unit/test_ability_manager.gd` | AbilityManager unit tests |
