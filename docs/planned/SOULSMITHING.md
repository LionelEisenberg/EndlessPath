# Soulsmithing System

> **Status: Planned, not started.** No code exists for this system. This document records the design intent from the Game Design Document.
>
> **Blocked on Iron:** Soulsmithing unlocks at the Iron stage. Foundation and Copper are reachable (the Tribulation breaks through from one to the other), but there is no stage data past Copper and no Copper-to-Iron breakthrough ([CULTIVATION.md](../cultivation/CULTIVATION.md)). No Sacred Resources (Remnants, Beast Parts) exist yet ([ADVENTURING.md](../adventuring/ADVENTURING.md)).

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
| Combat | Gear provides stats via `attribute_bonuses: Dictionary` (AttributeType → float) |
| Cycling | Trinkets may buff cycling efficiency |
| Cultivation | Unlocked at Iron stage |

## Implementation Considerations

### Existing Infrastructure
- **Equipment data:** `EquipmentDefinitionData` is a single class with `slot_type` and `attribute_bonuses: Dictionary` (AttributeType → float); there are no weapon/armor subclasses. Seven equipment items are authored in [ITEMS.md](../inventory/ITEMS.md), and only one (Dreadbeast Tooth Necklace) can currently be obtained in play.
- **Crafting hooks:** `ItemInstanceData.metadata: Dictionary` and `ItemInstanceData.instance_id: String` are exported but unread anywhere. They could store assembly quality or color data and tell crafted items apart.
- **Stats pipeline:** `CharacterManager._get_attribute_bonuses()` → `_get_equipment_bonuses()` sums bonuses from `equipped_gear` and `equipped_accessories`, so Soulsmithing output would feed straight into it ([CHARACTER.md](../infrastructure/CHARACTER.md)).
- **Slots:** `EquipmentSlot` has 5 values: `MAIN_HAND`, `OFF_HAND`, `HEAD`, `ARMOR`, `ACCESSORY`. Two physical accessory slots both accept `ACCESSORY` items, tracked in `InventoryData.equipped_accessories` by index 0/1.
- **Item tooling:** a generator (`scripts/tools/items_md_to_resources.gd`) writes equipment `.tres` files from the tables in [ITEMS.md](../inventory/ITEMS.md). That fits authored items, not runtime-crafted ones.
- **Gap:** `InventoryManager` has no API to spend materials, which Soulsmithing inputs need ([INVENTORY.md](../inventory/INVENTORY.md)).

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
