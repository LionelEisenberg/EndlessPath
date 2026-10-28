extends GutTest

## The dev panel's Items tab, against the real managers. The tab gives the player any
## item the game has (a picker of every item resource, a quantity from 1 to 99 and a
## Give button) and grants one more equipment page. Both go through DevCommands, which
## logs them and says why one refused. A refusal shows in a status line right under the
## controls, in view without scrolling, and the next command that works clears it.
##
## Each panel is built inside a 1920x1080 Control, as MainView holds it. Each test
## binds a fresh in-memory save and gives back everything it changed: the save, the
## player's log, DevManager's panel fields, the preset folder and pin file (which point
## at paths nothing is written to) and the item names a test changed.

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
const BARELY_COALESCED_SCALE: String = "res://resources/items/consumables/barely_coalesced_scale.tres"
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
## The name each item a test renamed had, to put back.
var _original_item_names: Dictionary[ItemDefinitionData, String] = {}

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
	for item: ItemDefinitionData in _original_item_names:
		item.item_name = _original_item_names[item]
	_original_item_names.clear()
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

## Renames the item for the rest of the test. after_each() puts every name back.
func _rename(item: ItemDefinitionData, item_name: String) -> void:
	if not _original_item_names.has(item):
		_original_item_names[item] = item.item_name
	item.item_name = item_name

#-----------------------------------------------------------------------------
# THE TAB
#-----------------------------------------------------------------------------

func test_the_items_tab_comes_right_after_story() -> void:
	var panel: DevPanel = _add_panel()
	var tabs: TabContainer = panel.get_node("%Tabs")
	var items: int = tabs.get_tab_idx_from_control(panel.get_node("%ItemsTab"))
	var story: int = tabs.get_tab_idx_from_control(panel.get_node("%StoryTab"))
	assert_ne(items, -1, "precondition: the Items tab is one of the tabs")
	assert_eq(tabs.get_tab_title(items), "Items")
	assert_eq(items, story + 1, "it follows the Story tab")

## The status shows nothing, and takes no room, until something is refused.
func test_the_status_starts_hidden() -> void:
	assert_false(_status(_open_items_tab()).visible)

## No text is cut off: the status, whose text is a command's reason, wraps and is told
## how wide it may be, and nothing on the tab (the picker included) clips its text or
## trims it with an ellipsis.
func test_no_text_on_the_tab_is_cut_off() -> void:
	var tab: Control = _open_items_tab()
	var status: Label = _status(tab)
	assert_eq(status.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "the status wraps by word")
	assert_gt(status.custom_minimum_size.x, 0.0, "and has a width to wrap in")
	var texts: Array[Node] = tab.find_children("*", "Label", true, false)
	texts.append_array(tab.find_children("*", "Button", true, false))
	assert_gt(texts.size(), 4, "precondition: the walk met the tab's labels and buttons")
	for node: Node in texts:
		assert_false(node.get("clip_text"), "%s does not clip its text" % node.name)
		assert_eq(node.get("text_overrun_behavior"), TextServer.OVERRUN_NO_TRIMMING, "%s does not trim its text" % node.name)

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

## Two items with one name would look alike in the picker. The file name tells them
## apart, and an item with a name of its own is left as it is.
func test_items_that_share_a_name_are_told_apart_by_their_file() -> void:
	var first: ItemDefinitionData = load(CRUDE_SCALE)
	_rename(load(BARELY_COALESCED_SCALE), first.item_name)
	var option: OptionButton = _item_option(_open_items_tab())
	var texts: Array[String] = _item_texts(option)
	assert_has(texts, "Crude Scale (crude_scale.tres)")
	assert_has(texts, "Crude Scale (barely_coalesced_scale.tres)")
	assert_does_not_have(texts, "Crude Scale", "no item reads the shared name alone")
	assert_has(texts, "Iron Shortsword", "an item whose name is its own reads as it did")
	assert_eq(option.get_item_metadata(texts.find("Crude Scale (crude_scale.tres)")), CRUDE_SCALE, "each still carries its own path")
	assert_eq(option.get_item_metadata(texts.find("Crude Scale (barely_coalesced_scale.tres)")), BARELY_COALESCED_SCALE)

func test_the_quantity_runs_from_1_to_99_and_starts_at_1() -> void:
	var spin: SpinBox = _open_items_tab().get_node("%QuantitySpin")
	assert_eq(spin.min_value, 1.0)
	assert_eq(spin.max_value, 99.0)
	assert_eq(spin.value, 1.0, "a Give with no quantity typed gives one")
	spin.value = 500.0
	assert_eq(spin.value, 99.0, "a larger quantity stops at 99")
	spin.value = -3.0
	assert_eq(spin.value, 1.0, "and a smaller one at 1")

## A long item name widens the picker (and the panel with it) rather than being cut.
func test_a_long_item_name_widens_the_picker_instead_of_being_cut() -> void:
	var usual: float = _item_option(_open_items_tab()).get_combined_minimum_size().x
	_rename(load(CRUDE_SCALE), "Crude Scale of the ".repeat(8))
	var long_name: float = _item_option(_open_items_tab()).get_combined_minimum_size().x
	assert_gt(long_name, usual + 500.0, "the picker is as wide as its longest name")

#-----------------------------------------------------------------------------
# GIVE
#-----------------------------------------------------------------------------

func test_give_awards_the_selected_item() -> void:
	var tab: Control = _open_items_tab()
	_pick_metadata(_item_option(tab), CRUDE_SCALE)
	_enter_quantity(tab, 3)
	var scale: ConsumableDefinitionData = load(CRUDE_SCALE)
	assert_eq(InventoryManager.get_inventory().consumables.get(scale, 0), 0, "precondition: a fresh save holds no Crude Scale")
	watch_signals(LogManager)
	_press(tab, "GiveButton")
	assert_eq(InventoryManager.get_inventory().consumables.get(scale, 0), 3, "three of the picked item")
	assert_eq(InventoryManager.get_inventory().consumables.size(), 1, "and no other item")
	assert_eq(_dev_lines(), [DEV_LINE + "Gave 3x crude_scale"] as Array[String], "through the command, which logs it")
	assert_false(_status(tab).visible, "a command that works shows no refusal")

## Equipment goes to the grid, one instance for each copy.
func test_give_awards_equipment_to_the_grid() -> void:
	var tab: Control = _open_items_tab()
	_pick_metadata(_item_option(tab), IRON_SHORTSWORD)
	_enter_quantity(tab, 2)
	_press(tab, "GiveButton")
	assert_eq(_copies_in_grid(IRON_SHORTSWORD), 2)
	assert_false(_status(tab).visible)

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

## The tab is short, so the status stands right under the controls rather than in a
## footer. It must be in view where the tab opens, with nothing scrolled.
func test_a_refusal_is_in_view_without_scrolling() -> void:
	var tab: Control = _open_items_tab()
	_fill_equipment_grid()
	_pick_metadata(_item_option(tab), IRON_SHORTSWORD)
	_press(tab, "GiveButton")
	await wait_process_frames(2)
	var status: Label = _status(tab)
	assert_true(status.is_visible_in_tree(), "precondition: the refusal shows")
	assert_eq((tab as ScrollContainer).scroll_vertical, 0, "the tab is not scrolled")
	assert_true(tab.get_global_rect().encloses(status.get_global_rect()), "the status stands inside the part of the tab that shows: %s in %s" % [status.get_global_rect(), tab.get_global_rect()])

func test_a_give_that_works_clears_the_refusal() -> void:
	var tab: Control = _open_items_tab()
	_fill_equipment_grid()
	_pick_metadata(_item_option(tab), IRON_SHORTSWORD)
	_press(tab, "GiveButton")
	assert_true(_status(tab).visible, "precondition: the full grid refused")
	_pick_metadata(_item_option(tab), CRUDE_SCALE)
	_press(tab, "GiveButton")
	assert_false(_status(tab).visible, "a command that works clears the refusal")

## With no item to pick, a press has nothing to give and does nothing.
func test_give_with_nothing_picked_does_nothing() -> void:
	var tab: Control = _open_items_tab()
	_item_option(tab).clear()
	watch_signals(LogManager)
	watch_signals(InventoryManager)
	_press(tab, "GiveButton")
	assert_signal_not_emitted(InventoryManager, "item_awarded")
	assert_eq(_dev_lines().size(), 0, "nothing was reported")
	assert_false(_status(tab).visible, "and nothing was refused")

#-----------------------------------------------------------------------------
# EQUIPMENT PAGES
#-----------------------------------------------------------------------------

func test_grant_page_adds_an_equipment_page() -> void:
	var tab: Control = _open_items_tab()
	var pages: int = InventoryManager.get_inventory().unlocked_equipment_pages
	watch_signals(LogManager)
	_press(tab, "GrantPageButton")
	assert_eq(InventoryManager.get_inventory().unlocked_equipment_pages, pages + 1)
	assert_eq(_dev_lines(), [DEV_LINE + "Granted an equipment page (%d now)" % (pages + 1)] as Array[String], "through the command, which logs it")
	assert_false(_status(tab).visible)

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
