# Adventure End Card Implementation Plan

> **Status:** COMPLETED (PR #19, merged 2026-04-11)

**Goal:** Show a scroll-themed results overlay when an adventure ends, displaying victory/defeat status, stats, and loot before returning to the zone view.

**Architecture:** A new `AdventureResultData` resource accumulates stats during an adventure. When the adventure ends, the data is passed to a new `AdventureEndCard` scene (pushed as a modal overlay via the existing MainView state machine). The end card uses scroll texture assets with an unroll/close animation driven by a single reversible AnimationPlayer animation.

**Tech Stack:** Godot 4.6, GDScript, AnimationPlayer, TextureRect (scroll assets from `assets/scroll/parts/`)

**Spec:** `docs/superpowers/specs/2026-04-10-adventure-end-card-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `scripts/resource_definitions/adventure/adventure_result_data.gd` | Pure data class holding all end-of-adventure stats |
| `scenes/adventure/adventure_end_card/adventure_end_card.gd` | Controller: populates UI from AdventureResultData, drives animations, emits `return_requested` |
| `scenes/adventure/adventure_end_card/adventure_end_card.tscn` | Scene: scroll textures, stat labels, loot slots, AnimationPlayer, RETURN button |
| `scenes/ui/main_view/states/adventure_end_card_state.gd` | MainViewState subclass: pushes/pops the end card as a modal overlay |
| `scenes/common/item_display_slot/item_display_slot.gd` | Reusable item icon with hover tooltip |
| `scenes/common/item_display_slot/item_display_slot.tscn` | ItemDisplaySlot scene |
| `scenes/common/item_description_panel/item_description_panel.gd` | Shared item detail panel (icon, name, type, description, effects) |
| `scenes/common/item_description_panel/item_description_panel.tscn` | ItemDescriptionPanel scene |
| `tests/unit/test_adventure_result_data.gd` | Unit tests for AdventureResultData defaults and population |
| `tests/unit/test_adventure_combat_count.gd` | Unit tests for combat encounter type filtering |
| `tests/unit/test_inventory_manager.gd` | Unit tests for item_awarded signal |

### Modified Files

| File | What Changed |
|------|-------------|
| `scenes/adventure/adventure_view/adventure_view.gd` | Added stat accumulators, `adventure_completed` signal, `_build_result_data()`, loot tracking via `InventoryManager.item_awarded` |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` | Added `boss_defeated` signal, `get_visited_tile_count()`, `get_total_tile_count()`, `get_total_combat_count()` |
| `scenes/ui/main_view/main_view.gd` | Registered new state, added end card view reference |
| `scenes/ui/main_view/states/adventure_view_state.gd` | Replaced direct zone transition with end card push via `push_state`/`pop_state` |
| `scenes/main/main_game/main_game.tscn` | Added AdventureEndCardState node and AdventureEndCard scene instance |
| `singletons/inventory_manager/inventory_manager.gd` | Added `item_awarded(item, quantity)` signal |
| `scenes/inventory/inventory_view/item_description_box.gd` | Refactored to thin wrapper delegating to shared ItemDescriptionPanel |
| `scenes/inventory/inventory_view/inventory_view.tscn` | Replaced inline description panel nodes with ItemDescriptionPanel scene instance |
| `scenes/inventory/item_instance/item_instance.gd` | Added `use_full_rect` flag for scalable icon display |
| `assets/themes/pixel_theme.tres` | Added 6 Label theme variants, ButtonEndCard variant, HSeparator/Panel variants, pixel font rendering fixes |

---

### Task 1: Create AdventureResultData Resource [DONE]

- [x] Created `scripts/resource_definitions/adventure/adventure_result_data.gd`

Key fields (final implementation):
- `combats_fought: int` — number of combat encounters fought (win or lose), NOT `combats_won`
- `combats_total: int` — total combat encounters on the map (from `get_total_combat_count()`), NOT encounters entered
- `madra_spent: float` — float, not int
- `loot_items: Array[Resource]` — populated via `InventoryManager.item_awarded` signal

---

### Task 2: Expose Tile and Combat Counts from AdventureTilemap [DONE]

- [x] Added `get_visited_tile_count()`, `get_total_tile_count()`, `get_total_combat_count()`
- [x] Added `boss_defeated` signal
- [x] `get_total_combat_count()` filters for combat encounter types: `COMBAT_REGULAR`, `COMBAT_BOSS`, `COMBAT_ELITE`, `COMBAT_AMBUSH`

---

### Task 3: Add Stat Tracking and Result Building to AdventureView [DONE]

- [x] Added `adventure_completed(result_data)` signal
- [x] Tracking vars: `_combats_fought`, `_gold_earned`, `_madra_budget`, `_loot_items`, `_adventure_start_time`, `_pending_victory`
- [x] Reset accumulators in `start_adventure()`
- [x] Track combat results in `_on_stop_combat()` — every combat increments `_combats_fought`, gold only on success
- [x] `_build_result_data()` assembles AdventureResultData from accumulators
- [x] `stop_adventure()` determines end condition (victory/health/timeout/retreat), builds result, emits signal
- [x] Loot tracking via `InventoryManager.item_awarded` signal — connected during `start_adventure()`, disconnected in `stop_adventure()`

---

### Task 4: Create AdventureEndCard Scene and Script [DONE]

- [x] Controller populates UI from AdventureResultData
- [x] Victory/defeat title with icon swapping (trophy vs skull from `assets/ui_images/stat_icons/`)
- [x] Stat icons for all 6 stats (combat, gold, time, health, tiles, madra)
- [x] Single `scroll_animation` played backwards to open, forwards to close (no separate open/close animations)
- [x] Loot section uses `ItemDisplaySlot` instances (not bare TextureRects)
- [x] Theme variants: Title, DefeatReason, StatName, StatValue, Section, Muted labels; ButtonEndCard; PanelLootTray; HSeparator variants

---

### Task 5: Create AdventureEndCardState [DONE]

- [x] Shows grey background on enter, hides end card + background on exit

---

### Task 6: Wire Everything Together [DONE]

- [x] `AdventureViewState._on_adventure_completed()` pushes `AdventureEndCardState` as modal overlay
- [x] `_on_stop_adventure()` is now a no-op — waits for `adventure_completed` signal
- [x] `_on_end_card_return()` pops state and transitions to zone view
- [x] Uses `CONNECT_ONE_SHOT` for return signal to prevent duplicate handlers

---

### Task 7: Reusable Item Components [DONE]

This was not in the original plan but was added during implementation.

- [x] Extracted `ItemDescriptionPanel` from inventory's inline description nodes
- [x] Created `ItemDisplaySlot` with hover tooltip using `ItemDescriptionPanel`
- [x] Inventory's `item_description_box.gd` refactored to thin wrapper
- [x] Tooltip has slide-up + fade-in tween on hover, slide-down + fade-out on exit
- [x] Uses inventory background texture for tooltip panel

---

### Task 8: Unit Tests [DONE]

- [x] 12 tests for AdventureResultData (defaults, population, loot)
- [x] 12 tests for combat count filtering (all encounter types, mixed maps)
- [x] 2 tests for InventoryManager.item_awarded signal
- [x] All 202 project tests passing

---

### Task 9: Manual Testing and Polish [DONE]

- [x] Verified full flow: start adventure → fight combats → end → scroll unrolls → stats correct → RETURN → zone view
- [x] Tested all defeat reasons (health, timeout, retreat) and victory
- [x] Pixel font rendering fix: disabled antialiasing, full hinting
- [x] Button hover fix: set mouse_filter pass-through on scroll layer textures
- [x] Tween race condition fix: kill active tween before starting new one in ItemDisplaySlot
