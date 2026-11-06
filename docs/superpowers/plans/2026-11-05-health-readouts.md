# Run on the Saved Health and Show It (#98) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The player's Health becomes ResourceManager's saved pool in runs, the fight lets go of it when it ends, and the cabinet and the Character book show it with the vitals plate's figure.

**Architecture:** The player's `VitalsManager` reads and writes Health through `ResourceManager`, in the same functions #89 made a facade for Madra; enemies keep their own Health. `AdventureCombat.stop()` disconnects the player's Health handler. The cabinet gains a Health readout with a pellet landing (hold and release), the book's fight row reads the pool, and every Health readout prints through `VitalsText`.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** [Phase 5 and Anti-goals of the stats rework design](../specs/2026-11-04-stats-rework-design.md), the master plan's [Phase 5 outline](2026-11-04-stats-rework.md) (Tasks 5.1, 5.3, 5.4), issue #98, and #89's answers (issue #89, PR #123).

## Global Constraints

- Never two different Health numbers on screen: every player Health readout prints through `VitalsText` (`health_figure` rounds up, `health_max_figure` rounds down, `health_pair` joins them as "62 / 100").
- UI nodes live in `.tscn` scenes with theme variants; scripts only set data. No text is cut off.
- New art ends in `_ai`; Lionel's art is never edited.
- `LacquerPellet.Ramp` is append-only and claimed at merge: `HEALTH = 10`, strip row 11.
- No save version step: #93 added `SaveGameData.health`. What changes is who writes it (runs do now); the PR says so.
- Enemies keep Health of their own.
- A feature PR edits no living doc; the PR ends with `## Docs to update`.
- Static types, `##` docs on public functions, `_` on private ones; conventional commits.
- Tests call production code; no test of how a screen looks.

## Review Focus

1. Health set to 0 after a fight, on the map or at home (the dev panel's Set Health), logs no "Combat Defeat...": Task 1's test.
2. A save swap (a preset switch, a save reset) while the cabinet or the book is shown: both read the new save's Health at once, since every bind announces it. Task 4's `test_a_loaded_save_shows_its_health`.
3. A max that drops under the pool (Body gear off): the pool comes down and the cabinet and the book show the lower figure. Task 4's and Task 6's max tests.
4. A fractional Health (61.3) reads "62 / 100" on the cabinet and the book, as on the vitals plate and the end card. Task 4's and Task 6's rounding cases.
5. Health in flight above what the pool holds: the cabinet's figure never reads below 0. Task 4's hold test.

## Mock-up answers

Canvas "One Health pool": https://claude.ai/artifact/Tb2mF2n82eQmR2tLh3hQnN, **approved as drawn by Lionel on 2026-11-05**; the answers are recorded on #98.

- Q1, the cabinet's readout: A, a Health orb row on top in the vitals plate's order (Health, Madra, Core Density), each row at the plate's offsets.
- Q2, the cabinet grows 92 px (board 504 → 596, new art). The Goals board hangs at (24, 616); the full log is 440 px, 13 whole lines. Runs keep (24, 368).
- Q3, Health pellets: land on the Health orb, held until each lands; crimson strip row after Control's.
- Q4, the book: HEALTH reads "62 / 100" in Health ink (#5A1626), live; Body's MAX HEALTH in Health ink too.

---

### Task 1: The fight lets go of the player's Health

**Files:**
- Modify: `scenes/combat/adventure_combat/adventure_combat.gd` (`stop()`)
- Test: `tests/unit/test_adventure_combat_victory_event.gd`

**Interfaces:**
- Produces: after `AdventureCombat.stop()`, `PlayerManager.vitals_manager.health_changed` no longer reaches `_on_player_health_changed`.

- [ ] **Step 1: Write the failing test**

```gdscript
## Once the fight stops it no longer listens to the player's Health, so Health
## reaching 0 after it (the dev panel on the map or at home) reports no fight.
func test_health_at_zero_after_the_fight_reports_nothing() -> void:
	_start_fight()
	_combat.enemy_combatant.vitals_manager.apply_vitals_change(LETHAL_DAMAGE)
	_combat.stop()
	PlayerManager.vitals_manager.apply_vitals_change(LETHAL_DAMAGE)
	assert_eq(_combat_ends.size(), 1, "only the won fight ended")
```

- [ ] **Step 2: Run it and see it fail** (`_combat_ends.size()` is 2)

Run: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/test_adventure_combat_victory_event.gd -gexit`

- [ ] **Step 3: In `stop()`, disconnect `_on_player_health_changed` from `PlayerManager.vitals_manager.health_changed` when connected** (the vitals manager may have been replaced by `reset_vitals()`; check `is_instance_valid`).

- [ ] **Step 4: Run the file again: PASS**

- [ ] **Step 5: Commit** `fix(combat): let go of the player's Health when a fight stops`

### Task 2: The player's Health is the saved pool

**Files:**
- Modify: `scenes/combat/combatant/vitals_manager/vitals_manager.gd`, `singletons/player_manager/player_manager.gd` (docs)
- Test: `tests/unit/test_player_vitals_manager.gd`, `tests/unit/test_change_vitals_effect_data.gd`, `tests/integration/test_dev_hooks.gd`, `tests/integration/test_vitals_plate.gd`

**Interfaces:**
- Consumes: `ResourceManager.get_health()`, `get_max_health()`, `set_health(amount)`, `add_health(amount, quiet)`, `health_changed` (#93).
- Produces: for the player, `VitalsManager.current_health` and `max_health` read the pool, a `current_health` write calls `set_health()`, `apply_vitals_change(health_amount)` calls `add_health(amount, true)` (nothing for a zero change), and `health_changed` is emitted once per pool change, from `ResourceManager.health_changed`. `initialize_current_values()` still fills the player's Health, through the pool (until #104). An enemy's Health is unchanged.

- [ ] **Step 1: Write the failing tests** in `test_player_vitals_manager.gd`, a section "HEALTH: THE ONE POOL" after the Madra one, mirroring its tests:

```gdscript
# _max_health_source(amount), the file's FLAT Stat.MAX_HEALTH source, serves these too
func test_the_players_health_reads_the_pool() -> void:
	ResourceManager.set_health(46.0)
	CharacterManager.set_modifier_source(TEST_SOURCE, _max_health_source(20.0))
	assert_eq(_vitals.current_health, 46.0, "current Health is the pool")
	assert_eq(_vitals.max_health, 120.0, "max Health is the pool's max")

func test_health_changes_land_in_the_pool() -> void   # table: a hit (50, -8 → 42), a rest tile (50, +20 → 70),
                                                       # past the max (90, +20 → 100), past 0 (5, -8 → 0)
func test_writing_current_health_sets_the_pool() -> void  # current_health = 33 → get_health() == 33
func test_each_health_change_reaches_the_vitals_once() -> void
	# watch _vitals; ResourceManager.add_health(-5.0, true); apply_vitals_change(-10.0)
	# health_changed emitted twice, last with 85.0 (a fresh save binds at 100)
func test_a_change_with_no_health_leaves_the_pool_quiet() -> void  # apply_vitals_change(0, -5, -3): no ResourceManager.health_changed
func test_a_rest_tile_heals_the_pool_quietly() -> void   # a ChangeVitalsEffectData(health_change = 10) at 50 → 60, no message_logged
func test_initialize_current_values_fills_the_pool() -> void  # set_health(30); initialize → get_health() == 100
func test_an_enemys_health_is_its_own() -> void
	# enemy from CharacterAttributesData.make(); initialize; apply_vitals_change(-30) → enemy 70, pool still 100
```

Also DM-01's missing check, in the GEAR section:

```gdscript
func test_unequipping_agility_gear_lowers_max_stamina_again() -> void:
	_equip(_make_gear(EquipmentSlot.MAIN_HAND, {&"agility": 0.4}), EquipmentSlot.MAIN_HAND)
	InventoryManager.unequip_item(EquipmentSlot.MAIN_HAND)
	assert_eq(_vitals.max_stamina, 50.0, "back to 10 Agility x 5")
```

`test_new_max_health_fills_the_next_run` stays: the run start fills the geared max, now through the pool. The file's class doc says Health is the pool too. In `test_change_vitals_effect_data.gd`: `test_process_heals_the_saved_pool` (a `health_change = 15` effect at 40 Health → 55).

- [ ] **Step 2: Run both files and see the Health tests fail**

- [ ] **Step 3: Make Health a facade in `vitals_manager.gd`**, in the same shape as Madra's: a `max_health` getter and a `current_health` getter and setter that go to `ResourceManager` while `is_player`; `_ready()` connects `ResourceManager.health_changed` to a handler that re-emits `health_changed`; `_apply_health_change()` sends a non-zero player change to `add_health(amount, true)` (keeping its `Log.info` line for changes over 1); `_on_stats_changed()` no longer writes `max_health`. Class doc, `initialize_current_values()`'s and `apply_vitals_change()`'s docs say Health is the pool. `PlayerManager`'s class doc and `reset_vitals()`'s doc: a fresh vitals manager reads the save's Health; only Stamina and the regen are the run's.

- [ ] **Step 4: Update the tests the facade changes**
  - `test_dev_hooks.gd::test_reset_vitals_gives_a_fresh_vitals_manager`: the new manager's `current_health` is `ResourceManager.get_health()`, and `ResourceManager.health_changed` keeps its connection count ("and its Health hook").
  - `test_vitals_plate.gd`: `_set_vitals()` sets max Health with a FLAT `Stat.MAX_HEALTH` source beside the Madra one (one source returning both modifiers), then `ResourceManager.set_health()`; the expected figures stay.

- [ ] **Step 5: Run the suite** (`tests/run_tests.ps1`). The other writers of the player's `current_health` (directly or through `adventure_map_fixture.gd`'s `swap_in_known_vitals()`) should stay green: each writes into the save it bound, or puts a save's own Health back. Fix any that write into the session save after restoring it, by restoring the save last.

- [ ] **Step 6: Commit** `feat(combat): make the player's Health the saved pool`

### Task 3: The player's combatant drops its unused VitalsManager

**Files:**
- Modify: `scenes/combat/combatant/combatant_node.gd` (`setup()`)
- Test: `tests/unit/test_adventure_combat_victory_event.gd`

**Interfaces:**
- Produces: a `CombatantNode` set up with an external vitals manager frees its own `VitalsManager` child; an enemy keeps it.

- [ ] **Step 1: Write the failing test**

```gdscript
func test_only_the_enemy_carries_a_vitals_manager_of_its_own() -> void:
	_start_fight()
	assert_same(_combat.player_combatant.vitals_manager, PlayerManager.vitals_manager, "the player fights on PlayerManager's")
	assert_eq(_combat.player_combatant.find_children("*", "VitalsManager", true, false).size(), 0, "with none of its own")
	assert_eq(_combat.enemy_combatant.find_children("*", "VitalsManager", true, false).size(), 1, "the enemy has its own")
```

- [ ] **Step 2: Run it: FAIL** (the player's node has 1)
- [ ] **Step 3: In `setup()`, with an external manager, remove the node's own `%VitalsManager` child and free it before taking the external one**
- [ ] **Step 4: Run it: PASS**
- [ ] **Step 5: Commit** `refactor(combat): drop the player combatant's unused VitalsManager`

### Task 4: The cabinet's Health readout (after the canvas)

**Files:**
- Create: `assets/ui/lacquer/lacquer_cult_health_ai.png` (444x596: `lacquer_cult_stats_ai.png` with a 92 px band of its plain lacquer repeated, as the canvas drew it)
- Modify: `scenes/zones/cultivator_plate/cultivator_plate.gd` and `.tscn`
- Test: `tests/integration/test_cultivator_plate.gd`

**Interfaces:**
- Consumes: `ResourceManager.health_changed`, `get_health()`, `get_max_health()`; `CharacterManager.stats_changed`; `VitalsText`.
- Produces: `CultivatorPlate.get_health_orb_global_position() -> Vector2`, `hold_health(amount: float) -> void`, `release_health(amount: float) -> void`, for #100's pellets. Unique names `%HealthOrb`, `%HealthValueLabel`, `%HealthMaxLabel`.

- [ ] **Step 1: Write the failing tests**

```gdscript
func test_shows_health_over_max() -> void   # a new save: "100", "/ 100", fill 1.0
func test_health_follows_its_signal_and_rounds_as_the_vitals_plate() -> void
	# table on set_health(): 46 → "46"; 61.3 → "62"; 0.4 → "1"; 0 → "0"
func test_the_health_max_follows_the_max_health_stat() -> void
	# set_health(100); MAX_HEALTH +40 source → "/ 140", fill 100/140; source removed → pool clamps, "100" "/ 100"
func test_a_loaded_save_shows_its_health() -> void   # a SaveGameData with health 37 loaded → "37"
func test_held_health_shows_once_released() -> void
	# set_health(46); hold_health(6) → "40", fill 0.40; release 4 → "44"; release 2 → "46"
	# and hold_health(60) at 46 → "0", never below
func test_health_pellets_land_on_the_health_orb() -> void   # get_health_orb_global_position() == orb centre
```

- [ ] **Step 2: Run the file: FAIL**
- [ ] **Step 3: Build the readout in the scene**: the vitals plate's Health nodes (`HealthOrb` with the Madra orb shader and the crimson ramp on its material, `lacquer_orb_health_ai.png`; `HealthTitleLabel` "Health", `LabelLacquerDetail`; `HealthRow` with `HealthValueLabel` and `HealthMaxLabel`, `LabelLacquerBig`, the max in tan) at the plate's offsets (orb 18,16; title 114,22; row 114,44). Every other node moves down 92 px, the Madra title and row to the plate's (110 and 132); the board takes the new art; the root ends at 616.
- [ ] **Step 4: In the script**: `_update_health()` shows `maxf(get_health() - _held_health, 0.0)` against `get_max_health()` through `VitalsText`, the fill at their fraction; it runs on `_ready`, `health_changed` and `stats_changed`. `hold_health()`/`release_health()` as `hold_madra()`/`release_madra()`, with `_less_held()`. Class doc names the Health row and its landing.
- [ ] **Step 5: Run the file: PASS; run `test_cycling_view.gd` and the zone tests** (the Madra orb moved; its pellets read its position)
- [ ] **Step 6: Commit** `feat(zones): show the Health pool on the cabinet`

### Task 5: The Goals board and the full log move under the taller cabinet

**Files:**
- Modify: `scenes/ui/main_view/states/zone_view_state.gd` (`GOALS_POSITION`), `scenes/ui/goals_panel/goals_panel.tscn` (root 616 to 836) and `goals_panel.gd` (cords doc), `scenes/ui/log_window/log_window.gd` (`FULL_LOG_HEIGHT`) and `log_window.tscn` (`FullBoard` offset_top −440; `FullLogText` offset_bottom 64 + 13 × 26 = 402)
- Test: `tests/integration/test_main_game_layout.gd`

**Interfaces:**
- Produces: `ZoneViewState.GOALS_POSITION == Vector2(24, 616)`; `LogWindow.FULL_LOG_HEIGHT == 440.0`. `AdventureViewState.GOALS_POSITION` stays (24, 368).

- [ ] **Step 1: Write the failing tests**: `PLACES`' GoalsPanel pin becomes (24, 616), and a rule test:

```gdscript
## The open full log reaches up from the log's slot to the Goals board's top in
## the zone view: it covers the Goals board exactly, and never the cabinet.
func test_the_full_log_covers_the_goals_board_and_never_the_cabinet() -> void:
	var main_game: Node = autofree(MAIN_GAME_SCENE.instantiate())
	var log_window: Control = main_game.get_node("MainView/LogWindow")
	var cabinet: Control = main_game.get_node("MainView/ZoneView/CultivatorPlate")
	var full_log_top: float = log_window.position.y + log_window.size.y - LogWindow.FULL_LOG_HEIGHT
	assert_eq(full_log_top, ZoneViewState.GOALS_POSITION.y, "it starts at the Goals board's top")
	assert_true(full_log_top >= cabinet.position.y + cabinet.size.y, "below the cabinet")
```

- [ ] **Step 2: Run the file: FAIL**
- [ ] **Step 3: Move the constants and the two scenes as listed**
- [ ] **Step 4: Run the file and `test_log_board.gd`, `test_goals_panel.gd`: PASS**
- [ ] **Step 5: Commit** `feat(ui): hang the Goals board and the full log under the taller cabinet`

### Task 6: The book's Health row

**Files:**
- Modify: `scenes/character/character_view.gd`, `scripts/utils/theme_constants.gd` (`BOOK_HEALTH_INK := Color("#5A1626")`)
- Create: `tests/integration/test_character_book_health.gd`
- Modify test: `tests/integration/test_character_book.gd::test_in_a_fight_lists_every_total`

**Interfaces:**
- Consumes: `CharacterView._rebuild_fight_rows()` (#89), `VitalsText.health_pair()`.
- Produces: `fight_lines()`'s Health entry reads `VitalsText.health_pair(get_health(), get_max_health())`; the open book rebuilds the fight rows on `ResourceManager.health_changed`; "Health" and "Max Health" values print in `BOOK_HEALTH_INK`, as "Madra" and "Max Madra" print in `BOOK_MADRA_INK`.

- [ ] **Step 1: Write the failing tests**, mirroring `test_character_book_madra.gd`:

```gdscript
func test_the_health_line_shows_the_saved_pool() -> void   # set_health(61.3) → "62 / 100"
func test_the_health_row_follows_the_pool_and_its_max_while_open() -> void
	# _view.show(); refresh(); set_health(40) → row "40 / 100"; MAX_HEALTH +40 source → "40 / 140"
```

and `test_in_a_fight_lists_every_total`'s Health assertion reads `VitalsText.health_pair(ResourceManager.get_health(), ResourceManager.get_max_health())`.

- [ ] **Step 2: Run them: FAIL**
- [ ] **Step 3: Implement**: the Health entry, `ResourceManager.health_changed` hooked as the Madra one is (rebuilding only the fight rows while shown), the ink map, the docs.
- [ ] **Step 4: Run both book files: PASS**
- [ ] **Step 5: Commit** `feat(character): show the Health pool in the book's fight block`

### Task 7: The Health pellet row

**Files:**
- Modify: `assets/ui/lacquer/lacquer_pellet_strip_ai.png` (an 11th row: the Madra row recoloured to the crimson ramp: `#E8F6FD`→`#FFD9D2`, `#849BE4`→`#B8304A`, `#BBD5E7`→`#E8737A`, `#1C2F60`→`#5A1626`, the outline kept), `scenes/common/lacquer/lacquer_pellet/lacquer_pellet.gd` (`Ramp.HEALTH`, docs) and `.tscn` (`vframes = 11` on the three sprites)
- Test: `tests/unit/test_lacquer_pellet.gd`

**Interfaces:**
- Produces: `LacquerPellet.Ramp.HEALTH` (10), for #100's Health pellets.

- [ ] **Step 1: Write the failing test**: `test_health_pellets_fly_in_their_own_row`: a pellet with `set_ramp(LacquerPellet.Ramp.HEALTH)` shows strip row 10. `test_the_strip_has_a_row_for_every_ramp` then fails on the strip too.
- [ ] **Step 2: Run: FAIL**
- [ ] **Step 3: Add the enum value, the strip row and the vframes**
- [ ] **Step 4: Run: PASS**
- [ ] **Step 5: Commit** `feat(ui): add a crimson Health row to the pellet strip`

### Task 8: Checks and the PR

- [ ] Run `tests/run_tests.ps1`; confirm any failure in one process before acting on it.
- [ ] Run #98's Done-when checks on `-- --save=user://dev/runs/health-readouts.tres` and record the figures under "Checks run" below.
- [ ] An old save still loads and plays, on a copy.
- [ ] Merge `main` once right before the merge, rerun the suite. Open the PR closing #98, ending with `## Docs to update`.

## Checks run

(Filled in as they run.)

## What was built differently

(Filled in at the end.)
