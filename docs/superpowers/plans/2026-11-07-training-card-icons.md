# Show pool and side icons on the Cycling and Riverbank Training cards (#145)

Playtest polish issue #145, tracked in #85. Built against `main` at 7d586171.

## Approved mock-up answers

Canvas: [Training card icons](https://claude.ai/artifact/9L9bo9KNgdmZ3jtEAYUTuJ), round 2, settled 2026-11-07 (round 1 was rejected). Recorded on #145.

1. **Side icons:** Strength's icon for the Physical side, Spirit's icon for the Spiritual side, "for now" (Lionel). `StatDisplay` hands them out per side, so a later side icon is one change there.
2. **Pool icons:** a 32 px Madra drop and Health heart redrawn from the 16 px minis on the kit's 2 px grid: `assets/ui/lacquer/lacquer_pool_madra_ai.png`, `lacquer_pool_health_ai.png`.
3. **Size:** 32 px. Both cards are 86 px tall.
4. **Placement:** the title, with its NEW seal, centred vertically on the card; the two icons in the right-hand column under the tag, right-aligned at the tag's right edge (x 380), 40 px down, pool first, then side, 12 px apart, 14 px of drawer under them. The socket and the tag stay where every card has them.
5. **No words, no marks.** Neither card changes as techniques and drills are learned, apart from the NEW seal.
6. **No cabinet change:** the cabinet's Strength and Spirit cells already head their sides. Hover text is #151's.

## Shape

- `StatDisplay` (`scripts/utils/stat_display.gd`):
  - `enum StatSide { PHYSICAL, SPIRITUAL }` (not `Side`: that name is a Godot global enum, which a return type would resolve to);
  - `side_icon(side) -> Texture2D`: the side's first stat's icon (`PHYSICAL[0]`, `SPIRITUAL[0]`).
- `ZoneActionButton`:
  - its scene gains `%IconColumn`, an `HBoxContainer` in the drawer, before the frames;
  - `get_icon_column()`, the slot a presenter reparents its icons into, as it does its rows into `get_detail_slot()`;
  - `relayout()` places the column under the tag and grows the card to hold it. With icons there and nothing on the detail line, it centres the title and its NEW seal on the card's height. A long title still wraps and the card grows round it;
  - `_spawn_presenter()` empties the column with the detail slot.
- `CyclingPresenter` and `BodyRefiningPresenter`:
  - each scene holds `%Icons` (an `HBoxContainer`, separation 12) with `%PoolIcon` (the pool's texture set in the scene) and `%SideIcon`;
  - `setup()` reparents `%Icons` into the icon column and sets `%SideIcon` from `StatDisplay.side_icon()`;
  - `reward_stats()`, `reward_words()`, the `technique_unlocked` hookup and the Health and Strength rewards go.
- `ZoneActionPresenter`'s doc names the icon column beside the detail slot.

## Tests

- `test_stat_display.gd`: each side's icon is its first stat's.
- `test_zone_action_cards.gd`:
  - the two cards show their pool icon, then their side's icon, and no words (a table over both cards);
  - neither card changes when every technique and drill is learned: the same icons on a card built before and on one built after;
  - a long title on an icon card wraps, every line shows, and the card grows to hold it.
  The three tests of the old words and icons go.
- `test_boards_never_trim_text.gd`: `cycling_presenter.tscn` leaves `BOARD_SCENES`, since it holds no Label.

## Checks in the game

On `-- --preset=path_open --save=user://dev/runs/training-card-icons.tres`, the issue's Done when list: both cards as approved, unchanged after the dev panel's "Unlock all techniques" and "Unlock all drills" apart from their NEW seals, the chest's other cards as before.
