# Make the Foundational Technique's perfect cycle easier to reach (#147)

Playtest polish issue #147, tracked in #85. Built against `main` at 7d586171 (#137 merged).

## Approved mock-up answers

Canvas: [An easier Foundational](https://claude.ai/artifact/4yairiqKUptUr9vkV59RJ8), round 1, approved 2026-11-07 after Lionel played board 1. Recorded on #147 (issuecomment-6713320418). Lionel: "we'll tune all the other cycling methods later, but apply general settings there as well".

1. **The Foundational slows through its own data:** a 10 s cycle at 37.5 Madra and 15 Spirit XP a cycle, the same per second. Its figure stays as drawn.
2. **A gentler ease, for every technique:** the ball speeds up over the first second, runs at an even speed, and slows over the last second. Auto cycles keep their even speed. Torrential Flow's seal nodes move to where the new ease puts the ball at their seconds.
3. **The ring stays 36 px**, for following and presses.
4. **A 0.1 s grace, for every technique:** a slip that short keeps following. A grace never starts following. A grace that holds counts as followed; one that runs out counts as not followed from the moment the cursor left.
5. **A perfect cycle needs 95% of the cycle followed**, plus every zone PERFECT and every seal opened, as before.
6. **The groove lights only where the ball was followed**, so a slip leaves a dark gap, kept until the next cycle starts. The ring does not blink in a grace and does not flash red.
7. **Once a cycle can no longer be perfect, the following ring dims.**
8. **The last cycle card** shows "Followed 93%", or "Followed all", for a technique with no zones or seals.
9. **The tooltip:** "Play a perfect cycle: follow the ball for 95% of the cycle", then "and press every zone PERFECT" or "and open every seal", and a full stop.

## Shape

- **`CyclingRules`** (pure, table-tested):
  - `EASE_SECONDS = 1.0` and `eased_ratio(seconds, duration) -> float`: the ball's share of the path. Its speed rises along a half cosine over the first `EASE_SECONDS` (at most half the cycle), holds, and falls the same way over the last.
  - `FOLLOW_GRACE = 0.1` and `grace_holds(slip_seconds) -> bool`.
  - `PERFECT_FOLLOWED_SHARE = 0.95`, `followed_enough(followed_ratio) -> bool` and `misses_allowed(missed_seconds, duration) -> bool` (missed time still under the 5%).
- **`FollowWindow.judge()`**: a cursor that was following and leaves the ring keeps following while `grace_holds()` the slip; `is_in_grace()` says so. Coming back to the ring inside the grace carries on without the 4 px move. A cursor that was not following gets no grace.
- **`CyclingTechnique`**:
  - `_ball_ratio()` and the seal nodes use `CyclingRules.eased_ratio()`; flat (Auto) cycles stay even.
  - Frames in a grace pay nothing yet: their seconds are held. When the cursor comes back, the held seconds are paid as followed (Madra, Spirit, followed time). When the grace runs out they are dropped and count as missed.
  - `_missed_seconds` replaces `_followed_throughout`. `can_still_be_perfect() -> bool`: the misses are still allowed, no zone ended other than PERFECT and no seal fizzled. While it is false the following ring is drawn dimmed (`RING_LOST_MODULATE`), no new art.
  - The groove lights where the ball paid: a frame lights it while the cursor follows (a grace included) or Auto pays. A grace that runs out ends the lit span where the cursor left. A finished cycle leaves its spans lit until the next cycle sweeps them away; a stop or a switch lights the whole groove as today.
- **`CyclingGroove`**: `set_lit_spans(spans: Array[Vector2])` lights the cells whose path length falls in any span; `set_lit_length(length)` is one span from the start. `hold_light()` keeps what shows as the light the next sweep clears. `light_all()` as today.
- **`CycleResult`**: `followed_throughout` goes; `is_perfect()` reads `CyclingRules.followed_enough(followed_ratio)`, then the zones and seals as before.
- **`LastCycleCard`**: a `%Followed` label in the row (scene node, `LabelLacquerNowName`), shown for a result with no zones and no seals: `FOLLOWED_FORMAT` "Followed %d%%" (the share floored, so it never reads 100% short of all) or `FOLLOWED_ALL_TEXT` "Followed all".
- **`CyclingView`**: `UNLOCK_HINT` becomes `UNLOCK_HINT_FORMAT` "Play a perfect cycle: follow the ball for %d%% of the cycle", filled from `PERFECT_FOLLOWED_SHARE`.
- **Data:** `foundation_cycling_technique.tres`: `cycle_duration = 10.0`, `base_madra_per_cycle = 37.5`, `spirit_xp_per_cycle = 15.0`.
- **Save:** none. No field changes; an unlocked Auto stays unlocked.

## Tests

- `test_cycling_rules.gd`: `eased_ratio()` table (start, the ramp's end, the middle, the end, a cycle shorter than two ramps, monotone), `grace_holds()` table, `followed_enough()` / `misses_allowed()` table, `is_perfect()` table on the share.
- `test_follow_window` cases (in `test_cycling_rules.gd` or `test_cycling_technique.gd`, where FollowWindow is tested today): a slip within the grace keeps following and resumes without a move; one past it ends following; no grace for a cursor that never followed; a resting cursor still never starts.
- `test_cycling_technique.gd`: the eased path; a short slip keeps the perfect and pays its held seconds; a long slip drops them; a 4% miss is still perfect, a 6% miss is not; the ring dims once lost (misses, a missed zone, a fizzled seal); the groove leaves a dark gap where a slip lost following and stays lit through a grace; an Auto cycle nobody follows lights its groove; the Foundational fixture's 10 s, 37.5 Madra and 15 Spirit XP; the helpers that invert the ease use `CyclingRules.eased_ratio()`.
- `test_cycling_groove.gd`: spans light their cells, `hold_light()` with a sweep.
- `test_last_cycle_card.gd`: the followed label for a zoneless result (a share, all), hidden with zones or seals.
- `test_cycling_view.gd`: the unlock hint table's copy.
- `test_cycling_technique_catalog.gd`, `test_zone_panel.gd` and any other test that pins the Foundational's 8 s, 30 Madra or 12 Spirit XP.

## Done when

The issue's checks, on `-- --preset=adventure_open --save=user://dev/runs/foundational-technique-easier.tres`, and the suite green.

## Built differently

- **The groove lights where the ball paid**, not only where it was followed: an Auto cycle nobody follows still lights behind the ball, since Auto paid there. The canvas had no Auto.
- **No grace on a cycle's first frame.** FollowWindow's first-frame rule stays: a cycle follows from its first frame only with the cursor on the ball. The grace starts from the second frame.
- **A held grace pays when the cursor is back:** its Madra steps and Spirit time are paid on the frame following resumes, not as the grace runs. A grace that runs out pays nothing (Auto's share, if Auto runs). The rate window counts a grace's frames as drawn.
- **The ring dims for any lost perfect:** too many misses, a zone that ended other than PERFECT, or a seal that fizzled.
- **A finished cycle's Madra is snapped to 0.0001.** 125 steps of 0.3 summed to 37.4999…, which the card and the log rounded to +37 while the drawer read "38 Madra". Snapped, all read 38.
- The Foundational's drawer line reads "38 Madra · 10 s cycle · no zones": it rounds 37.5 as it always rounded Madra a cycle.

## Checks run

On `-- --preset=adventure_open --save=user://dev/runs/foundational-technique-easier.tres`, through the real main scene with a scripted cursor (`mockups/easier_checks/check.tscn`, gitignored):

- A 0.8 s slip at 3 s: the ring dims, a dark gap stays on the groove after the cycle, "Followed 91%", not perfect, Auto locked.
- A cursor resting on the path for the rest of a cycle: no following ring while the ball passed it (the one ringed frame is the ready ring as the cycle ended), no Madra.
- A 0.05 s slip the grace held and a 0.3 s slip: 97% followed, perfect; Auto unlocks with "PERFECT CYCLE · Auto unlocked", the toggle's flash and "Foundational Technique · Auto unlocked" in the log. The card reads "Followed 96%" (floored).
- A whole cycle: the rate reads 3.75 Madra a second ("+3.7 / s" on the cabinet, as before); the card reads +38 Madra, +15 Spirit, "Followed all".
- Smooth Flow's and Torrential Flow's (the Seal Flow Technique since #152) locked tooltips read "… follow the ball for 95% of the cycle and press every zone PERFECT." and "… and open every seal."; both follow through a held 0.05 s slip.
- Relaunched on the same file: the Foundational's Auto is still unlocked.
- A copy of the main checkout's save (made before this change), with the Foundational added to its Auto list as an old unlock: it loads, Auto stays unlocked, and a cycle plays.
