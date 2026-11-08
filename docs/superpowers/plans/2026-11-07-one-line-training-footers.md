# One-line training board footers (#144)

Playtest polish issue #144, tracked in #85. Every instruction line on the cycling and body refining boards' footers is one line beside the Auto toggle, and a test keeps it so for every technique and drill to come.

## Approved canvas

[Training board footers](https://claude.ai/artifact/1kf2KtAupXaHPYZijeQ6jh), approved by Lionel on 2026-11-07 as drawn. The answers are recorded on #144. Widths are in the footer's font at 17 px; the room is 368 px.

| Board | State | Line | px |
|---|---|---|---|
| Cycling | waiting | Click the Madra ball to begin a cycle. (kept) | 285 |
| Cycling | running, no clause or its stat capped | Follow the ball for Madra and Spirit. (kept) | 281 |
| Cycling | running, Smooth Flow | Follow the ball. Click it over each zone. | 304 |
| Cycling | running, Seal Flow Technique | Follow the ball. Open each seal with W A S D. | 348 |
| Cycling | Auto, every technique | Auto cycles at 40%. Follow for the full rate. | 346 |
| Drills | Stone Lifting | Hold Space or the mouse to lift the stone. / Let go in the brass band. Hold again to lift. | 328 / 332 |
| Drills | Horse Stance | Hold Space or the mouse to sink. / Hold to sink, let go to rise. Stay in the brass. | 255 / 350 |
| Drills | Falling Leaf | Press Space or click to shake the branch. (kept) / Click a leaf to catch it. Click off to shake. | 322 / 324 |
| Drills | Waterfall Tempering | Press Space or click to send a surge. / Press to send a surge, again as it lands. | 287 / 309 |
| Drills | Auto | Auto drills at 40%. Turn it off for 100%. | 316 |

- A technique's clause names the action, not the stat; the floaters name the stat as it pays. It still drops while its stat is capped.
- Under Auto the cycling line is the Auto line alone: Auto plays no zone and no seal.
- The footer keeps its layout: 368 px beside the 120 px toggle, word wrap kept, the board still grows for a long line.

## Tasks

1. `CyclingView`: `FOLLOW_LEAD` added; `ZONES_CLAUSE`, `SEALS_CLAUSE` and `AUTO_LINE` reworded (clauses lose the stat's `%s`, `AUTO_LINE` keeps its `%d`); `status_line()` returns `AUTO_LINE` alone under Auto, `FOLLOW` with no clause, else `FOLLOW_LEAD` and the clauses. Doc comments state the rule.
2. `BodyRefiningView.AUTO_LINE` reworded, keeping its `%d`; its doc states the rule.
3. The four drill files' `ready_line` and `play_line`; `DrillData`'s doc on them states the rule.
4. Tests: the pinned copy in `test_cycling_view.gd` (`test_status_line_copy`, `test_the_status_line_under_auto`, `test_auto_starts_a_cycle_and_its_status_line`). `test_a_long_name_wraps_and_the_board_grows` measures the footer's bottom as the lower of line and toggle, since a one-line line now centres on the taller toggle.
5. New `tests/integration/test_training_footer_lines.gd`: every line `status_line()` gives for every technique in the catalog (waiting, running, capped, Auto), every drill's two lines and the drill Auto line lay out as one line on the real footers. A two-line string proves the count sees a wrap. It is a file of its own, not part of `test_boards_never_trim_text.gd`, so it doesn't collide with #149's and #145's edits there.

## What was built differently

Nothing: built as planned.
