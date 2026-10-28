# Elixir Making System

> **Status: Planned, not started.** No code exists for this system. This document records the design intent from the Game Design Document.
>
> **Unlocks at Copper, which nothing is gated on yet:** Elixir Making unlocks at the Copper stage. The Foundation → Copper breakthrough is built (the Tribulation) and Copper has a thin `AdvancementStageResource`, but no unlock condition, zone, path node or action checks for the stage. See [CULTIVATION.md](../cultivation/CULTIVATION.md).

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

Spirit Fern and Dewdrop Tear, from Spring Forest Foraging, are the only materials today, and nothing consumes them. `InventoryManager` has no API to spend or remove materials, which a crafting system needs first. See [INVENTORY.md](../inventory/INVENTORY.md).

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

What exists:
- **Views:** the multi-station flow could reuse the `MainViewState` push/pop pattern, one state per station ([MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md)).
- **Reusable mechanics from Cycling:** mouse-follow maps to its Madra Ball tracking, and timed-click to its cycling-zone PERFECT/GOOD/OK scoring ([CYCLING.md](../cycling/CYCLING.md)). Rapid-click could be a click counter with a timer.
- **Consumable items:** `ConsumableDefinitionData` (`effects: Array[EffectData]`, `cooldown_seconds`, `use()`) and consumable stacks in `InventoryData.consumables` are implemented. An Elixir fits as a consumable item ([INVENTORY.md](../inventory/INVENTORY.md)).
- **Recipe discovery:** could reuse the `EffectData` reward pipeline, e.g. an item awarded from adventure encounters ([EFFECTS.md](../infrastructure/EFFECTS.md)).

What's missing:
- **Long-duration buffs:** there is no system for them. `BuffEffectData` timed modifiers live in `CombatBuffManager` and only exist during a fight; nothing persists a buff across cycling, adventures, or a save/load. Elixir effects such as "+10% Core Density XP" need a persistent timed-modifier system that `CultivationManager`/`CyclingTechnique` read. That is the same hookup the path tree's inert `core_density_xp_mult` perk is missing ([PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md)).
- **Zone action:** a new `ElixirActionData` subclass of `ZoneActionData`, plus an `ActionManager` route, is needed ([ZONES.md](../zones/ZONES.md)).

## Open Design Questions

- How many stations per elixir recipe? Fixed or variable?
- Is there a failure state, or just quality tiers?
- Should recipes be consumed on use or permanently learned?
- What is the duration range for elixir buffs? (minutes? hours? sessions?)
- Should elixirs stack with Scripts, or occupy a separate buff slot?
- How does ingredient quality (Tier 0 vs. Sacred) affect the outcome?
- At Jade stage, the GDD mentions "advanced recipes" — what differentiates them?
