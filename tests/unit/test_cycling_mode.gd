extends GutTest

## Unit tests for cycling mode on the main view (spec: Behaviour › Opening and
## closing; Implementation notes › MainView and CyclingViewState). MainView's
## set_cycling_mode() turns the zone view's furniture over to the board: the
## chest lists the techniques, the dock hides and the map's SubViewport takes no
## input. CyclingViewState switches it on in enter() and off in exit(), shows
## the board, blocks the full log as a menu book does, and leaves the Goals and
## log boards where the zone view put them. The MainView is never added to the
## tree: each test fills in the views it needs, as test_view_state_hud_positions.gd
## does, with the real chest and the real log (the techniques mode and the
## full-log block can only be read there) and plain stand-ins for the rest.
## main_game.tscn is only instanced, never added to the tree: its SaveTimer
## would write the real save.

const MAIN_GAME_SCENE_PATH: String = "res://scenes/main/main_game/main_game.tscn"
const ZONE_PANEL_SCENE: PackedScene = preload("res://scenes/zones/zone_panel/zone_panel.tscn")
const LOG_WINDOW_SCENE: PackedScene = preload("res://scenes/ui/log_window/log_window.tscn")

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

## Counts the events its viewport hands it, as the map's tile layer reads a
## press in _input.
class InputCounter:
	extends Node

	var count: int = 0

	func _input(_event: InputEvent) -> void:
		count += 1

var _main_view: MainView = null
var _state: CyclingViewState = null
var _log: LogWindow = null

## A zone view's worth of furniture on a MainView that never enters the tree:
## the real chest and log, plain Controls for the dock, the board, Goals, and a
## bare SubViewport for the map. The board starts hidden, as in main_game.tscn.
func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_log = add_child_autofree(LOG_WINDOW_SCENE.instantiate()) as LogWindow
	_main_view = autofree(MainView.new())
	_main_view.state_stack = []
	_main_view.zone_panel = add_child_autofree(ZONE_PANEL_SCENE.instantiate())
	_main_view.dock = autofree(Control.new())
	_main_view.zone_map_viewport = autofree(SubViewport.new())
	_main_view.cycling_view = autofree(Control.new())
	_main_view.cycling_view.visible = false
	_main_view.goals_panel = autofree(Control.new())
	_main_view.log_window = _log
	_state = autofree(CyclingViewState.new())
	_state.scene_root = _main_view

## A left press, as the SubViewportContainer pushes it into the map.
func _left_press() -> InputEventMouseButton:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100.0, 100.0)
	press.global_position = press.position
	return press

#-----------------------------------------------------------------------------
# THE SWITCH
#-----------------------------------------------------------------------------

func test_cycling_mode_on_and_off() -> void:
	_main_view.set_cycling_mode(true)
	assert_true(_main_view.zone_panel.is_techniques_mode(), "the chest lists the techniques")
	assert_false(_main_view.dock.visible, "the dock hides")
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "the map takes no input")
	_main_view.set_cycling_mode(false)
	assert_false(_main_view.zone_panel.is_techniques_mode(), "the chest lists the activities again")
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "the map takes input again")

## The view-state tests run cycling on a MainView with none of the zone view's
## furniture, and each piece is switched whether or not the others exist.
func test_cycling_mode_hides_the_dock_when_the_chest_and_map_are_missing() -> void:
	var bare: MainView = autofree(MainView.new())
	bare.dock = _main_view.dock
	bare.set_cycling_mode(true)
	assert_false(bare.dock.visible)

func test_cycling_mode_stops_the_map_when_the_chest_and_dock_are_missing() -> void:
	var bare: MainView = autofree(MainView.new())
	bare.zone_map_viewport = _main_view.zone_map_viewport
	bare.set_cycling_mode(true)
	assert_true(bare.zone_map_viewport.gui_disable_input)

func test_cycling_mode_turns_the_chest_when_the_dock_and_map_are_missing() -> void:
	var bare: MainView = autofree(MainView.new())
	bare.zone_panel = _main_view.zone_panel
	bare.set_cycling_mode(true)
	assert_true(bare.zone_panel.is_techniques_mode())

## The switch leans on the engine: a SubViewportContainer pushes the press it
## gets into its SubViewport with push_input(), and a viewport with its input
## disabled drops what it is pushed. If this fails, switch the map off through
## the container's mouse_filter (IGNORE) instead, in set_cycling_mode() and here.
func test_a_disabled_map_viewport_takes_no_clicks() -> void:
	var viewport: SubViewport = SubViewport.new()
	var counter: InputCounter = InputCounter.new()
	viewport.add_child(counter)
	add_child_autofree(viewport)
	viewport.gui_disable_input = true
	viewport.push_input(_left_press())
	assert_eq(counter.count, 0, "a viewport with its input off takes no press")
	viewport.gui_disable_input = false
	viewport.push_input(_left_press())
	assert_eq(counter.count, 1, "the same press reaches it once input is back on")

#-----------------------------------------------------------------------------
# THE STATE
#-----------------------------------------------------------------------------

func test_cycling_state_turns_the_zone_view_over_and_back() -> void:
	_state.enter()
	assert_true(_main_view.zone_panel.is_techniques_mode(), "entering lists the techniques")
	assert_false(_main_view.dock.visible, "entering hides the dock")
	assert_true(_main_view.zone_map_viewport.gui_disable_input, "entering stops the map")
	_state.exit()
	assert_false(_main_view.zone_panel.is_techniques_mode(), "leaving lists the activities")
	assert_true(_main_view.dock.visible, "leaving brings the dock back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "leaving gives the map its input back")

func test_cycling_state_keeps_the_boards() -> void:
	_state.enter()
	assert_true(_main_view.goals_panel.visible, "Goals stays where the zone view put it")
	assert_true(_main_view.log_window.visible, "the log stays")
	assert_true(_main_view.cycling_view.visible, "the board shows")
	_log.toggle_full_log()
	assert_false(_log.is_full_log_open(), "the full log stays shut while cycling")
	_state.exit()
	assert_true(_main_view.goals_panel.visible, "Goals still shows")
	assert_true(_main_view.log_window.visible, "the log still shows")
	assert_false(_main_view.cycling_view.visible, "the board hides")
	_log.toggle_full_log()
	assert_true(_log.is_full_log_open(), "the full log opens again")

func test_start_cycling_twice_pushes_once() -> void:
	_state._on_start_cycling(null)
	_state._on_start_cycling(null)
	assert_eq(_main_view.state_stack.size(), 1, "a second push would stay on the stack after the close")
	assert_same(_main_view.state_stack.back(), _state)

func test_stop_cycling_undoes_start_cycling() -> void:
	_state._on_start_cycling(null)
	_state._on_stop_cycling()
	assert_true(_main_view.state_stack.is_empty(), "the state left the stack")
	assert_false(_main_view.cycling_view.visible, "the board is hidden")
	assert_false(_main_view.zone_panel.is_techniques_mode(), "the chest lists the activities")
	assert_true(_main_view.dock.visible, "the dock is back")
	assert_false(_main_view.zone_map_viewport.gui_disable_input, "the map takes input")

#-----------------------------------------------------------------------------
# THE CABINET HAND-OFF
#-----------------------------------------------------------------------------

## MainView._ready() hands the cultivator cabinet to the board through this
## helper. Without it the board has no cabinet, and no Madra or XP pellet ever
## flies. The cabinet and the board are script-only instances that never enter
## the tree, so neither runs its _ready().
func test_the_cabinet_is_handed_to_the_cycling_view() -> void:
	var cabinet: CultivatorPlate = autofree(CultivatorPlate.new())
	var board: CyclingView = autofree(CyclingView.new())
	_main_view.cultivator_plate = cabinet
	_main_view.cycling_view = board
	_main_view._hand_cabinet_to_cycling_view()
	assert_same(board.cultivator_plate, cabinet, "the board's pellets fly into the cabinet")

## The view-state tests stand a plain Control in for the board (the fixture's
## cycling_view is one): it has nowhere to keep a cabinet, so it is skipped.
func test_handing_over_the_cabinet_skips_a_plain_control() -> void:
	_main_view.cultivator_plate = autofree(CultivatorPlate.new())
	_main_view._hand_cabinet_to_cycling_view()
	assert_engine_error_count(0, "a view that is not a CyclingView is left alone, not cast and assigned to")

#-----------------------------------------------------------------------------
# MAIN_GAME.TSCN
#-----------------------------------------------------------------------------

## MainView finds the cabinet, the chest, the dock and the map's viewport by
## unique name. set_cycling_mode() skips a missing one without a word, so a
## scene that lost a name would quietly stop turning that piece over.
func test_main_game_names_the_zone_furniture_for_main_view() -> void:
	var game: Node = autofree((load(MAIN_GAME_SCENE_PATH) as PackedScene).instantiate())
	var main_view: Node = game.get_node("MainView")
	var zone_view: Node = main_view.get_node("%ZoneView")
	assert_same(main_view.get_node_or_null("%CultivatorPlate"), zone_view.get_node("CultivatorPlate"), "the cabinet")
	assert_same(main_view.get_node_or_null("%ZonePanel"), zone_view.get_node("ZonePanel"), "the chest")
	assert_same(main_view.get_node_or_null("%Dock"), zone_view.get_node("Dock"), "the dock")
	assert_same(main_view.get_node_or_null("%SubViewport"), zone_view.get_node("SubViewportContainer/SubViewport"), "the map's viewport")
