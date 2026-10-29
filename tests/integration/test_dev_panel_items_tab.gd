extends GutTest

## The dev panel's Items tab, against the real managers. The tab gives the player any
## item the game has (a picker of every item resource, a quantity and a Give button) and
## grants one more equipment page. Both go through DevCommands, which says why one
## refused. A refusal shows in a status line that wraps, and the next command that works
## clears it.
##
## Each panel is built inside a 1920x1080 Control, as MainView holds it. Each test
## binds a fresh in-memory save and gives back everything it changed: the save, the
## player's log, DevManager's panel fields, and the preset folder and pin file (which
## point at paths nothing is written to).

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DEV_PANEL_SCENE: PackedScene = preload("res://scenes/ui/dev_panel/dev_panel.tscn")

## The size MainView gives the panel in the game.
const SCREEN_SIZE: Vector2 = Vector2(1920, 1080)

## The prefix of every [DEV] line in the player's log.
const DEV_LINE: String = "[color=magenta][DEV][/color] "

## Where the preset folder and the pin file point, so the Saves tab of the panel reads
## neither the repository's presets nor the checkout's pin. Nothing is written there.
const PRESET_DIR: String = "user://__test_dev_panel_items_tab_presets/"
const PIN_PATH: String = "user://__test_dev_panel_items_tab_pin.cfg"

const CRUDE_SCALE: String = "res://resources/items/consumables/crude_scale.tres"
const IRON_SHORTSWORD: String = "res://resources/items/equipment/spirit_valley/iron_shortsword.tres"

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _original_save: SaveGameData
var _original_save_path: String
var _original_history: Array[String]
var _original_preset_dir_override: String
var _original_pin_path_override: String
var _original_panel_open: bool
var _original_panel_position: Vector2
var _original_panel_tab: int

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	_original_save_path = PersistenceManager.save_path
	_original_history = LogManager._history.duplicate()
	_original_preset_dir_override = DevManager.preset_dir_override
	_original_pin_path_override = LaunchOptions.pin_path_override
	_original_panel_open = DevManager.panel_open
	_original_panel_position = DevManager.panel_position
	_original_panel_tab = DevManager.panel_tab
	ActionManager.cancel_current_action()
	PersistenceManager.use_save(SaveGameData.new_current(), "")
	DevManager.preset_dir_override = PRESET_DIR
	LaunchOptions.pin_path_override = PIN_PATH
	DevManager.panel_open = false
	DevManager.panel_position = Vector2(24, 24)
	DevManager.panel_tab = 0

func after_each() -> void:
	ActionManager.cancel_current_action()
	PersistenceManager.use_save(_original_save, _original_save_path)
	LogManager._history = _original_history
	DevManager.preset_dir_override = _original_preset_dir_override
	LaunchOptions.pin_path_override = _original_pin_path_override
	DevManager.panel_open = _original_panel_open
	DevManager.panel_position = _original_panel_position
	DevManager.panel_tab = _original_panel_tab
	# Binding the original save again resumes its idle action, if it has one.
	# Stop it, so its tick timer does not run on into the next test.
	ActionManager.cancel_current_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Builds the panel inside a Control the size of the screen, as MainView holds it.
## It starts closed, as a launch's does.
func _add_panel() -> DevPanel:
	var host := Control.new()
	host.size = SCREEN_SIZE
	add_child_autofree(host)
	var panel: DevPanel = DEV_PANEL_SCENE.instantiate()
	host.add_child(panel)
	return panel

## Opens the panel on the Items tab and returns the tab.
func _show_items_tab(panel: DevPanel) -> Control:
	panel.set_open(true)
	var tab: Control = panel.get_node("%ItemsTab")
	var tabs: TabContainer = panel.get_node("%Tabs")
	tabs.current_tab = tabs.get_tab_idx_from_control(tab)
	return tab

## Builds the panel and opens it on the Items tab, as a developer finds it.
func _open_items_tab() -> Control:
	return _show_items_tab(_add_panel())

## Presses a button the way a click does: it says it was pressed.
func _press(tab: Node, button_name: String) -> void:
	(tab.get_node("%" + button_name) as BaseButton).pressed.emit()

## The status line under the controls.
func _status(tab: Node) -> Label:
	return tab.get_node("%ItemsStatus") as Label

func _item_option(tab: Node) -> OptionButton:
	return tab.get_node("%ItemOption") as OptionButton

## Types a quantity into the spin box.
func _enter_quantity(tab: Node, quantity: int) -> void:
	(tab.get_node("%QuantitySpin") as SpinBox).value = quantity

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

func _strings(packed: PackedStringArray) -> Array[String]:
	var strings: Array[String] = []
	strings.assign(packed)
	return strings

## Picks the item whose metadata is `metadata`, the way a player picks it from the list.
func _pick_metadata(option: OptionButton, metadata: String) -> void:
	for index: int in option.item_count:
		if option.get_item_metadata(index) == metadata:
			option.select(index)
			return
	fail_test("the picker has no item for %s" % metadata)

## The [DEV] lines the player's log got since watch_signals(LogManager).
func _dev_lines() -> Array[String]:
	var lines: Array[String] = []
	for index: int in maxi(get_signal_emit_count(LogManager, "message_logged"), 0):
		var line: String = get_signal_parameters(LogManager, "message_logged", index)[0]
		if line.begins_with(DEV_LINE):
			lines.append(line)
	return lines

## Fills every slot of the equipment grid with an item instance.
func _fill_equipment_grid() -> void:
	var inventory: InventoryData = InventoryManager.get_inventory()
	for index: int in inventory.equipment_capacity():
		inventory.equipment[index] = ItemInstanceData.new()

## How many instances of the item at `path` the equipment grid holds.
func _copies_in_grid(path: String) -> int:
	var item: ItemDefinitionData = load(path)
	var copies: int = 0
	for instance: ItemInstanceData in InventoryManager.get_inventory().equipment.values():
		if instance.item_definition == item:
			copies += 1
	return copies

#-----------------------------------------------------------------------------
# THE TAB
#-----------------------------------------------------------------------------

## No text is cut off: the status, whose text is a command's reason, wraps and is told
## how wide it may be.
func test_the_status_wraps() -> void:
	var tab: Control = _open_items_tab()
	var status: Label = _status(tab)
	assert_eq(status.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "the status wraps by word")
	assert_gt(status.custom_minimum_size.x, 0.0, "and has a width to wrap in")

#-----------------------------------------------------------------------------
# THE PICKER
#-----------------------------------------------------------------------------

func test_the_item_picker_lists_every_item_by_its_name() -> void:
	var option: OptionButton = _item_option(_open_items_tab())
	var paths: PackedStringArray = DevCommands.list_item_paths()
	var names: Array[String] = []
	for path: String in paths:
		var item_name: String = (load(path) as ItemDefinitionData).item_name
		assert_does_not_have(names, item_name, "precondition: no two items share the name %s" % item_name)
		names.append(item_name)
	assert_gt(paths.size(), 0, "precondition: the game has items")
	assert_eq(_item_texts(option), names, "each item reads its name, in the order of the paths")
	assert_eq(_item_metadata(option), _strings(paths), "and the item carries its path")
	assert_has(_item_texts(option), "Iron Shortsword", "an item of a nested folder")

#-----------------------------------------------------------------------------
# GIVE
#-----------------------------------------------------------------------------

func test_give_awards_the_selected_item() -> void:
	var tab: Control = _open_items_tab()
	_pick_metadata(_item_option(tab), CRUDE_SCALE)
	_enter_quantity(tab, 3)
	var scale: ConsumableDefinitionData = load(CRUDE_SCALE)
	assert_eq(InventoryManager.get_inventory().consumables.get(scale, 0), 0, "precondition: a fresh save holds no Crude Scale")
	_press(tab, "GiveButton")
	assert_eq(InventoryManager.get_inventory().consumables.get(scale, 0), 3, "three of the picked item")
	assert_eq(InventoryManager.get_inventory().consumables.size(), 1, "and no other item")
	assert_false(_status(tab).visible, "a command that works shows no refusal")

func test_give_shows_why_it_failed() -> void:
	var tab: Control = _open_items_tab()
	_fill_equipment_grid()
	var grid: Dictionary = InventoryManager.get_inventory().equipment.duplicate()
	_pick_metadata(_item_option(tab), IRON_SHORTSWORD)
	watch_signals(LogManager)
	_press(tab, "GiveButton")
	var status: Label = _status(tab)
	assert_true(status.is_visible_in_tree(), "the refusal shows")
	assert_eq(status.text, DevCommands.award_item(IRON_SHORTSWORD, 1), "and it is the command's reason")
	assert_string_contains(status.text, "full", "that the grid is full")
	assert_eq(InventoryManager.get_inventory().equipment, grid, "the grid is unchanged")
	assert_eq(_dev_lines().size(), 0, "and no success was reported")

#-----------------------------------------------------------------------------
# EQUIPMENT PAGES
#-----------------------------------------------------------------------------

## A full grid refuses equipment. The page the Grant button adds makes room for it, and
## the grant that works clears the refusal.
func test_a_granted_page_makes_room_for_the_equipment_a_full_grid_refused() -> void:
	var tab: Control = _open_items_tab()
	_fill_equipment_grid()
	_pick_metadata(_item_option(tab), IRON_SHORTSWORD)
	_press(tab, "GiveButton")
	assert_true(_status(tab).visible, "precondition: the full grid refused")
	assert_eq(_copies_in_grid(IRON_SHORTSWORD), 0, "precondition: nothing was given")
	_press(tab, "GrantPageButton")
	assert_false(_status(tab).visible, "a grant that works clears the refusal")
	_press(tab, "GiveButton")
	assert_eq(_copies_in_grid(IRON_SHORTSWORD), 1, "the sword fits the new page")
	assert_false(_status(tab).visible)
