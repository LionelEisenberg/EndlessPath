# Test suite reduction

The suite grew from 533 tests in June to 3,235 by 2026-10-29, most of it in one week of UI work. The growth is mostly tests that pin how a screen looks rather than what the game does: they fail on every layout, copy or style tweak, and catch nothing that looking at the screen would not. This cut removes them, and the rule below is what keeps them from coming back.

## The rule

A test checks something a player or a later system depends on, that a person would not notice by looking at the screen.

**Keep:**
- Game rules and numbers: managers, formulas, effects, unlocks, quest steps, costs, caps.
- State changes and their signals: what pressing, picking, buying, equipping, travelling or resolving does to the game.
- Save, load, migration and anything that keeps the user's real save safe.
- Flows across systems (a fight paying out, a breakthrough, a shop purchase, an idle action resolving).
- Per scene, a smoke test that it builds and shows its data (the name, count or value it is given ends up on screen), and the behaviour its controls trigger.
- Per board that can hold long text, one test that it wraps and grows with it (the standing "no text is ever cut off" rule). The game-wide scan in `test_boards_never_trim_text.gd` covers the rest.
- A regression test for a bug that really happened, when its name or comment says so.

**Cut:**
- Pixel placement: positions, sizes, offsets, grid alignment, "even" heights, columns, stacking order, which piece sits where. Checked by eye and captures.
- Colours, hex values, theme variants, fonts, modulate, frames and hover art.
- Exact player-facing wording: asserting a label or constant equals a sentence. Checked by reading it.
- Animation keyframes, tween curves and shake steps, unless the motion gates gameplay (input locked until it ends, a timer that pays out).
- Art files: their pixel sizes, nine-slice margins, palettes or colours.
- Shipped content values (`.tres` field values), unless the code depends on them being so (an id the code looks up, a wiring a flow needs).
- A second test of the same behaviour, at the same level, with different data. Keep the clearest one.
- Many tests of one small switch (a test per enum value). Fold them into one table-driven test when worth keeping at all.

## Scope

The cut covers UI, HUD, dev-tool and art test files. Manager, combat, save, persistence, quest, unlock and cross-system flow tests are not touched.

## Outcome

The first pass cut the six UI, HUD and dev-tool areas from 1,912 tests to 995, and the suite from 3,235 to 2,318. Six files were deleted: five that checked only art or animation, and the dev panel's zone toggles, whose commands other tests cover. The rest of the suite, the logic the Scope section leaves alone, was not touched.

| Area | Before | After |
|---|---|---|
| Adventure view | 289 | 99 |
| Zone view and map | 331 | 176 |
| Cycling and the technique dock | 315 | 162 |
| Books, inventory pages, lacquer kit | 336 | 159 |
| HUD boards, Tribulation view | 310 | 154 |
| Dev tools | 331 | 245 |

Dev tools kept the most, because their save-safety tests and the dev commands' rules stay: presets, the story route and other tests build on those commands.
