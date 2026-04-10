# Character & Player State

## Overview

CharacterManager and PlayerManager together manage the player's persistent identity: attributes, abilities, and combat vitals.

## CharacterManager
- Manages 8 attributes (all default 10.0): STRENGTH, BODY, AGILITY, SPIRIT, FOUNDATION, CONTROL, RESILIENCE, WILLPOWER
- `get_total_attributes_data()` = base + bonuses (`_get_attribute_bonuses()` → `_get_equipment_bonuses()` sums all equipped gear's `attribute_bonuses` dictionaries — implemented in PR #9)
- `get_equipped_abilities()` — hardcoded to 4 test abilities, not driven by save data
- `get_gold_multiplier()` — returns 1.0 (TODO)
- ~~**Debug:** `get_total_attributes_data()` permanently adds +100 to STRENGTH~~ *(Fixed long ago)*

## PlayerManager
- Thin container for the player's persistent `VitalsManager` (used in combat)
- `VitalsManager` is created as a child node with `is_player = true`
- When `is_player`, connects to `CharacterManager.base_attribute_changed` for live updates

## Key Files

| File | Purpose |
|------|---------|
| `singletons/character_manager/character_manager.gd` | Attribute management |
| `singletons/player_manager/player_manager.gd` | Player VitalsManager container |

## Work Remaining

### Bugs

- ~~`[HIGH]` Debug: +100 STRENGTH permanently added in `get_total_attributes_data()`~~ *(Fixed in PR #3)*

### Missing Functionality

- ~~`[HIGH]` `_get_attribute_bonuses()` always returns 0 — equipment and cultivation bonuses never apply. Inventory equipment stats (`attack_power`, `defense`) are cosmetic until this is wired~~ *(Done in PR #9 — `_get_attribute_bonuses()` now sums equipped gear bonuses via `_get_equipment_bonuses()`)*
- `[HIGH]` Ability unlock and equip system — currently `get_equipped_abilities()` hardcodes 4 test `.tres` files. Needs: an unlocked ability pool (persisted in save data), an equipped ability loadout (subset of pool), and an unlock mechanism (stage advancement, adventure rewards, quest rewards, etc.)
- `[MEDIUM]` No player-facing character/stats screen — attributes, equipped gear, and abilities exist internally but the player has no way to view their character's strength. For a cultivation game where getting stronger is the core fantasy, players need to see their growth. Also needs to be the UI home for ability loadout management (which tab/view?)
- `[MEDIUM]` `get_gold_multiplier()` always returns 1.0 — intended to scale gold rewards but never implemented
- `[HIGH]` Attribute system needs a design pass — tracked in [COMBAT.md](../combat/COMBAT.md), owned here since CharacterManager manages attributes
