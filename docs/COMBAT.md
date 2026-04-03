# Combat System

## Overview

Combat is a real-time system embedded within the Adventure mode. When the player selects a combat encounter on the hex map, the tilemap hides and two combatants (player and enemy) face off using ability-based combat. Abilities cost resources (HP/Madra/Stamina), have cooldowns and optional cast times, and can apply damage, healing, or buffs. The enemy uses a simple AI that casts the first available ability each frame.

## Player Experience

1. Player encounters a combat tile during an adventure and selects the fight choice
2. Combat view appears with player sprite (left) and enemy sprite (right)
3. All abilities start on a 1.5-second initial cooldown
4. Player clicks ability icons to cast — abilities may fire instantly or have a cast bar
5. Damage numbers float off health bars; a ghost trail shows recent damage
6. Enemy AI automatically uses abilities when ready
7. Combat ends when either combatant's health reaches 0
8. Victory awards gold (multi-factor formula); defeat ends the adventure

## Architecture

```
AdventureCombat (Node2D)                    — adventure_combat.gd
  CanvasLayer
    EnemyInfoPanel (CombatantInfoPanel)     — combatant_info_panel.gd

CombatantNode (Node2D)                      — combatant_node.gd (2 per fight, runtime)
  CombatAbilityManager (Node)               — combat_ability_manager.gd
    AbilityInstance_* (Node)                 — combat_ability_instance.gd (per ability)
  VitalsManager (Node)                      — vitals_manager.gd
  CombatEffectManager (Node)                — combat_effect_manager.gd
  CombatBuffManager (Node)                  — combat_buff_manager.gd
    _dot_timer (Timer)                      — 1s interval for DoT ticks
  Sprite2D
```

The player's `VitalsManager` is a persistent node from `PlayerManager` — it survives between fights. The enemy always gets a fresh local `VitalsManager`.

The `PlayerInfoPanel` lives in `AdventureView`, not inside `AdventureCombat`.

## Data Model

### CharacterAttributesData (8 attributes)
| Attribute | Combat Role |
|-----------|-------------|
| `STRENGTH` | Physical damage scaling |
| `BODY` | Max health (100 + BODY*10), max stamina (50 + BODY*5) |
| `AGILITY` | Ability scaling (no cooldown reduction implemented) |
| `SPIRIT` | Spiritual damage scaling, Madra-type defense |
| `FOUNDATION` | Max madra (50 + FOUNDATION*10) |
| `CONTROL` | Defined, no runtime use |
| `RESILIENCE` | Physical damage reduction |
| `WILLPOWER` | Spiritual damage reduction |

Default: all attributes start at 10.0.

### CombatantData
| Field | Type | Description |
|-------|------|-------------|
| `character_name` | `String` | Display name |
| `attributes` | `CharacterAttributesData` | Stat block |
| `abilities` | `Array[AbilityData]` | Available abilities |
| `texture` | `Texture2D` | Sprite |
| `base_gold_drop` | `int` | Gold reward on defeat |

### AbilityData
| Field | Type | Description |
|-------|------|-------------|
| `ability_id` | `String` | Unique identifier |
| `ability_name` | `String` | Display name |
| `ability_type` | `AbilityType` | Only `OFFENSIVE` exists |
| `target_type` | `TargetType` | `SELF`, `SINGLE_ENEMY`, `ALL_ALLIES` |
| `health_cost` / `madra_cost` / `stamina_cost` | `float` | Resource costs |
| `base_cooldown` | `float` | Cooldown in seconds |
| `cast_time` | `float` | 0 = instant |
| `effects` | `Array[CombatEffectData]` | Effects applied on hit |

### CombatEffectData
| Field | Type | Description |
|-------|------|-------------|
| `effect_type` | `EffectType` | `DAMAGE`, `HEAL`, `BUFF` |
| `base_value` | `float` | Base effect value |
| `damage_type` | `DamageType` | `PHYSICAL`, `MADRA`, `TRUE`, `MIXED` |
| `*_scaling` | `float` | Per-attribute scaling (8 fields) |

**Damage formula:** `base_value + sum(attribute * scaling)`, then defense reduction: `damage * (100 / (100 + defense))`.

### BuffEffectData (extends CombatEffectData)
| Field | Type | Description |
|-------|------|-------------|
| `buff_id` | `String` | Identity key for stacking/lookup |
| `duration` | `float` | Seconds |
| `buff_type` | `BuffType` | `ATTRIBUTE_MODIFIER_MULTIPLICATIVE`, `DAMAGE_OVER_TIME`, `OUTGOING_DAMAGE_MODIFIER`, `INCOMING_DAMAGE_MODIFIER` |
| `attribute_modifiers` | `Dictionary` | For multiplicative buffs |
| `dot_damage_per_tick` | `float` | For DoT buffs |
| `damage_multiplier` | `float` | For damage modifier buffs |
| `consume_on_use` | `bool` | If true, buff consumed on first proc |

## Core Systems

### Vitals (HP / Madra / Stamina)
- Max values derived from attributes: HP = `100 + BODY*10`, Stamina = `50 + BODY*5`, Madra = `50 + FOUNDATION*10`
- Continuous passive regen each frame via `_process(delta)` — currently only stamina regen is non-zero during adventures
- `apply_vitals_change(health, stamina, madra)` clamps all values to `[0, max]`
- Player VitalsManager reconnects to `CharacterManager.base_attribute_changed` for live stat updates

### Ability Lifecycle
1. `CombatAbilityManager.use_ability_instance(instance, enemy)` — gate checks (casting lock, cooldown, afford)
2. `consume_costs()` — deducts HP/Madra/Stamina immediately
3. If `cast_time > 0`: cast bar phase with `cast_timer`, then `execute_ability(target)` on timeout
4. If `cast_time == 0`: `execute_ability(target)` immediately
5. `execute_ability`: gets buff-modified attributes, optionally consumes outgoing damage modifier, applies each effect to target via `target.receive_effect(effect, modified_attributes)`
6. Cooldown starts (`base_cooldown` seconds)

A global casting lock prevents firing multiple abilities simultaneously.

### Buff System
- `apply_buff(buff_data)` — if buff_id already exists, refreshes duration (and stacks for DoT)
- `_process(delta)` ticks all buff durations, removes expired/consumed buffs
- DoT damage: separate 1-second timer, damage = `dot_damage_per_tick * stack_count`
- Modifier queries: `get_attribute_modifier()`, `get_outgoing_damage_modifier()`, `get_incoming_damage_modifier()` — all multiplicative
- `clear_all_buffs()` called on combat end

### Effect Resolution (CombatEffectManager)
| Type | Action |
|------|--------|
| `DAMAGE` | Calculate damage with attribute scaling + defense reduction, apply incoming modifier, deduct health |
| `HEAL` | Calculate value with attribute scaling, add health |
| `BUFF` | Cast to `BuffEffectData`, apply via `CombatBuffManager` |

### Enemy AI (SimpleEnemyAI)
- Every `_process` frame: iterates all abilities in order
- Casts the first one that is off cooldown and affordable
- No priority system, target evaluation, or health-based decision making

## Combat Flow

```
1. Player selects CombatChoice on hex tile
   → AdventureTilemap.start_combat signal
   → AdventureView._on_start_combat()

2. AdventureCombat.initialize_combat(choice, action_data)
   → Create player CombatantNode (pos 400,1000) with PlayerManager.vitals_manager
   → Create enemy CombatantNode (pos 1100,300) from enemy_pool[0]
   → Wire UI panels, start SimpleEnemyAI

3. Real-time combat
   → Player clicks ability buttons → ability_selected → use_ability_instance
   → Enemy AI auto-casts each frame
   → Effects resolve through CombatEffectManager
   → Buffs tick via CombatBuffManager

4. Victory/Defeat
   → health <= 0 triggers trigger_combat_end(successful, gold)
   → Gold = floor(base_gold * combat_mult * adventure_mult * char_mult)
   → AdventureView._on_stop_combat → combat.stop() → cleanup

5. Post-combat
   → Victory: gold awarded, success_effects applied, tile completed
   → Defeat: ActionManager.stop_action(false), adventure ends
```

## Combat UI

| Component | Description |
|-----------|-------------|
| `AbilityButton` | TextureButton + cooldown overlay (TextureProgressBar + Label) |
| `AbilitiesPanel` | HBox of ability buttons + casting indicator with progress bar |
| `CombatantInfoPanel` | Profile icon, 3 resource bars, buff container, abilities panel |
| `ResourceBar` | Main bar + ghost trail bar (delayed by 0.5s tween) + floating text spawner |
| `BuffIcon` | Buff texture + duration bar + stack count label |
| `FloatingText` | Label that floats up 100px and fades over 1.5s, then self-destructs |

## Integration Points

| System | Connection |
|--------|------------|
| Adventure | `CombatChoice` supplies enemy data; combat result feeds back to tilemap |
| ResourceManager | Gold awarded via `ResourceManager.add_gold()` on victory |
| InventoryManager | Loot via `AwardLootTableEffectData` / `AwardItemEffectData` in choice effects |
| CharacterManager | Player attributes via `get_total_attributes_data()`, abilities via `get_equipped_abilities()` |
| PlayerManager | Persistent `VitalsManager` survives between fights |
| LogManager | Damage/heal events logged with BBCode formatting |

## Existing Content

| Ability | Type | Cost | Cooldown | Cast | Effect |
|---------|------|------|----------|------|--------|
| `basic_strike` | Offensive | 5 stamina | 2.0s | 0s | Damage, STR+AGI scaling |
| `empty_palm` | Offensive | 30 stamina | 8.0s | 0s | High damage, STR scaling |
| `enforce` | Self-buff | 10 madra | 8.0s | 0s | STR/SPIRIT x1.5 for 10s |
| `power_font` | Offensive | 10 madra | 5.0s | 3.0s | Damage, SPIRIT scaling |
| `test_ability` | Offensive | 10 stamina | 3.0s | 0s | Damage, STR scaling |
| `test_cast_ability` | Offensive | 0 | 5.0s | 2.0s | Damage, STR scaling |

One enemy exists: `test_enemy` (attributes default 10, uses `test_cast_ability`, drops 10 gold).

## Key Files

| File | Purpose |
|------|---------|
| `scenes/combat/adventure_combat/adventure_combat.gd` | Combat orchestrator |
| `scenes/combat/combatant/combatant_node.gd` | Combatant composition root |
| `scenes/combat/combatant/combat_ability_manager/combat_ability_manager.gd` | Ability gate-keeping |
| `scenes/combat/combatant/combat_ability_manager/combat_ability_instance.gd` | Cast/cooldown lifecycle |
| `scenes/combat/combatant/combat_buff_manager/combat_buff_manager.gd` | Buff management |
| `scenes/combat/combatant/combat_effect_manager/combat_effect_manager.gd` | Effect routing |
| `scenes/combat/combatant/vitals_manager/vitals_manager.gd` | HP/Madra/Stamina tracking |
| `scenes/combat/ai/simple_enemy_ai.gd` | Enemy decision loop |
| `scripts/resource_definitions/combat/combat_effect_data.gd` | Damage/heal formula |
| `scripts/resource_definitions/combat/buff_effect_data.gd` | Buff definition |
| `scripts/resource_definitions/abilities/ability_data.gd` | Ability definition |

## Known Issues

- **No AP regeneration in combat.** The GDD describes AP regen; implementation uses Madra with no in-combat regen
- `AbilityType` only has `OFFENSIVE` — no DEFENSIVE, UTILITY, or HEALING types
- `ALL_ALLIES` target type has no implementation — only single-target works
- `percentage_value` on CombatEffectData is exported but never read
- `CONTROL` and `AGILITY` attributes have no runtime effects beyond damage scaling
- `damage_type = TRUE` works by accident (falls through to no-defense case)
- Madra defense uses `SPIRIT` attribute but labels it `"WILLPOWER"` — mismatch
- `enemy_pool[0]` always used — no random selection or multi-enemy support
- Player sprite hardcoded to `test_character_sprite.png`
- `enable_ai` debug export still present on `AdventureCombat`
- `_dot_timer` runs unconditionally from `_ready()`, even outside combat
- BuffIcon countdown runs independently of actual buff duration — can drift
- Leftover `CastTimer` label in scene with hardcoded debug text
