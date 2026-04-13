# Adventure End Card Design Spec

> **Status:** IMPLEMENTED (PR #19, merged 2026-04-11)

## Overview

When an adventure ends, a scroll-themed overlay shows the player why the adventure ended, how far they got, and what they earned — giving closure and actionable feedback before returning to the zone view.

## Visual Design

### Scroll Background

The end card uses the scroll asset kit from `assets/scroll/`:
- **Upper roll**: `parts/upper.png` — top of the scroll
- **Lower roll**: `parts/lower.png` — bottom of the scroll
- **Paper body**: `parts/paper.png` — tiling middle section, stretches vertically
- **Ribbon**: `parts/ribbon.png` — red accent on the upper roll
- **Flourish**: `parts/flourish.png` — decorative dividers between content sections

The scroll is centered on screen over a semi-transparent grey background overlay (matching the existing inventory overlay pattern).

### Layout

From top to bottom within the scroll paper area:

1. **Title row**: Victory icon (`victory_icon.png`) or skull icon (`skull_icon.png`) flanking "VICTORY" or "DEFEAT" text. Victory text is gold (#8b6914), defeat text is red (#8b2020). Title at 52px with drop shadow.
2. **Defeat reason** (defeat only): Small italic text below the title (DefeatReason theme variant). Hidden on victory, no layout shift. Values:
   - HP reached 0: "Your health reached zero"
   - Timer expired: "Time ran out"
   - Manual exit: "You retreated from the adventure"
3. **Flourish divider**: `flourish.png` separating title from stats
4. **Stats grid**: 3x2 GridContainer with icon + label + value per cell:
   - Row 1: Combat (fought/total on map) | Gold (earned total, dark gold)
   - Row 2: Time (elapsed, mm:ss) | Health (remaining/max, green alive, red dead)
   - Row 3: Tiles Explored (visited/total) | Madra Spent (budget amount, blue)
   - Stat names use golden StatName theme variant (22px), values use StatValue variant (26px)
5. **Flourish divider**: `flourish.png` separating stats from loot
6. **Loot section**: Underlined "LOOT" title above a loot tray panel (PanelLootTray theme variant, inset parchment style) containing `ItemDisplaySlot` instances with hover tooltips. Shows "No items found" in italic (Muted variant) when empty. Item slots at 40px.
7. **RETURN button**: ButtonEndCard theme variant with scroll-themed styleboxes (normal/hover/pressed). Triggers close animation and return to zone view.

### Stat Icons

All stat icons in `assets/ui_images/stat_icons/`:
- `combat_icon.png`, `health_icon.png`, `map_icon.png`, `time_icon.png`, `skull_icon.png`, `victory_icon.png`

Gold and Madra icons reused from `assets/ui_images/resources/`.

### Theme Variants

All styling uses Godot theme type variations (in `assets/themes/pixel_theme.tres`):
- **Labels**: Title (52px, drop shadow), DefeatReason, StatName (golden, 22px), StatValue (26px), Section, Muted
- **Button**: ButtonEndCard with scroll-themed styleboxes from `assets/styleboxes/buttons/scroll/`
- **Panel**: PanelLootTray from `assets/styleboxes/common/panel_loot_tray.tres`
- **HSeparator**: HSeparatorItemDesc, HSeparatorItemDescThin (#e9cead)
- **Label**: LabelDescItemName, LabelDescItemType (for ItemDescriptionPanel)

### Color Coding

| Stat | Color |
|------|-------|
| Victory title | Gold #8b6914 |
| Defeat title | Red #8b2020 |
| Gold earned | Dark gold #b8860b |
| Health (alive) | Green #228b22 |
| Health (dead) | Red #8b2020 |
| Madra spent | Blue #4a7ab5 |
| Stat name labels | Golden (via StatName theme variant) |

### Pixel Font Rendering

Fixed pixel font rendering across the project: disabled antialiasing, set full hinting in `m5x7.ttf.import`. This ensures crisp pixel text at all sizes.

## Animation

### Single Reversible Animation (`scroll_animation`)

Uses one AnimationPlayer animation played in both directions instead of separate open/close animations:

- **Open**: `animation_player.play_backwards("scroll_animation")` — upper and lower rolls separate from center, paper section grows vertically. Once unrolled, `content_container.modulate.a` set to 1.0.
- **Close**: `animation_player.play("scroll_animation")` — content fades, rolls come back together, paper shrinks.

## Data Architecture

### AdventureResultData Resource

Resource class at `scripts/resource_definitions/adventure/adventure_result_data.gd`:

```gdscript
var is_victory: bool = false
var defeat_reason: String = ""
var combats_fought: int = 0        # combats entered (win or lose)
var combats_total: int = 0         # total combat encounters on the map
var gold_earned: int = 0
var time_elapsed: float = 0.0      # seconds
var health_remaining: float = 0.0
var health_max: float = 0.0
var tiles_explored: int = 0
var tiles_total: int = 0
var madra_spent: float = 0.0       # float, not int
var loot_items: Array[Resource] = []
```

### Data Sources

| Field | Source |
|-------|--------|
| is_victory | `_pending_victory` flag set by `boss_defeated` signal from AdventureTilemap |
| defeat_reason | Derived from state: health <= 0, timer stopped, or fallback retreat |
| combats_fought | Incremented in `_on_stop_combat()` for every combat (win or lose) |
| combats_total | `AdventureTilemap.get_total_combat_count()` — filters for COMBAT_REGULAR, COMBAT_BOSS, COMBAT_ELITE, COMBAT_AMBUSH |
| gold_earned | Accumulated from successful `_on_stop_combat()` calls only |
| time_elapsed | `Time.get_ticks_msec()` delta from `_adventure_start_time` |
| health_remaining | `PlayerManager.vitals_manager.current_health` |
| health_max | `PlayerManager.vitals_manager.max_health` |
| tiles_explored | `AdventureTilemap.get_visited_tile_count()` |
| tiles_total | `AdventureTilemap.get_total_tile_count()` |
| madra_spent | `madra_budget` parameter from `start_adventure()` |
| loot_items | Collected via `InventoryManager.item_awarded` signal during adventure |

### Loot Tracking

`InventoryManager` emits `item_awarded(item: ItemDefinitionData, quantity: int)` whenever items are awarded. `AdventureView` connects to this signal during `start_adventure()` and disconnects in `stop_adventure()`, collecting items into `_loot_items`. The end card displays loot using `ItemDisplaySlot` instances with hover tooltips.

## Reusable Components

### ItemDisplaySlot (`scenes/common/item_display_slot/`)

Read-only item icon with hover tooltip:
- `setup_from_instance(data)` / `setup_from_definition(definition)` API
- Shows `ItemInstance` scene as icon with `use_full_rect = true`
- Tooltip uses `ItemDescriptionPanel` with inventory background texture
- Slide-up + fade-in tween (0.2s ease-out) on hover, slide-down + fade-out (0.1s ease-in) on exit
- Kills active tween before starting new one to prevent race conditions on rapid hover
- `@export var item_definition` for editor preview

### ItemDescriptionPanel (`scenes/common/item_description_panel/`)

Shared item detail panel:
- Shows icon, name, type (with equipment slot for equipment), description, effects
- `setup(item_instance_data)` / `setup_from_definition(definition)` / `reset()` API
- Used anchored in inventory sidebar (via `item_description_box.gd` thin wrapper)
- Used floating as tooltip in end card loot slots

## Integration Flow

### Adventure End Sequence

1. Adventure ends via one of four triggers:
   - Player HP reaches 0 (death) — defeat
   - Timer expires — defeat
   - Player manually exits — defeat
   - Boss encounter defeated — victory (via `boss_defeated` signal → `_pending_victory` flag)
2. `AdventureView.stop_adventure()` determines end condition, builds `AdventureResultData`
3. `AdventureView` disconnects loot tracking, cleans up, emits `adventure_completed(result_data)`
4. `AdventureViewState._on_adventure_completed()` pushes `AdventureEndCardState` as modal overlay
5. `AdventureEndCard.show_results()` populates UI, plays scroll open animation (backwards)
6. Player clicks RETURN
7. `AdventureEndCard` plays close animation (forwards), emits `return_requested`
8. `AdventureViewState._on_end_card_return()` pops state, transitions to `ZoneViewState`

### Transition Hook

The RETURN button emits a `return_requested` signal. Currently this directly triggers the close animation followed by zone view return. This signal serves as the future hook point for inserting transition scenes, reward animations, or narrative beats between the end card and zone view.

## File Summary

### New Files

| File | Purpose |
|------|---------|
| `scripts/resource_definitions/adventure/adventure_result_data.gd` | Data class for all end card stats |
| `scenes/adventure/adventure_end_card/adventure_end_card.tscn` | End card scene |
| `scenes/adventure/adventure_end_card/adventure_end_card.gd` | End card controller |
| `scenes/ui/main_view/states/adventure_end_card_state.gd` | Modal overlay state |
| `scenes/common/item_display_slot/item_display_slot.gd` | Reusable item icon with tooltip |
| `scenes/common/item_display_slot/item_display_slot.tscn` | ItemDisplaySlot scene |
| `scenes/common/item_description_panel/item_description_panel.gd` | Shared item detail panel |
| `scenes/common/item_description_panel/item_description_panel.tscn` | ItemDescriptionPanel scene |
| `assets/styleboxes/buttons/scroll/scroll_button_*.tres` | Scroll button styleboxes |
| `assets/styleboxes/common/panel_loot_tray.tres` | Loot tray panel stylebox |
| `tests/unit/test_adventure_result_data.gd` | 12 unit tests |
| `tests/unit/test_adventure_combat_count.gd` | 12 unit tests |
| `tests/unit/test_inventory_manager.gd` | 2 unit tests |

### Modified Files

| File | Change |
|------|--------|
| `scenes/adventure/adventure_view/adventure_view.gd` | Stat accumulators, adventure_completed signal, loot tracking via item_awarded |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` | boss_defeated signal, tile/combat count methods |
| `scenes/ui/main_view/main_view.gd` | End card state and view references |
| `scenes/ui/main_view/states/adventure_view_state.gd` | Push end card overlay instead of direct zone return |
| `scenes/main/main_game/main_game.tscn` | State node + scene instance |
| `singletons/inventory_manager/inventory_manager.gd` | Added item_awarded signal |
| `scenes/inventory/inventory_view/item_description_box.gd` | Refactored to delegate to shared ItemDescriptionPanel |
| `scenes/inventory/inventory_view/inventory_view.tscn` | Replaced inline nodes with scene instance |
| `scenes/inventory/item_instance/item_instance.gd` | Added use_full_rect flag |
| `assets/themes/pixel_theme.tres` | Theme variants, pixel font fixes |
