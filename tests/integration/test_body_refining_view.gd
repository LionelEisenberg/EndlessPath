extends GutTest

## Integration tests for BodyRefiningView, the body refining board in the map gap:
## its header names the action and the drill, and under them what a Perfect rep
## pays at the player's Strength, with Strength's icon and the Health heart; the
## footer tells how to start, then how to play, then what the last set paid; a
## finished set writes one log line; each scored rep sends its pellets from the
## stone to the cabinet, Strength's to its cell and Health's to the orb, carrying
## only what was taken; closing mid-set keeps what was paid and reports nothing.
## The cabinet stands beside the view, as MainView hands it over. Every test runs on
## a fresh save with the real Stone Lifting, on a test clock, with the original save
## put back after it.

const VIEW_SCENE: PackedScene = preload("res://scenes/body_refining/body_refining_view/body_refining_view.tscn")
const PLATE_SCENE: PackedScene = preload("res://scenes/zones/cultivator_plate/cultivator_plate.tscn")
const HEALTH_MINI: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_health_ai.png")
const ACTION_ID: String = "riverbank_training_action"

const AttributeType = CharacterAttributesData.AttributeType

const START_USEC: int = 1_000_000
const CENTRE: float = 1.37
## A board's room under its footer: the bottom frame, the corner brackets and the shadow.
const BOARD_ROOM: float = 30.0

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

#-----------------------------------------------------------------------------
# THE HEADER
#-----------------------------------------------------------------------------

func test_setup_names_the_action_and_the_drill() -> void:
	assert_eq((_node("ActionLabel") as Label).text, "Riverbank Training")
	assert_eq((_node("TitleLabel") as Label).text, "Stone Lifting")
	assert_eq(_view.get_status_text(), BodyRefiningView.READY)

func test_the_pay_line_reads_a_perfect_rep_at_your_strength() -> void:
	var text: String = _pay_line().get_parsed_text()
	assert_string_contains(text, "Perfect rep")
	assert_string_contains(text, "+6 XP", "Stone Lifting's Strength XP")
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
	assert_eq(_view.get_status_text(), BodyRefiningView.READY)
	_clock_to(0.0)
	_view.handle_press_event(_press())
	assert_eq(_view.get_status_text(), BodyRefiningView.LIFT, "a set runs")
	_clock_to(CENTRE)
	_view.handle_press_event(_press(false))
	for rep: int in range(1, 10):
		_lift(rep, CENTRE)
	_at(40.0)
	var text: String = _view.get_status_text()
	assert_string_contains(text, "Last set")
	assert_string_contains(text, "Perfect set", "ten Perfect reps")
	assert_string_contains(text, "+60 XP")
	assert_string_contains(text, "+40")

func test_a_set_with_misses_reads_its_perfect_count() -> void:
	ResourceManager.set_health(20.0)
	_play_set([CENTRE, CENTRE, CENTRE, CENTRE, CENTRE, CENTRE, 1.2, 1.2, 0.9, 0.6])
	var text: String = _view.get_status_text()
	assert_string_contains(text, "6 / 10 perfect")
	assert_false(text.contains("Perfect set"))

## Counted by the signal, not the history, which keeps only the last 200 lines
## the scripts before this one logged.
func test_a_finished_set_writes_one_log_line() -> void:
	ResourceManager.set_health(50.0)
	watch_signals(LogManager)
	_play_set(_ten(CENTRE))
	assert_signal_emit_count(LogManager, "message_logged", 1, "one line")
	var line: String = get_signal_parameters(LogManager, "message_logged", 0)[0]
	assert_eq(LogWindow.plain_text(line), "Set · +60 Strength XP · +40 Health")

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

func test_strength_pellets_land_on_strength_s_cell() -> void:
	_lift(0, CENTRE)
	var pellets: Array[LacquerPellet] = _pellets(LacquerPellet.Ramp.STRENGTH)
	assert_eq(pellets.size(), 4, "and four Strength pellets")
	var cell: StatCell = _plate.get_node("%StrengthCell") as StatCell
	assert_eq(cell.get_shown_xp(), 0.0, "none has landed")
	_land(pellets)
	assert_almost_eq(cell.get_shown_xp(), 6.0, 0.0001, "the rep's 6 XP has")

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
	assert_eq(_pellets(LacquerPellet.Ramp.STRENGTH).size(), 0, "a capped Strength takes no pellets")
	assert_eq(_pellets(LacquerPellet.Ramp.HEALTH).size(), 4, "the Health still comes")

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
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 12.0, "and their XP")
	assert_eq(_plate_health(), "58", "shown at once, nothing left in flight")
	assert_signal_not_emitted(LogManager, "message_logged", "no log line")
	assert_eq(PersistenceManager.save_game_data.stats.sets_finished, 0, "no set counted")
	assert_false(BodyRefiningManager.is_set_running(), "the session ended")
	await wait_process_frames(1)
	assert_eq(_node("EffectsLayer").get_children().filter(func(child: Node) -> bool: return child is LacquerPellet).size(), 0, "no pellet left")

func test_reopening_starts_clean() -> void:
	_play_set(_ten(CENTRE))
	_view.setup(ZoneManager.get_action_by_id(ACTION_ID))
	assert_eq(_view.get_status_text(), BodyRefiningView.READY, "the last set's line is gone")

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
	var takers: Array[String] = []
	for node: Node in _view.find_children("*", "Control", true, true):
		if node == board or node == close:
			continue
		if (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			takers.append(String(node.name))
	assert_eq(board.mouse_filter, Control.MOUSE_FILTER_PASS, "the board passes its clicks on to the root")
	assert_eq(takers.size(), 0, "every node but the board and the close button lets a click through, not %s" % [takers])

func test_a_mouse_press_anywhere_lifts() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(1700, 900)
	press.global_position = press.position
	_clock_to(0.0)
	_view._gui_input(press)
	assert_true(_play.is_set_running(), "a press over the chest starts a set")
	assert_true(_play.get_run().is_lifting(), "and lifts")

func test_a_long_name_wraps_and_the_board_grows() -> void:
	var action := BodyRefiningActionData.new()
	action.action_id = "test_long_body_refining"
	action.action_name = "The Long Riverbank Where Every Cultivator Who Ever Lifted A Stone Left A Mark On The Gravel, And The Reeds Remember Them"
	_view.setup(action)
	var label := _node("ActionLabel") as Label
	assert_eq(label.get_line_count(), 3, "precondition: the name wraps to three lines")
	var status := _node("StatusText") as Control
	var board := _node("Board") as Control
	assert_gt(status.position.y, 990.0, "the footer moves down under the longer header")
	assert_eq(board.position.y + board.size.y, status.position.y + status.size.y + BOARD_ROOM, "the board grows to keep its room under the footer")
	assert_lte(board.position.y + board.size.y, 1080.0, "and still ends on screen")
