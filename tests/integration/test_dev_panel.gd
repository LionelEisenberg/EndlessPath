extends GutTest

## The dev panel's shell and its World tab: Ctrl+Shift+D and toggle() open and
## close the body; the open state, the body's place and the tab live on DevManager,
## so a panel built again (a session switch frees the main scene and the panel in
## it) comes back as it was; the body is dragged by its title bar and always stays
## on screen; the title bar's picker sets DevManager's time speed, and the badge
## shows any speed but ×1, even with the panel closed. The World tab travels through
## DevCommands and shows a refusal, and its zone-map checks start from ZoneManager.
##
## Each panel is built inside a 1920x1080 Control, as MainView holds it in the
## game. Each test binds a fresh save and gives back what it changed: the save,
## DevManager's panel fields, the ×1 speed and the zone toggles.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DEV_PANEL_SCENE: PackedScene = preload("res://scenes/ui/dev_panel/dev_panel.tscn")

## The size MainView gives the panel in the game.
const SCREEN_SIZE: Vector2 = Vector2(1920, 1080)

const ZONE_ID: String = "SpiritValley"
## The zone the map hides, which the travel picker still offers.
const HIDDEN_ZONE_ID: String = "TestZone"
## An action that is not idle: travel is refused while it runs.
const CYCLING_ACTION: String = "wilderness_cycling_action"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_panel_open: bool
var _original_panel_position: Vector2
var _original_panel_tab: int
var _original_demo_zones: bool
var _original_hidden_zones: bool

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_panel_open = DevManager.panel_open
	_original_panel_position = DevManager.panel_position
	_original_panel_tab = DevManager.panel_tab
	_original_demo_zones = ZoneManager.are_demo_zones_visible()
	_original_hidden_zones = ZoneManager.are_hidden_zones_visible()
	_stop_actions()
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	DevManager.panel_open = false
	DevManager.panel_position = Vector2(24, 24)
	DevManager.panel_tab = 0
	ZoneManager.set_demo_zones_visible(false)
	ZoneManager.set_hidden_zones_visible(false)

func after_each() -> void:
	_stop_actions()
	GameSpeed.set_base_scale(1.0)
	DevManager.panel_open = _original_panel_open
	DevManager.panel_position = _original_panel_position
	DevManager.panel_tab = _original_panel_tab
	ZoneManager.set_demo_zones_visible(_original_demo_zones)
	ZoneManager.set_hidden_zones_visible(_original_hidden_zones)
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# Binding the original save again resumes its idle action, if it has one.
	# Stop it, so its tick timer does not run on into the next test.
	_stop_actions()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Builds the panel inside a Control the size of the screen, as MainView holds it.
## `spare_tab` adds a plain tab after the real ones before the panel is ready, so a
## test can show a tab other than the first.
func _add_panel(spare_tab: bool = false) -> DevPanel:
	var host := Control.new()
	host.size = SCREEN_SIZE
	add_child_autofree(host)
	var panel: DevPanel = DEV_PANEL_SCENE.instantiate()
	if spare_tab:
		var spare := Control.new()
		spare.name = "Spare"
		panel.get_node("%Tabs").add_child(spare)
	host.add_child(panel)
	return panel

## Drags the panel's title bar from one point of the screen to another: a left
## press, a move with the button held, and the release.
func _drag_title_bar(panel: DevPanel, from: Vector2, to: Vector2) -> void:
	var title_bar: Control = panel.get_node("%TitleBar")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = from
	title_bar.gui_input.emit(press)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.global_position = to
	title_bar.gui_input.emit(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.global_position = to
	title_bar.gui_input.emit(release)

## A key press of D with the modifiers given.
func _d_key(ctrl: bool, shift: bool, echo: bool = false) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_D
	key.pressed = true
	key.ctrl_pressed = ctrl
	key.shift_pressed = shift
	key.echo = echo
	return key

## The picker's item texts, in order.
func _item_texts(option: OptionButton) -> Array[String]:
	var texts: Array[String] = []
	for index: int in option.item_count:
		texts.append(option.get_item_text(index))
	return texts

## The picker's item metadata, in order, as strings.
func _item_metadata(option: OptionButton) -> Array[String]:
	var values: Array[String] = []
	for index: int in option.item_count:
		values.append(str(option.get_item_metadata(index)))
	return values

## Picks the item the way a player does: it shows as selected, and the picker
## says so.
func _pick(option: OptionButton, index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)

## True when the body stands wholly inside the panel, which covers the screen.
func _body_on_screen(panel: DevPanel) -> bool:
	var body: Control = panel.get_node("%Body")
	return Rect2(Vector2.ZERO, panel.size).encloses(body.get_rect())

func _stop_actions() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# OPENING AND CLOSING
#-----------------------------------------------------------------------------

func test_toggle_opens_and_closes_the_body() -> void:
	var panel: DevPanel = _add_panel()
	var body: Control = panel.get_node("%Body")
	assert_false(panel.is_open(), "precondition: the panel starts closed")
	assert_false(body.visible, "with its body hidden")
	panel.toggle()
	assert_true(panel.is_open(), "toggle opens it")
	assert_true(body.visible, "its body shows")
	assert_true(DevManager.panel_open, "and DevManager keeps it open")
	panel.toggle()
	assert_false(panel.is_open(), "toggle closes it again")
	assert_false(body.visible, "its body hides")
	assert_false(DevManager.panel_open, "and DevManager keeps it closed")
	assert_true(panel.visible, "the panel itself stays, for the speed badge")
	panel.set_open(true)
	(panel.get_node("%CloseButton") as Button).pressed.emit()
	assert_false(panel.is_open(), "the close button closes it too")

## The panel covers the screen, so it must let the game have the mouse: only the
## body takes it.
func test_only_the_body_takes_the_mouse() -> void:
	var panel: DevPanel = _add_panel()
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the panel lets clicks through to the game")
	assert_eq((panel.get_node("%SpeedBadge") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "and so does the badge")
	assert_eq((panel.get_node("%Body") as Control).mouse_filter, Control.MOUSE_FILTER_STOP, "the body keeps them")

## Ctrl+Shift+D, pushed through the viewport to the panel's _input(), opens and
## closes it, and nothing after the panel gets the key. The near misses go to
## _input() straight, so a key the panel leaves alone reaches nothing else.
func test_ctrl_shift_d_toggles() -> void:
	var panel: DevPanel = _add_panel()
	var viewport: Viewport = panel.get_viewport()
	viewport.push_input(_d_key(true, true))
	assert_true(panel.is_open(), "Ctrl+Shift+D opens the panel")
	assert_true(viewport.is_input_handled(), "and marks the key handled")
	viewport.push_input(_d_key(true, true))
	assert_false(panel.is_open(), "and closes it")
	panel._input(_d_key(true, false))
	panel._input(_d_key(false, true))
	panel._input(_d_key(true, true, true))
	assert_false(panel.is_open(), "Ctrl+D, Shift+D and a held key's echo leave it alone")

#-----------------------------------------------------------------------------
# PLACE AND TAB
#-----------------------------------------------------------------------------

func test_dragging_the_title_bar_moves_the_body() -> void:
	var panel: DevPanel = _add_panel()
	panel.set_open(true)
	var body: Control = panel.get_node("%Body")
	var start: Vector2 = body.position
	_drag_title_bar(panel, start + Vector2(16, 8), start + Vector2(216, 108))
	assert_eq(body.position, start + Vector2(200, 100), "the body follows the pointer")
	assert_eq(DevManager.panel_position, body.position, "and DevManager keeps its place")

## A place kept at a larger window, or a drag past an edge, never leaves any of the
## body, its title bar included, off screen.
func test_the_body_stays_on_screen() -> void:
	DevManager.panel_position = Vector2(5000, -300)
	var panel: DevPanel = _add_panel()
	panel.set_open(true)
	assert_true(_body_on_screen(panel), "a place off screen is brought back on it")
	var body: Control = panel.get_node("%Body")
	_drag_title_bar(panel, body.position + Vector2(16, 8), Vector2(-400, 9000))
	assert_true(_body_on_screen(panel), "a drag past an edge stops at the edge")
	assert_eq(body.position, Vector2(0, SCREEN_SIZE.y - body.size.y), "in the bottom left corner")
	assert_eq(DevManager.panel_position, body.position, "which DevManager keeps")

func test_open_state_position_and_tab_survive_a_rebuild() -> void:
	var panel: DevPanel = _add_panel(true)
	panel.toggle()
	var body: Control = panel.get_node("%Body")
	_drag_title_bar(panel, body.position + Vector2(16, 8), body.position + Vector2(316, 208))
	var kept_position: Vector2 = body.position
	var tabs: TabContainer = panel.get_node("%Tabs")
	var spare_index: int = tabs.get_tab_count() - 1
	tabs.current_tab = spare_index
	assert_eq(DevManager.panel_tab, spare_index, "precondition: DevManager keeps the tab")
	panel.free()

	var rebuilt: DevPanel = _add_panel(true)
	assert_true(rebuilt.is_open(), "the panel comes back open")
	assert_eq((rebuilt.get_node("%Body") as Control).position, kept_position, "where it was dragged to")
	assert_eq((rebuilt.get_node("%Tabs") as TabContainer).current_tab, spare_index, "on the tab it showed")

func test_the_world_tab_is_titled_world() -> void:
	var panel: DevPanel = _add_panel()
	var tabs: TabContainer = panel.get_node("%Tabs")
	var index: int = tabs.get_tab_idx_from_control(panel.get_node("%WorldTab"))
	assert_ne(index, -1, "precondition: the World tab is one of the tabs")
	assert_eq(tabs.get_tab_title(index), "World")

#-----------------------------------------------------------------------------
# TIME SPEED
#-----------------------------------------------------------------------------

func test_speed_option_sets_the_speed() -> void:
	var panel: DevPanel = _add_panel()
	var option: OptionButton = panel.get_node("%SpeedOption")
	assert_eq(_item_texts(option), ["×1", "×2", "×5", "×10"] as Array[String], "the picker offers DevManager's speeds")
	assert_eq(option.get_item_text(option.selected), "×1", "precondition: the game runs at ×1")
	_pick(option, _item_texts(option).find("×5"))
	assert_eq(DevManager.get_time_speed(), 5.0, "picking ×5 sets the time speed")
	assert_eq(Engine.time_scale, 5.0, "and the engine runs at it")

## The badge shows the speed whenever it is not ×1, with the panel open or closed.
## A panel built at ×10 shows it at once, and both the badge and the picker follow
## a speed set anywhere.
func test_badge_shows_only_above_x1() -> void:
	assert_eq(DevManager.set_time_speed(10.0), "", "precondition: the game runs at ×10")
	var panel: DevPanel = _add_panel()
	var badge: Label = panel.get_node("%SpeedBadge")
	var option: OptionButton = panel.get_node("%SpeedOption")
	assert_false(panel.is_open(), "precondition: the panel is closed")
	assert_true(badge.is_visible_in_tree(), "a panel built at ×10 shows the badge, closed")
	assert_eq(badge.text, "×10")
	assert_eq(option.get_item_text(option.selected), "×10", "and its picker reads ×10")
	DevManager.set_time_speed(2.0)
	assert_true(badge.is_visible_in_tree(), "the badge stays at ×2")
	assert_eq(badge.text, "×2", "and reads it")
	assert_eq(option.get_item_text(option.selected), "×2", "and so does the picker")
	DevManager.set_time_speed(1.0)
	assert_false(badge.visible, "at ×1 the badge hides")
	assert_eq(option.get_item_text(option.selected), "×1")

#-----------------------------------------------------------------------------
# WORLD TAB
#-----------------------------------------------------------------------------

## The checks take ZoneManager's state when the tab is built, without toggling,
## so building it logs nothing. The toggles live on ZoneManager and outlast the
## panel, so a panel built again shows them.
func test_world_checkboxes_follow_zone_manager() -> void:
	var panel: DevPanel = _add_panel()
	ZoneManager.set_hidden_zones_visible(true)
	panel.free()
	watch_signals(LogManager)
	var world: Node = _add_panel().get_node("%WorldTab")
	assert_true((world.get_node("%HiddenZonesCheck") as CheckButton).button_pressed, "the hidden zones show, so its check is pressed")
	assert_false((world.get_node("%DemoZonesCheck") as CheckButton).button_pressed, "the demo zones do not")
	assert_signal_not_emitted(LogManager, "message_logged", "and building the tab logs nothing")

func test_travel_shows_a_refusal() -> void:
	var world: Node = _add_panel().get_node("%WorldTab")
	var option: OptionButton = world.get_node("%TravelOption")
	var zone_ids: Array[String] = []
	for zone: ZoneData in ZoneManager.get_all_zones():
		zone_ids.append(zone.zone_id)
	assert_eq(_item_metadata(option), zone_ids, "the picker offers every zone")
	assert_has(zone_ids, HIDDEN_ZONE_ID, "the hidden one included")
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ACTION))
	assert_eq(ActionManager.get_current_action().action_id, CYCLING_ACTION, "precondition: cycling runs")
	option.select(zone_ids.find(HIDDEN_ZONE_ID))
	var travel_button: Button = world.get_node("%TravelButton")
	var status: Label = world.get_node("%TravelStatus")
	travel_button.pressed.emit()
	assert_true(status.visible, "a refusal shows")
	assert_eq(status.text, DevCommands.travel_to_zone(HIDDEN_ZONE_ID), "and it is the command's reason")
	assert_eq(ZoneManager.get_current_zone().zone_id, ZONE_ID, "the player stays")
	_stop_actions()
	travel_button.pressed.emit()
	assert_eq(ZoneManager.get_current_zone().zone_id, HIDDEN_ZONE_ID, "with nothing running, the player travels")
	assert_false(status.visible, "and the refusal goes")
