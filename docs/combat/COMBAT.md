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
  Atmosphere                                — vignette + mist + motes (PR #24)
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
| `BODY` | Max health (BODY*10), max stamina (BODY*5) |
| `AGILITY` | Ability scaling (no cooldown reduction implemented) |
| `SPIRIT` | Spiritual damage scaling, Madra-type defense |
| `FOUNDATION` | Max madra (FOUNDATION*10) |
| `CONTROL` | Cooldown reduction (not yet implemented) |
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
| `health_cost` / `madra_cost` / `stamina_cost` | `float` | Resource costs |
| `base_cooldown` | `float` | Cooldown in seconds |
| `cast_time` | `float` | 0 = instant |
| `effects_on_target` | `Array[CombatEffectData]` | Effects applied to the enemy target (damage, debuffs). Non-empty ⇒ ability needs an enemy target. |
| `effects_on_self` | `Array[CombatEffectData]` | Effects applied to the caster (self-buffs, self-heals). |

### CombatEffectData
| Field | Type | Description |
|-------|------|-------------|
| `effect_type` | `EffectType` | `DAMAGE`, `HEAL`, `BUFF`, `CANCEL_CAST`, `STRIP_BUFFS` |
| `base_value` | `float` | Base effect value |
| `damage_type` | `DamageType` | `PHYSICAL`, `SPIRIT`, `TRUE`, `MIXED` |
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
- Max values derived from attributes: HP = `BODY*10`, Stamina = `BODY*5`, Madra = `FOUNDATION*10` (shared with `CharacterAttributesData.get_max_madra()`)
- Continuous passive regen each frame via `VitalsManager._process(delta)` — regen rates default to 0.0; only stamina regen is set to 1.0/s during adventures (by `adventure_view.gd`), reset to 0 on adventure end
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
- `strip_all_buffs()` wipes every active buff mid-combat (PR #39) — invoked by `STRIP_BUFFS` effects (Power Font). Distinct from `clear_all_buffs()` so end-of-combat cleanup and mid-combat buff-sunder stay separate

### Effect Resolution (CombatEffectManager)
| Type | Action |
|------|--------|
| `DAMAGE` | Calculate damage with attribute scaling + defense reduction, apply incoming modifier, deduct health |
| `HEAL` | Calculate value with attribute scaling, add health |
| `BUFF` | Cast to `BuffEffectData`, apply via `CombatBuffManager` |
| `CANCEL_CAST` | Interrupt the target's in-progress cast via `CombatAbilityManager.cancel_current_cast()` — emits `cast_cancelled`, hides the cast bar UI. No-op if target isn't casting. (PR #39) |
| `STRIP_BUFFS` | Remove every active buff on the target via `CombatBuffManager.strip_all_buffs()`. Distinct from `clear_all_buffs()`, which only runs on combat end. (PR #39) |

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
| `AbilityButton` | TextureButton + cooldown overlay + gold keyhint badge (Q/W/E/R) + color-coded cost strip (blue=madra, gold=stamina, red=health) + can't-afford dimming (PR #24) |
| `AbilitiesPanel` | HBox of ability buttons + casting indicator + Q/W/E/R keybinding activation (PR #24) |
| `CombatantInfoPanel` | Fully rebuilt in PR #15 — container-based layout, dark floating styleboxes, integer vitals display. Profile icon, 3 resource bars (HP/Madra/Stamina), buff container, abilities panel |
| `ResourceBar` | Main bar + ghost trail bar (delayed by 0.5s tween) + floating text spawner |
| `BuffIcon` | Buff texture + duration bar + stack count label + hover tooltip (PR #24) |
| `CombatAbilityTooltip` | Hover tooltip showing icon, name, total DMG, cooldown, cast time, and resource costs (PR #24) |
| `CombatBuffTooltip` | Hover tooltip showing buff name, effect description, live remaining duration, and stack count (PR #24) |
| `FloatingText` | Label that floats up 100px and fades over 1.5s, then self-destructs |

### Styleboxes (PRs #15, #24)

| File | Used By |
|------|---------|
| `assets/styleboxes/combat/panel_vitals.tres` | Vitals section background on `CombatantInfoPanel` |
| `assets/styleboxes/combat/panel_abilities.tres` | Abilities section background on `CombatantInfoPanel` |
| `assets/styleboxes/combat/panel_buffs.tres` | Buffs section background on `CombatantInfoPanel` |
| `assets/styleboxes/combat/cast_bar_fill.tres` | Gold fill on the cast progress bar |
| `assets/styleboxes/combat/panel_keyhint.tres` | Gold badge behind Q/W/E/R keybinding hints on ability buttons (PR #24) |

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

### Abilities

Full per-path ability stats, costs, cooldowns, cast times, damage types, and attribute scaling live in [ABILITIES_MATRIX.md](../abilities/ABILITIES_MATRIX.md). See [ABILITIES.md](../abilities/ABILITIES.md) for the ability system architecture (data model, lifecycle, unlock/equip flow).

### Attribute Usage in Combat

| Attribute | Offensive Use | Defensive Use | Vitals | Status |
|-----------|--------------|---------------|--------|--------|
| **STRENGTH** | Damage scaling (basic_strike) | — | — | Active |
| **BODY** | — | — | Max HP (BODY*10), Max Stamina (BODY*5) | **Core** |
| **AGILITY** | Damage scaling (basic_strike, empty_palm) | — | — | Active |
| **SPIRIT** | Damage scaling (empty_palm, power_font) | Spirit damage defense | — | **Core** |
| **FOUNDATION** | Damage scaling (power_font) | — | Max Madra (FND*10) | **Core** |
| **CONTROL** | — | — | — | **Inert** (cooldown reduction planned) |
| **RESILIENCE** | — | Physical + Mixed damage defense | — | Active (defense only) |
| **WILLPOWER** | — | Mixed damage defense (averaged with Resilience) | — | Weak |

### Enemies

Enemy `CombatantData` resources live in [resources/combat/combatant_data/](../../resources/combat/combatant_data/).

| Enemy | Attributes (STR/BODY/AGI/SPI/FND/CTRL/RES/WPR) | Abilities | Gold | Sprite |
|-------|------------------------------------------------|-----------|------|--------|
| `amorphous_spirit` | 0 / 10 / 0 / 0 / 10 / 0 / 0 / 0 (unset attrs default to 0) | inline `madra_lash` (2.0s cast, 10 base SPIRIT dmg, no scaling) | 0 (unset) | *(none set)* |

**Known anomalies:**
- `amorphous_spirit` only sets BODY and FOUNDATION in its attribute dict; missing keys resolve to 0, giving it 0 Spirit/Resilience/Willpower and no physical damage scaling. Also missing `texture` and `base_gold_drop`.
- `amorphous_spirit`'s `madra_lash` is defined inline as a sub-resource on the enemy — not in the shared ability catalog, so it doesn't show up in [ABILITIES_MATRIX.md](../abilities/ABILITIES_MATRIX.md).

### Combat Encounters

| Encounter | Used In | Choices | Notes |
|-----------|---------|---------|-------|
| `amorphous_spirit_encounter` | Foundation Beat 3a content | "Attack the Spirit" → fights `amorphous_spirit` | Real content encounter |

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
| `scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.gd` | Ability hover tooltip (PR #24) |
| `scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.gd` | Buff hover tooltip (PR #24) |
| `scripts/resource_definitions/combat/combat_effect_data.gd` | Damage/heal formula |
| `scripts/resource_definitions/combat/buff_effect_data.gd` | Buff definition |
| `scripts/resource_definitions/abilities/ability_data.gd` | Ability definition |

## Work Remaining

### Bugs

- ~~`[MEDIUM]` `damage_type = TRUE` works by accident~~ *(Fixed in PR #5)*
- ~~`[MEDIUM]` Madra defense log labels it `"WILLPOWER"` but reads `SPIRIT`~~ *(Fixed in PR #5)*
- ~~`[LOW]` `DamageType.MADRA` should be renamed to `DamageType.SPIRIT`~~ *(Fixed in PR #6 — renamed to `DamageType.SPIRIT`)*
- ~~`[LOW]` BuffIcon countdown runs independently of actual buff duration~~ *(Fixed in PR #6 — synced from authoritative ActiveBuff state)*
- ~~`[LOW]` `_dot_timer` starts unconditionally in `_ready()`~~ *(Fixed in PR #6 — only runs while DoT buffs active)*

### Missing Functionality

- `[HIGH]` Attribute system needs a design pass — each attribute's purpose, offensive vs defensive role, and scaling rules need to be clearly defined. Currently several attributes overlap, CONTROL is inert, and WILLPOWER's defensive role is unclear. A design doc should be created before further ability authoring
- ~~`[HIGH]` Equipment stats not wired to combat — `attack_power` and `defense` from gear are ignored. Tracked in [CHARACTER.md](../infrastructure/CHARACTER.md)~~ *(Fixed in PR #9)*
- `[HIGH]` `enemy_pool[0]` always used — no random selection from the pool. Every combat encounter uses the first enemy regardless of pool contents
- `[MEDIUM]` `AbilityType` needs a deep dive and rework — currently only has `OFFENSIVE`, only checked in one place (consuming outgoing damage modifier), and that logic belongs on `EffectType.DAMAGE` not `AbilityType`. Need to clarify: does AbilityType serve a gameplay purpose (e.g., casting rules, interrupt behavior) or is it just a UI/display hint? Rework or remove
- `[MEDIUM]` `ALL_ALLIES` target type has no implementation — only `SELF` and `SINGLE_ENEMY` work
- `[MEDIUM]` `CONTROL` attribute should reduce ability cooldowns — currently completely inert, needs a formula (e.g., `effective_cooldown = base_cooldown * (100 / (100 + CONTROL))`)
- `[MEDIUM]` No AP regeneration in combat — GDD describes AP regen; current implementation uses Madra with no in-combat regen
- `[LOW]` `percentage_value` on CombatEffectData is exported but never read in calculations

### Content

- `[HIGH]` Only 1 enemy exists (`amorphous_spirit`) — needs diverse enemies with different abilities, stats, and strategies
- `[MEDIUM]` `amorphous_spirit` has an incomplete attribute dict (only BODY + FOUNDATION set), no `texture`, and no `base_gold_drop`
- `[HIGH]` Only 4 player abilities exist — GDD describes 3 starter skills (Flowing Strike, Stand Your Ground, Empty Palm) plus a Cycle tap skill
- `[MEDIUM]` Player sprite hardcoded to `test_character_sprite.png` — needs to be driven by player/character data
- ~~`[LOW]` No ability unlock or progression system — abilities are hardcoded in `CharacterManager.get_equipped_abilities()`~~ *(Fixed in PR #22 — AbilityManager singleton with unlock/equip system)*

### UI

- ~~`[HIGH]` Ability icons don't disable or visually indicate when the player can't afford the cost (not enough madra/stamina) — ability just silently fails to cast~~ *(Fixed — can't-afford visual state dims icon and turns cost labels red)*
- ~~`[HIGH]` No ability tooltips — hovering over an ability icon shows no information (cost, cooldown, damage, description). New players can't learn the system without them~~ *(Fixed — CombatAbilityTooltip shows on hover)*
- ~~`[MEDIUM]` No buff tooltips — hovering over a buff icon shows no information (effect, duration remaining, stacks)~~ *(Fixed — CombatBuffTooltip shows on hover with live duration)*
- `[MEDIUM]` Enemy sprite placement needs improvement — current positioning is placeholder
- ~~`[LOW]` Cast bar visual (PNG) needs improvement~~ *(Fixed in PR #15 — `cast_bar_fill.tres` gold stylebox)*
- `[LOW]` Combat background should be modular — different adventure zones should have different combat backdrops

### Tech Debt

#### Dead Code
- ~~`[MEDIUM]` `enable_ai: bool` debug export on `AdventureCombat` — marked with `TODO: DELETE DEBUG`~~ *(Removed in PR #15)*
- `[LOW]` `CastTimer` label in scene with hardcoded debug text `"2.7 / 8.0s"`
- `[LOW]` `percentage_value` field exported but unused — remove or implement

#### Code Quality
- ~~`[LOW]` `+100 STRENGTH` debug modifier in `CharacterManager.get_total_attributes_data()`~~ *(Fixed in PR #3)*
