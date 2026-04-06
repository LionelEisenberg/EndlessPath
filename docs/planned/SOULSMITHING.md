# Soulsmithing System

> **Status: Planned — Not Yet Implemented**
>
> No code exists for this system. This document describes the design intent from the Game Design Document for future implementation.

## Design Intent

Soulsmithing is an active assembly-puzzle mini-game unlocked at the **Iron** cultivation stage. The player fits abstract, colored, Tetris-like "Remnant Part" shapes into a "Schematic" grid to craft equipment and trinkets.

## Gameplay Concept

1. Player selects a Schematic (recipe) — defines the grid shape and target item
2. "Remnant Part" shapes (Tetris-like pieces) are presented as the raw materials
3. Player drags and rotates pieces to fill the schematic grid
4. Completion quality depends on coverage and color matching
5. The resulting item is placed in the player's inventory as equipment or a trinket

### Complexity Scaling
The GDD describes increasing complexity at higher tiers:
- Basic schematics: simple grids, uniform pieces
- Advanced schematics: color-coded regions requiring specific piece colors
- Master schematics: irregular grid shapes, harder piece geometry

## Resource Requirements

| Input | Source |
|-------|--------|
| Stone | Foraging (Tier 0 resource) |
| Sacred Resources (Remnants, Beast Parts) | Adventuring |
| Madra | Cycling |

## Output

| Output Type | Examples | Effect |
|-------------|----------|--------|
| **Gear** (Weapons/Armor) | Swords, chest plates | Stats for Adventuring/Combat |
| **Trinkets** (Rings/Amulets) | Parasite Ring | Cross-system bonuses |

The GDD specifically mentions a **Parasite Ring** that improves Cycling — demonstrating the intended cross-system synergy where Soulsmithing outputs feed back into earlier systems.

## Integration Points (Planned)

| System | Connection |
|--------|------------|
| Adventuring | Provides Sacred Resources (Remnants, Beast Parts) |
| Foraging | Provides Stone (Tier 0) |
| Inventory | Outputs stored as equipment/trinkets |
| Combat | Gear provides stats (attack_power, defense) |
| Cycling | Trinkets may buff cycling efficiency |
| Cultivation | Unlocked at Iron stage |

## Implementation Considerations

### Existing Infrastructure
- `EquipmentDefinitionData` already has `slot_type` and subtypes (`WeaponDefinitionData.attack_power`, `ArmorDefinitionData.defense`)
- `ItemInstanceData.metadata: Dictionary` is an unused hook — could store assembly quality, color data
- `ItemInstanceData.instance_id: String` is unused — could differentiate crafted items
- `CharacterManager._get_attribute_bonuses()` has a TODO for equipment stat application — this system would be the primary consumer
- The 8 `EquipmentSlot` values (HEAD, CHEST, LEGS, FEET, MAIN_HAND, OFF_HAND, ACCESSORY_1, ACCESSORY_2) are already defined

### New Components Needed
- Schematic data resource (grid dimensions, color regions, target item)
- Remnant Part data resource (shape, color, material source)
- Assembly puzzle UI scene (grid rendering, drag-and-rotate piece placement)
- Quality calculation logic (coverage percentage, color match accuracy)
- A `SoulsmithingActionData` subclass of `ZoneActionData`
- Schematics could be rewarded as "Knowledge" items from Adventuring

### Tetris-like Piece System
- Pieces defined as arrays of occupied cells relative to an origin
- Rotation: 4 orientations per piece (0, 90, 180, 270 degrees)
- Collision detection: check if all piece cells fit empty grid cells
- Color matching: compare piece color against grid region color requirements

## Open Design Questions

- How many pieces per schematic? Fixed count or variable?
- Can pieces be removed after placement, or is placement final?
- Is there a time limit on assembly?
- How does quality affect stats? Linear scaling or quality tiers?
- Should schematics be consumed on use or permanently learned?
- How do color-coded regions work at higher tiers? (exact match? category match?)
- What trinket effect types exist beyond the Parasite Ring example?
- At Jade stage, the GDD mentions "advanced Soulsmithing recipes" — what changes?
- How does the complexity of the puzzle scale with the item's power level?
