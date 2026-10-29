extends GutTest

## The dev panel's shell and its tabs: Ctrl+Shift+D and toggle() open and close the
## body, and only the body takes the mouse; the open state, the body's place and the
## tab live on DevManager, so a panel built again (a session switch frees the main
## scene and the panel in it) comes back as it was; the body is dragged by its title
## bar; the title bar's picker sets DevManager's time speed, and the badge shows any
## speed but ×1, even with the panel closed. While saving is blocked a warning says so
## and why, open or closed, and wraps a long reason. The panel hands its adventure view
## to the Adventure tab.
##
## The World tab travels through DevCommands and shows a refusal, and its zone-map
## checks start from ZoneManager. The Player tab reaches a level through its command
## and shows why a command refused. The Adventure tab follows the run and shows why a
## command refused.
##
## Each panel is built inside a 1920x1080 Control, as MainView holds it in the
## game. Each test binds a fresh save and gives back what it changed: the save and
## the file it writes, DevManager's panel fields, the ×1 speed and the zone toggles.
## The warning tests block saving on a temp save a newer build wrote, which
## after_each() deletes.

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

## An ability a fresh save has not unlocked: equipping it is refused until it is
## unlocked.
const ABILITY: String = "empty_palm"

## The prefix of every [DEV] line in the player's log.
const DEV_LINE: String = "[color=magenta][DEV][/color] "

## The controls that act on a run, which the Adventure tab shows only while one runs.
const RUN_CONTROLS: Array[String] = ["ForceWin", "ExitVictory", "ExitDefeat", "ShowWholeMap", "RefillVitals"]

## A save a newer build wrote, which a session plays with saving blocked. The warning
## tests write it here; after_each() deletes it.
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
	# Also clears a block a warning test left.
	PersistenceManager.use_save(_original_save, _original_save_path)
	# Binding the original save again resumes its idle action, if it has one.
	# Stop it, so its tick timer does not run on into the next test.
	_stop_actions()
	if FileAccess.file_exists(NEWER_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(NEWER_SAVE_PATH))

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
	(panel.get_node("%CloseButton") as BaseButton).pressed.emit()
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

#-----------------------------------------------------------------------------
# TIME SPEED
#-----------------------------------------------------------------------------

func test_speed_option_sets_the_speed() -> void:
	var panel: DevPanel = _add_panel()
	var option: OptionButton = panel.get_node("%SpeedOption")
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
	var badge: Control = panel.get_node("%SpeedBadge")
	var badge_label: Label = panel.get_node("%SpeedBadgeLabel")
	var option: OptionButton = panel.get_node("%SpeedOption")
	assert_false(panel.is_open(), "precondition: the panel is closed")
	assert_true(badge.is_visible_in_tree(), "a panel built at ×10 shows the badge, closed")
	assert_eq(badge_label.text, "×10")
	assert_eq(option.get_item_text(option.selected), "×10", "and its picker reads ×10")
	DevManager.set_time_speed(2.0)
	assert_true(badge.is_visible_in_tree(), "the badge stays at ×2")
	assert_eq(badge_label.text, "×2", "and reads it")
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

## A session that cannot save, such as one on a save a newer build wrote, is never
## silent. While saving is blocked the warning says so and why, with the panel
## closed too, as the badge does, and a session that can save hides it again.
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
## warning wraps it, and lets the mouse through to the game.
func test_the_warning_wraps_a_long_reason() -> void:
	_play_a_save_that_blocks_saving()
	var panel: DevPanel = _add_panel()
	var warning: Control = panel.get_node("%SaveWarning")
	var label: Label = panel.get_node("%SaveWarningLabel")
	label.text = "Not saving: " + "a reason long enough to need more than one line ".repeat(5)
	await get_tree().process_frame
	assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "it wraps by word")
	assert_gt(label.custom_minimum_size.x, 0.0, "in a width of its own")
	assert_gt(label.get_line_count(), 1, "precondition: the reason takes several lines")
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

## Reaching a level goes through real XP, and the stage line follows the core.
func test_player_tab_reaches_a_level() -> void:
	var player: Control = _open_tab(_add_panel(), "PlayerTab")
	var stage: Label = player.get_node("%StageLabel")
	assert_eq(stage.text, "Stage: Foundation · Core Density 0 / 100", "precondition: a fresh save")
	_enter(player, "LevelSpin", 42.0)
	_press(player, "LevelReach")
	assert_eq(CultivationManager.get_core_density_level(), 42.0)
	assert_eq(stage.text, "Stage: Foundation · Core Density 42 / 100")

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
