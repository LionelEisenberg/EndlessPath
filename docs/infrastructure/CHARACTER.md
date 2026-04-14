# Character & Player State

## Overview

CharacterManager and PlayerManager together manage the player's persistent identity: attributes, abilities, and combat vitals.

## CharacterManager
- Manages 8 attributes (all default 10.0): STRENGTH, BODY, AGILITY, SPIRIT, FOUNDATION, CONTROL, RESILIENCE, WILLPOWER
- `get_total_attributes_data()` = base + bonuses (`_get_attribute_bonuses()` → `_get_equipment_bonuses()` sums all equipped gear's `attribute_bonuses` dictionaries — implemented in PR #9)
- ~~`get_equipped_abilities()` — hardcoded to 4 test abilities~~ Removed in PR #22; abilities now managed by `AbilityManager` singleton
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
| `singletons/ability_manager/ability_manager.gd` | Ability unlock/equip state (PR #22) |

## Work Remaining

### Bugs

- ~~`[HIGH]` Debug: +100 STRENGTH permanently added in `get_total_attributes_data()`~~ *(Fixed in PR #3)*

### Missing Functionality

- ~~`[HIGH]` `_get_attribute_bonuses()` always returns 0 — equipment and cultivation bonuses never apply. Inventory equipment stats (`attack_power`, `defense`) are cosmetic until this is wired~~ *(Done in PR #9 — `_get_attribute_bonuses()` now sums equipped gear bonuses via `_get_equipment_bonuses()`)*
- ~~`[HIGH]` Ability unlock and equip system~~ *(Done in PR #22 — AbilityManager singleton with unlock/equip/4-slot loadout, AbilitiesView UI with drag-drop, filter/sort, stat tooltips. Path tree UNLOCK_ABILITY effects wire to AbilityManager)*
- `[MEDIUM]` No player-facing character/stats screen — AbilitiesView (PR #22) covers ability loadout, but player still can't see attributes, equipped gear, and cultivation progress in one place
- `[MEDIUM]` `get_gold_multiplier()` always returns 1.0 — intended to scale gold rewards but never implemented
- `[HIGH]` Attribute system needs a design pass — tracked in [COMBAT.md](../combat/COMBAT.md), owned here since CharacterManager manages attributes
