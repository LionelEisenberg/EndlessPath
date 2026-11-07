extends GutTest

## Integration tests for BodyRefiningView, the body refining board in the map gap:
## its header names the action and the drill, and under them what a Perfect rep
## pays at the player's Strength, with Strength's icon and the Health heart; the
## footer tells how to start, then how to play, then what the last set paid; a
## finished set writes one log line; each scored rep sends its pellets from its
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
	assert_eq(_view.get_status_text(), BodyRefiningManager.get_equipped_drill().ready_line)

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
	assert_eq(_view.get_status_text(), BodyRefiningManager.get_equipped_drill().ready_line)
	_clock_to(0.0)
	_view.handle_press_event(_press())
	assert_eq(_view.get_status_text(), BodyRefiningManager.get_equipped_drill().play_line, "a set runs")
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
	BodyRefiningManager.unlock_auto("stone_lifting")
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
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 12.0, "and their XP")
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

func test_reopening_starts_clean() -> void:
	_play_set(_ten(CENTRE))
	_view.setup(ZoneManager.get_action_by_id(ACTION_ID))
	assert_eq(_view.get_status_text(), BodyRefiningManager.get_equipped_drill().ready_line, "the last set's line is gone")

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
	assert_eq(board.position.y + board.size.y, status.position.y + status.size.y + BOARD_ROOM, "the board grows to keep its room under the footer")
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

## With Auto on, the footer reads Auto's line, then the Auto set's line once it
## ends, which stays through the next Auto set; the log line says Auto.
func test_the_footer_and_log_under_auto() -> void:
	ResourceManager.set_health(20.0)
	BodyRefiningManager.unlock_auto("stone_lifting")
	_toggle().button_pressed = true
	_at(0.0)
	assert_eq(_view.get_status_text(), BodyRefiningView.AUTO_LINE % 40)
	watch_signals(LogManager)
	_frames(0.5, 38.5)
	var text: String = _view.get_status_text()
	assert_string_contains(text, "Last set · Auto · ", "the Auto set's line")
	assert_string_contains(text, "+24 XP")
	assert_false(text.contains("perfect"), "no Perfect count")
	var line: String = get_signal_parameters(LogManager, "message_logged", 0)[0]
	assert_eq(LogWindow.plain_text(line), "Set · Auto · +24 Strength XP · +16 Health")
	_at(39.0)
	assert_true(_play.is_set_running(), "the next Auto set started")
	assert_string_contains(_view.get_status_text(), "Last set · Auto", "the last set's line stays")

## Turning Auto on mid-set ends the played set there: its reps stay paid.
func test_turning_auto_on_mid_set_ends_the_set() -> void:
	BodyRefiningManager.unlock_auto("stone_lifting")
	_lift(0, CENTRE)
	assert_true(_play.is_set_running())
	_toggle().button_pressed = true
	assert_false(_play.is_set_running(), "the played set ended")
	assert_eq(CharacterManager.get_stat_xp(AttributeType.STRENGTH), 6.0, "its rep stays paid")
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
