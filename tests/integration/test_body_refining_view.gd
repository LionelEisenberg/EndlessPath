extends GutTest

## Integration tests for BodyRefiningView, the body refining board in the map gap:
## its header names the action and the drill, and under them what a Perfect rep
## pays at the player's Strength, with Strength's icon and the Health heart; the
## footer tells how to start, then how to play, and never what a set paid (#149);
## a finished set becomes the chest's last set and writes one log line; each scored rep sends its pellets from its
## stage to the cabinet, Strength's to its cell and Health's to the orb, carrying
## only what was taken; closing mid-set keeps what was paid and reports nothing.
## The cabinet stands beside the view, as MainView hands it over. Every test runs on
## a fresh save with the real Stone Lifting, on a test clock, with the original save
## put back after it.

const VIEW_SCENE: PackedScene = preload("res://scenes/body_refining/body_refining_view/body_refining_view.tscn")
const PLATE_SCENE: PackedScene = preload("res://scenes/zones/cultivator_plate/cultivator_plate.tscn")
const DRAWER_SCENE: PackedScene = preload("res://scenes/body_refining/drill_drawer/drill_drawer.tscn")
const HEALTH_MINI: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_health_ai.png")
const ACTION_ID: String = "riverbank_training_action"

const AttributeType = CharacterAttributesData.AttributeType

const START_USEC: int = 1_000_000
const CENTRE: float = 1.37
## A board's room under its footer: the bottom frame, the corner brackets and the shadow.
const BOARD_ROOM: float = 30.0
## GUT draws its own window on this layer, over the whole screen: a test that
## pushes a click stands the chest and the board on a layer above it.
const GUT_OUTPUT_LAYER: int = 128
## Where the chest's first drawer stands, as the zone chest lists it.
const DRAWER_AT: Vector2 = Vector2(1472.0, 232.0)

var _view: BodyRefiningView = null
var _plate: CultivatorPlate = null
var _play: DrillPlay = null
var _now_usec: int = START_USEC
var _original_save: SaveGameData = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_now_usec = START_USEC
	_plate = add_child_autofree(PLATE_SCENE.instantiate()) as CultivatorPlate
	_view = VIEW_SCENE.instantiate() as BodyRefiningView
	_view.cultivator_plate = _plate
	add_child_autofree(_view)
	_view.show()
	_play = _view.get_node("%DrillPlay") as DrillPlay
	_play.clock_usec = func() -> int: return _now_usec
	_view.setup(ZoneManager.get_action_by_id(ACTION_ID))

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	BodyRefiningManager.end_set_session()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	_view = null
	_plate = null
	_play = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _node(unique_name: String) -> Node:
	return _view.get_node("%" + unique_name)

func _at(seconds: float) -> void:
	_clock_to(seconds)
	_play._process(0.0)

func _clock_to(seconds: float) -> void:
	_now_usec = START_USEC + roundi(seconds * 1e6)

func _press(down: bool = true) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"drill_press"
	event.pressed = down
	return event

## Lifts at the start of rep `rep`'s slot and lets go `held` seconds later.
func _lift(rep: int, held: float) -> void:
	_clock_to(rep * 4.0)
	_view.handle_press_event(_press())
	_clock_to(rep * 4.0 + held)
	_view.handle_press_event(_press(false))

## A click of the left button at `point`, in the stage's px, `seconds` after the
## set's first press: down, then up.
func _click_at(seconds: float, point: Vector2) -> void:
	_clock_to(seconds)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.global_position = _play.get_stage().get_global_transform() * point
		_view.handle_press_event(event)

## Plays a whole set, each rep held `holds[rep]` seconds, then steps past its end.
func _play_set(holds: Array) -> void:
	for rep: int in holds.size():
		_lift(rep, holds[rep])
	_at(40.0)

func _pellets(ramp: LacquerPellet.Ramp) -> Array[LacquerPellet]:
	var found: Array[LacquerPellet] = []
	for child: Node in _node("EffectsLayer").get_children():
		var pellet := child as LacquerPellet
		if pellet != null and pellet.get_ramp() == ramp:
			found.append(pellet)
	return found

func _land(pellets: Array[LacquerPellet]) -> void:
	for pellet: LacquerPellet in pellets:
		pellet._process(10.0)

func _plate_health() -> String:
	return (_plate.get_node("%HealthValueLabel") as Label).text

func _pay_line() -> RichTextLabel:
	return _node("PayLine") as RichTextLabel

func _ten(hold: float) -> Array:
	var holds: Array = []
	holds.resize(10)
	holds.fill(hold)
	return holds

## Puts Strength at Lv 2. A perfect Stone Lifting set pays 100 XP, Lv 2's whole
## cost: played at Lv 1 it buys that level, logs it and leaves no XP in Strength's
## cell. From Lv 2 the next level costs 125, so the set's XP stays XP.
func _strength_at_lv_2() -> void:
	CharacterManager.set_stat_level(AttributeType.STRENGTH, 2)

#-----------------------------------------------------------------------------
# THE HEADER
#-----------------------------------------------------------------------------

func test_setup_names_the_action_and_the_drill() -> void:
	assert_eq((_node("ActionLabel") as Label).text, "Riverbank Training")
	assert_eq((_node("TitleLabel") as Label).text, "Stone Lifting")
	assert_eq(_view.get_status_text(), BodyRefiningManager.get_equipped_drill().ready_line)

func test_the_pay_line_reads_a_perfect_rep_at_your_strength() -> void:
	var text: String = _pay_line().get_parsed_text()
	assert_string_contains(text, "Perfect rep")
	assert_string_contains(text, "+10 XP", "Stone Lifting's Strength XP")
	assert_string_contains(text, "+4", "and its Health at Strength Lv 1")
	assert_string_contains(_pay_line().text, StatDisplay.mini_icon_of(AttributeType.STRENGTH).resource_path, "with Strength's icon")
	assert_string_contains(_pay_line().text, HEALTH_MINI.resource_path, "and the Health heart")
	CharacterManager.set_stat_level(AttributeType.STRENGTH, 5)
	assert_string_contains(_pay_line().get_parsed_text(), "+5.6", "Strength 14 restores 4 x 1.4")

func test_the_pay_line_at_the_cap_says_capped() -> void:
	CharacterManager.set_stat_level(AttributeType.STRENGTH, CharacterManager.get_stat_level_cap())
	var text: String = _pay_line().get_parsed_text()
	assert_string_contains(text, "capped", "no Strength XP at the cap")
	assert_false(text.contains("XP"), "and no XP figure")
	assert_string_contains(text, "+7.6", "the Health still climbs with Strength")

#-----------------------------------------------------------------------------
# THE FOOTER AND THE LOG
#-----------------------------------------------------------------------------

func test_the_status_line_follows_the_set() -> void:
	ResourceManager.set_health(50.0)
	assert_eq(_view.get_status_text(), BodyRefiningManager.get_equipped_drill().ready_line)
	_clock_to(0.0)
	_view.handle_press_event(_press())
	assert_eq(_view.get_status_text(), BodyRefiningManager.get_equipped_drill().play_line, "a set runs")
	_clock_to(CENTRE)
	_view.handle_press_event(_press(false))
	for rep: int in range(1, 10):
		_lift(rep, CENTRE)
	_at(40.0)
	assert_eq(_view.get_status_text(), BodyRefiningManager.get_equipped_drill().ready_line, "the set ended: how to start the next, no result")

## A set played to its last rep becomes the chest's last set; it stays through the
## next set until that one ends.
func test_a_finished_set_becomes_the_last_set() -> void:
	ResourceManager.set_health(20.0)
	assert_null(BodyRefiningManager.get_last_set_result(), "none before a set")
	_play_set(_ten(CENTRE))
	var first: DrillSetResult = BodyRefiningManager.get_last_set_result()
	assert_eq(first, _play.get_result(), "the set just played")
	_lift(10, CENTRE)
	assert_eq(BodyRefiningManager.get_last_set_result(), first, "kept while the next set runs")

## Counted by the signal, not the history, which keeps only the last 200 lines
## the scripts before this one logged. Strength is at Lv 2, so the line is the
## set's alone, with Health at Strength 11: 10 reps of 4 x 1.1.
func test_a_finished_set_writes_one_log_line() -> void:
	ResourceManager.set_health(50.0)
	_strength_at_lv_2()
	BodyRefiningManager.unlock_auto("stone_lifting")
	watch_signals(LogManager)
	_play_set(_ten(CENTRE))
	assert_signal_emit_count(LogManager, "message_logged", 1, "one line")
	var line: String = get_signal_parameters(LogManager, "message_logged", 0)[0]
	assert_eq(LogWindow.plain_text(line), "Set · +100 Strength XP · +44 Health")

#-----------------------------------------------------------------------------
# PELLETS
#-----------------------------------------------------------------------------

func test_health_pellets_land_on_the_health_orb() -> void:
	ResourceManager.set_health(40.0)
	_lift(0, CENTRE)
	var pellets: Array[LacquerPellet] = _pellets(LacquerPellet.Ramp.HEALTH)
	assert_eq(pellets.size(), 4, "a Perfect rep sends four Health pellets")
	assert_eq(_plate_health(), "40", "none has landed")
	_land(pellets)
	assert_eq(_plate_health(), "44", "all have")

## A rep's XP waits for the set's end (#143): the rep sends Health pellets only.
func test_a_rep_sends_only_health_pellets() -> void:
	ResourceManager.set_health(40.0)
	_lift(0, CENTRE)
	assert_eq(_pellets(LacquerPellet.Ramp.STRENGTH).size(), 0, "no Strength pellets yet")
	assert_eq(_pellets(LacquerPellet.Ramp.HEALTH).size(), 4, "four Health pellets")

## The set's end pours its XP from the beads: one Strength pellet from each bead
## that stored XP, holding the XP out of Strength's cell until it lands.
func test_the_set_s_end_pours_xp_from_the_beads() -> void:
	ResourceManager.set_health(20.0)
	_strength_at_lv_2()
	_play_set(_ten(CENTRE))
	var pellets: Array[LacquerPellet] = _pellets(LacquerPellet.Ramp.STRENGTH)
	assert_eq(pellets.size(), 10, "a pellet a bead")
	var cell: StatCell = _plate.get_node("%StrengthCell") as StatCell
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 100.0, "the set's XP is paid")
	assert_eq(cell.get_shown_xp(), 0.0, "and held out of the cell while it flies")
	_land(pellets)
	assert_almost_eq(cell.get_shown_xp(), 100.0, 0.0001, "the set's 100 XP has landed")

## Each scored bead pours; a Miss's bead stored nothing.
func test_the_pour_skips_a_miss_s_bead() -> void:
	ResourceManager.set_health(20.0)
	_play_set([CENTRE, 0.6, CENTRE, CENTRE, CENTRE, CENTRE, CENTRE, CENTRE, CENTRE, CENTRE])
	var pellets: Array[LacquerPellet] = _pellets(LacquerPellet.Ramp.STRENGTH)
	assert_eq(pellets.size(), 9, "the Miss's bead stored nothing")

## Review Focus 4: leaves caught out of turn pour from their own beads. Leaf 1 is
## caught before leaf 0, which is caught Good (18 px off): every pellet leaves from
## the bead of the rep it carries, bead 0's carrying the Good catch's 5.25 XP.
func test_the_pour_leaves_from_each_leaf_s_own_bead() -> void:
	ResourceManager.set_health(20.0)
	BodyRefiningManager.unlock_drill("falling_leaf")
	_play.run_for = func(drill: DrillData, _seed: int) -> DrillRun:
		var leaves: Array[FallingLeafRun.Leaf] = []
		for rep: int in drill.reps_per_set:
			leaves.append(FallingLeafRun.Leaf.new(100.0 + rep * 30.0, 64.0, 0.0, 1_600_000, 0.0))
		return FallingLeafRun.new(drill, leaves)
	BodyRefiningManager.equip_drill("falling_leaf")
	await wait_process_frames(1)
	var shake := Vector2(500.0, 860.0)
	var fallen := func(seconds: float) -> float: return 64.0 + 792.0 * seconds / 3.6
	_click_at(0.0, shake)
	_click_at(0.5, shake)
	_click_at(1.0, Vector2(130.0, fallen.call(0.5)))
	_click_at(1.2, Vector2(118.0, fallen.call(1.2)))
	for rep: int in range(2, 10):
		var at: float = 1.5 + (rep - 2) * 1.0
		_click_at(at, shake)
		_click_at(at + 0.5, Vector2(100.0 + rep * 30.0, fallen.call(0.5)))
	_at(9.1)
	assert_eq(_play.get_result().count_of(DrillRules.Tier.PERFECT), 9, "precondition: nine Perfect catches")
	assert_eq(_play.get_result().count_of(DrillRules.Tier.GOOD), 1, "and leaf 0's Good one, after leaf 1")
	var pellets: Array[LacquerPellet] = _pellets(LacquerPellet.Ramp.STRENGTH)
	assert_eq(pellets.size(), 10, "a pellet a bead")
	var carried_from: Dictionary = {}
	for pellet: LacquerPellet in pellets:
		for rep: int in 10:
			if pellet.global_position.distance_to(_play.get_bead_origin(rep)) <= 2.0:
				for connection: Dictionary in pellet.delivered.get_connections():
					var bound: Array = (connection["callable"] as Callable).get_bound_arguments()
					if bound.size() == 2:
						carried_from[rep] = bound[1]
	assert_eq(carried_from.keys().size(), 10, "each from its own bead")
	assert_almost_eq(carried_from.get(0, 0.0), 5.25, 0.0001, "bead 0 carries the Good catch's XP")
	assert_almost_eq(carried_from.get(1, 0.0), 7.0, 0.0001, "bead 1 a Perfect catch's")

## The pour carries what the stat took, not what the set stored: 10 XP short of
## the cap, the pellets carry the 10 that reached it.
func test_the_pour_carries_only_what_was_taken() -> void:
	var cap: int = CharacterManager.get_stat_level_cap()
	CharacterManager.set_stat_level(AttributeType.STRENGTH, cap - 1)
	CharacterManager.set_stat_level(AttributeType.STRENGTH, cap - 1, CharacterManager.get_stat_xp_to_next(AttributeType.STRENGTH) - 10.0)
	ResourceManager.set_health(20.0)
	_play_set(_ten(CENTRE))
	var pellets: Array[LacquerPellet] = _pellets(LacquerPellet.Ramp.STRENGTH)
	assert_eq(pellets.size(), 10, "a pellet a bead")
	var carried: float = 0.0
	for pellet: LacquerPellet in pellets:
		for connection: Dictionary in pellet.delivered.get_connections():
			var bound: Array = (connection["callable"] as Callable).get_bound_arguments()
			if bound.size() == 2:
				carried += bound[1]
	assert_almost_eq(carried, 10.0, 0.0001, "the 10 XP that reached the cap, shared")

func test_fewer_pellets_for_a_lesser_tier() -> void:
	ResourceManager.set_health(40.0)
	_lift(0, 1.2)
	assert_eq(_pellets(LacquerPellet.Ramp.HEALTH).size(), 3, "Good sends three of each")
	_lift(1, 0.9)
	assert_eq(_pellets(LacquerPellet.Ramp.HEALTH).size(), 3 + 2, "OK two")

func test_a_miss_sends_no_pellets() -> void:
	_lift(0, 0.6)
	assert_eq(_node("EffectsLayer").get_children().filter(func(child: Node) -> bool: return child is LacquerPellet).size(), 0)

func test_no_strength_pellets_at_the_cap() -> void:
	CharacterManager.set_stat_level(AttributeType.STRENGTH, CharacterManager.get_stat_level_cap())
	ResourceManager.set_health(40.0)
	_lift(0, CENTRE)
	assert_eq(_pellets(LacquerPellet.Ramp.HEALTH).size(), 4, "the Health still comes")
	_play_set(_ten(CENTRE))
	assert_eq(_pellets(LacquerPellet.Ramp.STRENGTH).size(), 0, "a capped Strength takes no pellets at the set's end")

## Review Focus 5: a rep that tops Health up sends pellets carrying only what it
## restored.
func test_pellets_carry_only_what_was_taken() -> void:
	ResourceManager.set_health(98.0)
	_lift(0, CENTRE)
	assert_eq(_plate_health(), "98", "the 2 restored is in flight")
	_land(_pellets(LacquerPellet.Ramp.HEALTH))
	assert_eq(_plate_health(), "100", "and lands as 2, not 4")

#-----------------------------------------------------------------------------
# CLOSING
#-----------------------------------------------------------------------------

## Review Focus 4: closing mid-set keeps what the reps paid and reports nothing.
## The log line is watched by its signal: the history keeps only 200 lines.
func test_closing_mid_set_keeps_what_was_paid() -> void:
	ResourceManager.set_health(50.0)
	watch_signals(LogManager)
	_lift(0, CENTRE)
	_lift(1, CENTRE)
	_view.close()
	assert_false(_view.visible, "the board hides")
	assert_eq(ResourceManager.get_health(), 58.0, "the two reps' Health stays")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 20.0, "and their XP")
	assert_eq(_plate_health(), "58", "shown at once, nothing left in flight")
	assert_signal_not_emitted(LogManager, "message_logged", "no log line")
	assert_eq(PersistenceManager.save_game_data.stats.sets_finished, 0, "no set counted")
	assert_null(BodyRefiningManager.get_last_set_result(), "no last set")
	assert_false(BodyRefiningManager.is_set_running(), "the session ended")
	await wait_process_frames(1)
	assert_eq(_node("EffectsLayer").get_children().filter(func(child: Node) -> bool: return child is LacquerPellet).size(), 0, "no pellet left")

## Review Focus 4: picking another drill mid-set ends the set there. Its scored
## reps stay paid, it is neither counted nor logged, and the board readies the
## picked drill: its stage, its line before a set, the beads empty.
func test_picking_another_drill_mid_set_keeps_what_was_paid() -> void:
	ResourceManager.set_health(50.0)
	BodyRefiningManager.unlock_drill("horse_stance")
	watch_signals(LogManager)
	_lift(0, CENTRE)
	_lift(1, CENTRE)
	assert_true(_play.is_set_running(), "precondition: the set runs")
	BodyRefiningManager.equip_drill("horse_stance")
	assert_eq(ResourceManager.get_health(), 58.0, "the two reps' Health stays")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 20.0, "and their XP")
	assert_signal_not_emitted(LogManager, "message_logged", "no log line")
	assert_eq(PersistenceManager.save_game_data.stats.sets_finished, 0, "no set counted")
	assert_false(_play.is_set_running(), "the set ended")
	assert_false(BodyRefiningManager.is_set_running(), "and its session")
	for bead: Node in _play.get_node("%Beads").get_children():
		assert_eq((bead as LacquerStripRect).get_frame().x, DrillPlay.EMPTY_BEAD, "%s is empty" % bead.name)
	assert_eq((_node("TitleLabel") as Label).text, "Horse Stance", "the board names the picked drill")
	assert_eq(_view.get_status_text(), BodyRefiningManager.get_drill("horse_stance").ready_line, "with its line before a set")
	assert_true(_play.get_stage() is HorseStanceStage, "on its stage")
	_clock_to(9.0)
	_view.handle_press_event(_press())
	assert_true(_play.get_run() is HorseStanceRun, "and the next press plays it")

func test_reopening_forgets_the_last_set() -> void:
	_play_set(_ten(CENTRE))
	_view.setup(ZoneManager.get_action_by_id(ACTION_ID))
	assert_null(BodyRefiningManager.get_last_set_result())
	assert_eq(_view.get_status_text(), BodyRefiningManager.get_equipped_drill().ready_line)

## Picking another drill forgets the last set, even one that finished as the pick
## stopped it: its tenth rep had landed while its stone settled.
func test_picking_another_drill_forgets_the_last_set() -> void:
	BodyRefiningManager.unlock_drill("horse_stance")
	for rep: int in 10:
		_lift(rep, CENTRE)
	assert_true(_play.is_set_running(), "precondition: the tenth stone is still settling")
	BodyRefiningManager.equip_drill("horse_stance")
	assert_eq(PersistenceManager.save_game_data.stats.sets_finished, 1, "the set finished")
	assert_null(BodyRefiningManager.get_last_set_result(), "and is not the new drill's last set")

func test_the_close_button_stops_the_action() -> void:
	var action: ZoneActionData = ZoneManager.get_action_by_id(ACTION_ID)
	ActionManager.select_action(action)
	assert_same(ActionManager.get_current_action(), action, "precondition: body refining runs")
	(_node("CloseButton") as TextureButton).pressed.emit()
	assert_ne(ActionManager.get_current_action(), action, "the close button stops it")

#-----------------------------------------------------------------------------
# INPUT AND LAYOUT
#-----------------------------------------------------------------------------

func test_the_view_stops_every_click_beneath_it() -> void:
	assert_eq(_view.mouse_filter, Control.MOUSE_FILTER_STOP, "the full-screen root stops every click")
	assert_eq([_view.anchor_left, _view.anchor_top, _view.anchor_right, _view.anchor_bottom], [0.0, 0.0, 1.0, 1.0], "and covers the screen")
	var board := _node("Board") as Control
	var close := _node("CloseButton") as Control
	var toggle := _node("AutoToggle") as Control
	var takers: Array[String] = []
	for node: Node in _view.find_children("*", "Control", true, true):
		if node == board or node == close or node == toggle:
			continue
		if (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			takers.append(String(node.name))
	assert_eq(board.mouse_filter, Control.MOUSE_FILTER_PASS, "the board passes its clicks on to the root")
	assert_eq(takers.size(), 0, "every node but the board, the close button and the Auto toggle lets a click through, not %s" % [takers])

func test_a_mouse_press_anywhere_lifts() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(1700, 900)
	press.global_position = press.position
	_clock_to(0.0)
	_view._gui_input(press)
	assert_true(_play.is_set_running(), "a press beside the board starts a set")
	assert_true((_play.get_run() as StoneLiftingRun).is_lifting(), "and lifts")

## A left press and its release at `point` in the viewport's own 1920x1080 space,
## as the mouse sends them. The headless window is scaled down, so the events go in
## local coordinates.
func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		get_viewport().push_input(event, true)

## Review Focus 3: a press on a drill drawer while the board is up picks its drill
## and never reaches the drill as a press, and a press anywhere else still does.
## The drawer stands for the chest, and the board over it on a layer above GUT's
## window, after it in the tree as main_game.tscn has them.
func test_a_press_on_the_chest_picks_and_never_plays() -> void:
	BodyRefiningManager.unlock_drill("horse_stance")
	var layer := CanvasLayer.new()
	layer.layer = GUT_OUTPUT_LAYER + 1
	add_child_autofree(layer)
	var drawer: DrillDrawer = DRAWER_SCENE.instantiate() as DrillDrawer
	drawer.setup(BodyRefiningManager.get_drill("horse_stance"))
	drawer.position = DRAWER_AT
	layer.add_child(drawer)
	_view.reparent(layer)
	_view.chest = drawer
	await wait_process_frames(1)
	_clock_to(0.0)
	_click(drawer.get_global_rect().get_center())
	assert_eq(BodyRefiningManager.get_equipped_drill().id, "horse_stance", "the drawer picked its drill")
	assert_false(_play.is_set_running(), "and the press never reached the drill")
	_click((_node("Board") as Control).get_global_rect().get_center())
	assert_true(_play.is_set_running(), "a press on the board is the drill's")

func test_a_long_name_wraps_and_the_board_grows() -> void:
	var action := BodyRefiningActionData.new()
	action.action_id = "test_long_body_refining"
	action.action_name = "The Long Riverbank Where Every Cultivator Who Ever Lifted A Stone Left A Mark"
	_view.setup(action)
	var label := _node("ActionLabel") as Label
	assert_eq(label.get_line_count(), 2, "precondition: the name wraps to two lines")
	var status := _node("StatusText") as Control
	var board := _node("Board") as Control
	assert_gt(status.position.y, 990.0, "the footer moves down under the longer header")
	var toggle := _node("AutoToggle") as Control
	var footer_bottom: float = maxf(status.position.y + status.size.y, toggle.position.y + toggle.size.y)
	assert_eq(board.position.y + board.size.y, footer_bottom + BOARD_ROOM, "the board grows to keep its room under the footer")
	assert_lte(board.position.y + board.size.y, 1080.0, "and still ends on screen")

#-----------------------------------------------------------------------------
# AUTO
#-----------------------------------------------------------------------------

func _toggle() -> TextureButton:
	return _node("AutoToggle") as TextureButton

## Runs frames every half second from `from` to `to` seconds after the set's start.
func _frames(from: float, to: float) -> void:
	var t: float = from
	while t <= to:
		_at(t)
		t += 0.5

## Before a perfect set the toggle is locked: disabled, off, with the lock, and
## pressing it turns nothing on.
func test_auto_stays_locked_until_a_perfect_set() -> void:
	assert_true(_view.is_auto_locked())
	assert_true(_toggle().disabled, "the toggle takes no press")
	assert_true((_node("AutoLock") as CanvasItem).visible, "the lock shows")
	_toggle().button_pressed = true
	assert_false(_toggle().button_pressed, "a locked toggle stays off")
	assert_false(_play.is_auto_play(), "and Auto stays off")
	_play_set([CENTRE, CENTRE, CENTRE, CENTRE, CENTRE, CENTRE, CENTRE, CENTRE, CENTRE, 1.2])
	assert_true(_view.is_auto_locked(), "a near miss leaves it locked")
	assert_false(BodyRefiningManager.is_auto_unlocked("stone_lifting"))

## A perfect set unlocks the drill's Auto, and only that drill's: the toggle
## unlocks and stays off, the floater pops, and the log gets the yellow line.
func test_a_perfect_set_unlocks_auto() -> void:
	ResourceManager.set_health(20.0)
	_strength_at_lv_2()
	watch_signals(LogManager)
	_play_set(_ten(CENTRE))
	assert_true(BodyRefiningManager.is_auto_unlocked("stone_lifting"))
	assert_false(BodyRefiningManager.is_auto_unlocked("horse_stance"), "the other drill stays locked")
	assert_false(_view.is_auto_locked())
	assert_false(_toggle().disabled, "the toggle takes a press")
	assert_false(_toggle().button_pressed, "and stays off")
	assert_true((_node("UnlockFloater") as CanvasItem).visible, "the floater pops")
	assert_signal_emit_count(LogManager, "message_logged", 2, "the set's line and the unlock's")
	var line: String = get_signal_parameters(LogManager, "message_logged", 1)[0]
	assert_eq(line, "[color=yellow]Stone Lifting · Auto unlocked[/color]")

## The locked toggle's hover shows what unlocks it, and the footer stays.
func test_the_locked_toggle_shows_how_to_unlock() -> void:
	var before: String = _view.get_status_text()
	_toggle().mouse_entered.emit()
	var tooltip := _node("AutoTooltip") as StatTooltip
	assert_true(tooltip.visible, "the tooltip shows")
	assert_eq((tooltip.get_node("%FigureLabel") as Label).text, BodyRefiningView.UNLOCK_HINT)
	assert_eq(_view.get_status_text(), before, "the footer never changes for the lock")
	_toggle().mouse_exited.emit()
	assert_false(tooltip.visible)

## With Auto on, the footer reads Auto's line from an Auto set's start, through
## its end and the wait for the next; the set becomes the last set, and the log
## line says Auto.
func test_the_footer_and_log_under_auto() -> void:
	ResourceManager.set_health(20.0)
	BodyRefiningManager.unlock_auto("stone_lifting")
	_toggle().button_pressed = true
	_at(0.0)
	assert_eq(_view.get_status_text(), BodyRefiningView.AUTO_LINE % 40)
	watch_signals(LogManager)
	_frames(0.5, 38.5)
	assert_false(_play.is_set_running(), "precondition: the Auto set ended")
	assert_eq(_view.get_status_text(), BodyRefiningView.AUTO_LINE % 40, "Auto's line through the wait")
	assert_true(BodyRefiningManager.get_last_set_result().is_auto(), "the Auto set is the last set")
	var line: String = get_signal_parameters(LogManager, "message_logged", 0)[0]
	assert_eq(LogWindow.plain_text(line), "Set · Auto · +40 Strength XP · +16 Health")
	_at(40.0)
	assert_true(_play.is_set_running(), "the next Auto set started at Auto's pace, 40 s after the last")
	assert_eq(_view.get_status_text(), BodyRefiningView.AUTO_LINE % 40)

## Turning Auto on mid-set ends the played set there: its reps stay paid.
func test_turning_auto_on_mid_set_ends_the_set() -> void:
	BodyRefiningManager.unlock_auto("stone_lifting")
	_lift(0, CENTRE)
	assert_true(_play.is_set_running())
	_toggle().button_pressed = true
	assert_false(_play.is_set_running(), "the played set ended")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 10.0, "its rep stays paid")
	_at(5.0)
	assert_true(_play.is_auto_set(), "and Auto's set starts")

## A drill picked from the chest brings its own Auto state: a locked one turns
## Auto off.
func test_the_toggle_follows_the_drill_in_use() -> void:
	BodyRefiningManager.unlock_auto("stone_lifting")
	BodyRefiningManager.unlock_drill("horse_stance")
	_toggle().button_pressed = true
	BodyRefiningManager.equip_drill("horse_stance")
	assert_true(_view.is_auto_locked(), "Horse Stance's Auto is locked")
	assert_false(_toggle().button_pressed, "so the toggle is off")
	assert_false(_play.is_auto_play())
