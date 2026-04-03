# Inventory System

## Overview

The inventory system manages equipment, materials, and item rewards. Players access a book-style UI with two tabs: Equipment (50-slot grid + 8 gear slots on a paper doll) and Materials (scrollable list with quantities). Items are dragged between grid slots and gear slots. Loot comes from foraging timers and adventure encounter rewards.

## Player Experience

1. Press `I` from the zone view to open the inventory (book-open animation)
2. **Equipment Tab:** 50-slot grid on the left, 8 gear slots on a character paper doll on the right
3. Click an item to see its description; drag items between grid and gear slots
4. Gear slots enforce type matching (e.g., only weapons go in MAIN_HAND)
5. **Materials Tab:** Scrollable list showing material icons, names, and quantities
6. Press `I` or `Escape` to close (book-close animation)

## Architecture

```
InventoryView (Control)                           — inventory_view.gd
  BookAnimationPlayer                             — open/close book animation
  PageTurningAnimationPlayer                      — tab transition animation
  BookContent (Control)
    TabSwitcher                                   — tab_switcher.gd
      EquipmentTabButton / MaterialsTabButton     — tab_button.gd
    EquipmentTab (Control)                        — equipment_tab.gd
      EquipmentGrid                               — equipment_grid.gd (50 InventorySlots)
      GearSelector                                — gear_selector.gd (8 GearSlots)
      SelectorSprite                              — animated hover cursor
      ItemDescriptionBox                          — item_description_box.gd
      TrashSlot                                   — trash_slot.gd (visual only)
    MaterialsTab (Control)                        — materials_tab.gd
      MaterialsVbox
        MaterialContainer (per material)          — material_container.gd
```

## Data Model

### Item Hierarchy

```
ItemDefinitionData (Resource)
  ├── item_id, item_name, description, icon
  ├── item_type: ItemType (MATERIAL, CONSUMABLE, EQUIPMENT, QUEST_ITEM)
  ├── stack_size, base_value
  │
  ├── MaterialDefinitionData
  │     └── source_zone_ids: Array[String]
  │
  └── EquipmentDefinitionData
        ├── slot_type: EquipmentSlot
        ├── equipment_type: EquipmentType (WEAPON, ARMOR, ACCESSORY)
        │
        ├── WeaponDefinitionData
        │     └── attack_power: float
        │
        └── ArmorDefinitionData
              └── defense: float
```

### EquipmentSlot Enum
`HEAD`, `CHEST`, `LEGS`, `FEET`, `MAIN_HAND`, `OFF_HAND`, `ACCESSORY_1`, `ACCESSORY_2`

### ItemInstanceData
| Field | Type | Description |
|-------|------|-------------|
| `item_definition` | `ItemDefinitionData` | What item this is |
| `quantity` | `int` | Stack count (always 1 for equipment) |
| `instance_id` | `String` | Unused, future hook |
| `metadata` | `Dictionary` | Unused, future hook for enchantments |

### InventoryData (persistence container)
| Field | Type | Description |
|-------|------|-------------|
| `materials` | `Dictionary[MaterialDefinitionData, int]` | Resource type as key, count as value |
| `equipment` | `Dictionary` | Slot index (0-49) -> ItemInstanceData |
| `equipped_gear` | `Dictionary` | EquipmentSlot enum -> ItemInstanceData |

### Loot Tables

**LootTableEntry:** `item: ItemDefinitionData`, `drop_chance: float` (0-1), `min_quantity`, `max_quantity`

**LootTable.roll_loot():** Independent roll per entry — `randf() <= drop_chance` determines success, `randi_range(min, max)` determines quantity. All entries can drop simultaneously. Returns `Dictionary[ItemDefinitionData, int]`.

Validation on load checks null items, chance ranges, and quantity constraints.

## Drag & Drop (EquipmentTab)

All mouse input handled centrally in `EquipmentTab`:

| Action | Flow |
|--------|------|
| **Pick up** | `slot.grab_item()` → re-parent to scene root, scale 2x, ignore mouse |
| **Grid → Gear** | Validate `target_slot.is_valid_item()` → `InventoryManager.equip_item()` |
| **Gear → Gear** | Unequip first slot → equip to second slot |
| **Gear → Grid** | `InventoryManager.unequip_item_to_slot()` |
| **Grid → Grid** | `InventoryManager.move_equipment()` — swap or move |
| **Drop outside** | Return item to original slot |

`_get_slot_under_mouse()` manually iterates all slots checking `get_global_rect().has_point()`.

## InventoryManager (Singleton)

**Signal:** `inventory_changed(inventory: InventoryData)` — single reactive signal for all UI updates.

**Key API:**
| Method | Description |
|--------|-------------|
| `award_items(item, quantity)` | Routes to `_award_material()` or `_award_equipment()` |
| `equip_item(instance, slot, from_index)` | Move from grid to gear slot (swaps if occupied) |
| `unequip_item(slot)` | Move from gear to first available grid slot |
| `move_equipment(from, to)` | Swap/move within grid |
| `get_material_items()` | Returns materials dictionary |
| `get_equipped_item(slot)` | Returns equipped ItemInstanceData |

Material awards increment count in dictionary. Equipment awards create individual `ItemInstanceData` instances (one per unit). Max 50 grid slots (hardcoded in both `EquipmentGrid` and `InventoryManager`).

## Loot Paths

**Path A — Foraging:**
`ForageActionData.loot_table` → `ActionManager._on_forage_timer_finished()` → `loot_table.roll_loot()` → `InventoryManager.award_items()` (repeating timer)

**Path B — Adventure Encounter Effects:**
`AwardLootTableEffectData.process()` → `loot_table.roll_loot()` → `InventoryManager.award_items()` (on encounter completion)

**Path C — Direct Item Award:**
`AwardItemEffectData.process()` → `InventoryManager.award_items()` (e.g., dagger from NPC dialogue)

## Integration Points

| System | Connection |
|--------|------------|
| Zone View | `I` key pushes `InventoryViewState` |
| Foraging | ActionManager rolls loot table on timer |
| Combat/Adventure | Success effects award loot and items |
| CharacterManager | **Not yet wired** — `_get_attribute_bonuses()` has TODO for equipment stats |
| UnlockManager | `ITEM_OWNED` condition type exists but returns false (unimplemented) |
| Soulsmithing | Planned consumer — `metadata` and `instance_id` fields are forward-compatibility hooks |

## Existing Content

| Item | Type | Details |
|------|------|---------|
| Spirit Fern | Material | Source: SpiritValley |
| Dewdrop Tear | Material | Source: SpiritValley |
| Dagger | Weapon | attack_power: 10.0, MAIN_HAND |
| Dagger Instance | ItemInstanceData | Wraps dagger.tres |

No loot table `.tres` files exist yet (only a README guide in `resources/loot_tables/`).

## Key Files

| File | Purpose |
|------|---------|
| `scenes/inventory/inventory_view/inventory_view.gd` | Book animations, tab switching |
| `scenes/inventory/inventory_view/equipment_tab/equipment_tab.gd` | All drag & drop logic |
| `scenes/inventory/inventory_view/equipment_tab/equipment_grid/equipment_grid.gd` | 50-slot grid |
| `scenes/inventory/inventory_view/equipment_tab/gear_selector/gear_selector.gd` | 8 gear slots |
| `scenes/inventory/inventory_view/equipment_tab/gear_selector/gear_slot.gd` | Type-validated slot |
| `scenes/inventory/inventory_view/materials_tab/materials_tab.gd` | Materials list |
| `scenes/inventory/item_instance/item_instance.gd` | Visual item node |
| `scripts/resource_definitions/items/item_definition_data.gd` | Base item class |
| `scripts/resource_definitions/items/equipment/equipment_definition_data.gd` | Equipment base |
| `scripts/resource_definitions/loot/loot_table.gd` | Loot rolling logic |
| `singletons/inventory_manager/inventory_manager.gd` | Inventory state management |

## Known Issues

- **Equipment stats not wired to combat** — `attack_power` and `defense` are display-only; `CharacterManager._get_attribute_bonuses()` returns 0
- **TrashSlot non-functional** — node exists but `_get_slot_under_mouse()` doesn't check it; item deletion not implemented
- **Hardcoded slot count** — `NUM_INVENTORY_SLOTS = 50` duplicated in EquipmentGrid and InventoryManager
- **GearSlot-to-GearSlot drag fragile** — unequips by value scan after adding to grid, which can match the wrong instance
- **`save_game_data._to_string()` bug** — references `inventory.items.size()` but `InventoryData` has no `items` property
- **`reset_save_data = true`** — PersistenceManager resets inventory every startup (dev flag)
- **CONSUMABLE and QUEST_ITEM types** — `award_items()` logs error and drops them
- **No loot table resources authored** — the system works but has no content
- **Materials tab rebuilds entirely** on every `inventory_changed` signal (no diffing)
