# Equipment System Design

## Design Goals

1. Equipment provides **direct attribute bonuses** — no separate attack_power/defense layer
2. Items are **simple to compare** (1-2 stats per piece, rarely 3)
3. Hybrid model: base attribute bonuses for all gear, with a **future hook** for special effects on rare items
4. Gear comes from **both adventure drops and Soulsmithing crafting** (crafting produces the best gear)
5. Cross-system bonuses (cycling, foraging) are **designed as extension points but not implemented yet**

---

## Equipment Slots

6 slots total (reduced from 8 — removed Legs and Feet):

| Slot | Primary Fantasy | Typical Stats |
|------|----------------|---------------|
| **Main Hand** | Offensive identity | STRENGTH, SPIRIT, AGILITY |
| **Off Hand** | Defensive/utility | RESILIENCE, WILLPOWER, BODY |
| **Head** | Mental/spiritual | SPIRIT, WILLPOWER, CONTROL |
| **Armor** | Physical defense | BODY, RESILIENCE |
| **Accessory 1** | Wildcard / build-defining | Any attribute, future perks |
| **Accessory 2** | Wildcard / build-defining | Any attribute, future perks |

**Notes:**
- Off Hand is empty through Foundation/early Copper — players receive one-handed Main Hand weapons only. Off Hand becomes relevant when shields, focuses, or dual-wielding are introduced at later stages
- Accessories are the primary home for rare effects and cross-system bonuses when those are implemented
- "Typical Stats" is a guideline for authoring, not a hard constraint — a Spirit-aspected helm could grant FOUNDATION

---

## Stat Model

### Core Principle
Equipment grants **attribute bonuses** using the existing 8-attribute system. No parallel stat systems.

### Per-Item Data

```
EquipmentDefinitionData
├── slot_type: EquipmentSlot          (which slot it equips to)
├── attribute_bonuses: Dictionary      (AttributeType -> float)
│   e.g., { STRENGTH: 3.0, AGILITY: 1.0 }
└── effects: Array[ItemPerkData]       (FUTURE — empty for now)
```

**Remove:** `attack_power` from WeaponDefinitionData, `defense` from ArmorDefinitionData. These are replaced by attribute bonuses.

**Remove:** `EquipmentType` enum (WEAPON, ARMOR, ACCESSORY). The slot determines the item's role. A Main Hand item IS a weapon by virtue of its slot. Simplifies the class hierarchy.

### Attribute → Combat Mapping (existing, unchanged)

| Attribute | Offensive | Defensive | Vitals |
|-----------|-----------|-----------|--------|
| STRENGTH | Physical damage scaling | — | — |
| BODY | Minor damage scaling | — | Max HP, Max Stamina |
| AGILITY | Damage scaling | — | — |
| SPIRIT | Madra damage scaling | Madra defense | — |
| FOUNDATION | Madra damage scaling | — | Max Madra |
| CONTROL | (Cooldown reduction, planned) | — | — |
| RESILIENCE | — | Physical defense | — |
| WILLPOWER | — | Mixed defense | — |

### How Bonuses Apply

`CharacterManager._get_attribute_bonuses()` (currently returns 0) will:
1. Read all equipped items from `InventoryManager.get_inventory().equipped_gear`
2. Sum `attribute_bonuses` from each equipped item per attribute
3. Return the totals

`get_total_attributes_data()` = base attributes + equipment bonuses (+ future cultivation bonuses)

This is the **only integration point**. Combat, cycling, and all other systems already read from `get_total_attributes_data()` — wiring equipment bonuses here makes gear automatically affect everything downstream.

---

## Class Hierarchy Changes

### Current
```
ItemDefinitionData
└── EquipmentDefinitionData
    ├── WeaponDefinitionData      (adds attack_power)
    └── ArmorDefinitionData       (adds defense)
```

### Proposed
```
ItemDefinitionData
└── EquipmentDefinitionData       (adds attribute_bonuses, slot_type)
```

**Flatten the hierarchy.** WeaponDefinitionData and ArmorDefinitionData are removed. All equipment is `EquipmentDefinitionData` with:
- `slot_type` determines where it equips
- `attribute_bonuses` determines what it does
- The item's identity comes from its name, icon, description, and stats — not its class

This means a "Dagger" is an EquipmentDefinitionData with `slot_type = MAIN_HAND` and `attribute_bonuses = { STRENGTH: 3, AGILITY: 1 }`.

### EquipmentSlot Enum Update

```gdscript
enum EquipmentSlot {
    MAIN_HAND,
    OFF_HAND,
    HEAD,
    ARMOR,
    ACCESSORY_1,
    ACCESSORY_2
}
```

Removed: `CHEST` (renamed to `ARMOR`), `LEGS`, `FEET`.

---

## Future Extension: Item Perks

Not implemented now, but the data model reserves space:

```gdscript
@export var effects: Array[Resource] = []  # Future: ItemPerkData resources
```

When implemented, perks would be lightweight resources:
- `perk_id: String` — unique identifier
- `perk_description: String` — player-facing text
- `trigger: PerkTrigger` — enum (PASSIVE, ON_HIT, ON_DAMAGED, ON_CYCLE, etc.)
- `effect: Resource` — the actual effect (BuffEffectData, stat modifier, etc.)

Example future items:
- *Parasite Ring*: PASSIVE — +10% Madra generation during cycling
- *Venom Blade*: ON_HIT — 15% chance to apply Poison DoT
- *Iron Body Plate*: ON_DAMAGED — reflect 5% damage back to attacker

This is mentioned here for design intent only. Implementation is deferred.

---

## Item Tooltip Display

With attribute bonuses, tooltips show:

```
[Iron Dagger]
Main Hand
─────────────
+3 Strength
+1 Agility
─────────────
"A simple but effective blade forged
from mountain iron."
```

The `_get_item_effects()` method on EquipmentDefinitionData generates the stat lines from `attribute_bonuses`.

---

## Authoring Guidelines

### Foundation Tier (starting gear)
- 1-2 attribute bonuses per item
- Values in the +1 to +5 range
- Simple, clear identity (a sword gives STR, a helm gives WILLPOWER)

### Copper Tier
- 2-3 attribute bonuses per item
- Values in the +3 to +10 range
- Accessories start having more interesting stat combinations

### Iron Tier (Soulsmithing introduced)
- Soulsmithing produces best-in-slot gear
- Crafted items may have 2-3 attributes + a perk effect
- Drop gear remains simpler (1-2 stats, no perks)

---

## Implementation Plan

### Phase 1: Wire Equipment to Combat (DONE — PR #9)
1. ~~Update `EquipmentSlot` enum to the new 6 slots~~
2. ~~Add `attribute_bonuses: Dictionary` to `EquipmentDefinitionData`~~
3. ~~Remove `WeaponDefinitionData` and `ArmorDefinitionData` subclasses~~
4. ~~Implement `CharacterManager._get_attribute_bonuses()` to sum equipped gear bonuses~~
5. ~~Update the existing Dagger/Sword `.tres` to use the new format~~
6. ~~Update `GearSlot` scene references for the new slot set~~
7. ~~Update `_get_item_effects()` to display attribute bonus lines~~
8. ~~Add GearSelector slot coverage validation~~
9. ~~Add right-click quick equip/unequip~~
10. ~~Add tooltip persistence during drag~~

### Phase 2: Content (separate PR)
- Author Foundation-tier items for each slot
- Wire loot tables to drop equipment from adventures
- Balance stat values through playtesting

### Phase 3: Future
- Implement ItemPerkData for rare item effects
- Add cross-system bonus hooks
- Soulsmithing crafting integration

---

## Migration Notes

### .tres Files (MIGRATED)
- `dagger.tres` — STRENGTH +3, AGILITY +1 (was attack_power: 10)
- `sword.tres` — STRENGTH +6, AGILITY +2 (was attack_power: 25)
- `dagger_instance.tres` — no changes needed (UID reference resolved)

### GearSelector Scene (DONE)
- Reduced to 6 GearSlot nodes with slot coverage validation on startup

### Save Data Compatibility
- Old saves with CHEST/LEGS/FEET slots were cleared via `reset_save_data = true`
