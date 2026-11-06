# Stat XP pellets land on the cabinet (stats rework chunk #92)

**Issue:** LionelEisenberg/EndlessPath#92, tracked in #85. **Branch:** `feat/confident-panini-7ff122`, cut from `main` at `fefceec8` (#114 merged).

**Goal:** give each stat's XP pellets a landing, the stat's cell on the cultivator cabinet, with a level-up look, a capped look, a hop as each pellet lands and a hover figure. Pellet ramps for all six stats. Nothing in play sends a stat pellet yet: #94, #99 and #100 do, through the API this chunk adds.

## Approved canvas

"Where stat XP lands", https://claude.ai/artifact/NZGE8P9FNt5maDSCyeKNk5. **Approved 2026-11-05.** Lionel's answers:

1. **Where pellets land:** on the stat's cell, its 24-bead ring filling as they land (as proposed). What a pellet carries stays out of the cell until it lands; across a level-up the cell shows the old level until then. A capped stat takes no pellets.
2. **Level-up look:** both of the canvas's options at once, Lionel's pick. The ring shows all 24 beads in brass (`lacquer_stat_ring_flash_ai.png`) and the kit's square brass frame shows round the cell, together, 300 ms on and 300 ms off, twice, with the level in brass while they are on. It ends on the new level.
3. **When it plays:** when the level the cell shows goes up: as the pellet that carries the level lands, or at once when a level is gained or set with nothing in flight. Never on a save load, a preset switch, a breakthrough or a lowered level.
4. **Capped look:** Lionel asked for something more distinct than brass beads, "the rings attached and something flowing". Drawn and approved: the beads join into one dark channel with four brass glints flowing round it clockwise (`lacquer_stat_ring_capped_strip_ai.png`, 24 frames stepped 10 a second), the level in brass.
5. **Hover or click:** a hover figure (as proposed), no click. "Spirit Lv 4" over "105 / 196 XP to Lv 5"; at the cap "Lv 10 is Foundation's cap. Break through to train it further."
6. **Pellet colours (as proposed):** Strength copper, Body steel, Agility sky, Spirit violet, Mind leaf, Control orchid.
7. **Control icon (LL-15):** Lionel: redraw it ("you can redraw every icon if you need to"). Drawn and approved: his curl redrawn at 16 art px in his four colours, 14 wide and centred, replacing `control_icon_ai.png`. The other five icons already stand on the grid and stay.
8. **The receiving cell (Lionel's ask, added on the canvas):** the ring and its icon hop 0, −2, −4, −2, 0 px, 40 ms a step, as each pellet lands; a landing never restarts a running hop.

Built differently from the issue: the level-up look adds the brass frame and the hop, and the capped look is the flowing channel, not the full ring or brass beads.

## Pattern

Godot UI (`godot-prompter:godot-ui`). The tooltip is a `PanelContainer` scene on `board9.tres`, top-level and shown and hidden, its script setting text only, as `TechniqueTooltip` and `BuffTooltip` are. The flash, the hop and the capped glints step through held keyframes from elapsed time in `_process`, as `DockSlot`'s and `VitalsPlate`'s shakes do. Rejected: tweens (eased, which the style guide rules out) and Godot 4.7's `offset_transform_*` (layout-safe, but the cell's children are placed in absolute px, so a 2 px move of `XpRing` breaks no layout).

## Tasks

### Task 1: The art (`_ai`, generated)

- [x] `docs/superpowers/mockups/lacquer-pellet/gen/pellet_strip.py`: six ramps after tan; rerun writes `lacquer_pellet_strip_ai.png` (160×200; the first four rows pixel for pixel as before).
- [x] `docs/superpowers/mockups/cabinet-stat-pellets/gen/stat_looks.py` writes `lacquer_stat_ring_flash_ai.png`, `lacquer_stat_ring_capped_strip_ai.png` and `control_icon_ai.png`.

### Task 2: Six stat ramps on LacquerPellet

- [ ] `LacquerPellet.Ramp` grows at its end: `STRENGTH, BODY, AGILITY, SPIRIT, MIND, CONTROL` (4 to 9, claimed at merge). `static func stat_ramp(stat) -> Ramp`.
- [ ] `lacquer_pellet.tscn`: the three sprites' `vframes` 4 → 10.
- [ ] Tests (`test_lacquer_pellet.gd`): each stat's ramp, one table; the strip holds a row for every ramp.

### Task 3: StatCell's looks

- [ ] Capped: `XpRing` takes the capped strip and steps its frames at `CAPPED_FPS` (10), the level in brass; uncapped it takes the bead strip back, the level in cream.
- [ ] `play_level_up()`: `FlashRing` (a `TextureRect` child of `XpRing` under `Icon`, the flash frame) and `LevelFrame` (a brass `LacquerFrameOverlay` round the cell) show together for 300 ms on and off, twice, the level in brass while on. `is_flash_on_at(elapsed)` static.
- [ ] `hop()`: `XpRing` (with its icon) steps through `HOP_KEYFRAMES` (0, −2, −4, −2, 0), `HOP_STEP_SECONDS` (0.04) each; a hop that runs is not restarted. `hop_offset_at(elapsed)` static.
- [ ] Hover: the cell takes the pointer (`MOUSE_FILTER_PASS`) and emits `hover_changed(hovering)`. It keeps what it shows (`get_shown_level()`, XP, cost, capped) for the figure.
- [ ] Tests (`test_stat_cell.gd`): the capped strip and its frame stepping; the flash's on and off phases; the hop's offsets and no restart; the label colours.

### Task 4: The hover figure

- [ ] `scenes/zones/cultivator_plate/stat_tooltip/stat_tooltip.tscn` + `StatTooltip`: `board9.tres`, 208 wide at least, a `LabelLacquerPopoverTitle` and a wrapping `LabelLacquerDetail`. `static func figure_text(...)`. Never takes the pointer.
- [ ] `CultivatorPlate` shows it beside the cabinet, level with the hovered cell, refreshing as the cell changes.
- [ ] Tests: the figure's text (table: under the cap, at the cap with and without a next stage); the board joins `BOARD_SCENES`, its detail line the wrap list.

### Task 5: The cabinet's landing

- [ ] `get_stat_cell_global_position(stat)`, `accepts_stat_xp(stat)` (false at the cap), `hold_stat_xp(stat, amount)`, `release_stat_xp(stat, amount)`. A sender asks `accepts_stat_xp` before it pays, and holds the XP the stat took.
- [ ] A held stat shows as it stood that much XP ago, level by level, never below Lv 1 (`rewind_core` gains a lowest level) and never capped.
- [ ] The level-up look plays when a cell's shown level rises from `stat_level_changed`, `stat_xp_changed` or a release, never from `stats_changed` (save loads, gear), the stage changing or a hold. A release hops the cell.
- [ ] Tests (`test_cultivator_plate.gd`): held XP shows once released; a hold across a level-up keeps the old level until it lands; refusal at the cap; the level-up look on a gain, a set and a release, not on a load, a breakthrough or a lowered level; a release hops; the hover figure follows the cell.

### Task 6: LL-12, one group label row

- [ ] `scenes/common/lacquer/lacquer_group_row/lacquer_group_row.tscn` + `LacquerGroupRow` (`text` export): the label and its groove, lifted from `activity_group_label.tscn`.
- [ ] `ActivityGroupLabel` and the cabinet's two side rows instance it; `ActivityList` sets the group's text through it.
- [ ] Tests: the side rows read Physical and Spiritual through the shared row; the zone panel's group tests stay green.

### Task 7: Checks

- [ ] `tests/run_tests.ps1` green.
- [ ] The issue's Done-when checks on `-- --save=user://dev/runs/cabinet-stat-pellets.tres` and the `tribulation_ready` preset.
- [ ] PR closing #92 with `## Docs to update`.
