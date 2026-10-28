extends GutTest

## The dev panel's shell and its tabs: Ctrl+Shift+D and toggle() open and close the
## body; the open state, the body's place and the tab live on DevManager, so a panel
## built again (a session switch frees the main scene and the panel in it) comes back
## as it was; the body is dragged by its title bar and always stays on screen, also
## when a wider tab makes it grow, and shrinks back on a narrower tab; the title
## bar's picker sets DevManager's time speed, and the badge shows any speed but ×1,
## even with the panel closed. While saving is blocked a warning says so and why,
## open or closed, clear of the badge. The title reads against its bar. The panel
## hands its adventure view to the Adventure tab.
##
## The World tab travels through DevCommands and shows a refusal, and its zone-map
## checks start from ZoneManager. The Player tab's controls each reach their command
## and show why one refused. The Adventure tab shows only "No adventure running"
## until a run starts, follows the run, and shows the fight button only in a fight.
##
## Each panel is built inside a 1920x1080 Control, as MainView holds it in the
## game. Each test binds a fresh save and gives back what it changed: the save and
## the file it writes, DevManager's panel fields, the ×1 speed and the zone toggles.
## The warning tests block saving on a temp save a newer build wrote, which
## after_each() deletes with its lock.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DEV_PANEL_SCENE: PackedScene = preload("res://scenes/ui/dev_panel/dev_panel.tscn")
const ADVENTURE_VIEW_SCENE: PackedScene = preload("res://scenes/adventure/adventure_view/adventure_view.tscn")

## The size MainView gives the panel in the game.
const SCREEN_SIZE: Vector2 = Vector2(1920, 1080)

const ZONE_ID: String = "SpiritValley"
## The zone the map hides, which the travel picker still offers.
const HIDDEN_ZONE_ID: String = "TestZone"
## An action that is not idle: travel is refused while it runs.
const CYCLING_ACTION: String = "wilderness_cycling_action"

## A technique and an ability a fresh save has not unlocked: equipping either is refused
## until it is unlocked.
const TECHNIQUE: String = "smooth_flow"
const ABILITY: String = "empty_palm"

## The prefix of every [DEV] line in the player's log.
const DEV_LINE: String = "[color=magenta][DEV][/color] "

## The controls that act on a run, which the Adventure tab shows only while one runs.
const RUN_CONTROLS: Array[String] = ["ForceWin", "ExitVictory", "ExitDefeat", "ShowWholeMap", "RefillVitals"]

## A save a newer build wrote, which a session plays with saving blocked. The warning
## tests write it here; after_each() deletes it and its lock.
const NEWER_SAVE_PATH: String = "user://__test_dev_panel_newer.tres"
const NEWER_SAVE_TEXT: String = """[gd_resource type="Resource" script_class="SaveGameData" format=3]

[ext_resource type="Script" path="res://singletons/persistence_manager/save_game_data.gd" id="1_save"]

[resource]
script = ExtResource("1_save")
save_version = 99
gold = 42.0
"""

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_save_path: String
var _original_panel_open: bool
var _original_panel_position: Vector2
var _original_panel_tab: int
var _original_demo_zones: bool
var _original_hidden_zones: bool

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_save_path = PersistenceManager.save_path
	_original_panel_open = DevManager.panel_open
	_original_panel_position = DevManager.panel_position
	_original_panel_tab = DevManager.panel_tab
	_original_demo_zones = ZoneManager.are_demo_zones_visible()
	_original_hidden_zones = ZoneManager.are_hidden_zones_visible()
	_stop_actions()
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	# test_path_manager.gd leaves a one-entry ability index behind, and the Player tab
	# lists the catalog when it is built. Start from the real one.
	AbilityManager._build_catalog_index()
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
	# Also clears a block a warning test left, and gives up its temp save's lock.
	PersistenceManager.use_save(_original_save, _original_save_path)
	# Binding the original save again resumes its idle action, if it has one.
	# Stop it, so its tick timer does not run on into the next test.
	_stop_actions()
	for path: String in [NEWER_SAVE_PATH, SaveLock.lock_path_for(NEWER_SAVE_PATH)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Builds the panel inside a Control the size of the screen, as MainView holds it.
## `spare_tab` adds a plain tab after the real ones before the panel is ready, so a
## test can show a tab other than the first. `view` is the adventure view the panel
## is handed, as main_game.tscn hands it the real one.
func _add_panel(spare_tab: bool = false, view: AdventureView = null) -> DevPanel:
	var host := Control.new()
	host.size = SCREEN_SIZE
	add_child_autofree(host)
	var panel: DevPanel = DEV_PANEL_SCENE.instantiate()
	panel.adventure_view = view
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

## Opens the panel on the tab and returns the tab. A tab's controls are in view only
## while the panel is open and the tab is on top, and the tests of what a tab shows
## ask is_visible_in_tree().
func _open_tab(panel: DevPanel, tab_name: String) -> Control:
	panel.set_open(true)
	var tab: Control = panel.get_node("%" + tab_name)
	var tabs: TabContainer = panel.get_node("%Tabs")
	tabs.current_tab = tabs.get_tab_idx_from_control(tab)
	return tab

## Presses a button of the tab the way a click does: it says it was pressed.
func _press(tab: Node, button_name: String) -> void:
	(tab.get_node("%" + button_name) as BaseButton).pressed.emit()

## Types a value into a spin box of the tab.
func _enter(tab: Node, spin_name: String, value: float) -> void:
	(tab.get_node("%" + spin_name) as SpinBox).value = value

## Picks the item whose metadata is `metadata`, the way a player picks it from the list.
func _pick_item(option: OptionButton, metadata: Variant) -> void:
	for index: int in option.item_count:
		if option.get_item_metadata(index) == metadata:
			option.select(index)
			return
	fail_test("the picker has no item for %s" % str(metadata))

## A real AdventureView in the tree with no run on, as the main scene holds it: the
## panel is handed one. A run is `view.current_action_data` set, which is all
## is_adventure_running() asks, so no map is generated and nothing can fail its
## critical-path check; the dev commands' own tests play a real run
## (test_dev_adventure_commands.gd).
func _add_adventure_view() -> AdventureView:
	var view: AdventureView = ADVENTURE_VIEW_SCENE.instantiate()
	add_child_autofree(view)
	# AdventureTilemap makes its map generator with .new() and never frees it.
	autofree(view.adventure_tilemap.adventure_map_generator)
	return view

## The [DEV] lines the player's log got since watch_signals(LogManager).
func _dev_lines() -> Array[String]:
	var lines: Array[String] = []
	for index: int in maxi(get_signal_emit_count(LogManager, "message_logged"), 0):
		var line: String = get_signal_parameters(LogManager, "message_logged", index)[0]
		if line.begins_with(DEV_LINE):
			lines.append(line)
	return lines

## The WCAG contrast ratio of two colours: 1 for equal ones, 21 for black on white.
func _contrast(a: Color, b: Color) -> float:
	var light: float = maxf(_luminance(a), _luminance(b))
	var dark: float = minf(_luminance(a), _luminance(b))
	return (light + 0.05) / (dark + 0.05)

## The relative luminance of a colour (WCAG 2): its linear channels weighted by how
## bright the eye finds each.
func _luminance(color: Color) -> float:
	var linear: Color = color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b

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

## A wider tab makes the body grow from its top-left corner, which can push its right
## edge off the screen. The body is moved back on, and DevManager keeps where it
## stands, as it does for a drag. Back on a narrow tab, the body shrinks back to its
## own width where it was moved to.
func test_the_body_stays_on_screen_when_a_wider_tab_makes_it_grow() -> void:
	DevManager.panel_position = Vector2(SCREEN_SIZE.x - 600.0, 100.0)
	var panel: DevPanel = _add_panel(true)
	panel.set_open(true)
	var body: Control = panel.get_node("%Body")
	var tabs: TabContainer = panel.get_node("%Tabs")
	await wait_process_frames(2)
	assert_true(_body_on_screen(panel), "precondition: the body stands near the right edge, on screen")
	var narrow_tab: int = tabs.current_tab
	var narrow_width: float = body.size.x
	var wide: Control = tabs.get_node("Spare")
	wide.custom_minimum_size = Vector2(1000, 0)
	tabs.current_tab = tabs.get_tab_idx_from_control(wide)
	await wait_process_frames(2)
	assert_gt(body.size.x, 1000.0, "precondition: the wider tab made the body grow")
	assert_true(_body_on_screen(panel), "the body was moved back onto the screen")
	assert_eq(DevManager.panel_position, body.position, "and DevManager keeps where it stands")
	var moved_to: Vector2 = body.position
	tabs.current_tab = narrow_tab
	await wait_process_frames(2)
	assert_eq(body.size.x, narrow_width, "back on a narrow tab, the body shrinks back")
	assert_eq(body.position, moved_to, "and stays where it was moved to")
	assert_eq(DevManager.panel_position, moved_to, "which DevManager keeps")

## A wider tab that leaves the whole body on screen does not move it. The body shrinks
## back with the tab, also after a drag while it was wide: a body whose place is set
## while it is grown must not keep the grown size.
func test_a_body_the_growth_leaves_on_screen_shrinks_back_after_a_drag() -> void:
	var panel: DevPanel = _add_panel(true)
	panel.set_open(true)
	var body: Control = panel.get_node("%Body")
	var tabs: TabContainer = panel.get_node("%Tabs")
	await wait_process_frames(2)
	var start: Vector2 = body.position
	var narrow_tab: int = tabs.current_tab
	var narrow_width: float = body.size.x
	var wide: Control = tabs.get_node("Spare")
	wide.custom_minimum_size = Vector2(1000, 0)
	tabs.current_tab = tabs.get_tab_idx_from_control(wide)
	await wait_process_frames(2)
	assert_gt(body.size.x, 1000.0, "precondition: the wider tab made the body grow")
	assert_true(_body_on_screen(panel), "precondition: and it still stands on screen")
	assert_eq(body.position, start, "so it was not moved")
	assert_eq(DevManager.panel_position, start, "and DevManager keeps its place")
	_drag_title_bar(panel, start + Vector2(16, 8), start + Vector2(66, 108))
	assert_eq(body.position, start + Vector2(50, 100), "precondition: the wide body was dragged")
	tabs.current_tab = narrow_tab
	await wait_process_frames(2)
	assert_eq(body.size.x, narrow_width, "back on a narrow tab, the body shrinks back")
	assert_eq(body.position, start + Vector2(50, 100), "where it was dragged to")

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

func test_the_player_and_adventure_tabs_are_titled_and_come_before_world() -> void:
	var panel: DevPanel = _add_panel()
	var tabs: TabContainer = panel.get_node("%Tabs")
	var player: int = tabs.get_tab_idx_from_control(panel.get_node("%PlayerTab"))
	var adventure: int = tabs.get_tab_idx_from_control(panel.get_node("%AdventureTab"))
	var world: int = tabs.get_tab_idx_from_control(panel.get_node("%WorldTab"))
	assert_ne(player, -1, "precondition: the Player tab is one of the tabs")
	assert_ne(adventure, -1, "precondition: the Adventure tab is one of the tabs")
	assert_eq(tabs.get_tab_title(player), "Player")
	assert_eq(tabs.get_tab_title(adventure), "Adventure")
	assert_lt(player, adventure, "Player comes before Adventure")
	assert_lt(adventure, world, "and Adventure before World")
	assert_eq(world, tabs.get_tab_count() - 1, "World stays the last tab")

#-----------------------------------------------------------------------------
# TITLE
#-----------------------------------------------------------------------------

## The title keeps LabelSubheading's tan, which is faint on a tan bar (about 1.2 to 1)
## and reads on the dark brown panel the pixel theme gives its tooltips (about 4 to 1).
## 3 to 1 is what WCAG asks of large text, which the title's 24 px is.
func test_the_title_reads_against_its_bar() -> void:
	var panel: DevPanel = _add_panel()
	var title: Label = panel.get_node("%TitleBar/HBoxContainer/TitleLabel")
	var bar: StyleBoxFlat = (panel.get_node("%TitleBar") as Control).get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(bar, "precondition: the bar is a flat panel with a colour")
	if bar == null:
		return
	var ratio: float = _contrast(title.get_theme_color("font_color"), bar.bg_color)
	assert_gte(ratio, 3.0, "the title's contrast with its bar is %.2f to 1" % ratio)

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
# NOT SAVING
#-----------------------------------------------------------------------------

## Writes a save a newer build wrote and plays it, which blocks saving.
func _play_a_save_that_blocks_saving() -> void:
	var file := FileAccess.open(NEWER_SAVE_PATH, FileAccess.WRITE)
	file.store_string(NEWER_SAVE_TEXT)
	file.close()
	PersistenceManager.open_save_file(NEWER_SAVE_PATH)
	assert_true(PersistenceManager.is_save_blocked(), "precondition: a newer build's save blocks saving")

## Two runs of one checkout share its save, so a second run of the game, or a
## forgotten window, can leave a session that saves nothing. While saving is
## blocked the warning says so and why, with the panel closed too, as the badge
## does, and a session that can save hides it again.
func test_the_warning_shows_while_saving_is_blocked() -> void:
	var panel: DevPanel = _add_panel()
	var warning: Control = panel.get_node("%SaveWarning")
	var label: Label = panel.get_node("%SaveWarningLabel")
	assert_false(warning.visible, "precondition: nothing blocks saving yet")
	_play_a_save_that_blocks_saving()
	assert_false(panel.is_open(), "precondition: the panel is closed")
	assert_true(warning.is_visible_in_tree(), "the warning shows with the panel closed")
	assert_eq(label.text, "Not saving: " + PersistenceManager.get_block_reason(), "and names the reason")
	PersistenceManager.use_save(SaveGameData.new_current(), "")
	assert_false(warning.visible, "a session with nothing blocked hides it")

## A switch frees the panel and builds it again: the panel built shows the warning
## at once.
func test_a_panel_built_while_saving_is_blocked_shows_the_warning() -> void:
	_play_a_save_that_blocks_saving()
	var panel: DevPanel = _add_panel()
	assert_true((panel.get_node("%SaveWarning") as Control).is_visible_in_tree())

## A session in memory writes nothing by design, which is no block: the Saves tab
## says where it writes.
func test_a_session_in_memory_shows_no_warning() -> void:
	PersistenceManager.use_save(SaveGameData.new_current(), "")
	assert_true(PersistenceManager.is_in_memory(), "precondition: nothing writes the session")
	var panel: DevPanel = _add_panel()
	assert_false((panel.get_node("%SaveWarning") as Control).visible)

## A reason can be long (an unreadable save's names the path of its copy): the
## warning wraps it, stays on screen, never covers the badge, and lets the mouse
## through to the game.
func test_the_warning_wraps_clear_of_the_badge() -> void:
	assert_eq(DevManager.set_time_speed(10.0), "", "precondition: the badge shows")
	_play_a_save_that_blocks_saving()
	var panel: DevPanel = _add_panel()
	var warning: Control = panel.get_node("%SaveWarning")
	var label: Label = panel.get_node("%SaveWarningLabel")
	label.text = "Not saving: " + "a reason long enough to need more than one line ".repeat(5)
	await get_tree().process_frame
	assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "it wraps by word")
	assert_gt(label.custom_minimum_size.x, 0.0, "in a width of its own")
	assert_gt(label.get_line_count(), 1, "precondition: the reason takes several lines")
	var badge: Control = panel.get_node("%SpeedBadge")
	assert_true(badge.is_visible_in_tree(), "precondition: the badge shows at ×10")
	assert_false(warning.get_rect().intersects(badge.get_rect()), "the warning never covers the badge")
	assert_true(Rect2(Vector2.ZERO, panel.size).encloses(warning.get_rect()), "it stands wholly on screen")
	assert_eq(warning.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and lets clicks through to the game")

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

#-----------------------------------------------------------------------------
# PLAYER TAB
#-----------------------------------------------------------------------------

func test_player_tab_sets_gold() -> void:
	var player: Control = _open_tab(_add_panel(), "PlayerTab")
	_enter(player, "GoldSpin", 700.0)
	_press(player, "GoldSet")
	assert_eq(ResourceManager.get_gold(), 700.0)
	assert_false(player.get_node("%PlayerStatus").visible, "a command that works shows no refusal")

func test_player_tab_sets_madra() -> void:
	var player: Control = _open_tab(_add_panel(), "PlayerTab")
	_enter(player, "MadraSpin", 40.0)
	_press(player, "MadraSet")
	assert_eq(ResourceManager.get_madra(), 40.0)

## Reaching a level goes through real XP, and the stage line follows the core.
func test_player_tab_reaches_a_level() -> void:
	var player: Control = _open_tab(_add_panel(), "PlayerTab")
	var stage: Label = player.get_node("%StageLabel")
	assert_eq(stage.text, "Stage: Foundation · Core Density 0 / 100", "precondition: a fresh save")
	_enter(player, "LevelSpin", 42.0)
	_press(player, "LevelReach")
	assert_eq(CultivationManager.get_core_density_level(), 42.0)
	assert_eq(stage.text, "Stage: Foundation · Core Density 42 / 100")

func test_player_tab_advances_the_stage() -> void:
	var player: Control = _open_tab(_add_panel(), "PlayerTab")
	var stage: Label = player.get_node("%StageLabel")
	var status: Label = player.get_node("%PlayerStatus")
	_press(player, "AdvanceStage")
	assert_eq(CultivationManager.get_current_advancement_stage(), CultivationManager.AdvancementStage.COPPER)
	assert_eq(stage.text, "Stage: Copper · Core Density 0 / 100", "the line follows the new stage")
	assert_false(status.visible, "precondition: Foundation had a stage after it")
	_press(player, "AdvanceStage")
	assert_true(status.visible, "nothing follows Copper yet, so the second press is refused")
	assert_eq(status.text, DevCommands.advance_stage(), "with the command's reason")

func test_player_tab_adds_path_points() -> void:
	var player: Control = _open_tab(_add_panel(), "PlayerTab")
	_enter(player, "PointsSpin", 3.0)
	_press(player, "PointsAdd")
	assert_eq(PathManager.get_point_balance(), 3)

func test_player_tab_adds_to_the_picked_attribute() -> void:
	var player: Control = _open_tab(_add_panel(), "PlayerTab")
	var attributes: CharacterAttributesData = PersistenceManager.save_game_data.character_attributes
	var willpower: float = attributes.willpower
	var strength: float = attributes.strength
	_pick_item(player.get_node("%AttributeOption"), CharacterAttributesData.AttributeType.WILLPOWER)
	_enter(player, "AttributeSpin", 5.0)
	_press(player, "AttributeAdd")
	assert_eq(attributes.willpower, willpower + 5.0, "the picked attribute grows")
	assert_eq(attributes.strength, strength, "and no other does")

func test_player_tab_unlocks_and_equips_a_technique() -> void:
	var player: Control = _open_tab(_add_panel(), "PlayerTab")
	assert_false(CyclingManager.is_technique_unlocked(TECHNIQUE), "precondition: locked on a fresh save")
	_pick_item(player.get_node("%TechniqueOption"), TECHNIQUE)
	_press(player, "TechniqueUnlock")
	assert_true(CyclingManager.is_technique_unlocked(TECHNIQUE))
	assert_ne(CyclingManager.get_equipped_technique().id, TECHNIQUE, "unlocking does not equip")
	_press(player, "TechniqueEquip")
	assert_eq(CyclingManager.get_equipped_technique().id, TECHNIQUE)

func test_player_tab_unlocks_and_equips_an_ability_in_the_picked_slot() -> void:
	var player: Control = _open_tab(_add_panel(), "PlayerTab")
	assert_false(AbilityManager.is_ability_unlocked(ABILITY), "precondition: locked on a fresh save")
	_pick_item(player.get_node("%AbilityOption"), ABILITY)
	_press(player, "AbilityUnlock")
	assert_true(AbilityManager.is_ability_unlocked(ABILITY))
	assert_false(AbilityManager.is_ability_equipped(ABILITY), "unlocking does not equip")
	_enter(player, "AbilitySlotSpin", 3.0)
	_press(player, "AbilityEquip")
	assert_eq(AbilityManager.get_ability_at_slot(2), ABILITY, "slot 3 is the third, index 2")

func test_player_tab_unlocks_every_technique_and_ability() -> void:
	var player: Control = _open_tab(_add_panel(), "PlayerTab")
	assert_false(CyclingManager.is_technique_unlocked(TECHNIQUE), "precondition: a technique is locked")
	assert_false(AbilityManager.is_ability_unlocked(ABILITY), "precondition: an ability is locked")
	_press(player, "UnlockAllTechniques")
	_press(player, "UnlockAllAbilities")
	for technique: CyclingTechniqueData in CyclingManager.get_all_techniques():
		assert_true(CyclingManager.is_technique_unlocked(technique.id), technique.id)
	for ability: AbilityData in AbilityManager.get_all_abilities():
		assert_true(AbilityManager.is_ability_unlocked(ability.ability_id), ability.ability_id)

func test_player_tab_offers_every_attribute_technique_and_ability() -> void:
	var player: Node = _add_panel().get_node("%PlayerTab")
	assert_eq(_item_texts(player.get_node("%AttributeOption")), [
		"Strength", "Body", "Agility", "Spirit", "Foundation", "Control", "Resilience", "Willpower",
	] as Array[String], "the eight attributes")
	var technique_ids: Array[String] = []
	for technique: CyclingTechniqueData in CyclingManager.get_all_techniques():
		technique_ids.append(technique.id)
	assert_eq(_item_metadata(player.get_node("%TechniqueOption")), technique_ids, "every technique")
	var ability_ids: Array[String] = []
	for ability: AbilityData in AbilityManager.get_all_abilities():
		ability_ids.append(ability.ability_id)
	assert_eq(_item_metadata(player.get_node("%AbilityOption")), ability_ids, "every ability")
	assert_has(technique_ids, TECHNIQUE, "precondition: the catalog has the technique the tests use")
	assert_has(ability_ids, ABILITY, "and the ability")

## An ability the save has not unlocked is refused. The reason shows until a command
## works.
func test_player_tab_shows_a_refusal() -> void:
	var player: Control = _open_tab(_add_panel(), "PlayerTab")
	var status: Label = player.get_node("%PlayerStatus")
	assert_false(status.is_visible_in_tree(), "precondition: nothing has been refused yet")
	_pick_item(player.get_node("%AbilityOption"), ABILITY)
	_press(player, "AbilityEquip")
	assert_true(status.is_visible_in_tree(), "a refusal shows")
	assert_eq(status.text, DevCommands.equip_ability(ABILITY, 1), "and it is the command's reason")
	assert_false(AbilityManager.is_ability_unlocked(ABILITY), "equipping never unlocks")
	_press(player, "AbilityUnlock")
	assert_false(status.visible, "a command that works clears the refusal")

#-----------------------------------------------------------------------------
# ADVENTURE TAB
#-----------------------------------------------------------------------------

func test_adventure_tab_hides_without_a_run() -> void:
	var adventure: Control = _open_tab(_add_panel(false, _add_adventure_view()), "AdventureTab")
	var no_run: Label = adventure.get_node("%NoRunLabel")
	assert_true(no_run.is_visible_in_tree(), "the tab says no run is on")
	assert_eq(no_run.text, "No adventure running")
	for control_name: String in RUN_CONTROLS + ["AdventureStatus"]:
		assert_false((adventure.get_node("%" + control_name) as Control).is_visible_in_tree(), "%s waits for a run" % control_name)

## The tab follows the run through ActionManager's two signals, as the view does.
func test_adventure_tab_follows_the_run() -> void:
	var adventure: Control = _open_tab(_add_panel(), "AdventureTab")
	var no_run: Label = adventure.get_node("%NoRunLabel")
	ActionManager.start_adventure.emit(AdventureActionData.new(), 50.0)
	assert_false(no_run.is_visible_in_tree(), "a run began, so the tab no longer says none is on")
	for control_name: String in ["ExitVictory", "ExitDefeat", "ShowWholeMap", "RefillVitals"]:
		assert_true((adventure.get_node("%" + control_name) as Control).is_visible_in_tree(), "%s shows during a run" % control_name)
	assert_false((adventure.get_node("%ForceWin") as Control).is_visible_in_tree(), "though no fight is on, so there is nothing to force-win")
	ActionManager.stop_adventure.emit()
	assert_true(no_run.is_visible_in_tree(), "the run ended")
	for control_name: String in RUN_CONTROLS:
		assert_false((adventure.get_node("%" + control_name) as Control).is_visible_in_tree(), "%s goes with it" % control_name)

## A refusal is about the run it was made in: the next run starts without it.
func test_adventure_tab_forgets_a_refusal_when_the_run_ends() -> void:
	var adventure: Control = _open_tab(_add_panel(), "AdventureTab")
	var status: Label = adventure.get_node("%AdventureStatus")
	ActionManager.start_adventure.emit(AdventureActionData.new(), 50.0)
	_press(adventure, "ForceWin")
	assert_true(status.visible, "precondition: a refusal shows")
	ActionManager.stop_adventure.emit()
	ActionManager.start_adventure.emit(AdventureActionData.new(), 50.0)
	assert_false(status.visible, "the next run starts without it")
	ActionManager.stop_adventure.emit()

## The fight button polls the view's is_in_combat while the tab is in view.
func test_adventure_tab_shows_force_win_only_in_a_fight() -> void:
	var view: AdventureView = _add_adventure_view()
	view.current_action_data = AdventureActionData.new()
	var adventure: Control = _open_tab(_add_panel(false, view), "AdventureTab")
	var force_win: Button = adventure.get_node("%ForceWin")
	await wait_process_frames(2)
	assert_false(force_win.is_visible_in_tree(), "no fight is on, so there is nothing to force-win")
	view.is_in_combat = true
	await wait_process_frames(2)
	assert_true(force_win.is_visible_in_tree(), "a fight began")
	view.is_in_combat = false
	await wait_process_frames(2)
	assert_false(force_win.is_visible_in_tree(), "and ended")

## Both exits reach the command with the view: it logs an exit only for a view that
## has a run. The run is not played here: test_dev_adventure_commands.gd plays it.
func test_adventure_tab_exits_the_run_as_victory_and_as_defeat() -> void:
	var view: AdventureView = _add_adventure_view()
	view.current_action_data = AdventureActionData.new()
	var adventure: Control = _open_tab(_add_panel(false, view), "AdventureTab")
	watch_signals(LogManager)
	_press(adventure, "ExitVictory")
	_press(adventure, "ExitDefeat")
	assert_eq(_dev_lines(), [
		DEV_LINE + "Ended the adventure as a victory",
		DEV_LINE + "Ended the adventure as a defeat",
	] as Array[String])

## What a command refuses shows until one works: no fight is on, and no adventure
## action is the current one for the vitals to refill in.
func test_adventure_tab_shows_a_refusal() -> void:
	var view: AdventureView = _add_adventure_view()
	view.current_action_data = AdventureActionData.new()
	var adventure: Control = _open_tab(_add_panel(false, view), "AdventureTab")
	var status: Label = adventure.get_node("%AdventureStatus")
	assert_false(status.is_visible_in_tree(), "precondition: nothing has been refused yet")
	_press(adventure, "ForceWin")
	assert_true(status.is_visible_in_tree(), "a refusal shows")
	assert_eq(status.text, DevCommands.force_win_fight(view), "and it is the command's reason")
	_press(adventure, "RefillVitals")
	assert_eq(status.text, DevCommands.refill_vitals(), "the next refusal replaces it")
	_press(adventure, "ExitDefeat")
	assert_false(status.visible, "a command that works clears the refusal")

## Show whole map is a toggle on the view, not a command, so the tab writes its [DEV]
## line itself.
func test_adventure_tab_shows_the_whole_map_on_request() -> void:
	var view: AdventureView = _add_adventure_view()
	view.current_action_data = AdventureActionData.new()
	var adventure: Control = _open_tab(_add_panel(false, view), "AdventureTab")
	var check: CheckButton = adventure.get_node("%ShowWholeMap")
	assert_false(check.button_pressed, "precondition: the map shows as the player sees it")
	watch_signals(LogManager)
	check.button_pressed = true
	assert_true(view.adventure_tilemap.is_dev_reveal_all(), "the check lifts the fog off the whole map")
	check.button_pressed = false
	assert_false(view.adventure_tilemap.is_dev_reveal_all(), "and puts it back")
	assert_eq(_dev_lines(), [
		DEV_LINE + "Show Whole Map: ON",
		DEV_LINE + "Show Whole Map: OFF",
	] as Array[String])

## main_game.tscn sets the panel's adventure_view, and the panel's _ready() hands it to
## the Adventure tab. The tab then knows the view's run, reads the whole-map state off
## its tilemap (the flag outlasts a run and a panel), and the commands it calls get
## that view: an exit is logged only for a view that has a run.
func test_the_panel_hands_its_adventure_view_to_the_adventure_tab() -> void:
	var view: AdventureView = _add_adventure_view()
	view.current_action_data = AdventureActionData.new()
	view.set_show_whole_map(true)
	watch_signals(LogManager)
	var adventure: Control = _open_tab(_add_panel(false, view), "AdventureTab")
	assert_false((adventure.get_node("%NoRunLabel") as Control).is_visible_in_tree(), "the tab knows the view's run")
	assert_true((adventure.get_node("%ShowWholeMap") as CheckButton).button_pressed, "and the whole map the view shows")
	assert_eq(_dev_lines().size(), 0, "and building the tab logs nothing")
	_press(adventure, "ExitVictory")
	assert_eq(_dev_lines(), [DEV_LINE + "Ended the adventure as a victory"] as Array[String], "the exit command got the view, which has a run to end")
