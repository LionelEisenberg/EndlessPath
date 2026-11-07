# Stone Lifting target (#148)

Show, without words, where Stone Lifting's stone must stop and which part of it counts. The judging and its timing stay as they are.

## Approved mock-up answers

Canvas "Stone Lifting target" (https://claude.ai/artifact/GFVU1ZP9N5AFd28w8Bax7j), option A, approved as drawn by Lionel on 2026-11-07. Recorded on #148.

- The stone's base counts, as before. The stone is redrawn with a brass sill along its bottom edge and two brass arms reaching out to the rails, so one brass line runs rail to rail at the base. The handle stays.
- A brass band crosses the track between the rails, behind the stone and the jade, at the rails' brass. The rails stay as they are.
- The band is dim, and lit while a release would score Perfect. Brass only.
- A judged rep leaves a line rail to rail where the base stopped, in its tier's colour (red Miss, tan OK, cream Good, brass Perfect and Auto), until the next lift. None for "Dropped" or "Too late". Gone at rest.

## Geometry (stage px, unchanged)

The base rests at y 492 and travels 400 px. The band's centre (1.37 s of a 2 s rise) puts the base at y 218; the rails' brass runs 206 to 232.

## Tasks

1. **Art** (`assets/ui/lacquer/body_refining/`, all `_ai`):
   - `lacquer_drill_stone_sill_ai.png`, 88 × 56: `lacquer_drill_stone_ai.png` at x 12, its rows 52 and 53 brass, with brass arms out to x 1 and x 86 on those rows, inked above and below.
   - `lacquer_drill_band_ai.png`, a strip of two 72 × 29 frames: dim brass, then lit brass with a light top edge, inked top and bottom.
   - `lacquer_drill_stop_mark_ai.png`, a strip of four 88 × 4 frames in `DrillRules.Tier` order (red, tan, cream, brass): a 2 px line inked above and below.
   The old stone file stays (nothing else uses it, but it is the record of #127's art).
2. **`StoneLiftingRun.release_tier_at(t)`**, read-only: the tier a release at `t` would score, from `height_at()` and the release rule (`share_for_offset()` through `DrillRules.judge()`); MISS when no lift is in progress. Unit-tested against the judging windows.
3. **Scene** (`stone_lifting_stage.tscn`): `Band` (LacquerStripRect) after `Track`, before `Fill`; `StopMark` (LacquerStripRect, hidden) after `Fill`, before `Stone`; `Stone` 88 wide at x 218 on the new texture. `FLOATER_OFFSET` grows by 12 in x, so the tier pops where it did; the pellets' origin (the stone's middle) doesn't move.
4. **Script** (`StoneLiftingStage`): `show_rest()` dims the band and hides the mark; `show_run()` lights the band while the run's release tier is PERFECT, and hides the mark while lifting; `show_judgement()` shows the mark at the stopped base in the tier's frame, except for DROPPED and TOO_LATE.
5. **Tests** (`test_drill_play.gd`): the band lights exactly in the Perfect window; a judged rep leaves its tier's mark at its base, and the next lift clears it; Dropped and Too late leave none; rest clears it.

## What was built differently

- The sill's arms are part of the stone's texture, so the stone is one 88 px node that the arms move with; `FLOATER_OFFSET` grew by 12 to keep the pop where it was.
- `StoneLiftingStage.base_y()` is public, so the tests place the stop mark from the same rounding the stone uses.
- `DrillPlay` shows the stage at rest when a set ends, so the last rep's mark goes then, once its stone is down.

Checked in the game: the issue's "Done when" list, by a scratch driver (`mockups/stone_target/done_when.gd`, gitignored) on `--preset=harden_core --save=user://dev/runs/stone-lifting-clarity.tres`: 17 of 17. No save change.
