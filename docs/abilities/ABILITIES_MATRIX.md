# Abilities Matrix

Last updated: 2026-10-22

Every `AbilityData` resource in the project, player and enemy, with values read from the `.tres` files. This is the reference for ability numbers. For how abilities are unlocked, equipped and executed, see [ABILITIES.md](ABILITIES.md) and [COMBAT.md](../combat/COMBAT.md).

## Legend

- **Source / Madra**: `AbilitySource` (`INNATE` = unlocked on a new save, `PATH` = unlocked by a path node) and `MadraType` (`NONE`, `PURE`). Both are display-only. Enemy abilities leave them at the defaults `INNATE` / `NONE`.
- **Cost**: `H` Health, `M` Madra, `S` Stamina. Paid when the cast starts; not refunded if interrupted.
- **CD / Cast**: `base_cooldown` / `cast_time` in seconds. The cooldown starts when the cast resolves. A 0 s cooldown also means no 1.5 s opening cooldown and no cooldown after an interrupt.
- **Damage type** (defense used): `PHYSICAL` (target RESILIENCE), `SPIRIT` (target SPIRIT), `MIXED` (average of RESILIENCE and WILLPOWER), `TRUE` (none).
- **Scaling**: `value = base + Σ(caster attribute × coefficient)`; then `× 100 / (100 + defense)` for damage. `—` = 0.
- **Default math** assumes caster and target attributes of 10 (new save, no gear). Health 100, Stamina 50, Madra up to 100 per adventure.
- **Type / Tags**: what the Abilities book's details card would show. The type is its icon (`AbilitiesView._get_kind()`). The tags are the target shape plus any side effects (`AbilitiesView._describe_tags()`). Enemy abilities never appear in the book; their entries show what it would print.
- Unset fields in a `.tres` take the class default (effect type `DAMAGE`, damage type `PHYSICAL`, base 0, buff duration 5.0, `consume_on_use` false) and are listed here at that value.

## Catalog Check

| Check | Result |
|-------|--------|
| Player catalog `resources/abilities/ability_list.tres` | `basic_strike`, `empty_palm`, `enforce`, `power_font` |
| Player `.tres` files in `resources/abilities/` | The same four; nothing missing from the catalog, nothing in the catalog without a file |
| Enemy `.tres` files in `resources/combat/combatant_data/enemy_abilities/` | `madra_lash`, `famishing_bite`, `coalesce`; not in the catalog by design (referenced directly by enemy `CombatantData`) |
| Abilities defined inline as sub-resources on enemies | None (Madra Lash and Famishing Bite were extracted to files) |
| Abilities without an icon | `madra_lash`, `coalesce` (blank buttons in the enemy ability row) |
| Effects without an `effect_name` | `basic_strike` damage, `madra_lash` damage, `famishing_bite` damage and Hunger buff |

## Summary

| Ability | Name | Used by | Source / Madra | Cost | CD / Cast | On target | On self | Type / Tags |
|---------|------|---------|----------------|------|-----------|-----------|---------|------|
| `basic_strike` | Basic Strike | Player | INNATE / NONE | 3 S | 2.0 / 0.5 | PHYSICAL damage | — | Damage / Targeted |
| `enforce` | Enforce | Player | INNATE / NONE | 10 M | 15.0 / 1.0 | — | Outgoing ×1.5 buff, consumed | Buff / Self-cast |
| `empty_palm` | Empty Palm | Player | PATH / PURE | 8 M | 3.0 / 0 | SPIRIT damage + cancel cast | — | Damage / Targeted · Interrupts |
| `power_font` | Power Font | Player | PATH / PURE | 30 M | 25.0 / 3.0 | SPIRIT damage + strip buffs | — | Damage / Targeted · Strips buffs |
| `madra_lash` | Madra Lash | Amorphous Spirit, Coalescing Spirit | (defaults) | free | 0 / 2.0 | SPIRIT damage | — | Damage / Targeted |
| `famishing_bite` | Famishing Bite | Starving Dreadbeast, Ravenous Dreadbeast | (defaults) | free | 0 / 3.0 | PHYSICAL damage | Hunger: stacking outgoing ×1.5 | Damage / Mixed · Buffs you |
| `coalesce` | Coalesce | Coalescing Spirit | (defaults) | free | 30.0 / 5.0 | — | Heal | Heal / Self-cast |

## Damage at Default Attributes

| Ability | Raw value | vs target defense 10 | Other cases |
|---------|-----------|----------------------|-------------|
| `basic_strike` | 10 + 10×1.0 + 10×0.5 = 25 | 22.7 | With Enforce: 34.1 |
| `empty_palm` | 15 + 10×0.3 + 10×1.0 = 28 | 25.5 | vs Coalescing Spirit (SPIRIT 25): 22.4; with Enforce: 38.2 |
| `power_font` | 30 + 10×1.5 + 10×0.5 = 50 | 45.5 | vs Coalescing Spirit: 40.0; with Enforce: 68.2 |
| `madra_lash` (Amorphous Spirit, SPIRIT 10) | 10 | 9.1 | Coalescing Spirit (SPIRIT 25): raw 25 → 22.7 |
| `famishing_bite` (Starving Dreadbeast, STR 10) | 10 | 9.1, then ×1.5 per Hunger stack | Ravenous Dreadbeast (STR 15): raw 15 → 13.6; 5th consecutive bite ×5.06 |
| `coalesce` (Coalescing Spirit, SPIRIT 25) | heal 25×3.0 = 75 | — | Only cast when missing ≥ 75 Health |

Resource pacing for the player: Basic Strike can repeat every 2.5 s for 3 Stamina (Stamina regenerates 1/s in adventures). Empty Palm every 3 s for 8 Madra, Enforce every 16 s for 10 Madra, Power Font every 28 s for 30 Madra. Madra does not regenerate during an adventure, so a 100 Madra budget covers twelve Empty Palms or three Power Fonts across all fights in a run.

---

## Innate Abilities

On a new save both are in `unlocked_ability_ids` and `equipped_ability_ids` (slots 1 and 2).

### basic_strike — "Basic Strike"

> Strike the enemy with a purely physical attack.

| Field | Value |
|-------|-------|
| File | [resources/abilities/basic_strike.tres](../../resources/abilities/basic_strike.tres) |
| Icon | `assets/sprites/abilities/basic_strike.png` |
| Source / Madra | `INNATE` / `NONE` |
| Cost | 3 Stamina |
| Cooldown / Cast | 2.0 s / 0.5 s |
| `effects_on_target` | 1 × `DAMAGE` |
| `effects_on_self` | none |

**Target effect 1 — DAMAGE, PHYSICAL** (`effect_name` unset)

| Base | STR | BODY | AGI | SPI | FND | CTRL | RES | WPR |
|------|-----|------|-----|-----|-----|------|-----|-----|
| 10.0 | 1.0 | — | 0.5 | — | — | — | — | — |

### enforce — "Enforce"

> Enforce your body! Next attack to deal [1.5x] more damage!

| Field | Value |
|-------|-------|
| File | [resources/abilities/enforce.tres](../../resources/abilities/enforce.tres) |
| Icon | `assets/sprites/abilities/enforce.png` (also the buff icon) |
| Source / Madra | `INNATE` / `NONE` |
| Cost | 10 Madra |
| Cooldown / Cast | 15.0 s / 1.0 s |
| `effects_on_target` | none (no enemy target needed) |
| `effects_on_self` | 1 × `BUFF` (`BuffEffectData`) |

**Self effect 1 — BUFF**

| Field | Value |
|-------|-------|
| `effect_name` | `"Enforce"` |
| `effect_description` | `"Next attack deals [1.5x] damage!"` (not shown anywhere) |
| `buff_id` | `enforce_buff_effect` (tooltip title "Enforce Buff Effect") |
| `buff_type` | `OUTGOING_DAMAGE_MODIFIER` |
| `damage_multiplier` | 1.5 |
| `duration` | 5.0 s (default) |
| `consume_on_use` | `true` — consumed by the next cast of an ability whose `effects_on_target` contains `DAMAGE` |

No scaling. A cast with a 3 s cast time (Power Font) started right after Enforce resolves still lands inside the 5 s window.

---

## Pure Madra Path

Tree `pure_madra` ([pure_madra_tree.tres](../../resources/path_progression/pure_madra/pure_madra_tree.tres)): *"The path of Pure Madra. Versatile and balanced, specializing in disruption and neutralization of enemy techniques."* Combat identity: *"Neutralize, strip buffs, efficient strikes"*.

| Path node | Type | Cost | Prerequisite | Effects | `benefit_summary` |
|-----------|------|------|--------------|---------|-------------------|
| `pure_core_awakening` | KEYSTONE | 1 point | none (root) | `UNLOCK_ABILITY` `empty_palm`; `UNLOCK_CYCLING_TECHNIQUE` `smooth_flow` | "Empty Palm + Smooth Flow" |
| `power_font` | KEYSTONE | 1 point | `pure_core_awakening` | `UNLOCK_ABILITY` `power_font` | "Madra Strike unlocked" (stale name) |

Nodes that describe ability changes but have no effects (purchasing them changes nothing):

| Path node | Claims | Reality |
|-----------|--------|---------|
| `efficient_palm` | "-20% Palm Cost" | Empty Palm still costs 8 Madra |
| `lingering_silence` | "+2s Silence Duration" | Empty Palm has no silence |
| `focused_strike` | "+40% Strike Damage" ("Madra Strike") | No damage change |
| `strike_efficiency` | "-15% Stamina Cost" ("Madra Strike") | Power Font has no Stamina cost |

### empty_palm — "Empty Palm"

> A focused Pure Madra strike. Cancels the target's current cast if any.

| Field | Value |
|-------|-------|
| File | [resources/abilities/empty_palm.tres](../../resources/abilities/empty_palm.tres) |
| Icon | `assets/sprites/abilities/empty_palm.png` |
| Source / Madra | `PATH` / `PURE` |
| Cost | 8 Madra |
| Cooldown / Cast | 3.0 s / 0 s (instant) |
| `effects_on_target` | 2 — `DAMAGE` + `CANCEL_CAST` |
| `effects_on_self` | none |

**Target effect 1 — DAMAGE, SPIRIT** (`"Empty Palm Strike"`)

| Base | STR | BODY | AGI | SPI | FND | CTRL | RES | WPR |
|------|-----|------|-----|-----|-----|------|-----|-----|
| 15.0 | — | — | 0.3 | 1.0 | — | — | — | — |

**Target effect 2 — CANCEL_CAST** (`"Disrupting Palm"`): calls `CombatAbilityManager.cancel_current_cast()` on the target. If the target is casting, the cast stops, the target's ability goes on its full cooldown, and `cast_cancelled` hides the enemy's casting indicator. No value or scaling. Against 0 s-cooldown enemy abilities (Madra Lash, Famishing Bite) the enemy simply starts the cast again.

### power_font — "Power Font"

> Channel your body's Madra and release it in a cleansing wave — heavy damage and wipes every buff on the target.

| Field | Value |
|-------|-------|
| File | [resources/abilities/power_font.tres](../../resources/abilities/power_font.tres) |
| Icon | `assets/sprites/abilities/power_font.png` |
| Source / Madra | `PATH` / `PURE` |
| Cost | 30 Madra |
| Cooldown / Cast | 25.0 s / 3.0 s |
| `effects_on_target` | 2 — `DAMAGE` + `STRIP_BUFFS` |
| `effects_on_self` | none |

**Target effect 1 — DAMAGE, SPIRIT** (`"Sundering Font"`)

| Base | STR | BODY | AGI | SPI | FND | CTRL | RES | WPR |
|------|-----|------|-----|-----|-----|------|-----|-----|
| 30.0 | — | — | — | 1.5 | 0.5 | — | — | — |

**Target effect 2 — STRIP_BUFFS** (`"Sunder All Buffs"`): calls `CombatBuffManager.strip_all_buffs()` on the target, removing every active buff regardless of stacks (e.g. a dreadbeast's Hunger). No value or scaling. Damage resolves before the strip, so the strip does not affect this hit.

---

## Enemy Abilities

Referenced by enemy `CombatantData`; not in the player catalog. All are free (no costs), use the default `INNATE` / `NONE` classification, and are cast by `SimpleEnemyAI`. Enemy stats are in [COMBAT.md](../combat/COMBAT.md#enemies).

### madra_lash — "Madra Lash"

> Lashes at enemy scaling with Spirit

| Field | Value |
|-------|-------|
| File | [resources/combat/combatant_data/enemy_abilities/madra_lash.tres](../../resources/combat/combatant_data/enemy_abilities/madra_lash.tres) |
| Icon | none |
| Used by | `amorphous_spirit`, `coalescing_spirit` |
| Cost | none |
| Cooldown / Cast | 0 s / 2.0 s — no opening cooldown; recast as soon as the previous cast resolves |
| `effects_on_target` | 1 × `DAMAGE` |
| `effects_on_self` | none |

**Target effect 1 — DAMAGE, SPIRIT** (`effect_name` unset)

| Base | STR | BODY | AGI | SPI | FND | CTRL | RES | WPR |
|------|-----|------|-----|-----|-----|------|-----|-----|
| 0.0 | — | — | — | 1.0 | — | — | — | — |

### famishing_bite — "Famishing Bite"

> Bites enemy, increasing damage for 10seconds (stackable).

| Field | Value |
|-------|-------|
| File | [resources/combat/combatant_data/enemy_abilities/famishing_bite.tres](../../resources/combat/combatant_data/enemy_abilities/famishing_bite.tres) |
| Icon | `assets/sprites/abilities/famishing_bite.png` (also the Hunger buff icon) |
| Used by | `starving_dreadbeast`, `ravenous_dreadbeast` |
| Cost | none |
| Cooldown / Cast | 0 s / 3.0 s — no opening cooldown; bites back to back |
| `effects_on_target` | 1 × `DAMAGE` |
| `effects_on_self` | 1 × `BUFF` (Hunger) |

**Target effect 1 — DAMAGE, PHYSICAL** (`effect_name` unset)

| Base | STR | BODY | AGI | SPI | FND | CTRL | RES | WPR |
|------|-----|------|-----|-----|-----|------|-----|-----|
| 0.0 | 1.0 | — | — | — | — | — | — | — |

**Self effect 1 — BUFF "Hunger"**

| Field | Value |
|-------|-------|
| `buff_id` | `hunger` |
| `effect_name` | unset |
| `buff_type` | `OUTGOING_DAMAGE_MODIFIER` |
| `damage_multiplier` | 1.5 per stack, compounding (`1.5 ^ stack_count`) |
| `duration` | 10.0 s, refreshed by every bite |
| `consume_on_use` | `false` |
| Stack cap | none |

Order matters: the bite's damage uses the Hunger stacks present before the cast, then a stack is added. Consecutive bites deal ×1, ×1.5, ×2.25, ×3.375, ×5.06… Power Font resets the chain.

### coalesce — "Coalesce"

> Heals self

| Field | Value |
|-------|-------|
| File | [resources/combat/combatant_data/enemy_abilities/coalesce.tres](../../resources/combat/combatant_data/enemy_abilities/coalesce.tres) |
| Icon | none |
| Used by | `coalescing_spirit` |
| Cost | none |
| Cooldown / Cast | 30.0 s / 5.0 s (1.5 s opening cooldown applies) |
| `effects_on_target` | none |
| `effects_on_self` | 1 × `HEAL` |

**Self effect 1 — HEAL** (`"Heal"`)

| Base | STR | BODY | AGI | SPI | FND | CTRL | RES | WPR |
|------|-----|------|-----|-----|-----|------|-----|-----|
| 0.0 | — | — | — | 3.0 | — | — | — | — |

The AI casts it only when the spirit is missing at least the full heal amount (75 Health at SPIRIT 25). Its 5 s cast is the longest interrupt window in the game, and because Coalesce has a non-zero cooldown, an Empty Palm interrupt puts it on its full 30 s cooldown.

---

## Scaling Reference

One row per effect. `T` = `effects_on_target`, `S` = `effects_on_self`.

| Ability | Effect | Kind | Base | Damage type | STR | BODY | AGI | SPI | FND | CTRL | RES | WPR |
|---------|--------|------|------|-------------|-----|------|-----|-----|-----|------|-----|-----|
| `basic_strike` | T1 | DAMAGE | 10 | PHYSICAL | 1.0 | — | 0.5 | — | — | — | — | — |
| `enforce` | S1 | BUFF `enforce_buff_effect` (outgoing ×1.5, 5 s, consumed) | — | — | — | — | — | — | — | — | — | — |
| `empty_palm` | T1 | DAMAGE | 15 | SPIRIT | — | — | 0.3 | 1.0 | — | — | — | — |
| `empty_palm` | T2 | CANCEL_CAST | — | — | — | — | — | — | — | — | — | — |
| `power_font` | T1 | DAMAGE | 30 | SPIRIT | — | — | — | 1.5 | 0.5 | — | — | — |
| `power_font` | T2 | STRIP_BUFFS | — | — | — | — | — | — | — | — | — | — |
| `madra_lash` | T1 | DAMAGE | 0 | SPIRIT | — | — | — | 1.0 | — | — | — | — |
| `famishing_bite` | T1 | DAMAGE | 0 | PHYSICAL | 1.0 | — | — | — | — | — | — | — |
| `famishing_bite` | S1 | BUFF `hunger` (outgoing ×1.5 per stack, 10 s, stacking) | — | — | — | — | — | — | — | — | — | — |
| `coalesce` | S1 | HEAL | 0 | — | — | — | — | 3.0 | — | — | — | — |

No ability scales with BODY, CONTROL, RESILIENCE or WILLPOWER, and none deals `MIXED` or `TRUE` damage.

## Planned Paths

Blackflame and Earth have theme resources only (`resources/path_progression/themes/blackflame_theme.tres`, `earth_theme.tres`); there are no trees, nodes or abilities, and `MadraType` has no matching values. When added, their abilities will be `ability_source = PATH` with new `MadraType` entries.

## Maintenance Notes

- When an ability `.tres` changes, update its section, the Summary, the default-math row and the Scaling Reference in the same commit.
- New player abilities must also go into `resources/abilities/ability_list.tres`; enemy abilities go in `resources/combat/combatant_data/enemy_abilities/` and stay out of the catalog.
- List effective values: if a field is unset in the `.tres`, write the class default.
- Sanity-check numbers in a real fight: `CombatEffectData.calculate_value()` and `calculate_damage()` log every term to the `Log` output.
