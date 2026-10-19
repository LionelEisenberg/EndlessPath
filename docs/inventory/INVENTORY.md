# Inventory System

Last updated: 2026-10-18

## Overview

The inventory holds what the player owns and what they have equipped:

- equipment instances in a paged grid
- stacked materials
- stacked consumables
- quest items
- six gear slots and a four-slot consumable hotbar

`InventoryManager` (autoload) owns every mutation and emits a single `inventory_changed` signal. The state lives in `InventoryData` inside the save file.

The UI is a book (`InventoryView`) with four tabs:

| Tab | Contents |
|---|---|
| Equipment | Paged grid, category filter, gear selector, trash hold-buffer |
| Consumables | Stack list and a 4-slot combat hotbar |
| Materials | Grid and a detail card |
| Journal | Quest items |

Items arrive from three sources: foraging loot tables, adventure encounter effects and quest completion effects. Equipped gear feeds attribute bonuses into `CharacterManager`. Quest items gate content through the `ITEM_OWNED` unlock condition.

Related docs:
- [ITEMS.md](ITEMS.md) — equipment catalog. The headless generator turns it into `.tres` files. Other item types are hand-authored `.tres`.
- [EQUIPMENT_DESIGN.md](EQUIPMENT_DESIGN.md) — equipment design intent and tier guidelines.
- [resources/loot_tables/README.md](../../resources/loot_tables/README.md) — loot table authoring.

## Player Experience

1. **Open.** In the zone view, press `I` or click INVENTORY in the zone's SystemMenu. The book plays its open animation and lands on the Equipment tab. The inventory can't be opened from the adventure view.
2. **Switch tabs.** Four tab buttons sit on the left edge: Equipment, Consumables, Materials and Journal. The page-turn animation plays forwards when you move to a later tab and backwards when you move to an earlier one.
3. **Equipment tab — left page.**
   - **Layout:** a category pill (`All` / `Weapons` / `Armor` / `Accessories`) sits above a 7-column × 6-row page of slots. Page buttons (`1`, `2`) and a trash slot run along the bottom.
   - **Hover:** hovering or clicking a slot moves the animated selector ring there and shows the item in the description box on the right page.
   - **Drag:** left-drag works in these ways:
     - between grid slots: move or swap
     - onto a matching gear slot: equip, and the slot's previous item goes back where the dragged item came from
     - from a gear slot onto the grid: unequip
     - between the two accessory slots: swap them
     - hovering a page button mid-drag flips to that page
   - **Right-click:** on a grid item, it equips. An accessory goes to the first free accessory slot, or to slot 0 if both are full. On an equipped item, it unequips to the first free grid slot.
   - **Category pill:** changing it dims every non-matching slot (and every empty slot) to 30% opacity. Dimmed slots stay fully interactive.
   - **Trash:** drop an item on the trash slot to hold it there; drag it back out to restore it. Dropping a second item destroys the held one permanently and logs "Discarded <name>". Closing the book returns any held item to the inventory.
4. **Equipment tab — right page.** The "Gear Selector" portrait has six slots:
   - left column: Head, Armor, Accessory 1
   - right column: Main Hand, Off Hand, Accessory 2

   Each empty slot shows a per-slot outline sprite. The item description box sits below the portrait.
5. **Consumables tab.**
   - **Left page:** a list of owned stacks showing the icon, the name, and `xN` when N > 1. Click a row to show it in the description box.
   - **Right page:** "Combat Hotbar", four slots with key chips `1`–`4`.
     - Drag a row onto a slot to equip it. A consumable can sit in only one slot.
     - Drag between slots to move or swap.
     - Click an equipped slot to clear it.
     - Slots show the live stack count `xN`.
   - **Current limits:** on a real save the list is empty, because no consumable has an in-game source yet. Nothing on `main` reads the hotbar.
6. **Materials tab.**
   - **Left page:** a 6-column grid of stacks (`xN` when N > 1). "N kinds collected" and a trash slot sit above it. The sort pill shows a disabled `All`.
   - **Right page:** clicking a material fills the detail card: name, `[Material]`, description, a "Source Zones" line, then the Source, Used in and Worth rows (`—` when `base_value` is 0). A static tip card sits underneath.
7. **Journal tab** ("Items of consequence").
   - Each row shows the icon, the name, the first 60 characters of the description, and a red seal dot.
   - Clicking a row shows the journal card: icon, name, a drop-cap description, and a `From` row.
   - When there are no quest items it shows "No quest items yet." and hides the card.
8. **Close.** Press `I` or `Escape` to play the book-close animation. On close, every trash slot flushes back into the inventory.

## Architecture

```
MainView
  MainViewStateMachine/InventoryViewState        — inventory_view_state.gd (enter/exit, close on I/Escape)
  InventoryView (Control, scale 2x)              — inventory_view.gd (signals inventory_opened / inventory_closed)
    BookBackground (TextureRect)
      BookAnimationPlayer                        — "BookClosingAnimation" (played backwards to open)
      PageTurningRect/PageTurningAnimationPlayer — "PageTurningAnimation"
      BookContent (Control)
        TabSwitcher                              — tab_switcher.gd (signal tab_changed(index))
          EquipmentTabButton / ConsumablesTabButton / MaterialsTabButton / QuestItemsTabButton
                                                 — tab_button.tscn/.gd (icon_texture export, "TabButtonAnimation")
        EquipmentTab                             — equipment_tab.tscn/.gd
        ConsumablesTab                           — consumables_tab.tscn/.gd
        MaterialsTab                             — materials_tab.tscn/.gd
        QuestItemsTab                            — quest_items_tab.tscn/.gd (the Journal)
```

### Equipment tab

```
EquipmentTab (Control)                     — equipment_tab.gd: drag/drop, quick-equip, category filter, trash routing
  EquipmentTabBanner (TabBanner)           — title "Equipment" (default)
  SortSubBanner                            — 4 categories, enabled
  EquipmentGrid (MarginContainer, @tool)   — equipment_grid.gd; instance overrides num_columns = 7
    GridContainer
      Slot1 … Slot48 (InventorySlot)       — persistent pool (SLOT_POOL_SIZE = 48); slots past num_rows × num_columns hidden
  PaginationBar (HBoxContainer)            — pagination_bar.gd
    PageButtons (HBoxContainer)            — one page_button.tscn (TextureButton) per unlocked page, built in setup()
    TrashSlot                              — trash_slot.gd (group "TrashSlots")
  GearSelector (Control)                   — gear_selector.gd
    Top Signage/Title ("Gear Selector"), GearSelectorPortrait
    VBoxContainer:  HeadGearSlot, ArmorGearSlot, Accessory1GearSlot (accessory_index 0)
    VBoxContainer2: MainWeaponGearSlot, OffhandGearSlot, Accessory2GearSlot (accessory_index 1)
                                           — gear_slot.gd (group "GearSlots")
  SelectorSprite (Node2D, top_level, z 100) — animated hover ring ("start_select")
  ItemDescriptionBox (TextureRect)         — item_description_box.gd
    ItemDescriptionPanel                   — scenes/common/item_description_panel/
```

### Consumables, Materials, Journal

```
ConsumablesTab (Control)                   — consumables_tab.gd
  ConsumablesBanner (TabBanner)            — title "Consumables", title_font_size 38
  ConsumablesSortSubBanner                 — "All", disabled
  ConsumablesInventoryList (InventoryList) — ConsumableRow per stack (consumable_row.gd);
                                             PreviewRow1-3 are editor placeholders cleared at runtime
  ConsumablesHotbar (VBoxContainer)        — consumables_hotbar.gd ("Combat Hotbar" + lede)
    SlotsRow: HotbarSlot ×4 (slot_index 0-3) — hotbar_slot.gd (extends DropTargetSlot)
  ConsumablesItemDescriptionBox            — item_description_box.gd + ItemDescriptionPanel

MaterialsTab (Control)                     — materials_tab.gd
  MaterialsTabBanner (TextureRect)         — baked materials_tab/banner.png (not a TabBanner)
  MaterialsSortSubBanner                   — "All", disabled
  MaterialsGridToolbar (GridToolbar)       — CountLabel + TrashSlot
  MaterialsInventoryGrid (InventoryGrid)   — MaterialSlot per stack (material_slot.gd)
  MaterialDetailCard                       — material_detail_card.gd (extends ItemDetailCard)
  MaterialTipCard                          — static text

QuestItemsTab (Control)                    — quest_items_tab.gd
  JournalBanner (TabBanner)                — title "Journal"
  Subtitle                                 — "Items of consequence"
  ListPane/ScrollContainer/ListVBox        — JournalRow per item (journal_row.gd + wax_seal.tscn)
  EmptyLabel                               — "No quest items yet."
  QuestJournalCard                         — quest_journal_card.gd
```

### Shared components

| Component | Location | Used by |
|---|---|---|
| `InventoryScrollHost` (base: `add_slot` / `clear_slots` / `get_slots`, binds ScrollRail) | `scenes/inventory/common/inventory_scroll_host.gd` | InventoryGrid, InventoryList |
| `InventoryGrid` (GridContainer content, `columns` export, default 6) | `scenes/inventory/common/inventory_grid/` | Materials |
| `InventoryList` (VBoxContainer content) | `scenes/inventory/common/inventory_list/` | Consumables |
| `ScrollRail` (custom grabber; hides itself when content fits) | `scenes/inventory/common/scroll_rail/` | InventoryGrid, InventoryList |
| `SortSubBanner` (arrows + dots, `option_changed(index)`, `enabled`) | `scenes/inventory/common/sort_sub_banner/` | Equipment (enabled), Materials and Consumables (disabled) |
| `GridToolbar` (count label + TrashSlot) | `scenes/inventory/common/grid_toolbar/` | Materials |
| `TabBanner` (`@tool`; `title`, `title_font_size` exports) | `scenes/inventory/common/tab_banner/` | Equipment, Consumables, Journal |
| `ItemDetailCard` | `scenes/inventory/common/item_detail_card/` | Base of MaterialDetailCard only |
| `ItemDescriptionPanel` | `scenes/common/item_description_panel/` | Equipment and Consumables description boxes, ItemDisplaySlot tooltip |
| `ItemDisplaySlot` (read-only icon + hover tooltip) | `scenes/common/item_display_slot/` | Adventure end card loot row |
| `DropTargetSlot` (native drag-and-drop target, hover tint) | `scenes/common/drop_target_slot.gd` | HotbarSlot, ability loadout EquipSlot |
| `ItemInstance` (icon visual for an `ItemInstanceData`) | `scenes/inventory/item_instance/` | InventorySlot / GearSlot / TrashSlot, ItemDisplaySlot |
| `InventorySlot` → `GearSlot`, `TrashSlot` | `scenes/inventory/inventory_view/equipment_tab/` | Equipment tab |

## Data Model

### Item classes

```
ItemDefinitionData (Resource)          — item_definition_data.gd
  ├── EquipmentDefinitionData          — equipment/equipment_definition_data.gd
  ├── MaterialDefinitionData           — material_definition_data.gd
  ├── ConsumableDefinitionData         — consumable_definition_data.gd
  └── QuestItemDefinitionData          — quest_item_definition_data.gd
ItemInstanceData (Resource)            — item_instance_data.gd (one equipment item in the grid or a gear slot)
```

All of these live under `scripts/resource_definitions/items/`. Each subclass's `_init()` sets `item_type`, except `MaterialDefinitionData`, which relies on the default `MATERIAL`.

| Enum | Values |
|---|---|
| `ItemDefinitionData.ItemType` | `MATERIAL`, `CONSUMABLE`, `EQUIPMENT`, `QUEST_ITEM` |
| `EquipmentDefinitionData.EquipmentSlot` | `MAIN_HAND` (0), `OFF_HAND` (1), `HEAD` (2), `ARMOR` (3), `ACCESSORY` (4) |

**ItemDefinitionData**

| Field | Type | Default | Notes |
|---|---|---|---|
| `item_id` | `String` | `""` | Key for `has_item()` and `ITEM_OWNED` |
| `item_name` | `String` | `""` | |
| `description` | `String` | `""` | |
| `icon` | `Texture2D` | null | |
| `item_type` | `ItemType` | `MATERIAL` | |
| `stack_size` | `int` | 99 | Not enforced anywhere |
| `base_value` | `float` | 0.0 | Shown as "Worth" for materials only; no economy reads it |

Methods: `_get_item_type()` returns "Material", "Consumable", "Equipment" or "Quest Item". `_get_item_effects() -> Array[String]` returns tooltip lines, and each subclass overrides it.

**Subclass fields**

| Class | Field | Type | Default | Notes |
|---|---|---|---|---|
| `EquipmentDefinitionData` | `slot_type` | `EquipmentSlot` | `MAIN_HAND` | |
| | `attribute_bonuses` | `Dictionary` (AttributeType int → float) | `{}` | Tooltip: one `+N Attribute` line per non-zero bonus |
| `MaterialDefinitionData` | `source_zone_ids` | `Array[String]` | `[]` | Tooltip line "Source Zones: <ids>" |
| | `source_description` | `String` | `""` | Detail card "Source" |
| | `used_in` | `String` | `""` | Detail card "Used in" (free text) |
| `ConsumableDefinitionData` | `effects` | `Array[EffectData]` | `[]` | `use()` calls `process()` on each, in order |
| | `cooldown_seconds` | `float` | 0.0 | Metadata only on `main`. Tooltip shows `EffectData.describe()` per effect plus "Cooldown: N.Ns" |
| `QuestItemDefinitionData` | `from_source` | `String` | `""` | Journal "From" row |

**ItemInstanceData**

| Field | Type | Default | Notes |
|---|---|---|---|
| `item_definition` | `ItemDefinitionData` | null | |
| `quantity` | `int` | 1 | Always 1 for equipment |
| `instance_id` | `String` | `""` | Unused |
| `metadata` | `Dictionary` | `{}` | Unused (future enchantments and durability) |

### InventoryData

`InventoryData` is defined in `singletons/persistence_manager/inventory_data.gd` and saved as `SaveGameData.inventory`.

| Field | Type | Notes |
|---|---|---|
| `materials` | `Dictionary[MaterialDefinitionData, int]` | Stack counts |
| `equipment` | `Dictionary` (int → `ItemInstanceData`) | Unequipped gear keyed by global slot index |
| `equipped_gear` | `Dictionary` (`EquipmentSlot` → `ItemInstanceData`) | `MAIN_HAND`, `OFF_HAND`, `HEAD`, `ARMOR` |
| `equipped_accessories` | `Dictionary` (int → `ItemInstanceData`) | Physical accessory slot 0 or 1 |
| `quest_items` | `Dictionary[ItemDefinitionData, int]` | |
| `consumables` | `Dictionary[ConsumableDefinitionData, int]` | Entry erased when it reaches 0 |
| `equipped_consumables` | `Dictionary[int, ConsumableDefinitionData]` | Hotbar slot 0–3 → definition. The count is read from `consumables` |
| `unlocked_equipment_pages` | `int` | Default 2 |

| Constant / method | Value |
|---|---|
| `PAGE_ROWS`, `PAGE_COLUMNS` | 6, 6 |
| `SLOTS_PER_PAGE` | 36 |
| `equipment_capacity()` | `unlocked_equipment_pages * SLOTS_PER_PAGE` (72 by default) |

Stacked dictionaries are keyed by the definition resource itself, not by `item_id`. Two `.tres` files with the same `item_id` would therefore be two separate stacks.

### Loot tables

| Class | Fields |
|---|---|
| `LootTable` (`scripts/resource_definitions/loot/loot_table.gd`) | `entries: Array[LootTableEntry]`. `roll_loot() -> Dictionary` (ItemDefinitionData → int) |
| `LootTableEntry` (`loot_table_entries.gd`) | `item: ItemDefinitionData`, `drop_chance: float` (0–1, default 1.0), `min_quantity: int` (1), `max_quantity: int` (1) |

Each entry rolls independently: `randf() <= drop_chance`, then `randi_range(min, max)`. Quantities for the same item are summed. See [resources/loot_tables/README.md](../../resources/loot_tables/README.md).

## Core Systems

### InventoryManager

| Signal | When |
|---|---|
| `inventory_changed(inventory: InventoryData)` | After every mutation |
| `item_awarded(item: ItemDefinitionData, quantity: int)` | First thing in `award_items()`, before routing. It fires even if the item is then dropped |

| Method | Behaviour |
|---|---|
| `get_inventory()`, `get_material_items()`, `get_quest_items()` | Accessors |
| `award_items(item, quantity)` | Routes by `item_type`: MATERIAL, QUEST_ITEM and CONSUMABLE add to their stack; EQUIPMENT creates one `ItemInstanceData` per unit in the first free slot below capacity. Logs "Looted Nx Name" (materials light gray, equipment purple) or "Obtained Nx Name" (quest items yellow, consumables cyan). A class mismatch logs `Log.error` |
| `equip_item(instance, slot, from_index = -1, accessory_index = -1)` | If the slot is occupied, the occupant moves to `from_index` (or the first free slot when -1). Otherwise the instance is removed from the grid by `from_index`, or by identity search |
| `unequip_item(slot, accessory_index = -1)` | Moves the item to the first free grid slot |
| `unequip_item_to_slot(slot, target_index, accessory_index = -1) -> bool` | Swaps with a compatible grid item. Returns false and changes nothing when the occupant doesn't fit the slot |
| `swap_accessory_slots(from_index, to_index)` | Moves or swaps accessory 0 ↔ 1 |
| `move_equipment(from_index, to_index)` | Moves or swaps within the grid. No bounds or capacity check |
| `get_equipped_item(slot, accessory_index = -1)` | Accessor (no callers) |
| `has_item(item_id) -> bool` | Scans materials, grid, equipped gear, accessories, quest items and consumables (count > 0) |
| `use_consumable(def) -> bool` | Calls `def.use()`, then decrements or erases the stack. No cooldown check. No caller on `main` |
| `restore_equipment_instance(instance, target_slot_index = -1)` | Trash restore: uses the target if it is valid, empty and below capacity, otherwise the first free slot. No log |
| `restore_material(def, quantity)` | Trash restore for materials. No UI path reaches it |
| `grant_equipment_page()` | Adds one page. No caller on `main` |
| `equip_consumable(def, slot_index)` | Slots 0–3. Clears any other slot holding the same definition |
| `unequip_consumable(slot_index)`, `swap_consumable_slots(from_slot, to_slot)` | Hotbar edits |

### Equipment drag and drop

The Equipment tab uses a manual drag system, not Godot's built-in drag-and-drop:

- Slots forward `gui_input` as `clicked(slot, event)`.
- `EquipmentTab._input()` moves the floating `ItemInstance` (re-parented to the tab, 28×28) and handles the button release.
- `_get_slot_under_mouse()` hit-tests visible grid slots first, then gear slots, then the trash slot.
- The global index is `current_page * slots_per_page() + slot.get_index()`. The origin index is captured at pickup, so flipping pages mid-drag is safe.

| Drag | Result |
|---|---|
| Grid → grid | `move_equipment(origin, target)` |
| Grid → gear slot (`is_valid_item`) | `equip_item(instance, slot_type, origin, accessory_index)` |
| Any → gear slot of the wrong type | Item returns to its origin |
| Gear → gear | `swap_accessory_slots()` (only accessory ↔ accessory passes validation) |
| Gear → grid | `unequip_item_to_slot()`. A rejected swap returns the item to its origin |
| Any → trash | `TrashSlot.accept(instance)`. `EquipmentTab` then erases the item from `InventoryData` itself and emits `inventory_changed` |
| Trash → grid | `restore_equipment_instance(instance, target)` |
| Trash → gear slot (valid) | `equip_item(instance, slot_type, -1, accessory_index)` |
| Trash → nowhere | Item goes back into the hold-buffer |
| Origin slot, or nowhere | Item returns to its origin |

Right-click calls `_quick_equip()`, which ignores the trash slot: a held item is rescued only by dragging it out. `GearSlot.is_valid_item()` passes only `EquipmentDefinitionData` whose `slot_type` matches the gear slot. `GearSelector._validate_slot_coverage()` logs an error if a singular slot type, or accessory index 0 or 1, has no gear slot.

### Trash hold-buffer

`TrashSlot` extends `InventorySlot`. `_held` holds either an `ItemInstanceData` (equipment) or a `[definition, quantity]` pair (materials).

| Method | Behaviour |
|---|---|
| `accept(value) -> String` | If something is already held, logs "[color=red]Discarded <name>" and drops that reference (permanent deletion). Stores the new value and renders equipment visuals. Returns the discarded name |
| `get_held()`, `is_holding()`, `clear_hold()` | Accessors. `clear_hold()` also clears the visual |
| `flush_to_inventory()` | Called by `InventoryView` on close for every node in the "TrashSlots" group. Restores the held value through InventoryManager, then calls `clear_hold()` so no icon is left behind |

The Materials tab has a trash slot, but nothing is wired to it. The Consumables tab has no trash slot; that path was removed in f0e3e0a.

### Pagination and category filter

**Pagination**
- `EquipmentGrid` keeps a fixed pool of 48 slots. It shows `num_rows × num_columns` of them, capped at the pool size. `num_rows` and `num_columns` are `@tool` knobs that default to `InventoryData.PAGE_ROWS` and `PAGE_COLUMNS`.
- `set_page(p)` clamps `p` to `[0, unlocked_equipment_pages - 1]` and re-binds the slot data. It never recreates the slots.
- `PaginationBar.setup(unlocked_pages, active_page)` rebuilds the page buttons. `page_selected(index)` fires on click and `page_hovered(index)` on mouse-enter. The tab flips pages on hover only while a drag is in progress.

**Category filter (Equipment only)**
- `_build_categories()` builds a list of `{label, match: Callable}` entries:
  - All: everything
  - Weapons: `MAIN_HAND`, `OFF_HAND`
  - Armor: `HEAD`, `ARMOR`
  - Accessories: `ACCESSORY`
- `SortSubBanner.option_changed(index)` calls `EquipmentGrid.set_category_filter(match)`.
- `_update_grid()` sets each slot's `modulate.a` to 1.0 or `DIM_ALPHA` (0.3). Empty slots count as non-matching. The dimming re-applies on every page flip and inventory change.

### Consumable hotbar

The hotbar uses Godot's built-in drag-and-drop:

1. **Drag source.** `ConsumableRow._get_drag_data()` returns `{"consumable": def}`. `HotbarSlot._get_drag_data()` returns `{"consumable": def, "from_slot": i}`.
2. **Drop.** `HotbarSlot` (a `DropTargetSlot`) accepts any dictionary with a `consumable` key and emits `consumable_dropped(def, slot_index, from_slot)`. `ConsumablesHotbar` re-emits the signal.
3. **Routing.** `ConsumablesTab` calls `swap_consumable_slots()` when `from_slot >= 0`, otherwise `equip_consumable()`.
4. **Unequip.** Releasing the left button on an equipped slot without dragging calls `unequip_consumable()`.

### Refresh on `inventory_changed`

| Listener | Behaviour |
|---|---|
| `EquipmentGrid` | Re-clamps the page and re-binds the visible slots (slots persist) |
| `EquipmentTab` | `PaginationBar.setup()` rebuilds the page buttons |
| `GearSelector` | Re-binds the six gear slots |
| `ConsumablesHotbar` | Re-binds the four slots |
| `ConsumablesTab` | Rebuilds the list only when `consumables.hash()` changed. The detail box resets to the first stack |
| `MaterialsTab` | Full rebuild every time. The detail card resets to the first material |
| `QuestItemsTab` | Full rebuild. Keeps the selection if the item is still owned |

### Item flow

```
ForageActionData.loot_table ─(ActionManager ForageTimer, every foraging_interval_in_sec)─▶ LootTable.roll_loot() ─▶ award_items()
AwardLootTableEffectData.process() ─▶ LootTable.roll_loot() ─▶ award_items()
AwardItemEffectData.process() ─▶ award_items()

award_items() ─▶ item_awarded ─▶ AdventureView._loot_items ─▶ AdventureEndCard loot row (ItemDisplaySlot)
              ─▶ inventory_changed ─▶ tabs, GearSelector, hotbar
```

## Integration Points

| System | Connection |
|---|---|
| MainView / ZoneViewState | `open_inventory` (`I`) in `ZoneViewState` pushes `InventoryViewState`. `close_inventory` (`I` or `Escape`) or `open_inventory` plays the close animation, then pops the state. The SystemMenu INVENTORY button fires the same action |
| CharacterManager | `_get_attribute_bonuses()` → `_get_equipment_bonuses()` sums `attribute_bonuses` from `equipped_gear` and `equipped_accessories`. This feeds every attribute getter and `get_total_attributes_data()` |
| ActionManager (foraging) | `_on_forage_timer_finished()` rolls `ForageActionData.loot_table` and awards the result |
| Adventure encounters | `AwardLootTableEffectData` / `AwardItemEffectData` in choice `success_effects`. `AdventureView` listens to `item_awarded` for the end-card loot (one entry per award call; quantity ignored) |
| QuestManager | A quest's `completion_effects` can award items (`q_reach_core_density_10` → Refugee Camp Map) |
| UnlockConditionData `ITEM_OWNED` (5) | Returns `InventoryManager.has_item(str(target_value))`. `comparison_op` is ignored. `AdventureEncounter.is_eligible()` evaluates it directly. `UnlockManager` does not listen to `inventory_changed` |
| PersistenceManager | `InventoryData` is `SaveGameData.inventory`. InventoryManager re-grabs `live_save_data` on `save_data_reset`, and a reset creates a fresh `InventoryData` |
| LogManager | Award messages and "Discarded <name>" |
| Combat (unmerged) | `equipped_consumables` and `use_consumable()` are the hooks used by the `feat/infallible-chaum-58f8ad` branch |

## Existing Content

### Equipment

These seven items live in `resources/items/equipment/spirit_valley/` and are generated from [ITEMS.md](ITEMS.md).

| id | Name | Slot | Bonuses | base_value | How the player gets it on `main` |
|---|---|---|---|---|---|
| `makeshift_dagger` | Makeshift Dagger | MAIN_HAND | STRENGTH +3, AGILITY +2 | 0 | No way — the NPC award was removed on 2026-04-19 (d934de4) |
| `iron_shortsword` | Iron Shortsword | MAIN_HAND | STRENGTH +5, AGILITY +2 | 10 | No way — only in `test_loot_table_weapon` (unreachable) |
| `cultivators_cowl` | Cultivator's Cowl | HEAD | WILLPOWER +3, SPIRIT +1 | 6 | No way (planned: Merchant) |
| `reinforced_robes` | Reinforced Robes | ARMOR | BODY +4, RESILIENCE +2 | 7 | No way (planned: Merchant) |
| `dreadbeast_tooth_necklace` | Dreadbeast Tooth Necklace | ACCESSORY | STRENGTH +2, AGILITY +2 | 0 | 25% drop from the Ravenous Dreadbeast elite in Shallow Woods (quota 2 per map) |
| `leeching_ring` | Leeching Ring | ACCESSORY | FOUNDATION +2, CONTROL +2 | 50 | No way (planned: Merchant, Loot) |
| `scripted_bark` | Scripted Bark | OFF_HAND | BODY +2 | 0 | No way (planned: Loot) |

### Materials

These live in `resources/items/materials/`.

| item_id | Name | source_description | used_in | Source on `main` |
|---|---|---|---|---|
| `SpiritFern` | Spirit Fern | "Spirit Valley — shaded hex" | "Reinforced Robes · Greenleaf Tonic" | Spring Forest Foraging, 2–6 per roll |
| `DewdropTear` | Dewdrop Tear | "Glade pool, dawn only" | "Spirit Tea · Mirror Pill" | Spring Forest Foraging, 1–5 per roll |

Both materials have `source_zone_ids = ["SpiritValley"]`, `base_value` 0, the placeholder icon `res://64.png`, and placeholder descriptions ("Spirit Fern Description", "Dewdrop Tear Description"). Spring Forest Foraging unlocks on the event `q_fill_core_completed`, which fires when the quest "Awaken Your Core" completes.

### Consumables

These live in `resources/items/consumables/`.

| item_id | Name | Effect | cooldown_seconds | base_value | Icon | Source on `main` |
|---|---|---|---|---|---|---|
| `crude_scale` | Crude Scale | `ChangeVitalsEffectData` `madra_change` 20 ("+20 Madra") | 10.0 | 1 | `assets/sprites/items/consumables/crude_scale.png` | None |
| `barely_coalesced_scale` | Barely Coalesced Scale | Same: +20 Madra | 10.0 | 1 | None | None |

The two consumables also share the same description. The first scale was renamed Barely Coalesced → Crude in 459aeb6. Commit 21b3cb2 then re-added `barely_coalesced_scale.tres` as "a weaker counterpart", but its values are identical (see Content below).

### Quest items

| item_id | Name | from_source | Notes |
|---|---|---|---|
| `refugee_camp_map` | Refugee Camp Map | "Old Vesh, in the broken shrine" | `stack_size` 1, icon `res://64.png` |

The map is awarded on completing quest `q_reach_core_density_10` ("Harden Your Core"); step 2 completes on the event `celestial_intervener_dialogue_4`. While the player owns the map and `merchant_discovered` has not fired, the Refugee Camp special encounter is eligible.

### Loot tables

| Table | Location | Entries | Used by |
|---|---|---|---|
| `test_loot_table_foraging.tres` | `resources/zones/spirit_valley_zone/zone_actions/loot_table/` | Dewdrop Tear 100% ×1–5; Spirit Fern 100% ×2–6 | `spring_forest_foraging_action.tres` (rolls every 5.0 s) |
| `test_loot_table_weapon.tres` | same folder | Makeshift Dagger 100% ×1; Iron Shortsword 100% ×1 | `resources/adventure/encounters/test_treasure_encounter.tres` only, which no `AdventureData` references |
| inline sub-resource | `resources/adventure/encounters/shallow_woods/combat_encounters/elite/ravenous_dreadbeast_encounter.tres` | Dreadbeast Tooth Necklace 25% ×1 | "Attack the Dreadbeast" `CombatChoice.success_effects` |

## Key Files

| File | Purpose |
|---|---|
| `singletons/inventory_manager/inventory_manager.gd` | Inventory state and all mutations |
| `singletons/persistence_manager/inventory_data.gd` | Saved inventory container and page constants |
| `scripts/resource_definitions/items/item_definition_data.gd` | Base item class + `ItemType` |
| `scripts/resource_definitions/items/equipment/equipment_definition_data.gd` | `EquipmentSlot`, `attribute_bonuses` |
| `scripts/resource_definitions/items/material_definition_data.gd` | Material fields |
| `scripts/resource_definitions/items/consumable_definition_data.gd` | Effects, cooldown, `use()` |
| `scripts/resource_definitions/items/quest_item_definition_data.gd` | `from_source` |
| `scripts/resource_definitions/items/item_instance_data.gd` | Equipment instance wrapper |
| `scripts/resource_definitions/loot/loot_table.gd`, `loot_table_entries.gd` | Loot rolling |
| `scripts/resource_definitions/effects/award_item_effect_data.gd`, `award_loot_table_effect_data.gd` | Effect-driven awards |
| `scripts/tools/items_md_parser.gd`, `items_md_to_resources.gd` | ITEMS.md → equipment `.tres` generator |
| `scenes/ui/main_view/states/inventory_view_state.gd` | Open/close state |
| `scenes/inventory/inventory_view/inventory_view.gd` | Book animations, tab switching, trash flush on close |
| `scenes/inventory/inventory_view/tab_switcher/tab_switcher.gd`, `tab_button.gd` | Tab buttons |
| `scenes/inventory/inventory_view/equipment_tab/equipment_tab.gd` | Equipment drag/drop, quick-equip, filter, trash routing |
| `scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.gd` | Paged slot pool, dimming |
| `scenes/inventory/inventory_view/equipment_tab/pagination_bar/pagination_bar.gd` | Page buttons + trash |
| `scenes/inventory/inventory_view/equipment_tab/gear_selector/gear_selector.gd`, `gear_slot.gd` | Gear slots and validation |
| `scenes/inventory/inventory_view/equipment_tab/inventory_slot/inventory_slot.gd` | Base slot |
| `scenes/inventory/inventory_view/equipment_tab/trash_slot/trash_slot.gd` | Hold-buffer |
| `scenes/inventory/inventory_view/consumables_tab/` | `consumables_tab.gd`, `consumable_row.gd`, `consumables_hotbar/consumables_hotbar.gd`, `hotbar_slot/hotbar_slot.gd` |
| `scenes/inventory/inventory_view/materials_tab/` | `materials_tab.gd`, `material_slot.gd`, `material_detail_card.gd` |
| `scenes/inventory/inventory_view/quest_items_tab/` | `quest_items_tab.gd`, `journal_row.gd`, `quest_journal_card.gd` |
| `scenes/inventory/inventory_view/item_description_box.gd` | Wrapper around ItemDescriptionPanel |
| `scenes/inventory/common/` | Shared inventory chrome (see table above) |
| `scenes/common/item_description_panel/`, `item_display_slot/`, `drop_target_slot.gd` | Cross-system item UI |

Tests: `tests/unit/test_inventory_*.gd`, `test_equipment.gd`, `test_consumable_definition_data.gd`, `test_crude_scale_tres.gd`, `test_items_md_parser.gd`, `test_quest_item_definition_data.gd`, `test_unlock_condition_item_owned.gd`; `tests/integration/test_consumables_tab_hotbar_equip.gd`, `test_equipment_drag_paging.gd`, `test_equipment_filter.gd`, `test_equipment_grid_pagination.gd`, `test_item_detail_card.gd`, `test_journal_tab_render.gd`, `test_pagination_bar.gd`, `test_sort_sub_banner.gd`, `test_tab_banner_title.gd`, `test_trash_slot_flow.gd`. That is 22 files and 160 tests.

## Work Remaining

### Bugs

- `[MEDIUM]` **The visible page size and the data page size disagree.**
  - `equipment_tab.tscn` sets `EquipmentGrid.num_columns = 7`, so a page shows 42 slots. `InventoryData.SLOTS_PER_PAGE` is 36, so capacity is 72.
  - Page 2 shows global indices 42–83. Awards fill only 0–71, then log "Equipment full (72/72)" while 12 slots still look empty.
  - `move_equipment()` and `unequip_item_to_slot()` have no capacity check, so items can be parked at 72–83, past capacity.
  - The grid tests use the bare `equipment_grid.tscn` (6 × 6), so they don't catch this.
- `[MEDIUM]` **The Materials detail card snaps back to the first material** whenever the inventory changes. `MaterialsTab._rebuild()` re-creates every slot and calls `setup_from_definition(first_def)` on every `inventory_changed`, including each foraging roll (every 5 s) and every equipment move. `ConsumablesTab._rebuild()` resets its selection the same way whenever stacks change.
- `[LOW]` **Equipment overflow is silently dropped.** `_add_to_first_available_slot()` only logs a warning, and `item_awarded` has already fired, so the adventure end card lists an item the player never received.
- `[LOW]` **`use_consumable()` leaves an empty stack on the hotbar.** It erases the stack at zero but leaves the definition in `equipped_consumables`, so the hotbar would show `x0`. This is latent on `main` because nothing calls `use_consumable()`.
- `[LOW]` **An item in the trash is already erased from `InventoryData`.** The SaveTimer autosave (every 5 s) persists that state, so quitting with the inventory open and an item in the trash loses the item.

### Missing Functionality

- `[HIGH]` **Consumables can't be obtained or used on `main`.** No loot table, effect or merchant awards `crude_scale` or `barely_coalesced_scale`, and nothing calls `use_consumable()`. Combat use exists only on the unmerged branch `feat/infallible-chaum-58f8ad` (20 commits, 2026-06-01): `CombatConsumableManager` / `CombatConsumableInstance`, `ConsumableButton`, consumable hotkeys 1–4 and `get_consumable_count()`.
- `[HIGH]` **Six of the seven equipment items have no in-game source** (see Existing Content). The Merchant zone action is a stub that logs "(Shop coming soon.)", and the Shallow Woods loot only includes the necklace. A complete Foundation loop needs these wired.
- `[MEDIUM]` **There is no API to spend or remove items.** InventoryManager can't consume materials, take back quest items or sell equipment. The only removal path is the trash, which `EquipmentTab` implements by mutating `InventoryData` directly. Crafting (Elixir Making, Soulsmithing), merchant selling and quest hand-ins all need `remove_*` verbs. The redesign spec's `discard_*` methods were never built.
- `[MEDIUM]` **The Materials tab's trash slot does nothing.** `MaterialsTab` has no drag source and never connects `trash_slot`. As a result, `TrashSlot`'s `[def, qty]` path and `restore_material()` are reachable only from tests.
- `[LOW]` **`grant_equipment_page()` has no caller**, so every player stays at 2 pages (72 slots). The trigger was deferred by the pagination spec.
- `[LOW]` **`stack_size` is never enforced.**
- `[LOW]` **The Journal's "Linked quest" row and wax-seal state are still deferred.** `quest_item_definition_data.gd` and `journal_row.gd` defer them "until a QuestManager exists", and QuestManager is now an autoload. The seal is always the red "active" dot.
- `[LOW]` **Materials and Consumables have no category data**, so their sort banners stay a single disabled "All".
- `[LOW]` **`UnlockManager` never re-evaluates on `inventory_changed`.** An `ITEM_OWNED` condition in `unlock_condition_list.tres` would latch only when some other signal fires. The one current use, the refugee camp, is evaluated directly and is unaffected.

### Content

- `[HIGH]` **The catalog is tiny:** 7 equipment items, 2 materials, 2 consumables and 1 quest item, all Foundation / Spirit Valley. There are no Copper-tier items, and only one equipment drop exists in play.
- `[MEDIUM]` **`barely_coalesced_scale.tres` duplicates `crude_scale.tres`.** It has the same +20 Madra, 10 s cooldown, base value and description, and it has no icon, even though its commit calls it "weaker". Decide its values or delete it; there is no test for it.
- `[MEDIUM]` **Placeholder art and text.** Both materials and the Refugee Camp Map use `res://64.png`, and the material descriptions are placeholders.
- `[LOW]` **Material ids break the naming convention.** `SpiritFern` and `DewdropTear` are PascalCase while every other item id is snake_case. Bringing materials into ITEMS.md later would rename them.
- `[LOW]` **Material lore doesn't match the game.** The `used_in` strings name recipes and items that don't exist (Spirit Tea, Mirror Pill, Greenleaf Tonic). Dewdrop Tear's source text doesn't match its real source, Spring Forest Foraging.
- `[LOW]` **Test-named data files.** The two `test_loot_table_*.tres` files and `test_treasure_encounter.tres` are leftovers, even though the forage table is live. Rename, wire up or delete them.
- `[LOW]` **Iron Shortsword's description says it is "demanding both hands"**, but there is no two-handed rule and OFF_HAND stays free.

### UI

- `[MEDIUM]` **MaterialTipCard advertises a favorites feature that doesn't exist:** "Right-click a material to mark it as a favorite — favorites rise to the top of the grid…".
- `[MEDIUM]` **No on-screen close button.** Only `I` and `Escape` close the book.
- `[LOW]` **The hotbar's helper text** says "Hotkeys 1-4", but `main` has no consumable input actions.
- `[LOW]` **The Equipment tab shows no item count or capacity.** `PaginationBar`'s count label was dropped in 8d147eb.
- `[LOW]` **The material tooltip shows the raw zone id** ("Source Zones: SpiritValley").
- `[LOW]` **Banners are inconsistent.** The Materials banner is a baked image rather than a `TabBanner`. The Journal reuses the red ribbon; the redesign's gold banner never landed.
- `[LOW]` **Tab-button icons shrink** from 0.95 to 0.75 scale in `TabButtonAnimation`. This was reported as janky before the June icon swap (c33064c, c4d3b4e) and hasn't been re-checked (unverified).

### Tech Debt

- `[MEDIUM]` **`EquipmentTab._remove_dragged_from_inventory_state()` mutates `InventoryData` directly** and emits `InventoryManager.inventory_changed` itself. Move this into an InventoryManager verb.
- `[MEDIUM]` **`test_inventory_manager.gd` tests less than its count suggests.**
  - About 20 of its 33 tests re-implement the logic on a local `InventoryData` instead of calling the manager. As a result, `equip_item`, `unequip_item`, `move_equipment` and `swap_accessory_slots` are effectively untested.
  - `test_inventory_max_50_slots` checks a 50-slot rule that no longer exists.
  - There are no tests for `LootTable`, `AwardLootTableEffectData`, `AwardItemEffectData`, `_quick_equip` (only its trash-slot guard is tested), `GearSelector`, `MaterialsTab` or the generator script.
- `[LOW]` **Two item-detail widgets exist.** `ItemDescriptionPanel` serves Equipment, Consumables and the end-card tooltip; `ItemDetailCard` serves only Materials. Their setup logic is duplicated, and `ItemDetailCard`'s doc comment wrongly says Consumables and the Journal use it.
- `[LOW]` **Two drag systems coexist.** Equipment uses a manual one (`_input` plus hit-testing); consumables use Godot's built-in drag-and-drop. The drag-preview code is duplicated in `ConsumableRow` and `HotbarSlot`.
- `[LOW]` **Dead code:**
  - `quest_item_row.tscn/.gd`, replaced by `JournalRow`
  - `ItemInstanceData._to_description_box()` (no caller; `ConsumableDefinitionData`'s comment still points at it)
  - `GridToolbar.set_count()`
  - `QuestJournalCard`'s `%Sub` label, which is always empty
- `[LOW]` **UI nodes built in code.** `SortSubBanner._redraw()` creates its dot `TextureRect`s in code and frees the four authored `Dot0-3` nodes.
- `[LOW]` **Coding-standard gaps:**
  - `$AnimationPlayer` in `tab_button.gd` and `$MarginContainer/SlotBackground` in `gear_slot.gd` should use `%` unique names
  - untyped variables (for example `var inventory = get_inventory()` in `inventory_manager.gd`) and an untyped `func _input(event)` in `equipment_tab.gd`
  - no `##` docs on `get_inventory`, `get_material_items`, `award_items`, `unequip_item`, `move_equipment` and `get_equipped_item`
  - `_get_item_type()` and `_get_item_effects()` start with `_` but are called from other classes
- `[LOW]` **`GearSelector` finds its slots through the global "GearSlots" group**, so a second GearSelector in the tree would pick up both sets.
