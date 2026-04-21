# Abilities System

## Overview

Abilities are the player's active toolkit in combat: damage attacks, self-buffs, and (future) utility effects. Each ability is a data-driven `AbilityData` resource defining costs, cooldown, cast time, and two lists of `CombatEffectData` — one routed to the enemy target, one routed to the caster. An ability needs an enemy target iff its `effects_on_target` array is non-empty.

The system has two halves:

- **Meta layer** — `AbilityManager` singleton owns which abilities the player has **unlocked** (via path tree purchases or innate starting grants) and which 4 are **equipped** into combat loadout slots. State is persisted in `SaveGameData`.
- **Combat runtime** — `CombatAbilityManager` + `CombatAbilityInstance` per combatant, instantiated at fight start from the combatant's `abilities: Array[AbilityData]`. Handles gate checks (casting lock, cooldown, resource cost), cast timer lifecycle, and effect application.

See [ABILITIES_MATRIX.md](ABILITIES_MATRIX.md) for a per-path table of every ability with full stats, scaling, and effect composition.

## Data Model

### AbilityData

Defined in [scripts/resource_definitions/abilities/ability_data.gd](../../scripts/resource_definitions/abilities/ability_data.gd). Each ability is a `.tres` file in [resources/abilities/](../../resources/abilities/).

| Field | Type | Description |
|-------|------|-------------|
| `ability_id` | `String` | Unique ID — used by `AbilityManager`, path unlocks, and save data |
| `ability_name` | `String` | Display name |
| `description` | `String` (multiline) | Tooltip description |
| `icon` | `Texture2D` | UI icon (64x64 preferred) |
| `ability_type` | `AbilityType` | Only `OFFENSIVE` exists today — flagged for rework (see COMBAT.md tech debt) |
| `madra_type` | `MadraType` | `NONE` (physical) or `PURE` — flavor axis, separate from damage type |
| `ability_source` | `AbilitySource` | `INNATE` (persists) or `PATH` (tied to path tree, resets on ascension) |
| `health_cost` / `madra_cost` / `stamina_cost` | `float` | Resources consumed on use |
| `base_cooldown` | `float` | Cooldown in seconds after cast resolves |
| `cast_time` | `float` | Pre-cast duration — `0` = instant |
| `effects_on_target` | `Array[CombatEffectData]` | Effects applied to the enemy target on execute (damage, debuffs). Non-empty means the ability requires an enemy target. |
| `effects_on_self` | `Array[CombatEffectData]` | Effects applied to the caster on execute (self-buffs, self-heals). Can be combined with `effects_on_target` for mixed abilities (e.g. lifesteal, rage-stacking attacks). |

### CombatEffectData

Effect composition lives in [scripts/resource_definitions/combat/combat_effect_data.gd](../../scripts/resource_definitions/combat/combat_effect_data.gd).

| Field | Type | Description |
|-------|------|-------------|
| `effect_type` | `EffectType` | `DAMAGE`, `HEAL`, `BUFF` |
| `base_value` | `float` | Flat starting value |
| `damage_type` | `DamageType` | `PHYSICAL`, `SPIRIT`, `TRUE` (ignores defense), `MIXED` (avg of both defenses) |
| `*_scaling` | `float` | Per-attribute coefficient — 8 fields: `strength_scaling`, `body_scaling`, `agility_scaling`, `spirit_scaling`, `foundation_scaling`, `control_scaling`, `resilience_scaling`, `willpower_scaling` |

**Damage formula** (see `calculate_damage()`):

```
raw   = base_value + Σ (caster.attribute[i] * scaling[i])
final = raw * (100 / (100 + target_defense))
```

Defense is `RESILIENCE` for `PHYSICAL`, `SPIRIT` for `SPIRIT`, `(RESILIENCE + WILLPOWER) / 2` for `MIXED`. `TRUE` bypasses defense entirely.

### BuffEffectData (extends CombatEffectData)

[scripts/resource_definitions/combat/buff_effect_data.gd](../../scripts/resource_definitions/combat/buff_effect_data.gd). Used for `effect_type = BUFF`.

| Field | Purpose |
|-------|---------|
| `buff_id` | Identity key — stacking/refresh lookup |
| `duration` | Seconds (default `5.0`) |
| `buff_type` | `ATTRIBUTE_MODIFIER_MULTIPLICATIVE`, `DAMAGE_OVER_TIME`, `OUTGOING_DAMAGE_MODIFIER`, `INCOMING_DAMAGE_MODIFIER` |
| `attribute_modifiers` | Dict `AttributeType → multiplier` (for attribute buffs) |
| `dot_damage_per_tick` + `dot_damage_type` | For DoT buffs (1s tick) |
| `damage_multiplier` | For outgoing/incoming damage modifier buffs |
| `consume_on_use` | If `true`, buff is consumed after one proc (e.g. Enforce) |

## Classification Axes

Two orthogonal enums classify each ability. Targeting is no longer an enum — it is *derived* from whether `effects_on_target` is populated:

- **`MadraType`** — flavor/identity, shown as a badge in UI. `NONE` = physical (Basic Strike, Enforce), `PURE` = Pure Madra path (Empty Palm, Power Font). Future paths will add `BLACKFLAME`, `EARTH`, etc. Note: this is independent of `damage_type` on the effect — a `MadraType.PURE` ability can still deal physical damage.
- **`AbilitySource`** — lifecycle. `INNATE` abilities are in the default `unlocked_ability_ids` and persist across path changes / ascensions. `PATH` abilities are granted by path tree nodes and will reset when the path progression rework fully wires ascension reset.

**Targeting derivation:**

| `effects_on_target` | `effects_on_self` | Ability role |
|---|---|---|
| empty | populated | Pure self-cast (e.g. Enforce). No enemy target needed. UI tag: *Self-Cast*. |
| populated | empty | Pure offensive (e.g. Basic Strike, Empty Palm). Needs an enemy target. UI tag: *Targeted*. |
| populated | populated | Mixed (e.g. Famishing Bite — damages target, applies Hunger to self). Needs an enemy target. UI tag: *Mixed*. |

## Lifecycle

```
Catalog (.tres files)         resources/abilities/*.tres
    │                         registered in ability_list.tres
    ▼
AbilityManager
   • _abilities_by_id         Dict[String → AbilityData] (built on _ready)
   • unlocked_ability_ids     from SaveGameData — grown by unlock_ability()
   • equipped_ability_ids     4-slot array — positions matter for Q/W/E/R binding
    │
    │ at combat start: AbilityManager.get_equipped_abilities() →
    │                  player CombatantData.abilities
    ▼
CombatAbilityManager (per combatant)
    │ setup(owner): for each AbilityData →
    ▼
CombatAbilityInstance (Node child, one per ability)
    │
    │ player clicks button / enemy AI picks ready ability
    ▼
use_ability_instance(instance, enemy)
    ├─ is_casting()?           reject (global lock)
    ├─ is_ready()?              reject (on cooldown)
    ├─ can_afford()?            reject (not enough HP/Madra/Stamina)
    ├─ consume_costs()          deduct resources immediately
    └─ instance.start_cast(enemy)
         │
         ├─ cast_time > 0?      enter casting state, start cast_timer,
         │                      emit cast_started → UI shows cast bar
         │                      on timeout → execute_ability(enemy)
         │
         └─ cast_time == 0      execute_ability(enemy) immediately

execute_ability(enemy)
    ├─ modified_attributes = base * buff_manager.get_attribute_modifier()
    ├─ if OFFENSIVE: outgoing_mod = buff_manager.consume_outgoing_modifier()
    ├─ for each effect in ability.effects_on_target:
    │     enemy.receive_effect(effect, modified_attributes, outgoing_mod)
    ├─ for each effect in ability.effects_on_self:
    │     owner.receive_effect(effect, modified_attributes, 1.0)
    │     (routes via CombatEffectManager → damage/heal/buff)
    └─ start cooldown_timer (ability.base_cooldown)
```

Key runtime invariants:

- **Global casting lock** — `CombatAbilityManager.is_casting()` blocks any new ability while *any* instance of the owner is mid-cast.
- **Initial cooldown** — all abilities start combat on a `1.5s` cooldown (`CombatAbilityInstance.INITIAL_COOLDOWN`) to prevent front-load bursting.
- **Modifier consumption** — outgoing damage modifiers (like Enforce) are consumed once per *offensive ability cast*, not per effect. Applied multiplicatively into damage at the target.

## AbilityManager (Singleton)

[singletons/ability_manager/ability_manager.gd](../../singletons/ability_manager/ability_manager.gd). Autoloaded. Mirrors the `CyclingManager` pattern.

**Catalog**: loaded from [resources/abilities/ability_list.tres](../../resources/abilities/ability_list.tres) (an `AbilityListData` resource holding an `Array[AbilityData]`). Indexed by `ability_id` in `_build_catalog_index()` at `_ready()`.

**State** (held on `SaveGameData`):

```gdscript
@export var unlocked_ability_ids: Array[String] = ["basic_strike", "enforce"]
@export var equipped_ability_ids: Array[String] = ["basic_strike", "enforce"]
```

Default save: both innate abilities unlocked and equipped. `MAX_SLOTS = 4`; `_ensure_equipped_array_size()` pads the equipped array with `""` to length 4.

**Public API**:

| Method | Purpose |
|--------|---------|
| `get_unlocked_abilities()` | `Array[AbilityData]` from unlocked IDs |
| `get_equipped_abilities()` | `Array[AbilityData]` from equipped slots (skips empty) |
| `get_ability_at_slot(i)` | ID at slot or `""` |
| `unlock_ability(id)` | Idempotent — no-op if already unlocked; emits `ability_unlocked` |
| `equip_ability(id)` | First empty slot; fails if locked or slots full |
| `equip_ability_at_slot(id, i)` | Explicit slot placement; clears previous slot holding this ID |
| `unequip_ability(id)` | Clears the ID from all slots |
| `swap_slots(a, b)` | Reorder equipped layout (drives Q/W/E/R position) |
| `is_ability_unlocked(id)` / `is_ability_equipped(id)` | Booleans |
| `get_max_slots()` / `get_filled_slot_count()` | Slot queries |
| `has_unequipped_unlocks()` | Drives the "new ability" badge on the Abilities SystemMenuButton |

**Signals**: `ability_unlocked(ability)` and `equipped_abilities_changed()`.

## Path Integration

Path tree nodes unlock abilities via `PathNodeEffectData.EffectType.UNLOCK_ABILITY` (enum value `8`). The effect's `string_value` is the `ability_id` (not a resource path).

`PathManager._apply_effect()` forwards the ID to `AbilityManager.unlock_ability(id)` — same pattern as `UNLOCK_CYCLING_TECHNIQUE` → `CyclingManager`.

Current Pure Madra unlocks (see [resources/path_progression/pure_madra/nodes/](../../resources/path_progression/pure_madra/nodes/)):

| Path Node | Unlocks Ability |
|-----------|-----------------|
| `pure_core_awakening` | `empty_palm` |
| `madra_strike` | `power_font` |

Future paths (`blackflame`, `earth` themes exist, tree data pending) will unlock their own abilities via the same mechanism.

## UI Surfaces

### AbilitiesView (meta loadout)

[scenes/abilities/abilities_view.tscn](../../scenes/abilities/abilities_view.tscn) — full-screen overlay pushed by `AbilitiesViewState` via the `open_abilities` input action (default: `A`).

- Left sidebar: 4 equipped slots with icons
- Main area: filter bar (All / Offensive / Buff / Equipped) + sort dropdown + scrolling card list
- `AbilityCard` scene — collapsed row (icon, name, badges, equipped dot) expands on click to show description, stats, and an EQUIP/UNEQUIP button

### Combat UI

| Component | Purpose |
|-----------|---------|
| `AbilityButton` | Icon + cooldown overlay + Q/W/E/R keyhint + cost strip (blue/gold/red) + can't-afford dimming |
| `AbilitiesPanel` | HBox of ability buttons + casting indicator + Q/W/E/R keybinding activation |
| `CombatAbilityTooltip` | Hover tooltip — icon, name, total DMG, cooldown, cast time, costs |
| `CombatBuffTooltip` | Hover tooltip for active buffs — name, description, live remaining duration, stacks |

Slot position in `equipped_ability_ids` directly drives Q/W/E/R binding order.

### AbilityStatsDisplay

[scenes/abilities/ability_stats_display/](../../scenes/abilities/ability_stats_display/) — reusable stat block rendering for cards and tooltips. See the 2026-04-13 design spec for layout rules.

## Persistence

All state lives on `SaveGameData`:

```gdscript
# Ability Manager
@export var unlocked_ability_ids: Array[String] = ["basic_strike", "enforce"]
@export var equipped_ability_ids: Array[String] = ["basic_strike", "enforce"]
```

`AbilityManager` holds `_live_save_data` reference from `PersistenceManager.save_game_data` and reconnects on `save_data_reset`. All mutations are direct writes — `PersistenceManager` handles saving.

## Adding a New Ability

1. **Create the `.tres`** in `resources/abilities/<ability_id>.tres` — set `ability_id`, name, description, icon, target/madra/source, costs, cooldown, cast time.
2. **Author the effect sub-resource(s)** — `CombatEffectData` for damage/heal, `BuffEffectData` for buffs. Set scaling coefficients per the attribute design (see [COMBAT.md attribute usage](../combat/COMBAT.md#attribute-usage-in-combat)).
3. **Register in the catalog** — add the resource to the `abilities` array in [resources/abilities/ability_list.tres](../../resources/abilities/ability_list.tres).
4. **Wire unlock**:
   - `INNATE` → add `ability_id` to `unlocked_ability_ids` default in `SaveGameData.gd` and `reset()`.
   - `PATH` → add an `UNLOCK_ABILITY` effect (type `8`) with `string_value = "<ability_id>"` to the appropriate path node `.tres`.
5. **Update the matrix** — add the ability to [ABILITIES_MATRIX.md](ABILITIES_MATRIX.md) under the correct path section.
6. **Test** — run GUT (`test_ability_manager.gd` covers unlock/equip paths). For balance, play through a combat encounter and watch damage numbers.

## Key Files

| File | Purpose |
|------|---------|
| [scripts/resource_definitions/abilities/ability_data.gd](../../scripts/resource_definitions/abilities/ability_data.gd) | `AbilityData` class — ability definition |
| [scripts/resource_definitions/abilities/ability_list_data.gd](../../scripts/resource_definitions/abilities/ability_list_data.gd) | `AbilityListData` — catalog container |
| [scripts/resource_definitions/combat/combat_effect_data.gd](../../scripts/resource_definitions/combat/combat_effect_data.gd) | `CombatEffectData` — damage/heal/buff base, damage formula |
| [scripts/resource_definitions/combat/buff_effect_data.gd](../../scripts/resource_definitions/combat/buff_effect_data.gd) | `BuffEffectData` — attribute/DoT/damage-mod buffs |
| [singletons/ability_manager/ability_manager.gd](../../singletons/ability_manager/ability_manager.gd) | Unlock/equip state authority |
| [resources/abilities/ability_list.tres](../../resources/abilities/ability_list.tres) | Catalog `.tres` |
| [resources/abilities/](../../resources/abilities/) | All ability `.tres` definitions |
| [scenes/combat/combatant/combat_ability_manager/combat_ability_manager.gd](../../scenes/combat/combatant/combat_ability_manager/combat_ability_manager.gd) | Per-combatant ability gate-keeping |
| [scenes/combat/combatant/combat_ability_manager/combat_ability_instance.gd](../../scenes/combat/combatant/combat_ability_manager/combat_ability_instance.gd) | Cast/cooldown lifecycle |
| [scenes/abilities/abilities_view.gd](../../scenes/abilities/abilities_view.gd) | Loadout management view |
| [scenes/abilities/ability_card/ability_card.gd](../../scenes/abilities/ability_card/ability_card.gd) | Card component (collapsed + expanded rows) |
| [scenes/ui/combat/ability_button/ability_button.gd](../../scenes/ui/combat/ability_button/ability_button.gd) | Combat ability button |
| [tests/unit/test_ability_manager.gd](../../tests/unit/test_ability_manager.gd) | Unlock/equip unit tests |

## Related Docs

- [ABILITIES_MATRIX.md](ABILITIES_MATRIX.md) — per-path ability data tables (the source of truth for numbers)
- [COMBAT.md](../combat/COMBAT.md) — combat runtime, attribute roles, damage formula context
- [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md) — how path nodes unlock abilities
- `docs/superpowers/specs/2026-04-12-ability-system-redesign.md` — historical spec for the current architecture
- `docs/superpowers/specs/2026-04-13-ability-stats-display-design.md` — stats display component spec
