# Codebase State

Last updated: 2026-04-03

This document covers the technical health of the EndlessPath codebase — code quality issues, architectural concerns, bugs, and feature completeness per system.

## Architecture Summary

The codebase follows a clean separation:
- **13 autoload singletons** manage global state (loaded in dependency order via `project.godot`)
- **Resource definitions** (`scripts/resource_definitions/`) define data structures as Godot `Resource` subclasses
- **Scene scripts** (`scenes/`) contain behavior and UI logic
- **`.tres` data files** (`resources/`) instantiate resource classes with authored content
- **View state machine** (`MainView`) manages screen transitions via push/pop/change

The architecture is well-structured for a project at this stage. The data-driven design (resource classes + `.tres` files) is the right pattern for a game with many configurable entities.

---

## Critical Bugs

These will cause runtime errors or silent data loss:

| Bug | Location | Impact |
|-----|----------|--------|
| `reset_state()` vs `_reset_state()` naming mismatch | `persistence_manager.gd:21` calls `reset_state()`, but `save_game_data.gd:120` defines `_reset_state()` | Save reset silently fails or crashes |
| `reset_save_data = true` default | `persistence_manager.gd` export | Every boot wipes save data (dev flag) |
| `save_game_data._to_string()` references `inventory.items` | `save_game_data.gd:107` | `InventoryData` has no `items` property — runtime error in debug |
| Double signal connections in view states | `MainView._ready()` + `CyclingViewState._ready()` + `AdventureViewState._ready()` all connect to same ActionManager signals | State transitions fire twice per signal |

## Non-Critical Bugs

| Bug | Location | Impact |
|-----|----------|--------|
| Madra defense labeled "WILLPOWER" but reads SPIRIT | `combat_effect_data.gd:136` | Misleading log output |
| `damage_type = TRUE` has no explicit match case | `combat_effect_data.gd` | Works by accident (falls through to no-defense) |
| `_dot_timer` starts unconditionally in `_ready()` | `combat_buff_manager.gd` | Timer runs outside combat (no damage dealt, but unnecessary) |
| BuffIcon countdown independent of actual buff | `buff_icon.gd` | Visual duration can drift from actual |
| `_assign_path_tiles` infinite loop risk | `adventure_map_generator.gd:160` | No guard if `num_path_encounters > NoOp count` |
| `ChangeVitalsEffectData` uses `mana_change` | Not `madra_change` | Naming inconsistency |
| Forage timer not re-added to scene after stop | `action_manager.gd` | Timer node replaced but new one not added as child |

## Dead Code & Artifacts

| Item | Location | Notes |
|------|----------|-------|
| `AnimationPlayer` with `move_madra_ball` | `cycling_technique.tscn` | Replaced by Tween, never triggered |
| `CastTimer` label | `adventure_combat.tscn` | Hardcoded debug text "2.7 / 8.0s" |
| Debug buttons in adventure view | `adventure_view.tscn` | TODO comment to remove |
| `enable_ai: bool` export | `adventure_combat.gd` | TODO: DELETE DEBUG comment |
| `num_combats_in_map` variable | `adventure_map_generator.gd` | Declared, never read or written |
| `new_curve_2d.tres` at project root | Root directory | Shared curve, should be in `resources/cycling/` |
| +100 STRENGTH debug modifier | `character_manager.gd` | Hardcoded in `get_total_attributes_data()` |

## Unused Data Fields

Fields that are exported/defined but never read by any system:

| Field | Class | Notes |
|-------|-------|-------|
| `timing_window_ratio` | `CyclingZoneData` | Zone radius hardcoded to 20 |
| `madra_multiplier`, `cycle_duration_modifier`, `xp_multiplier`, `madra_cost_per_cycle` | `CyclingActionData` | Stored but never applied |
| `madra_cost_per_second` | `ForageActionData` | Never deducted |
| `experience_multiplier`, `difficulty_modifier` | `AdventureActionData` | Never read |
| `cooldown_seconds`, `daily_limit` | `AdventureActionData` | Never enforced |
| `percentage_value` | `CombatEffectData` | Exported, never used in calculations |
| `unlocking_mechanics`, `icon` | `AdvancementStageResource` | Defined, never consumed |
| `forage_active`, `forage_start_time` | `ZoneProgressionData` | Saved, never used on load |

## Singleton Dependency Concerns

| Concern | Details |
|---------|---------|
| Private method cross-boundary call | `ResourceManager` calls `CultivationManager._get_current_stage_resource()` (underscore = private) |
| Event ID magic strings | No enum or constants file for event IDs — scattered at call sites |
| Hardcoded ability list | `CharacterManager.get_equipped_abilities()` loads 4 specific `.tres` files |
| Hardcoded inventory slot count | `50` defined separately in `EquipmentGrid` and `InventoryManager` |

---

## Feature Completeness by System

### Cycling — ~75% Complete
| Feature | Status |
|---------|--------|
| Mouse tracking + Madra generation | Done |
| Zone clicking + Core Density XP | Done |
| Technique selection + persistence | Done |
| Resource panel UI | Done |
| Auto-cycle toggle | Done (no visual distinction on/off) |
| CyclingActionData modifiers (multipliers) | Defined, not wired |
| Multiple distinct techniques | 2 exist but share same path |
| Breakthrough / Tribulation | Stub |

### Combat — ~65% Complete
| Feature | Status |
|---------|--------|
| Real-time ability casting | Done |
| Cooldown system | Done |
| Cast bar system | Done |
| Buff/debuff system | Done |
| DoT damage | Done |
| Attribute-scaled damage | Done |
| Defense reduction | Done |
| Enemy AI (basic) | Done |
| Combat UI (bars, buttons, floating text) | Done |
| Multiple ability types (DEFENSIVE, HEALING) | Missing |
| Multi-target (ALL_ALLIES) | Missing |
| Multiple enemy selection from pool | Missing |
| AP regeneration in combat | Missing (GDD feature) |
| Equipment stat integration | Missing |

### Adventuring — ~60% Complete
| Feature | Status |
|---------|--------|
| Procedural hex map generation | Done |
| MST path connectivity | Done |
| Fog-of-war tile reveal | Done |
| Movement + stamina cost | Done |
| Encounter presentation + choices | Done |
| Combat encounters | Done |
| Dialogue encounters | Done |
| Timer system | Done |
| Boss encounter (furthest tile) | Done |
| Stamina feedback UI | Missing |
| Dynamic movement cost | Missing |
| Experience/difficulty modifiers | Missing |
| Cooldown/daily limits | Missing |
| Multiple adventure configurations | Only 1 test adventure exists |

### Inventory — ~50% Complete
| Feature | Status |
|---------|--------|
| Equipment grid (50 slots) | Done |
| Gear slots (8 paper doll) | Done |
| Drag & drop equip/unequip | Done |
| Materials tab | Done |
| Book animation | Done |
| Item description display | Done |
| Loot table system | Done (no authored content) |
| Equipment stat effects | Missing |
| Trash/delete items | Missing |
| Consumable item usage | Missing |
| Quest items | Missing |
| Loot table content | Missing |

### Zones — ~55% Complete
| Feature | Status |
|---------|--------|
| Hex tilemap rendering | Done |
| Zone selection + character movement | Done |
| Action display + routing | Done |
| Condition-based unlocking | Done |
| Forage action (timer + loot) | Done |
| Cycling action routing | Done |
| Adventure action routing | Done |
| NPC dialogue routing | Done |
| Merchant, Train Stats, Zone Event, Quest Giver | Missing |
| Offline forage resume | Missing |
| Action cooldowns/daily limits | Missing |

### Cultivation — ~30% Complete
| Feature | Status |
|---------|--------|
| Core Density XP + leveling | Done |
| Madra cap scaling | Done |
| Foundation stage resource | Done |
| Unlock condition system | Done |
| Event-triggered unlocks | Done |
| Breakthrough mechanic | Stub |
| Copper/Iron/Jade/Silver stages | Missing |
| Equipment stat bonuses | Missing |
| Gold multiplier system | Missing |
| GameSystem UI gating | Missing |

### Infrastructure — ~70% Complete
| Feature | Status |
|---------|--------|
| View state machine | Done |
| Autoload singleton architecture | Done |
| Save/load framework | Done |
| Log system (file + console + in-game) | Done |
| Dialogic integration | Done |
| Auto-save timer | Done |
| Input mappings | Done |
| Save data validation | Minimal (only zone ID check) |
| Save data reset | Broken (naming mismatch) |

---

## Technical Debt Priority

### High Priority (blocks gameplay features)
1. Fix `reset_state()` / `_reset_state()` naming mismatch
2. Set `reset_save_data = false` for persistence testing
3. Wire equipment stats to CharacterManager attribute bonuses
4. Remove +100 STRENGTH debug modifier
5. Fix double signal connections in view state machine

### Medium Priority (bugs and quality)
6. Apply CyclingActionData modifiers in cycling logic
7. Implement missing UnlockConditionData types (ITEM_OWNED, ZONE_UNLOCKED, etc.)
8. Create AdvancementStageResources for Copper/Iron/Jade/Silver
9. Remove dead code artifacts (debug buttons, AnimationPlayer, CastTimer)

### Low Priority (polish and future-proofing)
11. Centralize event ID strings into constants
12. Unify hardcoded slot count (50) into a single source of truth
13. Move `new_curve_2d.tres` to proper location
14. Add auto-cycle toggle visual distinction
15. Implement consumable/quest item support in InventoryManager
