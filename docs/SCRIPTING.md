# Scripting System

> **Status: Planned — Not Yet Implemented**
>
> No code exists for this system. This document describes the design intent from the Game Design Document for future implementation.

## Design Intent

Scripting is an active mini-game unlocked at the **Copper** cultivation stage. The player performs calligraphy — tracing characters with the mouse — to create consumable Scripts that provide short-term, stackable buffs.

## Gameplay Concept

1. Player selects a Script recipe (unlocked via advancement or discovery)
2. A glowing character appears on a parchment background
3. Player traces the character with the mouse, following stroke order
4. Accuracy and stroke order determine quality: **Basic**, **Quality**, or **Pristine**
5. Higher quality = stronger effect or longer duration
6. The resulting Script is a consumable item placed in inventory

## Resource Requirements

| Input | Source |
|-------|--------|
| Paper | Foraging (Tier 0 resource) |
| Ink | Foraging (Tier 0 resource) |
| Madra | Cycling |

## Output

Consumable Scripts providing short-duration, stackable buffs. Example from GDD:
- **Auto-Cycle Script** — automates cycling for a duration

Scripts are intended to be relatively cheap to produce and frequently consumed, creating a steady demand for Tier 0 foraging resources.

## Integration Points (Planned)

| System | Connection |
|--------|------------|
| Cycling | Scripts may buff cycling efficiency (e.g., Auto-Cycle) |
| Foraging | Consumes Paper and Ink |
| Inventory | Scripts stored as consumable items |
| Cultivation | Unlocked at Copper stage |
| Adventuring | Scripts may buff combat stats before runs |

## Implementation Considerations

- The `ItemDefinitionData.ItemType.CONSUMABLE` enum value exists but `InventoryManager.award_items()` doesn't handle it yet
- No `ScriptActionData` subclass of `ZoneActionData` exists
- The `ActionType.ZONE_EVENT` or a new `SCRIPTING` type could serve as the action handler
- The calligraphy tracing mechanic likely needs a custom `Path2D`-based input system similar to how Cycling uses paths
- Quality tiers could leverage the existing `EffectData` system for buff application

## Open Design Questions

- How complex should stroke order validation be? (exact match vs. proximity-based)
- Should Scripts stack additively or multiplicatively?
- What is the duration range? (seconds? minutes? tied to quality?)
- Should Script recipes be unlocked via the advancement tree or found in adventures?
- How does the "Auto-Cycle" Script interact with the existing auto-cycle toggle?
