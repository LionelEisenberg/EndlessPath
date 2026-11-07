# The book's cycling lines (stats rework chunk #102)

**Goal:** Spirit's page in the Character book shows the Madra a cycle draws, now and at the next level. Spirit's, Mind's and Control's pages say how many perfect cycles of the equipped technique the next level takes. The pages follow the equipped technique, the book's two XP bars round down, and the next-level figures are exact.

**Issue:** LionelEisenberg/EndlessPath#102, tracked in #85. Needs #99 (PR #128) and #98 (PR #126), both on `main` at ca2c2a06.

**Canvas:** [The book's cycling lines](https://claude.ai/artifact/NmSw6c1nKDa4byAM9CEZwF), approved as drawn on 2026-11-06. The answers are recorded on #102.

## Approved answers

1. **Madra per cycle** is the first line under Spirit's WHAT IT DOES: "MADRA PER CYCLE 96 → 104", in Madra ink. It reads the equipped technique's `get_madra_per_cycle()` at the multiplier of the now block and of the next block. Both figures are `roundi`, as `TechniqueDrawer.detail_text()` rounds, so the now figure is the drawer's.
2. **The cycles line** reads "4 perfect cycles to Lv 4", or "1 perfect cycle to Lv 4" for one. It sits in the level panel, right under the XP bar, and the panel grows one line. It shows only while the stat is under the cap and the equipped technique pays it XP, so the Physical pages never show it. It never names a technique.
3. **Spirit's description:** "The force of your Madra. Your Spirit techniques hit harder, and each cycle draws more Madra."
4. **One cycle** is one played at its best: `CyclingTechniqueData.get_xp_per_cycle(stat)`. The count is `ceili((xp_to_next - xp) / per_cycle)`.
5. **Two techniques at once:** not applicable. One technique runs at a time.
6. **LL-14:** the tile's and the page's XP bars round down. No other `LacquerRod` changes.
7. **RL-07:** keep the pressed bars.
8. **RL-08:** exact next figures. `CharacterManager.get_stat_at_level(stat, level)` returns the stat's total if its trained level were `level`, with gear recounted on that level's trained value. The next block uses it.

LL-09 (one shared tag fit and XP fraction) changes no screen. It was built while the canvas waited: commit e8abaf2e.

## Tasks

Build bottom-up. Run the named test files after each task, then commit.

### Task 1: A stat's total at a given level (RL-08)

- `singletons/character_manager/character_manager.gd`: `get_stat_at_level(stat: AttributeType, level: int) -> float`. The base is `stat_progression.get_value_for_level(level)` plus the change in the worn gear's bonus at that value: each equipped item's `get_stat_bonus(stat, value)`, summed, minus `get_gear_bonus(stat)`. It then goes through `_modifiers.apply()`, so every source counts, and percents apply after the flat bonuses as in `get_stat()`. At the current level it equals `get_stat()`.
- Test, in `tests/unit/test_character_manager.gd`: `test_a_stats_total_at_a_level_recounts_its_gear`. This is a table test: a +15% item with floor 1 at several levels; the current level equals `get_stat()`; a PERCENT source counts.

### Task 2: The two bars round down (LL-14)

- `scenes/common/lacquer/lacquer_rod.gd`: `@export var round_down: bool = false`. When it is set, `_apply_step()` uses `floori(fraction × steps + 1e-6)`, so the rod reads full only at 1.0. The 1e-6 lifts a product a hair under its whole number back onto it.
- `round_down = true` on `attribute_tile.tscn`'s `%XpBar` and `character_view.tscn`'s `%DetailXpBar`. No other rod scene changes.
- Tests:
  - `tests/unit/test_lacquer_pieces.gd`: `test_a_rod_can_round_down`.
  - `tests/integration/test_character_book.gd`: `test_the_bars_never_read_full_short_of_a_level`. Body is at Lv 3 with 155.6 XP of 156, and neither the tile's bar nor the page's is full.
  - The tests that expect `roundi` steps move to `floori`.

### Task 3: Madra per cycle, the description and the exact next block

- `scenes/character/character_view.gd`:
  - `effect_lines()` gains `technique: CyclingTechniqueData = null`. For SPIRIT with a technique, the first line is "Madra per cycle", `"%d" % roundi(technique.get_madra_per_cycle(block.get_cycling_madra_multiplier()))`, read from the now block and from the next.
  - `_show_details()` passes `CyclingManager.get_equipped_technique()`.
  - `_POOL_INKS` gains "Madra per cycle" in Madra ink.
  - `STAT_DESCRIPTIONS[SPIRIT]` gets the approved sentence.
  - `_next_level_block()` sets the stat to `CharacterManager.get_stat_at_level(stat, level + 1)`.
- Tests in `test_character_book.gd`:
  - `test_spirit_reads_madra_per_cycle_first`: a table over the three techniques. The first line's now figure starts the drawer's `detail_text()`.
  - `test_each_stat_names_what_it_does`: Spirit, given a technique, starts with Madra per cycle.
  - `test_a_stat_with_no_known_technique_says_so`: points at Strength, since Spirit always has its line.
  - `test_next_figures_count_the_gear_the_next_level_adds`: Spirit at Lv 4 wearing +15% Spirit with Smooth Flow equipped reads "112 → 128".
  - `test_a_capped_spirit_shows_madra_per_cycle_alone`.

### Task 4: The cycles line, and the pages follow the technique

- `character_view.gd`:
  - `static func cycles_to_next_level(stat, technique) -> int`. It returns 0 while the stat is capped, with no technique, or when the technique pays the stat no XP. Otherwise it returns the XP still needed over `get_xp_per_cycle(stat)`, rounded up.
  - `static func cycles_line(count: int, next_level: int) -> String`.
  - `_show_details()` shows `%CyclesRow` only while the count is above 0, and writes `%CyclesLabel`.
  - `_ready()` connects `CyclingManager.equipped_technique_changed` to `_refresh_if_shown` through `.unbind(1)`.
  - The class doc names the equipped technique.
- `character_view.tscn`: `DetailPanel` gets a `VBoxContainer` (`DetailStack`, separation 0) holding `Header` and `%CyclesRow`. `%CyclesRow` is a hidden `MarginContainer` whose left margin puts its text under the XP bar (the icon well's 72 px plus the header's 16 px separation). It holds `%CyclesLabel`, a `LabelBookDetail` Label that wraps (`autowrap_mode = 3`). A hidden row takes no space, so the panel keeps today's size on pages with no count.
- `tests/integration/test_boards_never_trim_text.gd`: add `CyclesLabel` to `character_view.tscn`'s wrapping list.
- Tests in `test_character_book.gd`:
  - `test_cycles_to_next_level_reads_the_equipped_technique`: a table test covering Spirit and Control with Smooth Flow, Mind with Smooth Flow (0), Mind with Torrential Flow, Strength (0), and a capped Spirit (0).
  - `test_the_cycles_line_follows_the_equipped_technique`: with the book open on Control and Smooth Flow equipped, the line reads "4 perfect cycles to Lv 3". Equipping the Foundational Technique hides it at once.
  - `test_the_cycles_line_names_no_technique`.
  - `test_a_physical_page_shows_no_cycles_line`.

### Task 5: Verify

- `tests/run_tests.ps1` is green.
- The issue's Done-when checks run in the real game on `-- --preset=path_open --save=user://dev/runs/book-cycling-lines.tres`.
- A copy of an old save loads and plays. No saved field changes, and no save version is taken.

## Built differently

- **LL-09:** both book tags became `PaperTag` instances. `PaperTag` gained `set_figure()`, so the copied fit is gone instead of moved, and the tags refit when the theme changes, as the Inventory's do. `AttributeTile.xp_fraction()` is the one fraction the tile and the page share.
- **The cycles row:** `DetailPanel`'s `DetailStack` holds `Header` and `%CyclesRow`. The row's 3 px bottom margin makes the panel grow exactly the canvas's 20 px.
- **`cycles_to_next_level()`** never returns less than 1 under the cap, as a guard. A stat under the cap always needs some XP, so the guard changes no figure.
- **Done-when checks:** they ran in the real main scene, driven by `mockups/book_cycling_checks/check.gd` (gitignored). They used `--preset=path_open --save=user://dev/runs/book-cycling-lines.tres`, the real cycling board with a scripted perfect Smooth Flow cycle (four PERFECT presses, +30 Control XP, the count 4 → 3), and the dev commands. The old-save check ran on a copy of the checkout's save.
