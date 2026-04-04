# Character & Player State

## Overview

CharacterManager and PlayerManager together manage the player's persistent identity: attributes, abilities, and combat vitals.

## CharacterManager
- Manages 8 attributes (all default 10.0): STRENGTH, BODY, AGILITY, SPIRIT, FOUNDATION, CONTROL, RESILIENCE, WILLPOWER
- `get_total_attributes_data()` = base + bonuses (bonuses always return 0 — TODO)
- `get_equipped_abilities()` — hardcoded to 4 test abilities, not driven by save data
- `get_gold_multiplier()` — returns 1.0 (TODO)
- **Debug:** `get_total_attributes_data()` permanently adds +100 to STRENGTH

## PlayerManager
- Thin container for the player's persistent `VitalsManager` (used in combat)
- `VitalsManager` is created as a child node with `is_player = true`
- When `is_player`, connects to `CharacterManager.base_attribute_changed` for live updates

## Key Files

| File | Purpose |
|------|---------|
| `singletons/character_manager/character_manager.gd` | Attribute management |
| `singletons/player_manager/player_manager.gd` | Player VitalsManager container |

## Known Issues

- `_get_attribute_bonuses()` always returns 0 — equipment and cultivation bonuses are TODOs
- `get_equipped_abilities()` is hardcoded to 4 test abilities
- `get_gold_multiplier()` always returns 1.0
- Debug: +100 STRENGTH permanently added in `get_total_attributes_data()`
