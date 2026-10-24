# LootTable Guide

## Overview

A `LootTable` is a list of entries. Each entry rolls on its own, so one roll can award several items at once.

Two systems roll tables:
- foraging actions (`ForageActionData`)
- encounter rewards (`AwardLootTableEffectData`)

The results go to `InventoryManager.award_items()`.

This folder holds only this guide. Current loot tables live next to the content that uses them; see [Where loot tables live](#where-loot-tables-live). For how awarded items are stored and shown, see [docs/inventory/INVENTORY.md](../../docs/inventory/INVENTORY.md).

## Data

| Class | File | Field | Type | Default |
|---|---|---|---|---|
| `LootTable` | `scripts/resource_definitions/loot/loot_table.gd` | `entries` | `Array[LootTableEntry]` | `[]` |
| `LootTableEntry` | `scripts/resource_definitions/loot/loot_table_entries.gd` | `item` | `ItemDefinitionData` | null |
| | | `drop_chance` | `float`, `@export_range(0.0, 1.0)` | 1.0 |
| | | `min_quantity` | `int` | 1 |
| | | `max_quantity` | `int` | 1 |

Note that the file name `loot_table_entries.gd` is plural, but the class is `LootTableEntry`.

## How a roll works

`LootTable.roll_loot() -> Dictionary` returns `ItemDefinitionData → int` and works like this:

1. Each entry rolls independently. Null entries and entries with no item are skipped with a warning.
2. The entry succeeds if `randf() <= drop_chance`. Its quantity is then `randi_range(min_quantity, max_quantity)`.
3. If two entries award the same item, their quantities are summed.
4. Every roll is logged at info level (`LootTable: SUCCESS - …` / `FAILED - …`), followed by a summary line.

All four item types can be loot, because `award_items()` routes materials, equipment, consumables and quest items. Awarding equipment with quantity N creates N separate `ItemInstanceData`. If the equipment grid is full (`equipment_capacity()`), the overflow is dropped with only a warning.

Gold and Madra are not items. Award them with `AwardResourceEffectData` next to the loot effect.

## Using a loot table

### Foraging

Set `ForageActionData.loot_table` (`scripts/resource_definitions/zones/zone_action_data/forage_action_data/forage_action_data.gd`).

While foraging runs, `ActionManager._on_forage_timer_finished()` does the following every `foraging_interval_in_sec` seconds (default 5.0):
1. rolls the table
2. awards each result
3. emits `foraging_completed(items)`

`madra_cost_per_second` defaults to 0.0.

### Encounter rewards

Add an `AwardLootTableEffectData` (`loot_table` field) to an `EncounterChoice` or `CombatChoice` `success_effects` array. You can point `loot_table` at a shared `.tres`, or embed it as a sub-resource when only one encounter uses it. The live example embeds it:

```
ravenous_dreadbeast_encounter.tres
└─ CombatChoice "Attack the Dreadbeast"
   └─ success_effects
      └─ AwardLootTableEffectData
         └─ loot_table: LootTable (sub-resource)
            └─ LootTableEntry: item = dreadbeast_tooth_necklace.tres, drop_chance = 0.25, min 1, max 1
```

`AdventureView` collects every `item_awarded` during an adventure for the end-card loot row. It records one entry per award call and ignores the quantity.

### Single guaranteed item

When there's no chance involved, skip the table and use `AwardItemEffectData` (`item`, `quantity`). For example, quest `q_reach_core_density_10` uses it to award the Refugee Camp Map.

## Where loot tables live

| Table | Path | Entries | Used by |
|---|---|---|---|
| `test_loot_table_foraging.tres` | `resources/zones/spirit_valley_zone/zone_actions/loot_table/` | Dewdrop Tear 100% ×1–5; Spirit Fern 100% ×2–6 | `spring_forest_foraging_action.tres` ("Spring Forest Foraging", every 5.0 s) |
| `test_loot_table_weapon.tres` | `resources/zones/spirit_valley_zone/zone_actions/loot_table/` | Makeshift Dagger 100% ×1; Iron Shortsword 100% ×1 | `resources/adventure/encounters/test_treasure_encounter.tres` only. No `AdventureData` references that encounter, so this table never rolls in play |
| inline sub-resource | `resources/adventure/encounters/shallow_woods/combat_encounters/elite/ravenous_dreadbeast_encounter.tres` | Dreadbeast Tooth Necklace 25% ×1 | The encounter's "Attack the Dreadbeast" choice. The Shallow Woods quota is 2 per map |

Despite its `test_` prefix, the foraging table is live content.

## Validation

`LootTable._init()` calls `_verify_loot_table()` through `call_deferred`, so it runs after the resource's properties are loaded. It logs `Log.error` for:
- a null entry or a null item
- a `drop_chance` outside 0.0–1.0
- a `min_quantity` or `max_quantity` below 1
- a `min_quantity` greater than `max_quantity`

It then logs "LootTable: Validation failed!". Validation only reports problems; the table still rolls. Check the console after loading a new table.

There are no automated tests for `LootTable`, `AwardLootTableEffectData` or `AwardItemEffectData` yet.

## Authoring tips

- **Guaranteed rewards:** use `drop_chance = 1.0`.
- **Variety:** use quantity ranges rather than fixed counts.
- **Excitement:** keep rare drops at 5–25%. The only live gear drop is 25%.
- **Bonus loot:** put several `AwardLootTableEffectData` in one `success_effects` array to layer a base table and a bonus table.
- **Shared vs embedded:** keep a table as its own `.tres` when several encounters or actions share it, and embed it when it belongs to one encounter.
