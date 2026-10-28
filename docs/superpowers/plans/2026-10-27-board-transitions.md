# Board Transitions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The cycling board and the Tribulation board open and close in the zone view's map gap through one shared, reversible transition: the camera pushes in on the cultivator, the dock steps down, the board scales out of the cultivator, and (for cycling) the zone chest's rows slide out and the technique rows slide in.

**Architecture:** A `BoardTransition` node under `MainView` holds one progress value (0 closed, 1 open) and a direction, and each frame draws every piece from that progress through the pure functions in `BoardTransitionTiming`. A board state hands `MainView.open_board()` / `close_board()` a `BoardTransitionSpec`; the state stays on the stack until the close has finished. With no `BoardTransition` (the view-state tests' bare `MainView`s), `MainView` falls back to today's instant open and close. The player itself is a four-state enum FSM (closed, opening, open, closing) folded into progress and direction, not a node-based FSM: four states with no per-state enter/exit logic do not need nodes.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-10-27-board-transitions-design.md`

## Global Constraints

- Every function has an explicit return type; public functions have no leading `_` and a `##` doc comment; class variables are typed; node references use `%Unique` names (CLAUDE.md).
- No UI node is created in code: new Controls go in `.tscn` files (user's standing rule).
- No `print()`; diagnostics through `Log`.
- Never modify `addons/`.
- Stepped moves are even px at constant speed (style guide §8). The board's smooth scale and the camera ease are the only eased motions.
- Opening timeline (ms from the open's start): camera 0–480 ease in-out cubic to 1.5× the current zoom, the cultivator ending at (board centre x, board centre y + 70); dock 0–140 down off screen; board 200–520 scale 0.03 → 1, ease-out cubic, about that point; chest rows out 0–300, swap at 300, rows in and height 300–540; HUD boards (Tribulation) Goals 0–160, log 40–200, off the left edge. Close = the same played backwards.
- Docs follow "Keeping Docs Current" in `docs/README.md` (no counts, no "Last updated", one home per fact).
- Run tests with `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`; confirm a failure with the one-process command it prints.
- Commits: conventional commits, specific files staged, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

**A refinement of the spec's chest timeline, decided here.** The spec's table overlaps the chest's out rows (0–365) with its in rows (260–540), as the mockup drew both lists at once. The chest shows one list at a time (`ZonePanel.set_techniques_mode()` hides one and shows the other), so the plan runs them in sequence inside the same 540 ms: the out rows fill 0–300 and the in rows 300–540, with the stagger shrinking for a long list so each phase keeps its length. Task 10 updates the spec's table to match.

## Review Focus

- **A rebuild of the activity list mid-slide** (`action_completed`, an unlock): the old row nodes are freed and new ones appear. Expect no errors (freed rows are skipped) and every row at rest when the transition ends. Test in Task 5.
- **Esc pressed repeatedly while the board opens, or a start and stop in quick succession from the dev panel:** the board must end fully open or fully closed, the state on the stack exactly when the board is up, with no second callback. Tests in Tasks 5, 7 and 8.
- **A save reset or a dev-panel stop mid-trial while the Tribulation board is still opening:** nothing of the run is applied, and the board closes. Test in Task 8.
- **The player zoomed out (wheel zoom 1) when cycling starts:** the push goes to 1.5 and the restore returns exactly to 1 and the old position. Test in Task 2.
- **A long frame hitch** (a delta of several seconds): progress clamps at 0 or 1 and the transition finishes cleanly in one step. Test in Task 5.

---

### Task 1: The timing functions

**Files:**
- Create: `scripts/utils/board_transition_timing.gd`
- Test: `tests/unit/test_board_transition_timing.gd`

**Interfaces:**
- Produces: `class_name BoardTransitionTiming` (extends `RefCounted`, all static), constants `CAMERA_END_MS = 480.0`, `DOCK_END_MS = 140.0`, `BOARD_START_MS = 200.0`, `BOARD_END_MS = 520.0`, `BOARD_START_SCALE = 0.03`, `CAMERA_ZOOM_FACTOR = 1.5`, `CULTIVATOR_BELOW_CENTRE = 70.0`, `CHEST_SWAP_MS = 300.0`, `CHEST_END_MS = 540.0`, `ROW_OUT_MS = 120.0`, `ROW_IN_MS = 140.0`, `OUT_STAGGER_MAX = 20.0`, `IN_STAGGER_MAX = 25.0`, `HUD_MS = 160.0`, `HUD_STAGGER = 40.0`, and:
  - `static func duration_ms(swaps_chest: bool) -> float` (540 / 520)
  - `static func segment(t_ms: float, start_ms: float, end_ms: float) -> float` (0..1, clamped)
  - `static func snap_even(value: float) -> float` (`roundf(value / 2.0) * 2.0`)
  - `static func camera_weight(t_ms: float) -> float`
  - `static func is_board_shown(t_ms: float) -> bool` (`t_ms >= BOARD_START_MS`)
  - `static func board_scale(t_ms: float) -> float`
  - `static func dock_offset(t_ms: float, travel: float) -> float`
  - `static func out_stagger(row_count: int) -> float`, `static func in_stagger(row_count: int) -> float`
  - `static func row_out_offset(t_ms: float, index: int, row_count: int, travel: float) -> float`
  - `static func row_in_offset(t_ms: float, index: int, row_count: int, travel: float) -> float`
  - `static func chest_height(t_ms: float, from_height: float, to_height: float) -> float`
  - `static func hud_offset(t_ms: float, index: int, travel: float) -> float`
  - `static func cultivator_target(board_rect: Rect2) -> Vector2`
  - `static func push_camera_position(world_point: Vector2, screen_point: Vector2, zoom: float) -> Vector2` (`world_point - (screen_point - ZoneMapMath.VIEWPORT_SIZE / 2.0) / zoom`)

Staggers: `out_stagger(n) = 0 if n <= 1 else minf(OUT_STAGGER_MAX, (CHEST_SWAP_MS - ROW_OUT_MS) / (n - 1))`; `in_stagger(n) = 0 if n <= 1 else minf(IN_STAGGER_MAX, (CHEST_END_MS - CHEST_SWAP_MS - ROW_IN_MS) / (n - 1))`. Row *i* out runs from `i × out_stagger` for `ROW_OUT_MS`; row *j* in runs from `CHEST_SWAP_MS + j × in_stagger` for `ROW_IN_MS`, from `travel` to 0. HUD board *k* runs from `k × HUD_STAGGER` for `HUD_MS`. Every offset and height goes through `snap_even`. `chest_height` lerps over `CHEST_SWAP_MS`–`CHEST_END_MS`.

- [ ] **Step 1: Write the failing tests** — `extends GutTest`, one test per function, with these exact assertions:

```gdscript
func test_durations() -> void:
	assert_eq(BoardTransitionTiming.duration_ms(true), 540.0)
	assert_eq(BoardTransitionTiming.duration_ms(false), 520.0)

func test_board_scale() -> void:
	assert_false(BoardTransitionTiming.is_board_shown(199.0))
	assert_true(BoardTransitionTiming.is_board_shown(200.0))
	assert_almost_eq(BoardTransitionTiming.board_scale(200.0), 0.03, 0.0001)
	assert_almost_eq(BoardTransitionTiming.board_scale(360.0), 0.87875, 0.0001)
	assert_eq(BoardTransitionTiming.board_scale(520.0), 1.0)

func test_camera_weight() -> void:
	assert_eq(BoardTransitionTiming.camera_weight(0.0), 0.0)
	assert_almost_eq(BoardTransitionTiming.camera_weight(240.0), 0.5, 0.0001)
	assert_eq(BoardTransitionTiming.camera_weight(480.0), 1.0)

func test_dock_offset_is_even() -> void:
	assert_eq(BoardTransitionTiming.dock_offset(70.0, 104.0), 52.0)
	assert_eq(BoardTransitionTiming.dock_offset(10.0, 105.0), 8.0)
	assert_eq(BoardTransitionTiming.dock_offset(140.0, 104.0), 104.0)

func test_staggers_keep_each_phase_inside_its_window() -> void:
	assert_eq(BoardTransitionTiming.out_stagger(1), 0.0)
	assert_eq(BoardTransitionTiming.out_stagger(10), 20.0)
	assert_eq(BoardTransitionTiming.out_stagger(11), 18.0)
	assert_eq(BoardTransitionTiming.in_stagger(5), 25.0)
	assert_eq(BoardTransitionTiming.in_stagger(6), 20.0)

func test_row_out_offsets() -> void:
	assert_eq(BoardTransitionTiming.row_out_offset(0.0, 0, 10, 444.0), 0.0)
	assert_eq(BoardTransitionTiming.row_out_offset(60.0, 0, 10, 444.0), 222.0)
	assert_eq(BoardTransitionTiming.row_out_offset(180.0, 9, 10, 444.0), 0.0)
	assert_eq(BoardTransitionTiming.row_out_offset(300.0, 9, 10, 444.0), 444.0)

func test_row_in_offsets() -> void:
	assert_eq(BoardTransitionTiming.row_in_offset(300.0, 0, 5, 444.0), 444.0)
	assert_eq(BoardTransitionTiming.row_in_offset(370.0, 0, 5, 444.0), 222.0)
	assert_eq(BoardTransitionTiming.row_in_offset(440.0, 0, 5, 444.0), 0.0)
	assert_eq(BoardTransitionTiming.row_in_offset(540.0, 4, 5, 444.0), 0.0)

func test_chest_height() -> void:
	assert_eq(BoardTransitionTiming.chest_height(300.0, 746.0, 468.0), 746.0)
	assert_eq(BoardTransitionTiming.chest_height(420.0, 746.0, 468.0), 608.0)
	assert_eq(BoardTransitionTiming.chest_height(540.0, 746.0, 468.0), 468.0)

func test_hud_offsets() -> void:
	assert_eq(BoardTransitionTiming.hud_offset(160.0, 0, 470.0), 470.0)
	assert_eq(BoardTransitionTiming.hud_offset(40.0, 1, 470.0), 0.0)
	assert_eq(BoardTransitionTiming.hud_offset(200.0, 1, 470.0), 470.0)

func test_cultivator_target_and_camera_position() -> void:
	assert_eq(BoardTransitionTiming.cultivator_target(Rect2(680, 24, 564, 1036)), Vector2(962, 612))
	var position: Vector2 = BoardTransitionTiming.push_camera_position(Vector2(100, 100), Vector2(962, 612), 3.0)
	assert_eq(ZoneMapMath.world_to_screen(Vector2(100, 100), position, 3.0), Vector2(962, 612))
```

- [ ] **Step 2: Run them and see them fail**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=res://tests/unit/test_board_transition_timing.gd -gexit`
Expected: parse failure, `BoardTransitionTiming` not found.

- [ ] **Step 3: Implement `scripts/utils/board_transition_timing.gd`** as the Interfaces block gives it. Run `--headless --import` once afterwards so the class name registers.

- [ ] **Step 4: Run the tests and see them pass** (same command). Expected: all pass.

- [ ] **Step 5: Commit** — `feat(ui): add the board transition's timing functions`

---

### Task 2: The camera push

**Files:**
- Create: `scenes/camera/camera_push/camera_push.gd`
- Test: `tests/unit/test_camera_push.gd`

**Interfaces:**
- Produces: `class_name CameraPush extends RefCounted`:
  - `func begin(camera: Camera2D, world_point: Vector2, screen_point: Vector2, end_zoom: float) -> void`: saves the camera's zoom and position unless already saved, and computes the end position with `BoardTransitionTiming.push_camera_position(world_point, screen_point, end_zoom)`.
  - `func apply(weight: float) -> void`: zoom and position lerp from the saved values (weight 0) to the end values (weight 1).
  - `func restore() -> void`: sets exactly the saved zoom and position, then forgets them.
  - `func is_active() -> bool`
- The end zoom is a parameter, so the adventure zoom (fixed zoom 3) can use it later. `ZoneTransition` is not changed.

- [ ] **Step 1: Write the failing tests** with a bare `Camera2D` (`autofree`), zoom `Vector2(2, 2)` and position `Vector2(500, 300)`:
  - `test_apply_one_reaches_the_end_zoom_and_aims_at_the_point`: `begin(camera, Vector2(640, 420), Vector2(962, 612), 3.0)`, `apply(1.0)` → `camera.zoom == Vector2(3, 3)` and `ZoneMapMath.world_to_screen(Vector2(640, 420), camera.position, 3.0) == Vector2(962, 612)`.
  - `test_apply_zero_is_where_it_started`: after `apply(1.0)` then `apply(0.0)` → zoom `(2, 2)`, position `(500, 300)`.
  - `test_restore_is_exact_after_a_partial_push`: `apply(0.37)`, `restore()` → zoom `(2, 2)`, position `(500, 300)` exactly, `is_active()` false.
  - `test_a_second_begin_keeps_the_first_saved_camera`: `apply(0.5)`, `begin(...)` again, `restore()` → zoom `(2, 2)`, position `(500, 300)`.
  - `test_a_zoomed_out_player_is_pushed_to_one_and_a_half`: camera zoom `(1, 1)`, `begin(camera, p, s, 1.5)`, `apply(1.0)` → zoom `(1.5, 1.5)`; `restore()` → `(1, 1)`.

- [ ] **Step 2: Run and see them fail** (`-gtest=res://tests/unit/test_camera_push.gd`, `-gdir=res://tests/unit/`). Expected: `CameraPush` not found.
- [ ] **Step 3: Implement `CameraPush`.** It sets `camera.zoom` and `camera.position` directly, as `ZoneTransition` does, so `CameraZoomController` (which only moves while its own `is_zooming`) and `CameraClampController` (which clamps on the controllers' signals) leave it alone.
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit** — `feat(camera): add a reversible camera push`

---

### Task 3: The chest's slide support

**Files:**
- Modify: `scenes/zones/zone_panel/zone_panel.gd` (`_relayout`, `_place_activity_list`, `_place_technique_list`), `scenes/zones/zone_panel/zone_panel.tscn` (wrap `ActivitiesHeader` in a `HeaderClip` Control: `clip_contents = true`, `mouse_filter = 2`, at (0, 0) and 436 × 1032 so it clips at the chest's inner right edge; `ActivitiesHeader` keeps its unique name)
- Modify: `scenes/zones/zone_panel/activity_list/activity_list.gd`, `scenes/zones/zone_panel/technique_list/technique_list.gd`, `scenes/zones/zone_panel/technique_list/technique_list.tscn` (root `clip_contents = true`)
- Test: `tests/integration/test_zone_panel.gd` (add tests)

**Interfaces:**
- Produces:
  - `ZonePanel.chest_height_for(techniques: bool) -> float`: the height `_relayout()` would give the chest in that mode (the last-cycle line counted only in the techniques mode, the lore as it is now), changing nothing. Extract the arithmetic `_relayout()` and `_place_*_list()` share into a helper both use, so the two cannot drift.
  - `ZonePanel.set_height_override(height: float) -> void` and `ZonePanel.clear_height_override() -> void`: while an override is set, `_relayout()` sizes the chest frame (`size.y`, `_chest_mid`, `_chest_bottom`) to it instead of the natural height; the lists keep their own layout.
  - `ZonePanel.get_slide_rows() -> Array[Control]`: the `ActivitiesHeader` first, then the shown list's rows.
  - `ActivityList.get_slide_rows() -> Array[Control]`: the group label rows and cards, top to bottom, that show at least partly in the scroll window.
  - `TechniqueList.get_slide_rows() -> Array[Control]`: the drawers, top to bottom.
- A row slides by its `position.x`. The containers set x only when they re-sort, so the player sets the offset every frame. A re-sort can undo it for at most one frame.

- [ ] **Step 1: Write the failing tests** in `test_zone_panel.gd`, following its existing fixture:
  - `test_chest_height_for_matches_each_mode`: `chest_height_for(false) == size.y` in the activities mode; after `set_techniques_mode(true)`, `chest_height_for(true) == size.y` and `chest_height_for(false)` equals the activities height read before.
  - `test_height_override_sizes_the_frame_and_clears`: `set_height_override(400.0)` → `size.y == 400.0` and the bottom slice at `400.0 - ZonePanel.CHEST_BOTTOM_HEIGHT`; `clear_height_override()` → back to the natural height.
  - `test_slide_rows_start_with_the_header`: `get_slide_rows()[0]` is the `%ActivitiesHeader` node, and the rest are the activity cards and group labels in top-to-bottom order (assert increasing `global_position.y`). In the techniques mode, the rest are the technique drawers.
  - `test_the_header_and_technique_list_clip`: the header's parent and the technique list both have `clip_contents == true`.
- [ ] **Step 2: Run and see them fail** (`-gdir=res://tests/integration/ -gtest=res://tests/integration/test_zone_panel.gd`).
- [ ] **Step 3: Implement** the Interfaces block. Update the class doc comment of `ZonePanel` for the override and the slide rows.
- [ ] **Step 4: Run `test_zone_panel.gd`, `test_cycling_mode.gd` and the technique and activity list tests**, and see them pass.
- [ ] **Step 5: Commit** — `feat(zones): let the zone chest's rows and height be animated`

---

### Task 4: The boards' rects and the Tribulation's halt

**Files:**
- Modify: `scenes/cycling/cycling_view/cycling_view.gd`, `scenes/tribulation/tribulation_view.gd`
- Test: `tests/integration/test_cycling_view.gd`, `tests/integration/test_tribulation_view.gd` (add tests)

**Interfaces:**
- Produces:
  - `CyclingView.get_board_rect() -> Rect2` and `TribulationView.get_board_rect() -> Rect2`: `%Board`'s global rect.
  - `TribulationView.halt() -> void`: drops a run in progress and its effects (mode `CLOSED`, `_run = null`, `_clear_effects()`), applying nothing, but leaves the board showing. `close()` becomes `halt()` then `hide()`.

- [ ] **Step 1: Write the failing tests:** `test_board_rect_is_the_board` in both files (cycling: `Rect2(680, 24, 564, 1036)` with the scene's default text; Tribulation: x 484, y 24, width 952). In `test_tribulation_view.gd`: `test_halt_mid_run_applies_nothing_and_keeps_the_board_up`, which begins a run, calls `halt()`, advances the test clock past the run's end, and asserts the stage and the core density are unchanged, `get_mode() == TribulationView.Mode.CLOSED`, and `visible` is still true.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both files and see them pass.**
- [ ] **Step 5: Commit** — `feat(ui): expose the board rects and let the Tribulation halt without hiding`

---

### Task 5: The transition player

**Files:**
- Create: `scenes/ui/main_view/board_transition/board_transition_spec.gd`, `scenes/ui/main_view/board_transition/board_transition.gd`, `scenes/ui/main_view/board_transition/board_transition.tscn` (root `Control` named `BoardTransition`, full rect, `z_index = 9`, `mouse_filter = 2`, script attached)
- Test: `tests/unit/test_board_transition.gd`

**Interfaces:**
- Consumes: `BoardTransitionTiming` (Task 1), `CameraPush` (Task 2), the `ZonePanel` API (Task 3).
- Produces:
  - `class_name BoardTransitionSpec extends RefCounted` with `var view: Control`, `var board_rect: Rect2`, `var swaps_chest: bool = false`, `var moves_hud_boards: bool = false`, `var holder: MainViewState = null`.
  - `class_name BoardTransition extends Control` with:
    - `signal opened` and `signal closed`
    - `func bind(dock: Control, zone_panel: ZonePanel, hud_boards: Array[Control], camera: Camera2D, cultivator: Node2D) -> void` (any may be null; the HUD boards in order Goals, log)
    - `func open(spec: BoardTransitionSpec) -> void`: from closed, records the rest positions (dock y, HUD boards x), begins the camera push (`end_zoom` = current zoom × `CAMERA_ZOOM_FACTOR`, aimed at `cultivator.global_position` → `cultivator_target(spec.board_rect)`), reads both chest heights with `chest_height_for()`, and collects the shown list's rows; while closing, it turns around and drops the pending close callback; while opening or open, it does nothing. If another spec's board is not closed, that board is first snapped closed (everything restored, its callback called).
    - `func close(on_closed: Callable = Callable()) -> void`: turns around to closing and keeps `on_closed` (replacing an earlier one); when already closed, calls `on_closed` at once.
    - `func advance(delta: float) -> void`: moves the progress by `delta × 1000 / duration_ms(spec.swaps_chest)` in the current direction, clamped to 0..1, and applies it; `_process()` calls it while moving.
    - `func finish() -> void`: jumps to the current direction's end.
    - `func is_moving() -> bool`, `func is_closing() -> bool`, `func is_open() -> bool`, `func get_progress() -> float`, `func get_spec() -> BoardTransitionSpec`
- What each frame applies, at `t = progress × duration`:
  - camera: `apply(camera_weight(t))`
  - dock: y = rest + `dock_offset(t, 1080 − rest y)`, hidden once the offset reaches the travel
  - view: `visible = is_board_shown(t)`, `pivot_offset = cultivator_target(board_rect) − view.global_position`, `scale = Vector2.ONE × board_scale(t)`
  - chest (if `swaps_chest`): the techniques mode on iff `t >= CHEST_SWAP_MS`. On a mode switch, restore the old rows' x, call `set_techniques_mode()`, and collect the new rows. Activity rows use `row_out_offset`, technique rows `row_in_offset`, with travel `zone_panel.size.x`. The height override is `chest_height(t, h_activities, h_techniques)` while `CHEST_SWAP_MS < t < CHEST_END_MS`, and cleared otherwise.
  - HUD boards (if `moves_hud_boards`): x = rest − `hud_offset(t, k, rest x + width)`
  - `mouse_filter = STOP` while moving, `IGNORE` otherwise
- At progress 1: scale 1, rows at rest, override cleared, emit `opened`. At progress 0: the view hidden, scale 1 and `pivot_offset` zero, dock and HUD boards and rows at rest, the dock shown, override cleared, `CameraPush.restore()`, then the pending callback (once), then `closed`. A freed row (`is_instance_valid`) is skipped.

- [ ] **Step 1: Write the failing tests.** Build the player from its scene with `add_child_autofree` and `set_process(false)`, and drive it with `advance()` only. Bind it to plain Controls for the dock, the HUD boards and the view (`Control` at (0, 0), 1920 × 1080), a real `ZonePanel` scene (as `test_cycling_mode.gd` builds it), a `Camera2D` (zoom 2) and a `Node2D` cultivator. The spec's `board_rect` is `Rect2(680, 24, 564, 1036)`. Tests:
  - `test_the_view_appears_at_the_board_start_scaled_from_the_cultivator`: `advance(0.19)` → view hidden; `advance(0.02)` (t 210) → shown, `scale.x` almost `BoardTransitionTiming.board_scale(210.0)` (about 0.118), `pivot_offset == Vector2(962, 612)`; `finish()` → `scale == Vector2.ONE`, `opened` emitted once (`watch_signals`).
  - `test_the_dock_steps_off_and_comes_back`: after `advance(0.14)` the dock is hidden; after `close()` and `finish()` it is shown at its rest y.
  - `test_the_shield_blocks_the_mouse_only_while_moving`: STOP while opening, IGNORE when open, STOP while closing, IGNORE when closed.
  - `test_the_camera_is_pushed_and_restored_exactly`: at progress 1 the camera zoom is `(3, 3)` and the cultivator is at screen (962, 612); after `close()` and `finish()` the zoom and position equal the starting ones exactly.
  - `test_a_reversal_mid_open_restores_everything`: `advance(0.3)`, `close(cb)`, `finish()` → the view hidden, the camera, dock and chest as they started, the callback called once.
  - `test_the_chest_swaps_at_the_swap_point_both_ways`: at t 299 the chest is in the activities mode; at t 301 in the techniques mode; reversing back below 300 returns it to the activities mode.
  - `test_the_height_override_lives_between_the_swap_and_the_end`: at t 420 `zone_panel.size.y == BoardTransitionTiming.chest_height(420, h_act, h_tech)`; at progress 1 `size.y == zone_panel.chest_height_for(true)`.
  - `test_rows_slide_and_end_at_rest`: during the out phase the first activity row's x is greater than its rest x; at progress 1 every technique row is at rest.
  - `test_a_row_freed_mid_slide_is_skipped`: free one collected row mid-slide; `finish()` raises no error and the other rows end at rest.
  - `test_reopening_mid_close_drops_the_callback`: `close(cb)`, `advance(0.1)`, `open(spec)`, `finish()` → the callback is never called, and the view is open.
  - `test_close_when_closed_calls_back_at_once`.
  - `test_a_long_hitch_finishes_in_one_step`: `advance(5.0)` → progress 1 and `opened` emitted once.
  - `test_missing_pieces_are_skipped`: `bind(null, null, [], null, null)`, then open, `finish()`, close, `finish()` raise no errors and the view ends hidden.
  - `test_hud_boards_step_off_left_and_back`: with `moves_hud_boards`, at progress 1 each HUD board's right edge is at or left of x 0; after the close, both are at their rest x.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the spec class, the scene and the player.
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit** — `feat(ui): add the reversible board transition player`

---

### Task 6: MainView's board API

**Files:**
- Modify: `scenes/ui/main_view/main_view.gd`, `scenes/main/main_game/main_game.tscn` (instance `board_transition.tscn` under `MainView` as `BoardTransition` with `unique_name_in_owner = true`, and set `unique_name_in_owner = true` on `ZoneTilemap`)
- Test: `tests/unit/test_cycling_mode.gd` (rework the `set_cycling_mode` tests)

**Interfaces:**
- Consumes: `BoardTransition`, `BoardTransitionSpec` (Task 5).
- Produces, on `MainView`:
  - `var board_transition: BoardTransition = null` (set in `_ready()` with `get_node_or_null("%BoardTransition")`, then bound to the dock, the chest, `[goals_panel, log_window]`, the zone map's camera (`%ZoneTilemap.get_camera()`) and its `character_body`)
  - `func open_board(spec: BoardTransitionSpec) -> void`
  - `func close_board(spec: BoardTransitionSpec, on_closed: Callable) -> void`
  - `func is_board_moving() -> bool` and `func is_board_closing() -> bool` (false with no player)
- With a player: `open_board()` turns the map's input off at once (`zone_map_viewport.gui_disable_input = true`) and calls `board_transition.open(spec)`. `close_board()` calls `board_transition.close()` with a callback that turns the map's input back on and then calls `on_closed`.
- With no player (the tests' bare `MainView`s): `open_board()` does today's instant open: `set_board_mode(true)`, `zone_panel.set_techniques_mode(true)` if `swaps_chest` and there is a chest, `hide_hud_boards(spec.holder)` if `moves_hud_boards`, then `spec.view.visible = true`. `close_board()` undoes all of it in reverse order and calls `on_closed`.
- `set_cycling_mode()` is removed, since no production code calls it now. `set_board_mode()` stays for the fallback.

- [ ] **Step 1: Rework the failing tests** in `test_cycling_mode.gd`: the `set_cycling_mode(true/false)` tests become `open_board(spec)` / `close_board(spec, cb)` tests on the bare `MainView`, with a cycling spec (`swaps_chest = true`). Same assertions: the chest in the techniques mode, the dock hidden, the map without input, and all of it back after the close, with `cb` called once. Keep the missing-piece tests.
- [ ] **Step 2: Run and see them fail** (`open_board` not found).
- [ ] **Step 3: Implement**, and update `MainView`'s class doc comment.
- [ ] **Step 4: Run `test_cycling_mode.gd`, `test_view_state_hud_positions.gd` and `test_tribulation_view_state.gd`.** Expected: all pass.
- [ ] **Step 5: Commit** — `feat(ui): open and close map-gap boards through MainView`

---

### Task 7: Cycling on the transition

**Files:**
- Modify: `scenes/ui/main_view/states/cycling_view_state.gd`
- Test: `tests/unit/test_cycling_mode.gd` (add tests)

**Interfaces:**
- Consumes: `MainView.open_board`, `close_board`, `is_board_closing` (Task 6); `CyclingView.get_board_rect()` (Task 4).
- Behaviour:
  - `enter()`: blocks the full log, then `open_board(spec)`. The spec has the cycling view, `get_board_rect()` when the view is a `CyclingView` (else the view's global rect), `swaps_chest = true`, and `holder = self`.
  - `exit()`: lifts the full-log block only.
  - `_on_stop_cycling()`: `close_board(spec, remove_state(self))`.
  - `_on_start_cycling()`: pushes the state when it is not on the stack; when it is (a close in progress), calls `open_board(spec)`, which reverses the close.
  - `handle_input()`: `close_cycling_view` calls `ActionManager.stop_action()` unless `is_board_closing()`; nothing else.

- [ ] **Step 1: Write the failing tests**, on a `MainView` that has a real `BoardTransition` (added with `add_child_autofree`, `set_process(false)`, and bound to the test's stand-ins), using `_on_start_cycling` / `_on_stop_cycling` and `board_transition.advance()`:
  - `test_the_state_stays_until_the_close_has_finished`: after a stop, the state is still in `state_stack` and the full log is still blocked; after `finish()`, it is gone and the block is lifted.
  - `test_a_start_while_closing_reverses_and_keeps_the_state`: stop, `advance(0.1)`, start → the state is in the stack once, `is_board_closing()` is false, and after `finish()` the board is open.
  - `test_esc_while_closing_does_nothing`: during the close, `handle_input` with `close_cycling_view` does not call `stop_action` (no current-action change).
  - `test_menu_keys_during_the_close_are_dropped`: during the close, `handle_input` with `open_inventory` leaves `state_stack` unchanged.
  - Keep the existing bare-`MainView` tests passing: they cover the fallback.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement**, and update the class doc comment.
- [ ] **Step 4: Run `test_cycling_mode.gd` and `test_cycling_view.gd`.** Expected: all pass.
- [ ] **Step 5: Commit** — `feat(cycling): open and close the cycling board through the transition`

---

### Task 8: The Tribulation on the transition

**Files:**
- Modify: `scenes/tribulation/tribulation_view_state.gd`
- Test: `tests/unit/test_tribulation_view_state.gd`, `tests/integration/test_tribulation_flow.gd` (add tests)

**Interfaces:**
- Consumes: Tasks 4 and 6.
- Behaviour:
  - `enter()`: blocks the full log, then `open_board(spec)`. The spec has the Tribulation view, its `get_board_rect()`, `swaps_chest = false`, `moves_hud_boards = true`, and `holder = self`. The fallback hides the HUD boards; the player slides them.
  - `_on_stop_tribulation()`: `tribulation_view.halt()` at once (nothing of a run is applied from here on), then `close_board(spec, remove_state(self))`.
  - `exit()`: `tribulation_view.close()` and lifts the full-log block.
  - `_on_start_tribulation()`: as today, and when the state is already on the stack, also `open_board(spec)` (reversing a close).
  - `handle_input()`: does nothing while `is_board_closing()`. While `is_board_moving()` (opening), only `ui_cancel` acts (`view.cancel()`). Otherwise, as today.

- [ ] **Step 1: Write the failing tests** (a `MainView` with a real `BoardTransition`, as in Task 7):
  - `test_a_stop_while_the_board_opens_applies_nothing_and_closes`: start, `advance(0.1)`, stop from outside (`ActionManager.stop_action()` with the dev-panel path, as the existing mid-trial test does) → the run is dropped, the stage and core density are unchanged, and after `finish()` the board is hidden and the state is gone.
  - `test_space_while_opening_does_not_begin_the_run`: during the open, `handle_input` with `tribulation_press` leaves the view on its intro.
  - `test_the_hud_boards_are_back_after_the_close`: the Goals board and log are at their rest x after the close.
  - The existing bare-`MainView` tests keep passing (the fallback).
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement**, and update the class doc comment.
- [ ] **Step 4: Run `test_tribulation_view_state.gd`, `test_tribulation_flow.gd` and `test_tribulation_view.gd`.** Expected: all pass.
- [ ] **Step 5: Commit** — `feat(tribulation): open and close the Tribulation board through the transition`

---

### Task 9: See it in the game

**Files:**
- Create (scratch, not committed): a capture script in the session scratchpad, modelled on the brainstorm's `capture_layers.gd`. It blocks saving with `PersistenceManager.set("_save_blocked", true)`, starts the cycling action, and saves screenshots at 100, 250, 400 and 600 ms into the open and again into the close.

- [ ] **Step 1: Run the full suite:** `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`. Expected: every script passes.
- [ ] **Step 2: Run the capture script** with `--path . --resolution 1920x1080 -s <script>` and read the frames. Expected: the dock stepping down, the board small near the cultivator and growing, the chest's rows partly out and then the techniques in, and in the close the same backwards ending on the untouched zone view (camera where it started).
- [ ] **Step 3: Repeat for the Tribulation** with the dev panel's path to start it (or `ActionManager.select_action()` on a Tribulation action after `ResourceManager` is filled). Expected: the log and Goals board stepping off left and back.
- [ ] **Step 4: Fix** anything the frames show (an override not cleared, a row off rest), with a test for it in the owning task's test file, and commit as `fix(ui): …`.

---

### Task 10: The docs

**Files:**
- Modify: `docs/infrastructure/MAIN_VIEW.md` (a "Board transitions" section: what the transition does, the timeline's owner `BoardTransitionTiming`, `open_board` / `close_board`, the spec's fields, how a board declares itself, the input rules; the state-table rows for `CyclingViewState` and `TribulationViewState`; the ActionManager-driven flow; the node tree gains `BoardTransition`; drop `set_cycling_mode`)
- Modify: `docs/STYLE_GUIDE.md` §8 (a row next to Camera: "Board open and close: the board scales smoothly out of the cultivator (0.32 s, ease-out cubic) and back", named as an exception)
- Modify: `docs/cycling/CYCLING.md` and `docs/cultivation/breakthrough-tribulation.md` (one line each linking to the section, where they describe how the board opens)
- Modify: `docs/superpowers/specs/2026-10-27-board-transitions-design.md` (the chest rows of the opening timeline: out 0–300, swap at 300, in and height 300–540, with the shrinking stagger, and why)

- [ ] **Step 1: Write the doc changes.** Check the rules in "Keeping Docs Current": no counts, no test file lists, no private helpers named.
- [ ] **Step 2: Commit** — `docs(ui): describe the board transitions`

---

### Task 11: The extension write-up

**Files:**
- Modify: `docs/superpowers/specs/2026-10-27-board-transitions-design.md` (a closing "Result: how far it extends" section)

- [ ] **Step 1: Write the section**, grounded in the built code, covering what the spec's "Extending it" asks:
  - **The on-demand idle boards (Aura Well, foraging).** What a new board needs: a view with `get_board_rect()`, a state that builds a `BoardTransitionSpec` and calls `open_board` / `close_board`, and its chest choice. Say what the chest needs for rows of their own: `ZonePanel`'s boolean techniques mode becoming a list mode, with `chest_height_for()` and `get_slide_rows()` keyed by it.
  - **Zone ↔ adventure.** What `CameraPush` already gives (its fixed `end_zoom` = 3 and the restore), what the player's progress model and the input rules would give, and what the adventure needs of its own: a `change_state` switch rather than a board in the gap, the Madra drain before the push, and an entry motion for the adventure view. Say how much of `ZoneTransition` it would replace, and what moving the zoom onto `CameraPush`'s curve would change for the player.
  - Anything that was harder than the spec assumed (for example the container re-sort on the sliding rows).
- [ ] **Step 2: Commit** — `docs(ui): assess how far the board transition extends`
