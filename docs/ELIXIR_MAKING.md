# Elixir Making System

> **Status: Planned — Not Yet Implemented**
>
> No code exists for this system. This document describes the design intent from the Game Design Document for future implementation.

## Design Intent

Elixir Making is an active multi-stage crafting mini-game unlocked at the **Copper** cultivation stage. The player processes ingredients through several stations to produce Elixirs — consumable items providing long-duration buffs.

## Gameplay Concept

The crafting process involves multiple stations, each with a distinct interaction pattern:

| Station | Interaction | Description |
|---------|-------------|-------------|
| **Purification** | Rapid-click | Click rapidly to purify raw ingredients |
| **Power Infusion** | Mouse-follow | Follow a path to infuse Madra into the mixture |
| **Stabilization** | Timed-click | Click at precise moments to stabilize the compound |

Quality is determined by performance across all stations. Higher quality elixirs have stronger or longer-lasting effects.

## Resource Requirements

| Input | Source |
|-------|--------|
| Herbs / Ingredients | Foraging (Tier 0), Adventuring (higher tiers) |
| Madra | Cycling |

## Output

Consumable Elixirs providing long-duration buffs. Example from GDD:
- **+10% Core Density XP** — increases XP gain from Cycling zone clicks

Elixirs are meant to be more expensive than Scripts but last much longer, rewarding investment in higher-tier ingredients from Adventuring.

## Integration Points (Planned)

| System | Connection |
|--------|------------|
| Cycling | Elixirs may buff XP gain or Madra generation |
| Foraging | Consumes herbs and ingredients (Tier 0) |
| Adventuring | Higher-tier ingredients from adventure loot |
| Inventory | Elixirs stored as consumable items |
| Cultivation | Unlocked at Copper stage |
| Combat | Elixirs may provide pre-combat stat buffs |

## Implementation Considerations

- The multi-station approach could reuse or extend the `MainViewState` pattern — one state per station
- Rapid-click could use a simple click counter with a timer
- Mouse-follow reuses the concept from Cycling's `mouse_tracking_accuracy`
- Timed-click reuses the concept from Cycling Zones' timing quality
- `ItemDefinitionData.ItemType.CONSUMABLE` needs implementation in `InventoryManager`
- The `BuffEffectData` system already supports timed attribute modifiers — elixir effects could map directly
- A new `ElixirActionData` subclass of `ZoneActionData` would be needed
- Recipe discovery could use the `EffectData` system (awarded as knowledge items from adventures)

## Open Design Questions

- How many stations per elixir recipe? Fixed or variable?
- Is there a failure state, or just quality tiers?
- Should recipes be consumed on use or permanently learned?
- What is the duration range for elixir buffs? (minutes? hours? sessions?)
- Should elixirs stack with Scripts, or occupy a separate buff slot?
- How does ingredient quality (Tier 0 vs. Sacred) affect the outcome?
- At Jade stage, the GDD mentions "advanced recipes" — what differentiates them?
