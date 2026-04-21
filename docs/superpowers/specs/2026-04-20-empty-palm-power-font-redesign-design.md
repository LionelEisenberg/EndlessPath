# Empty Palm & Power Font Redesign

Rebuild Empty Palm and Power Font so both abilities express the Pure Path's stated identity — disruption, technique cancellation, buff purification — instead of reading as generic Pure Madra damage. Empty Palm becomes the main Pure Madra DPS with a built-in interrupt. Power Font becomes the heavy-commit finisher that wipes enemy buffs.

## Motivation

The Pure Madra tree describes the path as: *"Disruption, technique cancellation, versatility"* and *"Neutralize, strip buffs, efficient strikes"* (see `resources/path_progression/pure_madra/pure_madra_tree.tres`). Current Empty Palm and Power Font do neither — they're just damage. This redesign realigns both abilities with the path's own promise.

## Empty Palm — Disrupting Palm

### Role
Main Pure Madra DPS ability + free ability interrupt rider.

### Rules
- Target: single enemy
- Madra type: Pure, Source: Path
- Cast time: 0 (instant)
- Cooldown: 3s
- Madra cost: 8
- Damage: 15 Spirit base, scales spirit 1.0 + agility 0.3
- **On hit, if the target's `is_casting == true`: cancel their cast.** No damage modifier. No silence. No added debuff. The cancellation is the only rider.

### Balance philosophy

The interrupt and the DPS role structurally conflict: cheap + low-CD + always-interrupts = enemy lock. Resolution is to **let the Madra pool be the gate** — no new mechanics added. Spamming Empty Palm every CD drains Madra faster than it regenerates, forcing natural windows where the player can't cast and enemies can land their big attacks.

This depends on one tuning truth: **Madra cost × usage rate > Madra regen rate** during combat. If regen is too generous, the design has no natural cap and needs a different gate (see "Balance knobs" below).

### 5-Component evaluation

- **Clarity:** Strong, conditional on enemy cast bars being visible to the player. Verify during implementation that `scenes/ui/combat/combatant_info_panel/combatant_info_panel.gd` displays enemy casting progress. If it doesn't, adding one is a prerequisite — the interrupt is invisible without it.
- **Motivation:** Always-used main DPS; caster fights become skill checks.
- **Response:** Instant cast is essential. Any non-zero cast time closes the interrupt window before it resolves.
- **Satisfaction:** The interrupt landing needs a dedicated feedback pass — minimum 2 channels (screen-shake + distinct SFX + cast-bar shatter VFX on the enemy). A successful cancel without feedback will feel like nothing happened.
- **Fit:** Dead-on Pure Madra identity.

### State machine

| Property | Value |
|----------|-------|
| Entry | Off CD, Madra ≥ 8, target alive |
| Exit | Hit resolves → CD starts |
| Interruptibility | N/A (instant) |
| Chained actions | None |
| Resource cost | 8 Madra on execute |

**Edge cases:**
- Target finishes casting between `start_cast` resolution and Empty Palm's hit: no interrupt fires, damage still lands.
- Target dies before Empty Palm resolves: existing retarget/fail behavior applies.
- Target not casting: damage lands, cancel effect no-ops.

### Starting values (Numbers Policy — all tunable via playtest)

| Value | Starting | Notes |
|-------|----------|-------|
| Madra cost | 8 | Lower than current 12 — this is now rotation staple |
| Cooldown | 3s | Unchanged from current |
| Cast time | 0s | Must be instant |
| Base damage | 15 Spirit | Up from current 10; this is now main DPS |
| Spirit scaling | 1.0 | Matches current |
| Agility scaling | 0.3 | Matches current |

### Test plan

1. **Madra pressure:** Spam Empty Palm every CD in an average fight. Does the player run out of Madra? Pass: ~30-60% effective uptime. Fail: >80% uptime means regen is too generous — tune regen, not the ability.
2. **Interrupt feel:** Cancel a 3s enemy cast. Does it feel decisive? If it reads as "nothing happened," iterate on feedback channels.
3. **Boss-lock stress test:** In a single-enemy caster fight, try to perma-lock the enemy by interrupting every cast. If successful, the Madra economy is not gating — widen regen/cost gap.

### Balance knobs (in order of preference if playtest shows issues)

1. Lower combat Madra regen rate (preferred — affects whole system coherently)
2. Raise Empty Palm Madra cost (8 → 10 → 12)
3. Extend CD (3s → 4s)

### Open validation

Pull the current combat Madra regen values and confirm economic pressure exists at 8-Madra/3s-CD usage. If current regen is fast enough to support perma-spam, an additional gate is needed before this design ships.

## Power Font — Sundering Font

### Role
Heavy-commit finisher with signature buff-wipe.

### Rules
- Target: single enemy
- Madra type: Pure, Source: Path
- Cast time: 3s
- Cooldown: 25s
- Madra cost: 30
- Damage: 30 Spirit base, scales spirit 1.5 + foundation 0.5
- **On hit, remove ALL buffs on the target.** Every buff entity is removed, regardless of stack count or source (including player-applied DoTs).
- **No bonus damage from stack count at this tier.** Reserved for future path-tree upgrade nodes.

### Balance philosophy

Power Font should feel like a commitment-heavy finisher — expensive, slow, decisive. The earlier version added +10% damage per buff stripped, which stacked runaway burst on top of already-high base damage. That's deferred to future path-tree upgrades; this tier keeps raw base damage + wipe. The wipe itself is the payoff against buff-stacking enemies.

### 5-Component evaluation

- **Clarity:** 3s channel is visible to both player and enemy; buff icons visibly vanish on resolve.
- **Motivation:** Signature anti-boss tool. Every buff-stacking enemy becomes "this is the answer."
- **Response:** Long commit with risk — interruptible by damage (existing cast-cancel behavior).
- **Satisfaction:** Big damage number + cascading buff-strip VFX + heavy impact. Needs dedicated SFX+VFX pass to sell the purification moment.
- **Fit:** Dead-on Pure Madra identity.

### State machine

| Property | Value |
|----------|-------|
| Entry | Off CD, Madra ≥ 30, target alive |
| Exit | 3s cast completes → damage + strip resolve → CD starts |
| Interruptibility | Cancellable by taking damage (existing behavior) |
| Chained actions | None |
| Resource cost | 30 Madra on execute (not on cast start) |

**Edge cases:**
- Target dies during cast → Power Font fizzles; full CD still triggers (commitment = commitment).
- Target has no buffs → damage lands normally; strip is no-op.
- Target's buffs include player-applied DoTs → they get stripped too (all buffs, no exceptions).

### Dreadbeast benchmark (reference enemy for this design)

Hypothetical enemy that stacks a damage-multiplier buff every attack. After 5 attacks, 5 stacks are active. Expected player flow:
1. Player tanks several attacks while Madra builds up.
2. Player commits Power Font (3s cast).
3. On hit: 30+scaled Spirit damage lands AND the 5-stack buff is wiped entirely (buff entity removed, rebuilds from 0).

The wipe is the payoff; no burst multiplier is layered on top at this tier.

### Starting values

| Value | Starting | Notes |
|-------|----------|-------|
| Madra cost | 30 | Up from current 20 — "uses a lot of Madra" |
| Cooldown | 25s | Up from current 15s — "high CD" |
| Cast time | 3s | Unchanged |
| Base damage | 30 Spirit | Unchanged from current |
| Spirit scaling | 1.5 | Matches current |
| Foundation scaling | 0.5 | Matches current |

### Test plan

1. **Fight cadence:** With 25s CD, does Power Font land once per medium fight? If less than once, CD is too long.
2. **Commitment feel:** Against the dreadbeast reference (or any ramping enemy), is the 3s cast risky but rewarding? If always interrupted by enemy DPS during the channel, CD is too short to justify the commit.
3. **Wipe satisfaction:** Does stripping a 5-stack buff feel proportionate to the investment (3s + 30 Madra + 25s CD)? Iterate feedback channels if not.

### Balance knobs (in order of preference if playtest shows issues)

1. Tune base damage and scalings (too weak)
2. Tune Madra cost / CD (too frequent or too rare)
3. Narrow strip scope to "beneficial buffs only" (too disruptive; this spec locks in "all buffs" for v1)

### Future path-tree upgrade hooks (out of scope for this spec)

- Bonus damage per buff stripped (+10%/stack, cap 5)
- Reduced cast time, cooldown, or Madra cost
- Stack-cap expansion if bonus-damage upgrade ships

## Engineering prerequisites

Neither ability can be implemented with existing combat primitives. The following combat-system additions are required:

### 1. Cast cancellation

`CombatAbilityInstance` (`scenes/combat/combatant/combat_ability_manager/combat_ability_instance.gd`) tracks `is_casting` and `cast_timer` but has no public way for external code to cancel an in-progress cast. Required additions:

- `cancel_cast()` method on `CombatAbilityInstance`: stops `cast_timer`, resets `is_casting`, emits a new `cast_cancelled` signal. Starts the normal cooldown (prevents immediate re-cast spam).
- A way for effects to find and cancel a target's active cast. Likely a helper on `CombatAbilityManager` or `CombatantNode` that iterates the target's active ability instances and cancels the one currently casting.

### 2. Buff stripping as a mid-combat operation

`CombatBuffManager.clear_all_buffs()` exists but is only called on combat end. Required addition:
- `strip_all_buffs()` (or make `clear_all_buffs()` callable mid-combat) — removes all `ActiveBuff` entries, emits `buff_removed` for each.

### 3. New `CombatEffectData` effect types

Current enum: `DAMAGE`, `HEAL`, `BUFF`. Add:
- `CANCEL_CAST` — routes to the target's cast-cancel method
- `STRIP_BUFFS` — routes to the target's buff-strip method

Effect routing (in the effect-dispatch code that handles `receive_effect`) must handle the new types. Alternative design: flags on existing `BUFF` type instead of new enum values. Pick one during implementation.

### 4. Enemy cast-bar UI (Empty Palm clarity prerequisite)

Empty Palm's interrupt rider is only readable if the player sees the enemy's cast bar. Verify `combatant_info_panel.gd` already shows enemy casting progress. If not, add one as a prerequisite — without a visible telegraph, interrupting is invisible and frustrating.

### 5. Out of scope: stacking for non-DoT buffs

The dreadbeast reference enemy needs a stacking damage-multiplier buff (not a DoT). `CombatBuffManager` currently only stacks DoTs. Extending stack support to `OUTGOING_DAMAGE_MODIFIER` and `INCOMING_DAMAGE_MODIFIER` is a separate concern — it's needed for the dreadbeast to exist as an enemy, but Power Font works correctly with both single-instance and stacked buffs (it wipes the whole entity either way). Spec'd separately when the dreadbeast enemy is built.

## Asset requirements

- Empty Palm retains existing icon (`assets/sprites/abilities/empty_palm.png`) — only mechanics change.
- Power Font retains existing icon (`assets/sprites/abilities/power_font.png`).
- New VFX/SFX for interrupt landing (Empty Palm) and buff-wipe resolve (Power Font) — treat as separate tracked work.

## Data changes

- Modify `resources/abilities/empty_palm.tres` with new values (cost 8, damage 15, cancel-cast effect).
- Modify `resources/abilities/power_font.tres` with new values (cost 30, CD 25s, strip-buffs effect).
- No changes to `ability_list.tres` (IDs stay the same, abilities remain Pure+Path).

## Summary table

| | Empty Palm | Power Font |
|---|---|---|
| Role | Main DPS + interrupt | Heavy finisher + buff wipe |
| Madra cost | 8 | 30 |
| Cooldown | 3s | 25s |
| Cast time | 0s | 3s |
| Base damage | 15 Spirit | 30 Spirit |
| Scaling | spi 1.0 / agi 0.3 | spi 1.5 / fnd 0.5 |
| Rider | Cancel target's cast | Strip all buffs |
| Gate | Madra economy | CD + cast time + cost |

## Out of scope

- Path-tree nodes that upgrade either ability
- Feedback-pass asset creation (VFX, SFX) — call out prerequisites only
- Buff-stacking extension for non-DoT buffs
- Enemy cast-bar UI construction if not already present
- Any other Pure Path ability redesign
