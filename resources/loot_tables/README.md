# LootTable System Guide

## Overview

The LootTable system provides a flexible way to define item rewards with independent probability rolls. Each entry in a loot table rolls separately, allowing multiple items to drop from a single roll.

## Creating a LootTable Resource

1. In Godot, create a new Resource of type `LootTable`
2. Add entries to the `entries` array
3. For each entry, configure:
   - **item**: Reference to an `ItemDefinitionData` resource
   - **drop_chance**: Probability from 0.0 (never) to 1.0 (always)
   - **min_quantity**: Minimum items to award if roll succeeds
   - **max_quantity**: Maximum items to award if roll succeeds

### Example: Basic Combat Loot

```
LootTable
├─ Entry 0:
│  ├─ item: Gold Coin
│  ├─ drop_chance: 1.0 (100% - guaranteed)
│  ├─ min_quantity: 10
│  └─ max_quantity: 25
├─ Entry 1:
│  ├─ item: Health Potion
│  ├─ drop_chance: 0.3 (30% chance)
│  ├─ min_quantity: 1
│  └─ max_quantity: 2
└─ Entry 2:
   ├─ item: Rare Gem
   ├─ drop_chance: 0.05 (5% chance)
   ├─ min_quantity: 1
   └─ max_quantity: 1
```

This loot table:
- **Always** drops 10-25 gold coins
- Has a **30% chance** to drop 1-2 health potions
- Has a **5% chance** to drop 1 rare gem

## Using LootTable in Combat Encounters

Combat rewards are handled through the effect system. Use `AwardLootTableEffectData` in your `EncounterChoice` resources.

### Step-by-Step: Adding Combat Loot

1. **Create a LootTable** (as described above)
2. **Open your CombatChoice resource** in the inspector
3. Navigate to **success_effects** array
4. **Add a new effect** of type `AwardLootTableEffectData`
5. Set the **loot_table** property to your LootTable resource

### Example: Boss Combat

For a boss fight that always drops good rewards plus rare items:

**boss_loot.tres:**
```
LootTable
├─ Guaranteed Gold (100%, 100-200)
├─ Guaranteed Equipment (100%, 1-1)
├─ Bonus Materials (50%, 5-10)
└─ Legendary Item (10%, 1-1)
```

**CombatChoice:**
```
success_effects:
  - AwardLootTableEffectData
      loot_table: res://resources/loot_tables/boss_loot.tres
```

## Using LootTable for Foraging

Foraging uses LootTable directly through `ForageActionData`:

1. Create a LootTable with your forage resources
2. Open your `ForageActionData` resource
3. Set the `loot_table` property to your LootTable

### Example: Forest Foraging

```
LootTable
├─ Berries (80%, 2-5)
├─ Herbs (60%, 1-3)
├─ Wood (40%, 1-2)
└─ Rare Flower (5%, 1-1)
```

Each foraging interval will roll all items independently, so you might get berries + herbs + wood in a single roll!

## Advanced Patterns

### Guaranteed Baseline + Rare Drops

Ensure players always get something useful while adding excitement:
```
├─ Common Currency (100%, 50-100)
├─ Common Material (100%, 3-7)
├─ Uncommon Material (30%, 1-3)
└─ Rare Material (5%, 1-1)
```

### Tiered Drops

Create separate loot tables for different difficulty levels:
- `easy_combat_loot.tres` - Higher drop chances, lower quantities
- `hard_combat_loot.tres` - Lower drop chances, higher quantities
- `boss_loot.tres` - Guaranteed good rewards + rare items

### Multiple Loot Tables

You can add multiple `AwardLootTableEffectData` effects to the same encounter choice:
```
success_effects:
  - AwardLootTableEffectData (basic_loot.tres)
  - AwardLootTableEffectData (bonus_loot.tres)
  - AwardResourceEffectData (gold)
```

## Tips

1. **Use 100% drop_chance** for guaranteed rewards players expect
2. **Keep rare drops at 5-20%** for excitement without frustration
3. **Use quantity ranges** to add variety (e.g., 3-7 instead of 5)
4. **Test your loot tables** by checking the logs - they show every roll
5. **Combine with other effects** - LootTable for items, separate effects for resources/XP

## Validation

LootTable automatically validates entries on load:
- Checks that all items are assigned
- Ensures drop_chance is 0.0-1.0
- Verifies min_quantity <= max_quantity
- Confirms quantities are >= 1

Check the console for any validation errors when loading resources.
