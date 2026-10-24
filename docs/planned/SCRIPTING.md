# Scripting System

Last updated: 2026-10-24

> **Status: Planned, not started.** No code exists for this system. This document records the design intent from the Game Design Document.
>
> **Unlocks at Copper, which nothing is gated on yet:** Scripting unlocks at the Copper stage. The Foundation → Copper breakthrough is built (the Tribulation, on `feat/gameplay-priorities-c64b38`, not merged), and `CultivationManager.advance_to_next_stage()` puts the player in a thin Copper stage, but no unlock condition, zone, path node or action checks for it. See [CULTIVATION.md](../cultivation/CULTIVATION.md) and [breakthrough-tribulation.md](../cultivation/breakthrough-tribulation.md).

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

No Paper or Ink materials exist yet. Foraging yields only Spirit Fern and Dewdrop Tear (see [INVENTORY.md](../inventory/INVENTORY.md) and [ZONES.md](../zones/ZONES.md)).

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

What exists:
- **Consumable items:** `ConsumableDefinitionData` has `effects: Array[EffectData]`, `cooldown_seconds`, and `use()`. `InventoryManager` stacks consumables in `InventoryData.consumables`, and a 4-slot `equipped_consumables` hotbar is managed in the inventory's Consumables tab. A Script fits this as a `ConsumableDefinitionData`. See [INVENTORY.md](../inventory/INVENTORY.md).
- **Using consumables:** nothing on `main` consumes from the hotbar. In-combat use (`CombatConsumableManager`, consumable hotkeys) exists only on the unmerged branch `feat/infallible-chaum-58f8ad`. Using one outside combat has no UI at all.
- **Effects:** quality tiers could pick between different `EffectData` sets. See [EFFECTS.md](../infrastructure/EFFECTS.md).

What's missing:
- **Buffs outside combat:** there is no system for them. `BuffEffectData` and `CombatBuffManager` only run inside a fight, and `CharacterManager.get_total_attributes_data()` has a TODO for active buffs. Short-duration Script buffs that act outside combat (e.g. on cycling) need a timed-modifier system first. The same hookup problem leaves the path tree's numeric perks inert ([PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md)).
- **Zone action:** no `ScriptActionData` subclass of `ZoneActionData` exists. `ZoneActionData.ActionType` is `FORAGE`, `ADVENTURE`, `NPC_DIALOGUE`, `MERCHANT`, `TRAIN_STATS`, `CYCLING`, `ZONE_EVENT`, `TRIBULATION`. A new `SCRIPTING` type (or `ZONE_EVENT`) could route it through `ActionManager` ([ZONES.md](../zones/ZONES.md)).
- **Tracing input:** the calligraphy mechanic likely needs a custom `Path2D`-based input system, similar to how Cycling uses paths ([CYCLING.md](../cycling/CYCLING.md)).

## Open Design Questions

- How complex should stroke order validation be? (exact match vs. proximity-based)
- Should Scripts stack additively or multiplicatively?
- What is the duration range? (seconds? minutes? tied to quality?)
- Should Script recipes be unlocked via the advancement tree or found in adventures?
- The cycling view already has an "Auto: ON/OFF" toggle that chains cycles back to back. The player must still keep the cursor in the Madra Ball to earn anything ([CYCLING.md](../cycling/CYCLING.md)). What does an Auto-Cycle Script add: removing the cursor requirement, or running cycles while the view is closed?
