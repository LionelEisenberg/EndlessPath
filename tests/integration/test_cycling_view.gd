extends GutTest

## Integration tests for the cycling board (CyclingView): the status line, which
## changes only as a cycle starts or ends, a long name and status line that
## wrap and keep the board on screen, the title that follows the equipped
## technique, the result a cycle leaves for the chest and the one log line it
## writes, the Madra and stat pellets that bring what a cycle drew to the cabinet,
## the floater a scored zone or an opened seal pops, the Auto toggle (locked until
## a perfect cycle unlocks it, then starting cycles by itself), a press that
## reaches the ball through the board, and what a close or a reopening leaves
## behind. The board
## is built the way MainView builds it: the cabinet beside it, the view shown
## and the cabinet handed over, and the technique stepped by hand with advance()
## (its own processing is off, so the real mouse never races a test). The
## technique is smooth_flow, a 15 s cycle of 80 Madra with 4 zones, on a fresh
## save (25 Madra, max 100).

const VIEW_SCENE_PATH: String = "res://scenes/cycling/cycling_view/cycling_view.tscn"
const VIEW_SCENE: PackedScene = preload(VIEW_SCENE_PATH)
const PLATE_SCENE: PackedScene = preload("res://scenes/zones/cultivator_plate/cultivator_plate.tscn")

const SMOOTH_ID: String = "smooth_flow"
const TORRENTIAL_ID: String = "torrential_flow"
const FOUNDATION_ID: String = "foundation_technique"
const CYCLING_ACTION_ID: String = "wilderness_cycling_action"
const AURA_WELL_ID: String = "aura_well_training"
const AURA_WELL_EVENT: String = "aura_well_discovered"
const SMOOTH_PATH: String = "res://resources/cycling/cycling_techniques/smooth_flow/smooth_flow.tres"
const TORRENTIAL_PATH: String = "res://resources/cycling/cycling_techniques/torrential_flow/torrential_flow.tres"
const FOUNDATION_PATH: String = "res://resources/cycling/cycling_techniques/foundation_cycling_technique/foundation_cycling_technique.tres"

const CONTROL: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.CONTROL
const MIND: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.MIND

## Smooth Flow's zones by index: zone 2, near the board's left side, and zone
## 3, the top one, worth 12 Control XP at PERFECT.
const LEFT_ZONE: int = 1
const TOP_ZONE: int = 2

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

## The last finished cycle's result, which the chest shows, or null with none:
## the board records each cycle's result on CyclingManager.
func _last_result() -> CycleResult:
	return CyclingManager.get_last_cycle_result()

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
	return _approach_zone(0, within)

## Starts a cycle, unless one runs, and steps it until zone `index` is closer
## than `within` px (or just active, when within is 0). A zone just active
## scores OK, one within 6 px PERFECT.
func _approach_zone(index: int, within: float) -> CyclingZone:
	var zone: CyclingZone = _zone(index)
	_technique.start_cycle()
	var reached: bool = _step_until(func() -> bool:
		return zone.get_state() == CyclingZone.State.ACTIVE and (within <= 0.0 or _distance_to(zone) < within))
	assert_true(reached, "precondition: the ball comes within %s px of zone %d" % [within, index])
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

## The floaters in the effects layer: the zones' in their order, then the seal
## nodes'.
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

## The status line, as Lionel set it: the instruction to start while the ball
## waits, on every technique; while it runs, following, then the clause of the
## technique's own game with its other stat's name, which drops while that stat
## is capped.
func test_status_line_copy() -> void:
	var foundation: CyclingTechniqueData = load(FOUNDATION_PATH)
	var smooth: CyclingTechniqueData = load(SMOOTH_PATH)
	var torrential: CyclingTechniqueData = load(TORRENTIAL_PATH)
	var ready: String = "Click the Madra ball to begin a cycle."
	var follow: String = "Follow the ball for Madra and Spirit."
	var cases: Array[Dictionary] = [
		{"name": "waiting, Foundational", "running": false, "technique": foundation, "capped": false, "line": ready},
		{"name": "waiting, Smooth Flow", "running": false, "technique": smooth, "capped": false, "line": ready},
		{"name": "waiting, Torrential Flow", "running": false, "technique": torrential, "capped": false, "line": ready},
		{"name": "running, Foundational", "running": true, "technique": foundation, "capped": false, "line": follow},
		{"name": "running, Smooth Flow", "running": true, "technique": smooth, "capped": false, "line": "Follow the ball. Click it over each zone."},
		{"name": "running, Torrential Flow", "running": true, "technique": torrential, "capped": false, "line": "Follow the ball. Open each seal with W A S D."},
		{"name": "running, Smooth Flow, Control capped", "running": true, "technique": smooth, "capped": true, "line": follow},
		{"name": "running, Torrential Flow, Mind capped", "running": true, "technique": torrential, "capped": true, "line": follow},
	]
	for case: Dictionary in cases:
		assert_eq(CyclingView.status_line(case.running, case.technique, case.capped), case.line, case.name)

## The line changes only as a cycle starts or ends: not with the seconds, the
## cursor, a full pool or a capped Spirit.
func test_the_status_line_changes_only_as_a_cycle_starts_or_ends() -> void:
	var running: String = CyclingView.status_line(true, _technique.technique_data, false)
	assert_eq(_view.get_status_text(), CyclingView.READY, "waiting before the first cycle")
	_technique.start_cycle()
	_technique.advance(FRAME, _technique.get_ball_global_position())
	_view._process(0.0)
	assert_eq(_view.get_status_text(), running, "running, following")
	_run(6.0, 60.0, false)
	_view._process(0.0)
	assert_eq(_view.get_status_text(), running, "running, six seconds on, off the ball")
	ResourceManager.set_madra(ResourceManager.get_max_madra())
	CharacterManager.set_stat_level(CharacterAttributesData.AttributeType.SPIRIT, CharacterManager.get_stat_level_cap())
	_run(1.0, 60.0, true)
	_view._process(0.0)
	assert_eq(_view.get_status_text(), running, "running with the pool full and Spirit capped")
	_run(CYCLE_SECONDS, 60.0, false)
	_view._process(0.0)
	assert_eq(_view.get_status_text(), CyclingView.READY, "waiting again after the cycle")

## The cap is read as a cycle starts: Control capped mid-cycle keeps the zones'
## clause on the line until the next cycle starts.
func test_the_status_line_reads_the_cap_as_a_cycle_starts() -> void:
	var with_zones: String = CyclingView.status_line(true, _technique.technique_data, false)
	_technique.start_cycle()
	_view._process(0.0)
	assert_eq(_view.get_status_text(), with_zones, "precondition: the zones' clause shows")
	CharacterManager.set_stat_level(CONTROL, CharacterManager.get_stat_level_cap())
	_run(1.0, 60.0, false)
	_view._process(0.0)
	assert_eq(_view.get_status_text(), with_zones, "the running cycle keeps it")
	_run(CYCLE_SECONDS, 60.0, false)
	assert_false(_technique.is_cycling(), "precondition: the cycle ended")
	_technique.start_cycle()
	_view._process(0.0)
	assert_eq(_view.get_status_text(), CyclingView.FOLLOW, "the next cycle drops it")

## The Foundational has no zones, so its running line leaves them out.
func test_a_technique_with_no_zones_leaves_them_out() -> void:
	CyclingManager.equip_technique(FOUNDATION_ID)
	_view._process(0.0)
	assert_eq(_view.get_status_text(), CyclingView.READY)
	_technique.start_cycle()
	_technique.advance(FRAME, _technique.get_ball_global_position())
	_view._process(0.0)
	assert_eq(_view.get_status_text(), CyclingView.FOLLOW)
	await _await_queued_frees()

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
	assert_eq(title.text, "Seal Flow Technique")
	await _await_queued_frees()

func test_the_technique_follows_the_equipped_technique() -> void:
	assert_eq(_technique.technique_data.id, SMOOTH_ID)
	assert_eq(_technique.cycling_zones.size(), 4)
	assert_eq(_floaters().size(), 4, "one floater for each zone")
	CyclingManager.unlock_technique(FOUNDATION_ID)
	CyclingManager.equip_technique(FOUNDATION_ID)
	assert_eq(_technique.technique_data.id, FOUNDATION_ID)
	assert_eq(_technique.cycling_zones.size(), 0)
	assert_eq(_floaters().size(), 0, "the floaters were rebuilt for the new zones")
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
	assert_eq(bare.get_status_text(), CyclingView.READY)
	assert_false(bare_technique.start_cycle(), "and no cycle starts")
	bare.hide()
	bare.show()
	assert_null(_last_result())

func test_switching_technique_ends_the_cycle_without_a_result() -> void:
	watch_signals(LogManager)
	_technique.start_cycle()
	_run(3.0, 60.0, false)
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	CyclingManager.equip_technique(TORRENTIAL_ID)
	assert_false(_technique.is_cycling(), "the cycle ended")
	assert_null(_last_result(), "no result")
	assert_signal_not_emitted(LogManager, "message_logged")
	await _await_queued_frees()

func test_switching_technique_clears_the_last_result_and_the_ready_text() -> void:
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_not_null(_last_result(), "precondition: a cycle left a result")
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	CyclingManager.equip_technique(TORRENTIAL_ID)
	_view._process(0.0)
	assert_null(_last_result())
	assert_eq(_view.get_status_text(), CyclingView.READY, "the new technique waits for a press")
	await _await_queued_frees()

#-----------------------------------------------------------------------------
# THE RESULT AND THE LOG
#-----------------------------------------------------------------------------

func test_a_tracked_cycle_reports_the_madra_it_drew() -> void:
	watch_signals(LogManager)
	watch_signals(_technique)
	ResourceManager.set_madra(0.0)
	_technique.start_cycle()
	# Tracking for 6 s draws 32 Madra, well under the 100 cap.
	_run(6.0, 60.0, true)
	_run(CYCLE_SECONDS - 6.0 + FRAME, 60.0, false)
	assert_signal_emit_count(_technique, "cycle_completed", 1)
	var result := get_signal_parameters(_technique, "cycle_completed", 0)[0] as CycleResult
	# 6 s hold 75 whole steps of 0.4267 Madra. The step tolerance pays the 75th
	# even when the float sum of the frames lands a hair under 6 s.
	assert_almost_eq(result.madra_added, 32.0, 0.001, "precondition: the cursor drew Madra")
	assert_eq(_last_result(), result, "the cycle's own result goes to the chest")
	assert_signal_emit_count(LogManager, "message_logged", 1, "cycling writes no \"Gained N Madra\" lines")
	assert_eq(get_signal_parameters(LogManager, "message_logged", 0), ["[color=cyan]%s[/color]" % result.log_line()])

func test_the_last_result_stays_until_the_next_cycle_ends() -> void:
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	var first: CycleResult = _last_result()
	assert_not_null(first, "precondition: a cycle left a result")
	_technique.start_cycle()
	_run(3.0, 60.0, false)
	assert_eq(_last_result(), first, "a running cycle leaves the last result showing")

#-----------------------------------------------------------------------------
# PELLETS
#-----------------------------------------------------------------------------

## The cabinet shows each step's Madra as its pellet lands, not as it leaves.
func test_the_madra_orb_fills_as_the_pellets_land() -> void:
	# From 25.8, the first step of 0.4267 lands past 26.
	ResourceManager.set_madra(25.8)
	_technique.start_cycle()
	_run(0.2, 60.0, true)
	var pellets: Array[LacquerPellet] = _pellets()
	assert_eq(pellets.size(), 2, "precondition: two steps in flight")
	var drawn: float = ResourceManager.get_madra()
	assert_gt(drawn, 26.5, "precondition: the cursor drew two steps of Madra")
	assert_eq(_plate_text("MadraValueLabel"), "25", "none of it has landed")
	pellets[0]._process(CyclingView.MADRA_PELLET_FLIGHT)
	assert_eq(_plate_text("MadraValueLabel"), "26", "the first step has landed")
	pellets[1]._process(CyclingView.MADRA_PELLET_FLIGHT)
	assert_eq(_plate_text("MadraValueLabel"), str(floori(drawn)), "and the second")

## The pellets in the effects layer in `stat`'s ramp.
func _stat_pellets(stat: CharacterAttributesData.AttributeType) -> Array[LacquerPellet]:
	return _pellets().filter(func(pellet: LacquerPellet) -> bool: return pellet.get_ramp() == LacquerPellet.stat_ramp(stat))

func _control_cell() -> StatCell:
	return _plate.get_node("%ControlCell") as StatCell

func _mind_cell() -> StatCell:
	return _plate.get_node("%MindCell") as StatCell

## A hit pays Control: its floater pops the tier and the XP with Control's icon
## and name, and the tier's pellets fly in Control's ramp to its cell, which
## shows the XP once they land.
func test_scoring_pops_the_zone_floater_and_pellets() -> void:
	var zone: CyclingZone = _approach_zone(TOP_ZONE, 6.0)
	assert_true(_technique.try_score_zone(zone))
	assert_eq(zone.get_state(), CyclingZone.State.PERFECT, "precondition: a PERFECT")
	var floater: LacquerFloater = _floaters()[TOP_ZONE]
	assert_true(floater.visible)
	assert_eq(floater.get_text(), "PERFECT +12 Control")
	assert_eq(floater.get_icons(), [StatDisplay.icon_of(CONTROL)] as Array[Texture2D], "Control's icon")
	for other: LacquerFloater in _floaters():
		if other != floater:
			assert_false(other.visible, "only the scored zone's floater shows")
	var pellets: Array[LacquerPellet] = _pellets()
	assert_eq(pellets.size(), CyclingRules.pellet_count(CyclingRules.Tier.PERFECT), "the tier's pellets")
	assert_eq(_stat_pellets(CONTROL).size(), pellets.size(), "all of them in Control's ramp")
	assert_eq(_control_cell().get_shown_xp(), 0.0, "none of it has landed")
	for pellet: LacquerPellet in pellets:
		pellet._process(10.0)
	assert_almost_eq(_control_cell().get_shown_xp(), 12.0, 0.0001, "all of it has landed")

func test_a_capped_control_floater_sends_no_pellets() -> void:
	CharacterManager.set_stat_level(CONTROL, CharacterManager.get_stat_level_cap())
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	var floater: LacquerFloater = _floaters()[0]
	assert_true(floater.visible)
	assert_eq(floater.get_text(), "OK · Control capped", "the tier and the cap in place of the XP")
	assert_true(floater.get_icons().is_empty(), "no icon")
	assert_eq(_pellets().size(), 0, "a capped Control takes no XP, so none flies to it")

## Control 2 XP short of the cap takes 2 of a PERFECT's 12: the floater says
## what the hit was worth, and the pellets carry what Control took.
func test_a_hit_that_reaches_the_cap_sends_what_control_took() -> void:
	var below_cap: int = CharacterManager.get_stat_level_cap() - 1
	var short_of_cap: float = CharacterManager.stat_progression.get_xp_to_next(below_cap) - 2.0
	CharacterManager.set_stat_level(CONTROL, below_cap, short_of_cap)
	var zone: CyclingZone = _approach_zone(TOP_ZONE, 6.0)
	assert_true(_technique.try_score_zone(zone))
	assert_true(CharacterManager.is_stat_capped(CONTROL), "precondition: the hit reached the cap")
	assert_eq(_floaters()[TOP_ZONE].get_text(), "PERFECT +12 Control")
	assert_eq(_stat_pellets(CONTROL).size(), CyclingRules.pellet_count(CyclingRules.Tier.PERFECT), "the tier's pellets fly")
	assert_eq(_control_cell().get_shown_level(), below_cap, "the cell holds back what they carry")
	assert_almost_eq(_control_cell().get_shown_xp(), short_of_cap, 0.0001, "2 XP in all")
	for pellet: LacquerPellet in _stat_pellets(CONTROL):
		pellet._process(10.0)
	assert_true(_control_cell().is_shown_capped(), "once they land, the cell shows the cap")

## A floater over a zone near the board's side stays on the board,
## FLOATER_BOARD_MARGIN px in from it, rather than hanging off its edge.
func test_a_floater_over_an_edge_zone_stays_on_the_board() -> void:
	var zone: CyclingZone = _approach_zone(LEFT_ZONE, 0.0)
	assert_true(_technique.try_score_zone(zone))
	var floater: LacquerFloater = _floaters()[LEFT_ZONE]
	var board: Rect2 = _view.get_board_rect()
	var margin: float = CyclingView.FLOATER_BOARD_MARGIN
	assert_lt(zone.global_position.x - floater.get_token_width() / 2.0, board.position.x + margin, "precondition: centred on its zone, the floater would cross the margin")
	for step: int in 3:
		_view._process(0.0)
		var rect: Rect2 = floater.get_global_rect()
		assert_gte(rect.position.x, board.position.x + margin, "it stands the margin in from the board's left side, step %d" % step)
		assert_lte(rect.end.x, board.end.x - margin, "and from its right, step %d" % step)
		floater._process(0.3)

## A hidden board frees its pellets, and what they carried shows at once.
func test_hiding_the_view_shows_what_its_pellets_carried() -> void:
	_technique.start_cycle()
	_run(0.2, 60.0, true)
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	assert_gt(_stat_pellets(CONTROL).size(), 0, "precondition: Control pellets in flight")
	_view.hide()
	assert_eq(_plate_text("MadraValueLabel"), str(floori(ResourceManager.get_madra())))
	assert_almost_eq(_control_cell().get_shown_xp(), CharacterManager.get_stat_xp(CONTROL), 0.0001, "the hit's Control XP shows")
	await _await_queued_frees()

#-----------------------------------------------------------------------------
# SEAL PELLETS
#-----------------------------------------------------------------------------

## Plays torrential_flow until the ball bursts through its first seal, keyed in
## full as it shows. Returns the seal.
func _burst_first_seal() -> SealNode:
	_play_torrential(0.6)
	var seal: SealNode = _technique.seal_nodes[0]
	for arrow: int in seal.get_arrows():
		_view.press_seal(arrow)
	assert_eq(seal.get_state(), SealNode.State.OPEN, "precondition: the seal is open")
	watch_signals(_technique)
	var burst: bool = _step_until(func() -> bool: return get_signal_emit_count(_technique, "seal_burst") > 0)
	assert_true(burst, "precondition: the ball bursts through the seal")
	return seal

## An opened seal pays Mind as the ball bursts through: its floater pops "+5"
## with Mind's icon and name, and SEAL_PELLETS pellets fly in Mind's ramp to its
## cell.
func test_an_open_seal_bursts_mind_pellets() -> void:
	_burst_first_seal()
	var floaters: Array[LacquerFloater] = _floaters()
	assert_eq(floaters.size(), 3, "a floater for each seal node")
	assert_true(floaters[0].visible, "the first seal's floater pops")
	assert_eq(floaters[0].get_text(), "+5 Mind")
	assert_eq(floaters[0].get_icons(), [StatDisplay.icon_of(MIND)] as Array[Texture2D], "Mind's icon")
	var pellets: Array[LacquerPellet] = _stat_pellets(MIND)
	assert_eq(pellets.size(), CyclingView.SEAL_PELLETS)
	assert_eq(_mind_cell().get_shown_xp(), 0.0, "none of it has landed")
	for pellet: LacquerPellet in pellets:
		pellet._process(10.0)
	assert_almost_eq(_mind_cell().get_shown_xp(), 5.0, 0.0001, "all of it has landed")
	await _await_queued_frees()

func test_a_capped_mind_seal_floater() -> void:
	CharacterManager.set_stat_level(MIND, CharacterManager.get_stat_level_cap())
	_burst_first_seal()
	var floater: LacquerFloater = _floaters()[0]
	assert_true(floater.visible)
	assert_eq(floater.get_text(), "OPEN · Mind capped", "the seal and the cap in place of the XP")
	assert_eq(_stat_pellets(MIND).size(), 0, "a capped Mind takes no XP, so none flies to it")
	await _await_queued_frees()

## The Spirit pellets in the effects layer.
func _spirit_pellets() -> Array[LacquerPellet]:
	return _pellets().filter(func(pellet: LacquerPellet) -> bool: return pellet.get_ramp() == LacquerPellet.Ramp.SPIRIT)

func _spirit_cell() -> StatCell:
	return _plate.get_node("%SpiritCell") as StatCell

## Each half second followed sends a puff of pellets in Spirit's colour to its
## cell, which shows the XP as they land, not as they leave.
func test_spirit_pellets_fly_to_spirit_s_cell() -> void:
	_technique.start_cycle()
	_run(0.55, 60.0, true)
	var puff: Array[LacquerPellet] = _spirit_pellets()
	assert_eq(puff.size(), CyclingView.STAT_PELLETS, "one puff for the first half second")
	assert_almost_eq(CharacterManager.get_stat_xp(CharacterAttributesData.AttributeType.SPIRIT), 1.0, 0.0001, "precondition: Spirit took Smooth Flow's 1 XP")
	assert_eq(_spirit_cell().get_shown_xp(), 0.0, "none of it has landed")
	for pellet: LacquerPellet in puff:
		pellet._process(10.0)
	assert_almost_eq(_spirit_cell().get_shown_xp(), 1.0, 0.0001, "all of it has landed")

func test_no_spirit_pellets_at_the_cap() -> void:
	CharacterManager.set_stat_level(CharacterAttributesData.AttributeType.SPIRIT, CharacterManager.get_stat_level_cap())
	_technique.start_cycle()
	_run(1.1, 60.0, true)
	assert_gt(_pellets().size(), 0, "precondition: Madra pellets still fly")
	assert_eq(_spirit_pellets().size(), 0, "a capped Spirit takes no pellets")

## A board that hides mid-cycle pays the Spirit XP followed since the last puff
## straight into the cell: nothing flies from a hidden board, and nothing stays held.
func test_hiding_the_view_pays_the_spirit_xp_without_pellets() -> void:
	_technique.start_cycle()
	_run(0.3, 60.0, true)
	assert_eq(_spirit_pellets().size(), 0, "precondition: no half second paid yet")
	_view.hide()
	assert_almost_eq(CharacterManager.get_stat_xp(CharacterAttributesData.AttributeType.SPIRIT), 0.6, 0.0001, "0.3 s of Smooth Flow's 2 a second")
	assert_eq(_spirit_pellets().size(), 0, "no pellet flies from the hidden board")
	assert_almost_eq(_spirit_cell().get_shown_xp(), 0.6, 0.0001, "and the cell shows it at once")
	await _await_queued_frees()

#-----------------------------------------------------------------------------
# AUTO
#-----------------------------------------------------------------------------

## Plays a cycle from the press to its end with the cursor on the ball,
## pressing each zone as `tiers` says ("P" PERFECT under 3 px from its centre,
## "G" GOOD between 8 and 12 px). Returns the finished cycle's result.
func _play_cycle(tiers: String) -> CycleResult:
	var follow := _technique.get_node("%PathFollow2D") as PathFollow2D
	_technique.press_ball()
	for _frame: int in roundi((CYCLE_SECONDS + 1.0) * 60.0):
		if not _technique.is_cycling():
			break
		_technique.advance(FRAME, _technique.get_ball_global_position())
		for index: int in _technique.cycling_zones.size():
			var zone: CyclingZone = _technique.cycling_zones[index]
			if zone.get_state() != CyclingZone.State.ACTIVE:
				continue
			var distance: float = follow.global_position.distance_to(zone.global_position)
			var tier: String = tiers[index]
			if (tier == "P" and distance < 3.0) or (tier == "G" and distance > 8.0 and distance < 12.0):
				_technique.try_score_zone(zone)
	return _last_result()

func test_auto_toggle_sets_auto_cycle() -> void:
	CyclingManager.unlock_auto(SMOOTH_ID)
	var toggle := _node("AutoToggle") as TextureButton
	assert_true(toggle.toggle_mode)
	assert_false(toggle.disabled, "an unlocked toggle takes a press")
	assert_false(toggle.button_pressed)
	assert_false(_technique.auto_cycle)
	toggle.button_pressed = true
	assert_true(_technique.auto_cycle)
	toggle.button_pressed = false
	assert_false(_technique.auto_cycle)

func test_a_locked_toggle_keeps_auto_off() -> void:
	var toggle := _node("AutoToggle") as TextureButton
	assert_true(_view.is_auto_locked(), "a new save has every Auto locked")
	assert_true(toggle.disabled, "the locked toggle takes no press")
	assert_true((_node("AutoLock") as TextureRect).visible)
	toggle.button_pressed = true
	assert_false(toggle.button_pressed, "set anyway, it turns itself off")
	assert_false(_technique.auto_cycle)

func test_a_toggle_that_starts_pressed_is_honoured_once_unlocked() -> void:
	var cases: Array[Dictionary] = [
		{"name": "unlocked", "unlocked": true, "auto": true},
		{"name": "locked", "unlocked": false, "auto": false},
	]
	for case: Dictionary in cases:
		PersistenceManager.save_game_data = SaveGameData.new()
		PersistenceManager.save_data_reset.emit()
		CyclingManager.unlock_technique(SMOOTH_ID)
		CyclingManager.equip_technique(SMOOTH_ID)
		if case.unlocked:
			CyclingManager.unlock_auto(SMOOTH_ID)
		var built: CyclingView = VIEW_SCENE.instantiate() as CyclingView
		(built.get_node("%AutoToggle") as TextureButton).button_pressed = true
		add_child_autofree(built)
		var built_technique := built.get_node("%CyclingTechnique") as CyclingTechnique
		built_technique.set_process(false)
		assert_eq(built_technique.auto_cycle, case.auto, case.name)
		built.hide()

func test_switching_to_a_locked_technique_turns_auto_off() -> void:
	CyclingManager.unlock_auto(SMOOTH_ID)
	(_node("AutoToggle") as TextureButton).button_pressed = true
	CyclingManager.equip_technique(FOUNDATION_ID)
	assert_true(_view.is_auto_locked())
	assert_false((_node("AutoToggle") as TextureButton).button_pressed)
	assert_false(_technique.auto_cycle)
	await _await_queued_frees()

func test_unlock_hint_names_each_technique_s_perfect_cycle() -> void:
	var cases: Array[Dictionary] = [
		{"path": FOUNDATION_PATH, "hint": "Play a perfect cycle: follow the ball for 95% of the cycle."},
		{"path": SMOOTH_PATH, "hint": "Play a perfect cycle: follow the ball for 95% of the cycle and press every zone PERFECT."},
		{"path": TORRENTIAL_PATH, "hint": "Play a perfect cycle: follow the ball for 95% of the cycle and open every seal."},
	]
	for case: Dictionary in cases:
		assert_eq(CyclingView.unlock_hint(load(case.path)), case.hint, case.path)

func test_hovering_the_locked_toggle_shows_the_tooltip_not_the_status_line() -> void:
	var toggle := _node("AutoToggle") as TextureButton
	var tooltip := _node("AutoTooltip") as StatTooltip
	var status: String = _view.get_status_text()
	toggle.mouse_entered.emit()
	assert_true(tooltip.visible)
	assert_eq((tooltip.get_node("%TitleLabel") as Label).text, "Unlock Auto")
	assert_eq((tooltip.get_node("%FigureLabel") as Label).text, CyclingView.unlock_hint(load(SMOOTH_PATH)))
	assert_false((_node("AutoHover") as Control).visible, "no hover frame on a locked toggle")
	assert_eq(_view.get_status_text(), status, "the status line never changes for the lock")
	assert_lt(tooltip.get_global_rect().end.y, toggle.get_global_rect().position.y, "the tooltip rises above the toggle")
	toggle.mouse_exited.emit()
	assert_false(tooltip.visible)

func test_hovering_an_unlocked_toggle_shows_its_frame() -> void:
	CyclingManager.unlock_auto(SMOOTH_ID)
	var toggle := _node("AutoToggle") as TextureButton
	toggle.mouse_entered.emit()
	assert_true((_node("AutoHover") as Control).visible)
	assert_false((_node("AutoTooltip") as Control).visible)
	toggle.mouse_exited.emit()
	assert_false((_node("AutoHover") as Control).visible)

func test_a_perfect_cycle_unlocks_auto_for_its_technique() -> void:
	watch_signals(LogManager)
	var result: CycleResult = _play_cycle("PPPP")
	assert_true(result.is_perfect(), "precondition: four PERFECTs, followed the whole way")
	assert_true(CyclingManager.is_auto_unlocked(SMOOTH_ID))
	assert_false(CyclingManager.is_auto_unlocked(FOUNDATION_ID), "only the technique it was played with")
	assert_false(_view.is_auto_locked())
	assert_false((_node("AutoToggle") as TextureButton).button_pressed, "Auto stays off")
	assert_false((_node("AutoLock") as Control).visible)
	var floater := _node("UnlockFloater") as LacquerFloater
	assert_true(floater.visible)
	assert_eq(floater.get_text(), "PERFECT CYCLE · Auto unlocked")
	assert_true((_node("AutoFlash") as Control).visible, "the toggle flashes")
	var last: int = get_signal_emit_count(LogManager, "message_logged") - 1
	assert_eq(get_signal_parameters(LogManager, "message_logged", last), ["[color=yellow]Smooth Flow Technique · Auto unlocked[/color]"])

func test_a_near_miss_leaves_auto_locked() -> void:
	watch_signals(CyclingManager)
	var result: CycleResult = _play_cycle("PPGP")
	assert_true(CyclingRules.followed_enough(result.followed_ratio), "precondition: followed enough")
	assert_false(result.is_perfect())
	assert_true(_view.is_auto_locked())
	assert_signal_not_emitted(CyclingManager, "auto_unlocked")

func test_the_status_line_under_auto() -> void:
	var smooth: CyclingTechniqueData = load(SMOOTH_PATH)
	var foundation: CyclingTechniqueData = load(FOUNDATION_PATH)
	var auto: String = "Auto cycles at 40%. Follow for the full rate."
	assert_eq(CyclingView.status_line(true, foundation, false, true), auto)
	assert_eq(CyclingView.status_line(true, smooth, false, true), auto, "Auto plays no zone, so the line has no clause")
	assert_eq(CyclingView.status_line(true, load(TORRENTIAL_PATH), false, true), auto, "nor any seal")
	assert_eq(CyclingView.status_line(false, smooth, false, true), "Click the Madra ball to begin a cycle.", "waiting reads as ever")

func test_auto_starts_a_cycle_and_its_status_line() -> void:
	CyclingManager.unlock_auto(SMOOTH_ID)
	(_node("AutoToggle") as TextureButton).button_pressed = true
	await wait_process_frames(2)
	assert_true(_technique.is_cycling(), "the board starts a cycle by itself")
	assert_string_starts_with(_view.get_status_text(), "Auto cycles at 40%.")
	(_node("AutoToggle") as TextureButton).button_pressed = false
	_technique.stop_cycling()
	await wait_process_frames(2)
	assert_false(_technique.is_cycling(), "with Auto off the ball waits for a press")

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
	# A finished cycle leaves its result for the chest.
	_technique.start_cycle()
	_run(CYCLE_SECONDS + FRAME, 60.0, false)
	assert_not_null(_last_result(), "precondition: a cycle left a result")
	# Then a second cycle, closed half way with a zone scored.
	var zone: CyclingZone = _approach_zone_0(0.0)
	assert_true(_technique.try_score_zone(zone))
	_view._process(0.0)
	assert_eq(_view.get_status_text(), CyclingView.status_line(true, _technique.technique_data, false), "precondition: the status line shows the running cycle's instructions")
	_view.hide()
	_view.show()
	assert_null(_last_result(), "no stale result")
	for each: CyclingZone in _technique.cycling_zones:
		assert_eq(each.get_state(), CyclingZone.State.IDLE, "%s is idle" % each.name)
	assert_false(_technique.is_cycling(), "the cycle ended")
	assert_false(CyclingManager.is_cycle_running(), "and its session")
	assert_eq(_view.get_status_text(), CyclingView.READY, "and the ball waits for a press")
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
	assert_eq((_node("TitleLabel") as Label).text, "Seal Flow Technique")
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

#-----------------------------------------------------------------------------
# SEALS
#-----------------------------------------------------------------------------

## Plays torrential_flow on the board, `seconds` into a cycle with the cursor on
## the ball; its seal RNG seeded.
func _play_torrential(seconds: float) -> void:
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	CyclingManager.equip_technique(TORRENTIAL_ID)
	_technique.seal_rng.seed = 99
	_technique.start_cycle()
	for i: int in roundi(seconds / FRAME):
		_technique.advance(FRAME, _technique.get_ball_global_position())

func test_press_seal_reaches_the_technique() -> void:
	_play_torrential(0.6)
	var seal: SealNode = _technique.seal_nodes[0]
	assert_true(_view.press_seal(seal.get_arrows()[0]), "the seal takes its first arrow")
	assert_eq(seal.get_keyed(), 1)
	await _await_queued_frees()

## A click on Auto or the close button gives it no keyboard focus, so the arrow
## keys still reach the seals instead of moving focus.
func test_the_board_s_buttons_take_no_keyboard_focus() -> void:
	assert_eq((_node("CloseButton") as Control).focus_mode, Control.FOCUS_NONE)
	assert_eq((_node("AutoToggle") as Control).focus_mode, Control.FOCUS_NONE)

## The scenes that stay on screen beside the board while the player cycles.
const SCENES_BESIDE_THE_BOARD: Array[String] = [
	VIEW_SCENE_PATH,
	"res://scenes/zones/zone_panel/zone_panel.tscn",
	"res://scenes/cycling/technique_drawer/technique_drawer.tscn",
	"res://scenes/zones/cultivator_plate/cultivator_plate.tscn",
	"res://scenes/ui/dock/dock.tscn",
	"res://scenes/ui/goals_panel/goals_panel.tscn",
	"res://scenes/ui/log_window/log_window.tscn",
	"res://scenes/ui/quest_toast/quest_toast.tscn",
]

## The arrow keys are also the GUI's focus keys: while any Control holds
## keyboard focus, the viewport spends them moving it, and they never reach the
## seals. So nothing on screen beside the board may take focus from a click or
## the keys. (Rich text and scroll bars keep Godot's accessibility-only focus,
## which only a screen reader moves.)
func test_nothing_beside_the_board_takes_keyboard_focus() -> void:
	for path: String in SCENES_BESIDE_THE_BOARD:
		var scene: Node = (load(path) as PackedScene).instantiate()
		add_child_autofree(scene)
		var controls: Array[Node] = scene.find_children("*", "Control", true, false)
		if scene is Control:
			controls.append(scene)
		for node: Node in controls:
			var mode: Control.FocusMode = (node as Control).focus_mode
			assert_false(mode == Control.FOCUS_CLICK or mode == Control.FOCUS_ALL, "%s in %s takes no focus" % [node.name, path.get_file()])
	await _await_queued_frees()
