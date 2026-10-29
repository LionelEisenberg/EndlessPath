extends GutTest

## Integration tests for the cycling board (CyclingView): the status line and
## what it says when Madra or the core is full, a long name and status line that
## wrap and keep the board on screen, the title that follows the equipped
## technique, the result a cycle leaves for the chest and the one log line it
## writes, the Madra and XP pellets that bring what a cycle drew to the cabinet
## and the floater a scored zone pops, the Auto toggle, a press that reaches the
## ball through the board, and what a close or a reopening leaves behind. The board
## is built the way MainView builds it: the cabinet beside it, the view shown
## and the cabinet handed over, and the technique stepped by hand with advance()
## (its own processing is off, so the real mouse never races a test). The
## technique is smooth_flow, a 15 s cycle of 200 Madra with 4 zones, on a fresh
## save (25 Madra, cap 100).

const VIEW_SCENE_PATH: String = "res://scenes/cycling/cycling_view/cycling_view.tscn"
const VIEW_SCENE: PackedScene = preload(VIEW_SCENE_PATH)
const PLATE_SCENE: PackedScene = preload("res://scenes/zones/cultivator_plate/cultivator_plate.tscn")

const SMOOTH_ID: String = "smooth_flow"
const TORRENTIAL_ID: String = "torrential_flow"
const FOUNDATION_ID: String = "foundation_technique"
const CYCLING_ACTION_ID: String = "wilderness_cycling_action"
const AURA_WELL_ID: String = "aura_well_training"
const AURA_WELL_EVENT: String = "aura_well_discovered"

## A technique name and a status line too long for one line of the board.
const LONG_TITLE: String = "The Heaven-Shaking Thousandfold Smooth Flow Technique"
const LONG_STATUS: String = "Cycling · 12 / 15 s · follow the ball · Madra full · zones still pay XP"
## The room the board keeps under its footer for its bottom frame, corner
## brackets and shadow once it grows; with one line each it has 42.
const ROOM_UNDER_FOOTER: float = 30.0

## A cursor far from the ball and from every zone.
const FAR: Vector2 = Vector2(-9999.0, -9999.0)

## One frame at 60 FPS. A cycle is run for its duration plus one frame, because
## 900 sums of 1 / 60 can land a hair under 15.
const FRAME: float = 1.0 / 60.0
const CYCLE_SECONDS: float = 15.0

var _plate: CultivatorPlate = null
var _view: CyclingView = null
var _technique: CyclingTechnique = null
var _effects: Control = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	CyclingManager.unlock_technique(SMOOTH_ID)
	CyclingManager.equip_technique(SMOOTH_ID)
	_plate = add_child_autofree(PLATE_SCENE.instantiate())
	_view = VIEW_SCENE.instantiate() as CyclingView
	_view.cultivator_plate = _plate
	add_child_autofree(_view)
	_view.show()
	_technique = _node("CyclingTechnique") as CyclingTechnique
	# Only the steps these tests take move the cycle, never the real mouse.
	_technique.set_process(false)
	_effects = _node("EffectsLayer") as Control

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	# A cycle session or a last result left behind would leak into later files.
	CyclingManager.end_cycle_session()
	CyclingManager.clear_last_cycle_result()
	_plate = null
	_view = null
	_technique = null
	_effects = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _node(unique_name: String) -> Node:
	return _view.get_node("%" + unique_name)

## Waits a frame, so the nodes the board took out of the tree and queue-freed (a
## switch's old zones and floaters, the pellets a hide frees) are gone before GUT
## counts orphans.
func _await_queued_frees() -> void:
	await wait_process_frames(1)

## The last finished cycle's line as the chest shows it, or "" with none: the
## board records each cycle's result on CyclingManager.
func _last_line() -> String:
	var result: CycleResult = CyclingManager.get_last_cycle_result()
	return result.result_line() if result != null else ""

## Steps `seconds` of frames at `fps`, with the cursor on the ball (the drawn
## centre) or far away.
func _run(seconds: float, fps: float, track: bool) -> void:
	for _frame: int in roundi(seconds * fps):
		_technique.advance(1.0 / fps, _technique.get_ball_global_position() if track else FAR)

## Steps 60 FPS frames with the cursor far away until `done` returns true, the
## cycle ends or `limit` seconds pass. Returns whether `done` is true.
func _step_until(done: Callable, limit: float = 20.0) -> bool:
	for _frame: int in roundi(limit * 60.0):
		if done.call() or not _technique.is_cycling():
			break
		_technique.advance(FRAME, FAR)
	return done.call()

func _zone(index: int) -> CyclingZone:
	return _technique.cycling_zones[index]

## The ball's true distance to the zone: the path follower's, not the drawn ball's.
func _distance_to(zone: CyclingZone) -> float:
	return (_technique.get_node("%PathFollow2D") as PathFollow2D).global_position.distance_to(zone.global_position)

## Starts a cycle and steps it until zone 0 is closer than `within` px (or just
## active, when within is 0).
func _approach_zone_0(within: float) -> CyclingZone:
	var zone: CyclingZone = _zone(0)
	_technique.start_cycle()
	var reached: bool = _step_until(func() -> bool:
		return zone.get_state() == CyclingZone.State.ACTIVE and (within <= 0.0 or _distance_to(zone) < within))
	assert_true(reached, "precondition: the ball comes within %s px of zone 0" % within)
	return zone

## The Madra and XP pellets in the effects layer, in the order they were sent.
func _pellets() -> Array[LacquerPellet]:
	var found: Array[LacquerPellet] = []
	for child: Node in _effects.get_children():
		if child is LacquerPellet:
			found.append(child as LacquerPellet)
	return found

## The text of the cabinet's Label `unique_name`.
func _plate_text(unique_name: String) -> String:
	return (_plate.get_node("%" + unique_name) as Label).text.strip_edges()

## The zone floaters in the effects layer, in the order of the zones.
func _floaters() -> Array[LacquerFloater]:
	var found: Array[LacquerFloater] = []
	for child: Node in _effects.get_children():
		if child is LacquerFloater:
			found.append(child as LacquerFloater)
	return found

func _left_press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

## A press pushed through the viewport at `position`, with two physics frames on
## each side. The physics server learns where an Area2D is at its next step, so
## the frames before let it catch up with the areas the test just made or moved,
## and the frames after let physics picking deliver the press. The position is in
## the viewport's own coordinates (push_input's local coordinates): the headless
## window is 64 px square, so the usual window-to-viewport stretch would move it.
func _press_at(position: Vector2) -> void:
	await wait_physics_frames(2)
	var event: InputEventMouseButton = _left_press()
	event.position = position
	event.global_position = position
	get_viewport().push_input(event, true)
	await wait_physics_frames(2)

#-----------------------------------------------------------------------------
# THE STATUS LINE
#-----------------------------------------------------------------------------

func test_status_line_copy() -> void:
	assert_eq(CyclingView.status_line(false, false, 0.0, 15.0, false, false, true), CyclingView.READY_FIRST)
	assert_eq(CyclingView.status_line(true, false, 0.0, 15.0, false, false, true), CyclingView.READY_AGAIN)
	assert_eq(CyclingView.status_line(true, true, 9.4, 15.0, true, false, true), "Cycling · 9 / 15 s")
	assert_eq(CyclingView.status_line(true, true, 9.4, 15.0, false, false, true), "Cycling · 9 / 15 s · follow the ball")
	assert_eq(CyclingView.status_line(true, true, 9.4, 15.0, true, true, true), CyclingView.MADRA_FULL_ZONES)
	assert_eq(CyclingView.status_line(true, true, 9.4, 15.0, true, true, false), CyclingView.MADRA_FULL)

func test_the_status_label_follows_the_cycle() -> void:
	assert_eq(_view.get_status_text(), CyclingView.READY_FIRST, "ready before the first cycle")
	_technique.start_cycle()
	_technique.advance(FRAME, _technique.get_ball_global_position())
	_view._process(0.0)
	assert_eq(_view.get_status_text(), "Cycling · 0 / 15 s", "the cursor follows the ball")
	_technique.advance(FRAME, FAR)
	_view._process(0.0)
	assert_eq(_view.get_status_text(), "Cycling · 0 / 15 s · follow the ball", "the cursor drifted off")
	_run(6.0, 60.0, false)
	_view._process(0.0)
	assert_eq(_view.get_status_text(), "Cycling · 6 / 15 s · follow the ball")
	_run(CYCLE_SECONDS, 60.0, false)
	_view._process(0.0)
	assert_eq(_view.get_status_text(), CyclingView.READY_AGAIN, "ready again after a cycle")

## A full core takes no XP, so a technique's zones pay none and the line must not
## say they do. The board was built with room in the core: the line follows the
## core as it stands this frame.
func test_the_status_label_stops_promising_xp_at_a_full_core() -> void:
	PersistenceManager.save_game_data.core_density_level = 100.0
	assert_true(CultivationManager.is_core_full(), "precondition: the core is full")
	assert_false(_technique.cycling_zones.is_empty(), "precondition: the technique has zones")
	ResourceManager.set_madra(CultivationManager.get_max_madra())
	_technique.start_cycle()
	_technique.advance(FRAME, _technique.get_ball_global_position())
	_view._process(0.0)
	assert_eq(_view.get_status_text(), CyclingView.MADRA_FULL)

#-----------------------------------------------------------------------------
# LONG TEXT
#-----------------------------------------------------------------------------

func test_a_long_name_and_a_long_status_line_still_end_on_screen() -> void:
	var data: CyclingTechniqueData = _technique.technique_data.duplicate() as CyclingTechniqueData
	data.technique_name = LONG_TITLE
	_technique.setup(data)
	_view.hide()
	_view.show()
	var status := _node("StatusLabel") as Label
	status.text = LONG_STATUS
	_view._relayout_board()
	assert_eq((_node("TitleLabel") as Label).get_line_count(), 2, "precondition: the name takes two lines")
	assert_eq(status.get_line_count(), 2, "precondition: and so does the status line")
	var board := _node("Board") as Control
	assert_lte(board.position.y + board.size.y, 1080.0, "the board, its frame and its shadow still end on screen")
	assert_lte(status.position.y + status.size.y + ROOM_UNDER_FOOTER, board.position.y + board.size.y, "with the status line clear of the bottom frame")
	await _await_queued_frees()

#-----------------------------------------------------------------------------
# THE TECHNIQUE
#-----------------------------------------------------------------------------

func test_title_follows_the_equipped_technique() -> void:
	var title := _node("TitleLabel") as Label
	assert_eq(title.text, "Smooth Flow Technique", "the technique equipped when the board was built")
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	CyclingManager.equip_technique(TORRENTIAL_ID)
	assert_eq(title.text, "Torrential Flow")
	await _await_queued_frees()

func test_the_technique_follows_the_equipped_technique() -> void:
	assert_eq(_technique.technique_data.id, SMOOTH_ID)
	assert_eq(_technique.cycling_zones.size(), 4)
	assert_eq(_floaters().size(), 4, "one floater for each zone")
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	CyclingManager.equip_technique(TORRENTIAL_ID)
	assert_eq(_technique.technique_data.id, TORRENTIAL_ID)
	assert_eq(_technique.cycling_zones.size(), 1)
	assert_eq(_floaters().size(), 1, "the floaters were rebuilt for the new zones")
	await _await_queued_frees()

func test_the_first_unlocked_technique_is_equipped_when_none_is() -> void:
	PersistenceManager.save_game_data.equipped_cycling_technique_id = ""
	var second: CyclingView = VIEW_SCENE.instantiate() as CyclingView
	add_child_autofree(second)
	assert_eq(PersistenceManager.save_game_data.equipped_cycling_technique_id, FOUNDATION_ID, "the fallback equips the first unlocked technique")
	assert_eq((second.get_node("%TitleLabel") as Label).text, "Foundational Technique")
	# The fixture's board follows the equip too.
	await _await_queued_frees()

func test_a_save_with_no_techniques_leaves_the_board_idle() -> void:
	PersistenceManager.save_game_data.unlocked_cycling_technique_ids.clear()
	PersistenceManager.save_game_data.equipped_cycling_technique_id = ""
	var bare: CyclingView = VIEW_SCENE.instantiate() as CyclingView
	add_child_autofree(bare)
	var bare_technique := bare.get_node("%CyclingTechnique") as CyclingTechnique
	bare_technique.set_process(false)
	assert_null(bare_technique.technique_data, "nothing to play")
	bare._process(0.0)
	assert_eq(bare.get_status_text(), CyclingView.READY_FIRST)
	assert_false(bare_technique.start_cycle(), "and no cycle starts")
	bare.hide()
	bare.show()
	assert_eq(_last_line(), "")

func test_switching_technique_ends_the_cycle_without_a_result() -> void:
	watch_signals(LogManager)
	_technique.start_cycle()
	_run(3.0, 60.0, false)
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	CyclingManager.equip_technique(TORRENTIAL_ID)
	assert_false(_technique.is_cycling(), "the cycle ended")
	assert_eq(_last_line(), "", "no result line")
	assert_signal_not_emitted(LogManager, "message_logged")
	await _await_queued_frees()

func test_switching_technique_clears_the_result_line_and_the_ready_text() -> void:
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_ne(_last_line(), "", "precondition: a cycle left a result line")
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	CyclingManager.equip_technique(TORRENTIAL_ID)
	_view._process(0.0)
	assert_eq(_last_line(), "")
	assert_eq(_view.get_status_text(), CyclingView.READY_FIRST, "a new technique has not been cycled yet")
	await _await_queued_frees()

#-----------------------------------------------------------------------------
# THE RESULT LINE AND THE LOG
#-----------------------------------------------------------------------------

func test_a_tracked_cycle_reports_the_madra_it_drew() -> void:
	watch_signals(LogManager)
	watch_signals(_technique)
	ResourceManager.set_madra(0.0)
	_technique.start_cycle()
	# Tracking for 6 s keeps the Madra drawn (80) under the 100 cap.
	_run(6.0, 60.0, true)
	_run(CYCLE_SECONDS - 6.0 + FRAME, 60.0, false)
	assert_signal_emit_count(_technique, "cycle_completed", 1)
	var result := get_signal_parameters(_technique, "cycle_completed", 0)[0] as CycleResult
	# 6 s hold 75 whole steps of Madra. The step tolerance pays the 75th even when
	# the float sum of the frames lands a hair under 6 s.
	assert_almost_eq(result.madra_added, 80.0, 0.001, "precondition: the cursor drew Madra")
	assert_eq(_last_line(), result.result_line(), "the cycle's own line goes to the chest")
	assert_signal_emit_count(LogManager, "message_logged", 1, "cycling writes no \"Gained N Madra\" lines")
	assert_eq(get_signal_parameters(LogManager, "message_logged", 0), ["[color=cyan]%s[/color]" % result.log_line()])

func test_the_result_line_stays_until_the_next_cycle_ends() -> void:
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	var first: String = _last_line()
	_technique.start_cycle()
	_run(3.0, 60.0, false)
	assert_eq(_last_line(), first, "a running cycle leaves the last result showing")

#-----------------------------------------------------------------------------
# PELLETS
#-----------------------------------------------------------------------------

## The cabinet shows each step's Madra as its pellet lands, not as it leaves.
func test_the_madra_orb_fills_as_the_pellets_land() -> void:
	_technique.start_cycle()
	_run(0.2, 60.0, true)
	var pellets: Array[LacquerPellet] = _pellets()
	assert_eq(pellets.size(), 2, "precondition: two steps in flight")
	var drawn: float = ResourceManager.get_madra()
	assert_gt(drawn, 27.0, "precondition: the cursor drew two steps of Madra")
	assert_eq(_plate_text("MadraValueLabel"), "25", "none of it has landed")
	pellets[0]._process(CyclingView.MADRA_PELLET_FLIGHT)
	assert_eq(_plate_text("MadraValueLabel"), "26", "the first step has landed")
	pellets[1]._process(CyclingView.MADRA_PELLET_FLIGHT)
	assert_eq(_plate_text("MadraValueLabel"), str(floori(drawn)), "and the second")

func test_scoring_pops_the_zone_floater_and_pellets() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	watch_signals(_technique)
	assert_true(_technique.try_score_zone(zone))
	var params: Array = get_signal_parameters(_technique, "zone_scored", 0)
	var tier: CyclingRules.Tier = params[1]
	var xp: int = params[2]
	var floater: LacquerFloater = _floaters()[0]
	assert_true(floater.visible)
	assert_eq(floater.get_text(), "%s +%d XP" % [CyclingRules.tier_name(tier), xp])
	assert_eq(_pellets().size(), CyclingRules.pellet_count(tier), "one pellet for each XP pellet the tier sends")
	for other: LacquerFloater in _floaters().slice(1):
		assert_false(other.visible, "only the scored zone's floater shows")

func test_a_full_core_floater_sends_no_pellets() -> void:
	PersistenceManager.save_game_data.core_density_level = 100.0
	assert_true(CultivationManager.is_core_full(), "precondition: the core is full")
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	var floater: LacquerFloater = _floaters()[0]
	assert_true(floater.visible)
	assert_eq(floater.get_text(), "OK · Core full", "the tier and the core's state in place of the XP")
	assert_eq(_pellets().size(), 0, "a full core takes no XP, so none flies to it")

## The Core row shows the hit's XP as its pellets land: as it stood before the
## hit while they fly, and as the hit left it once the last one is in.
func test_the_core_shows_the_xp_as_its_pellets_land() -> void:
	var before: String = _plate_text("XpLabel")
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	var pellets: Array[LacquerPellet] = _pellets()
	assert_gt(CultivationManager.get_core_density_xp() + CultivationManager.get_core_density_level(), 0.0, "precondition: the hit paid XP")
	assert_eq(_plate_text("XpLabel"), before, "none of the XP has landed")
	for pellet: LacquerPellet in pellets:
		pellet._process(10.0)
	assert_eq(_plate_text("LevelLabel"), "Level %d" % floori(CultivationManager.get_core_density_level()))
	assert_eq(_plate_text("XpLabel"), "%d / %d XP" % [floori(CultivationManager.get_core_density_xp()), floori(CultivationManager.get_xp_for_next_level())], "all of it has landed")

## A hidden board frees its pellets, and what they carried shows at once.
func test_hiding_the_view_shows_what_its_pellets_carried() -> void:
	_technique.start_cycle()
	_run(0.2, 60.0, true)
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	assert_gt(_pellets().size(), 0, "precondition: pellets in flight")
	_view.hide()
	assert_eq(_plate_text("MadraValueLabel"), str(floori(ResourceManager.get_madra())))
	assert_eq(_plate_text("XpLabel"), "%d / %d XP" % [floori(CultivationManager.get_core_density_xp()), floori(CultivationManager.get_xp_for_next_level())])
	await _await_queued_frees()

#-----------------------------------------------------------------------------
# AUTO
#-----------------------------------------------------------------------------

func test_auto_toggle_sets_auto_cycle() -> void:
	var toggle := _node("AutoToggle") as TextureButton
	assert_true(toggle.toggle_mode)
	assert_false(toggle.button_pressed)
	assert_false(_technique.auto_cycle)
	toggle.button_pressed = true
	assert_true(_technique.auto_cycle)
	toggle.button_pressed = false
	assert_false(_technique.auto_cycle)

func test_a_toggle_that_starts_pressed_is_honoured() -> void:
	var built: CyclingView = VIEW_SCENE.instantiate() as CyclingView
	(built.get_node("%AutoToggle") as TextureButton).button_pressed = true
	add_child_autofree(built)
	var built_technique := built.get_node("%CyclingTechnique") as CyclingTechnique
	built_technique.set_process(false)
	assert_true(built_technique.auto_cycle, "the technique follows the toggle from the start")

#-----------------------------------------------------------------------------
# SHOWING, HIDING AND CLOSING
#-----------------------------------------------------------------------------

func test_the_view_processes_only_while_it_shows() -> void:
	assert_true(_view.is_processing(), "the shown view updates its status, floaters and cursor")
	assert_false(_technique.is_processing(), "precondition: this fixture stopped the technique's processing")
	_view.hide()
	assert_false(_view.is_processing())
	assert_false(_technique.is_processing(), "a hidden view's technique is not processed")
	_view.show()
	assert_true(_view.is_processing())
	assert_true(_technique.is_processing(), "showing the view turns the technique's processing back on")

func test_hiding_the_view_frees_the_pellets_in_flight() -> void:
	# A pellet left flying under the hidden board would show up mid-flight if the
	# board reopened within its flight.
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	var flying: Array[LacquerPellet] = _pellets()
	assert_gt(flying.size(), 0, "precondition: the hit's pellets are in flight")
	_view.hide()
	assert_eq(_pellets().size(), 0, "the effects layer holds no pellet")
	for pellet: LacquerPellet in flying:
		assert_true(pellet.is_queued_for_deletion(), "each pellet is freed, not just left out of the tree")
	assert_eq(_floaters().size(), 4, "the floaters stay for the next cycle")
	await _await_queued_frees()

func test_a_view_that_starts_hidden_does_not_process() -> void:
	var host := Control.new()
	host.visible = false
	add_child_autofree(host)
	var hidden: CyclingView = VIEW_SCENE.instantiate() as CyclingView
	hidden.visible = false
	host.add_child(hidden)
	assert_false(hidden.is_processing())
	assert_false((hidden.get_node("%CyclingTechnique") as CyclingTechnique).is_processing())

func test_reopening_starts_clean() -> void:
	# A finished cycle leaves its result for the chest's line.
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_ne(_last_line(), "", "precondition: a cycle left a result line")
	# Then a second cycle, closed half way with a zone scored.
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	_view._process(0.0)
	assert_true(_view.get_status_text().begins_with("Cycling · "), "precondition: the status line shows the cycle")
	_view.hide()
	_view.show()
	assert_eq(_last_line(), "", "no stale result line")
	for each: CyclingZone in _technique.cycling_zones:
		assert_eq(each.get_state(), CyclingZone.State.IDLE, "%s is idle" % each.name)
	assert_false(_technique.is_cycling(), "the cycle ended")
	assert_false(CyclingManager.is_cycle_running(), "and its session")
	assert_eq(_view.get_status_text(), CyclingView.READY_FIRST, "and the status reads as the first time again")
	await _await_queued_frees()

func test_showing_names_whatever_action_runs() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	var aura_well: ZoneActionData = ZoneManager.get_action_by_id(AURA_WELL_ID)
	assert_ne(aura_well.action_name, "Wilderness Cycling", "precondition: the label would not read that anyway")
	assert_eq(ActionManager.get_current_action(), aura_well, "precondition: the Aura Well runs")
	_view.hide()
	_view.show()
	assert_eq((_node("ActionLabel") as Label).text, aura_well.action_name)

func test_showing_names_the_technique_that_is_set_up() -> void:
	# Something other than the equipped-technique signal set the technique up.
	_technique.setup(load("res://resources/cycling/cycling_techniques/torrential_flow/torrential_flow.tres"))
	assert_eq((_node("TitleLabel") as Label).text, "Smooth Flow Technique", "precondition: the title still names the old one")
	_view.hide()
	_view.show()
	assert_eq((_node("TitleLabel") as Label).text, "Torrential Flow")
	await _await_queued_frees()

func test_close_stops_the_action() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ACTION_ID))
	assert_eq(ActionManager.get_current_action().action_id, CYCLING_ACTION_ID, "precondition: the cycling action is current")
	_technique.start_cycle()
	(_node("CloseButton") as TextureButton).pressed.emit()
	var current: ZoneActionData = ActionManager.get_current_action()
	assert_not_null(current, "the zone's idle action resumed")
	assert_eq(current.action_id, AURA_WELL_ID)
	assert_false(_technique.is_cycling(), "the running cycle ended")

func test_stopping_the_cycling_action_resets_the_technique() -> void:
	var zone: CyclingZone = _approach_zone_0(0.0)
	_technique.try_score_zone(zone)
	ActionManager.stop_cycling.emit()
	assert_false(_technique.is_cycling())
	for each: CyclingZone in _technique.cycling_zones:
		assert_eq(each.get_state(), CyclingZone.State.IDLE)

#-----------------------------------------------------------------------------
# PRESSES
#-----------------------------------------------------------------------------

func test_a_press_on_the_ball_reaches_it_through_the_board() -> void:
	await _press_at(_technique.get_ball_global_position())
	assert_true(_technique.is_cycling(), "the board and the figure box let the press through to the ball")
