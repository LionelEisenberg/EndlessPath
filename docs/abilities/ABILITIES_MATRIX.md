# Abilities Matrix

Per-path reference table for every ability in the game: costs, timing, damage type, attribute scaling, and buff composition. This doc is the **source of truth for ability numbers** — all values here mirror the `.tres` resources in [resources/abilities/](../../resources/abilities/).

For how abilities are defined, unlocked, equipped, and executed at runtime, see [ABILITIES.md](ABILITIES.md).

## Legend

- **Source**: `INNATE` = unlocked by default, persists across path changes. `PATH` = unlocked via a path tree node, tied to the current path.
- **Madra**: flavor type (separate from damage type). `NONE` = physical / non-Madra. `PURE` = Pure Madra path identity.
- **Target**: `SELF` / `SINGLE_ENEMY` / `ALL_ALLIES` (last unimplemented).
- **Cost**: resource costs paid on cast start. `H` = health, `M` = madra, `S` = stamina.
- **CD / Cast**: base cooldown / cast time in seconds. `0s` cast = instant.
- **Scaling**: attribute coefficients applied to `base_value` — `STR 1.0` means `+1.0 × caster STRENGTH` added to effect value.
- **Damage type**: `PHYSICAL` (reduced by Resilience), `SPIRIT` (reduced by Spirit), `TRUE` (ignores defense), `MIXED` (avg of Resilience + Willpower).
- **Default attributes** at character creation: all 8 stats start at `10.0`.

---

## Innate Abilities

Granted on new save — included in `unlocked_ability_ids` and `equipped_ability_ids` defaults. Persist across ascensions and path changes.

### basic_strike — "Basic Strike"

> Strike the enemy with a purely physical attack.

| Field | Value |
|-------|-------|
| Source / Madra | `INNATE` / `NONE` |
| Target | `SINGLE_ENEMY` |
| Cost | 3 S |
| Cooldown / Cast | 2.0s / 0.5s |
| Effects | 1 × damage |

**Effect 1 — damage (PHYSICAL)**

| Base | STR | BODY | AGI | SPI | FND | CTRL | RES | WPR |
|------|-----|------|-----|-----|-----|------|-----|-----|
| 10.0 | 1.0 | — | 0.5 | — | — | — | — | — |

*At default attributes (all 10): raw damage = 10 + (10×1.0) + (10×0.5) = 25, vs 10 Resilience → `25 × 100/110 ≈ 22.7` damage.*

[resources/abilities/basic_strike.tres](../../resources/abilities/basic_strike.tres)

### enforce — "Enforce"

> Enforce your body! Next attack to deal [1.5x] more damage!

| Field | Value |
|-------|-------|
| Source / Madra | `INNATE` / `NONE` |
| Target | `SELF` |
| Cost | 10 M |
| Cooldown / Cast | 15.0s / 1.0s |
| Effects | 1 × buff (outgoing damage modifier, consumed on use) |

**Effect 1 — buff**

| Field | Value |
|-------|-------|
| `buff_id` | `enforce_buff_effect` |
| `buff_type` | `OUTGOING_DAMAGE_MODIFIER` |
| `damage_multiplier` | ×1.5 |
| `duration` | 5.0s (default) |
| `consume_on_use` | `true` — consumed by the next offensive ability |

Applied via the buff's `damage_multiplier`, not attribute scaling — no `*_scaling` values used.

[resources/abilities/enforce.tres](../../resources/abilities/enforce.tres)

---

## Pure Madra Path

Path identity: *"Versatile and balanced, specializing in disruption and neutralization of enemy techniques."* See [resources/path_progression/pure_madra/pure_madra_tree.tres](../../resources/path_progression/pure_madra/pure_madra_tree.tres).

| Path Node | Unlocks | Cost | Tier |
|-----------|---------|------|------|
| `pure_core_awakening` | `empty_palm` (+ `smooth_flow` cycling technique) | root node | 1 |
| `madra_strike` | `power_font` | 2 points (after `pure_core_awakening`) | 1 |

### empty_palm — "Empty Palm"

> Infuse a strike with Madra and push it through the enemy's core.

| Field | Value |
|-------|-------|
| Source / Madra | `PATH` / `PURE` |
| Target | `SINGLE_ENEMY` |
| Cost | 12 M, 3 S |
| Cooldown / Cast | 3.0s / 0s |
| Effects | 1 × damage |

**Effect 1 — damage (PHYSICAL)**

| Base | STR | BODY | AGI | SPI | FND | CTRL | RES | WPR |
|------|-----|------|-----|-----|-----|------|-----|-----|
| 10.0 | — | — | 0.3 | 1.0 | — | — | — | — |

> **Note:** `madra_type = PURE` but `damage_type = PHYSICAL` — the ability is Pure Madra in flavor/identity but the palm strike resolves against physical defense (Resilience). This is intentional composition flexibility.

[resources/abilities/empty_palm.tres](../../resources/abilities/empty_palm.tres)

### power_font — "Power Font"

> After a short moment to channel your body's madra into your palms, you throw a wave of power at the enemy with the might of your entire spirit!

| Field | Value |
|-------|-------|
| Source / Madra | `PATH` / `PURE` |
| Target | `SINGLE_ENEMY` |
| Cost | 20 M |
| Cooldown / Cast | 15.0s / 3.0s |
| Effects | 1 × damage |

**Effect 1 — damage (SPIRIT)**

| Base | STR | BODY | AGI | SPI | FND | CTRL | RES | WPR |
|------|-----|------|-----|-----|-----|------|-----|-----|
| 30.0 | — | — | — | 1.5 | 0.5 | — | — | — |

*At default attributes: raw = 30 + (10×1.5) + (10×0.5) = 50, vs 10 Spirit → `50 × 100/110 ≈ 45.5` damage. Heavy payoff for the 3s cast.*

[resources/abilities/power_font.tres](../../resources/abilities/power_font.tres)

---

## Blackflame Path (planned)

Theme exists at [resources/path_progression/themes/blackflame_theme.tres](../../resources/path_progression/themes/blackflame_theme.tres), but the path tree and abilities are not yet authored. When added, abilities here will be `ability_source = PATH`, `madra_type = BLACKFLAME` (enum extension needed).

*No abilities defined yet.*

## Earth Path (planned)

Theme exists at [resources/path_progression/themes/earth_theme.tres](../../resources/path_progression/themes/earth_theme.tres), tree pending. `madra_type = EARTH` enum extension will be required.

*No abilities defined yet.*

---

## Scaling Reference

One row per ability. All 8 attribute scaling coefficients, base value, damage type, and the effect composition. Dashes = zero / not applicable. Multiple effects per ability list as separate rows tagged `(E1)`, `(E2)`, etc.

| Ability | Base | Damage Type | STR | BODY | AGI | SPI | FND | CTRL | RES | WPR | Effect |
|---------|------|-------------|-----|------|-----|-----|-----|------|-----|-----|--------|
| `basic_strike` | 10 | PHYSICAL | 1.0 | — | 0.5 | — | — | — | — | — | 1 × damage |
| `enforce` | — | — (buff) | — | — | — | — | — | — | — | — | 1 × buff: `OUTGOING_DAMAGE_MODIFIER` ×1.5, 5s, consume_on_use |
| `empty_palm` | 10 | PHYSICAL | — | — | 0.3 | 1.0 | — | — | — | — | 1 × damage |
| `power_font` | 30 | SPIRIT | — | — | — | 1.5 | 0.5 | — | — | — | 1 × damage |

## Maintenance Notes

- When editing an ability `.tres`, update its row here in the same commit.
- When adding a new ability, add it under the correct path section with both the field table and the scaling table.
- When adding a new path, create a new H2 section with the path's theme description and a "Path Node → Ability" mapping table.
- If a field is unset in the `.tres`, list the *effective* value (the resource default) here.
- Effects go into `effects_on_target` (enemy-facing) or `effects_on_self` (caster-facing). An ability with no `effects_on_target` entries is a pure self-cast and takes no enemy selection.
- Sanity-check numbers by running a combat encounter — `CombatEffectData.calculate_value()` logs the full scaling breakdown.
