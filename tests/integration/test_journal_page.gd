extends GutTest

## The Journal tab pressed into the book's pages (spec: Journal). The left page
## lists the quest items under the caption "ITEMS OF CONSEQUENCE", one row every
## 80 px: the item in a deep slot, its name, and its quest's name under it, with
## a DONE seal at the right once the quest is finished, or the step the player
## is on. The right page's title is the item's name; under it the item's panel
## (where it came from, the description under a vermilion drop cap) and its
## quest's panel, shown the way the Goals board shows a quest: the quest's name,
## its flavour text and the steps reached so far, ticked when finished. The
## details follow the pointer and keep to the item the player picked.

const InventoryViewScene: PackedScene = preload("res://scenes/inventory/inventory_view/inventory_view.tscn")
const MAP: QuestItemDefinitionData = preload("res://resources/items/quest_items/refugee_camp_map.tres")
const QUEST_CATALOG_PATH: String = "res://resources/quests/quest_list.tres"
## "Harden Your Core": its completion awards the Refugee Camp Map.
const CORE_QUEST_ID: String = "q_reach_core_density_10"
## The fake quest the tests start, which needs the test's own bell.
const SHRINE_QUEST_ID: String = "test_journal_shrine"
## Thirty characters and more: two lines of a title, and of a row's name.
const LONG_NAME: String = "Lantern of the Thousand Quiet Valley Mornings"
const LONG_QUEST_NAME: String = "The Long Walk Through the Misty Bamboo Hollow"
## Runs past the two lines beside the drop cap.
const LONG_DESCRIPTION: String = "A bell cast for the old shrine, its rim worn smooth by a thousand hands. It still rings at dusk, though no one has struck it since the sect fell and the valley went quiet."

var _saved_save: SaveGameData = null
var _view: MenuBookView = null

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

## A fresh save, on the real quest catalog, in which "Harden Your Core" is done.
func before_each() -> void:
	_saved_save = PersistenceManager.save_game_data
	_restore_quest_catalog()
	_use_save(SaveGameData.new())
	PersistenceManager.save_game_data.quest_progression.completed_quest_ids.append(CORE_QUEST_ID)

func after_each() -> void:
	# The list and the details free the rows they replace a frame late: let
	# that frame pass so GUT counts no orphans.
	await wait_process_frames(1)
	_use_save(_saved_save)
	_restore_quest_catalog()

## Swaps in `save` and tells the managers to re-bind, as a fresh save does.
func _use_save(save: SaveGameData) -> void:
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()

## Unit tests may leave a stub catalog in QuestManager, and some tests here add
## a quest of their own: put the real quests back.
func _restore_quest_catalog() -> void:
	QuestManager._quest_catalog = load(QUEST_CATALOG_PATH)
	QuestManager._build_catalog_index()

## The Refugee Camp Map, as "Harden Your Core" awarded it.
func _hold_map() -> void:
	InventoryManager.award_items(MAP, 1)

## A quest item of the test's own.
func _quest_item(id: String, item_name: String, from_source: String = "The Broken Shrine") -> QuestItemDefinitionData:
	var item: QuestItemDefinitionData = QuestItemDefinitionData.new()
	item.item_id = id
	item.item_name = item_name
	item.description = "A bell for the tests."
	item.from_source = from_source
	return item

## Adds a quest of the test's own to QuestManager's catalog and starts it at
## `step_index`: three steps, the second of which completes on owning `item`.
func _start_quest_that_needs(item: ItemDefinitionData, step_index: int, quest_name: String = "The Broken Shrine") -> QuestData:
	var descriptions: Array[String] = ["Find the broken shrine", "Bring back its bell", "Ring it at dusk"]
	var steps: Array[QuestStepData] = []
	for index: int in descriptions.size():
		var step: QuestStepData = QuestStepData.new()
		step.step_id = "step_%d" % index
		step.description = descriptions[index]
		if index == 1:
			var owns: UnlockConditionData = UnlockConditionData.new()
			owns.condition_id = "test_journal_owns_bell"
			owns.condition_type = UnlockConditionData.ConditionType.ITEM_OWNED
			owns.target_value = item.item_id
			step.completion_conditions = [owns] as Array[UnlockConditionData]
		else:
			step.completion_event_id = "test_journal_never_fires"
		steps.append(step)
	var quest: QuestData = QuestData.new()
	quest.quest_id = SHRINE_QUEST_ID
	quest.quest_name = quest_name
	quest.description = "Something still rings in the old shrine at dusk."
	quest.steps = steps
	QuestManager._quests_by_id[quest.quest_id] = quest
	PersistenceManager.save_game_data.quest_progression.active_quests[quest.quest_id] = step_index
	return quest

## The inventory book's Journal tab, before the book opens.
func _tab() -> Control:
	_view = InventoryViewScene.instantiate() as MenuBookView
	add_child_autofree(_view)
	return _view.find_child("QuestItemsTab", true, false) as Control

## The book lying open at the Journal page, laid out. The page opens and shows
## as it does when a page turn lands on it.
func _open_tab() -> Control:
	var tab: Control = _tab()
	for page: Control in _view.tabs:
		page.visible = page == tab
	tab.open_page()
	_view._on_book_opened()
	await wait_process_frames(2)
	return tab

## The list's rows, top to bottom.
func _rows(tab: Control) -> Array[JournalRow]:
	var rows: Array[JournalRow] = []
	for node: Node in (tab.get_node("%JournalList") as InventoryList).get_slots():
		rows.append(node as JournalRow)
	return rows

func _rail(tab: Control) -> ScrollRail:
	return tab.get_node("%JournalList").get_node("ScrollRail") as ScrollRail

func _details(tab: Control) -> JournalDetails:
	return tab.get_node("%JournalDetails") as JournalDetails

## A node of the details, by its unique name.
func _detail(tab: Control, unique_name: String) -> Node:
	return _details(tab).get_node("%" + unique_name)

func _detail_text(tab: Control, unique_name: String) -> String:
	return (_detail(tab, unique_name) as Label).text

func _right_title(tab: Control) -> Label:
	return tab.get_node("%RightTitle").get_node("%TitleLabel") as Label

## The quest panel's step rows, top to bottom.
func _step_rows(tab: Control) -> Array[QuestStepRow]:
	var rows: Array[QuestStepRow] = []
	for node: Node in _detail(tab, "Steps").get_children():
		rows.append(node as QuestStepRow)
	return rows

func _is_ticked(row: QuestStepRow) -> bool:
	return (row.get_node("%Tick") as TextureRect).texture == QuestStepRow.TICKED_TEXTURE

## Where the line holding the character at `index` sits on screen: the top of
## that line as the engine lays the Label out, plus the font's ascent.
func _baseline(label: Label, index: int = 0) -> float:
	var ascent: float = label.get_theme_font(&"font").get_ascent(label.get_theme_font_size(&"font_size"))
	return label.get_global_rect().position.y + label.get_character_bounds(index).position.y + ascent

## The baseline of a Label's last line.
func _last_baseline(label: Label) -> float:
	return _baseline(label, label.text.length() - 1)

## A left press, as the row's gui_input passes it on.
func _left_press() -> InputEventMouseButton:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	return press

#-----------------------------------------------------------------------------
# THE LIST
#-----------------------------------------------------------------------------

func test_row_shows_item_quest_and_seal() -> void:
	_hold_map()
	var tab: Control = await _open_tab()
	var row: JournalRow = _rows(tab)[0]
	assert_eq(row.get_item(), MAP)
	assert_eq((row.get_node("%Name") as Label).text, "Refugee Camp Map")
	assert_eq((row.get_node("%SecondLine") as Label).text, "Harden Your Core", "the quest that gave it")
	var seal: Label = row.get_node("%Seal") as Label
	assert_eq(seal.text, "DONE")
	assert_true(seal.is_visible_in_tree(), "the quest is finished")
	assert_false((row.get_node("%StepLabel") as Control).is_visible_in_tree())
	assert_eq((row.get_node("%Icon") as TextureRect).texture, MAP.icon)

func test_the_map_has_its_own_icon() -> void:   # the Godot logo no more
	assert_eq(MAP.icon.resource_path, "res://assets/sprites/items/quest_items/refugee_camp_map_ai.png")

func test_rows_sit_where_the_spec_puts_them() -> void:   # Rulings R14, R17, R18
	_hold_map()
	var bell: QuestItemDefinitionData = _quest_item("test_bell", "Tarnished Shrine Bell")
	_start_quest_that_needs(bell, 0)
	InventoryManager.award_items(bell, 1)
	var tab: Control = await _open_tab()
	var rows: Array[JournalRow] = _rows(tab)
	var first: JournalRow = rows[0]
	assert_eq(first.get_global_rect(), Rect2(452, 334, 428, 80), "the slot area and its rule")
	assert_eq(rows[1].get_global_rect(), Rect2(452, 414, 428, 72), "one row every 80 px; the last has no rule")
	assert_eq((first.get_node("%Well") as Control).get_global_rect(), Rect2(452, 334, 72, 72), "the deep slot")
	assert_eq((first.get_node("%Icon") as Control).get_global_rect(), Rect2(456, 338, 64, 64))
	var name_label: Label = first.get_node("%Name") as Label
	assert_eq(name_label.get_global_rect().position.x, 540.0)
	assert_eq(_baseline(name_label), 364.0, "the name, baseline +30")
	var second: Label = first.get_node("%SecondLine") as Label
	assert_eq(second.get_global_rect().position.x, 540.0)
	assert_eq(_baseline(second), 390.0, "the quest's name, baseline +56")
	assert_eq((first.get_node("%Seal") as Control).get_global_rect(), Rect2(810, 356, 66, 26), "the mockup's seal, its right edge at x 876")
	assert_eq(_baseline(first.get_node("%Seal") as Label), 374.0, "DONE on the mockup's baseline, 18 px under the seal's top")
	assert_eq((first.get_node("%Rule") as Control).get_global_rect(), Rect2(452, 410, 428, 4), "the rule 4 px under the slot, touching the next one")
	assert_eq((first.get_node("%Marks") as Control).get_global_rect(), Rect2(444, 326, 442, 90), "the mockup's marks: (444, 326) to (886, 416)")
	var step: Label = rows[1].get_node("%StepLabel") as Label
	assert_eq(step.get_global_rect().end.x, 876.0, "the step, right-aligned at x 876")
	assert_eq(_baseline(step), 460.0, "baseline +46")

func test_last_row_has_no_rule() -> void:
	_hold_map()
	InventoryManager.award_items(_quest_item("test_bell", "Tarnished Shrine Bell"), 1)
	var tab: Control = _tab()
	var rows: Array[JournalRow] = _rows(tab)
	assert_true((rows[0].get_node("%Rule") as Control).visible)
	assert_false((rows[1].get_node("%Rule") as Control).visible)

func test_caption_and_list_sit_under_the_title() -> void:
	_hold_map()
	var tab: Control = await _open_tab()
	var caption: Label = tab.get_node("%CaptionLabel") as Label
	assert_eq(caption.text, "ITEMS OF CONSEQUENCE")
	assert_eq(caption.get_global_rect().get_center().x, 678.0, "centred on the left page")
	assert_eq(_baseline(caption), 316.0, "the caption row's baseline")
	assert_eq((tab.get_node("%JournalList") as Control).get_global_rect(), Rect2(452, 334, 452, 546), "from y 334 to the content's end at 880")

func test_the_list_frame_lets_the_marks_show_whole() -> void:   # Rulings R15, R20
	_hold_map()
	var tab: Control = await _open_tab()
	var frame: Control = tab.get_node("ListFrame") as Control
	assert_true(frame.clip_contents, "the frame clips the rows")
	assert_eq(frame.get_global_rect(), Rect2(444, 326, 460, 564), "the list grown 8 px left and up and 10 px down")
	var scroll: Control = tab.get_node("%JournalList").get_node("%ScrollContainer") as Control
	assert_false(scroll.clip_contents, "the list itself does not")
	var row: JournalRow = _rows(tab)[0]
	assert_true(row.is_marked(), "the page opens on its first item")
	assert_true(frame.get_global_rect().encloses((row.get_node("%Marks") as Control).get_global_rect()), "its marks show whole")
	assert_true(PageBounds.LEFT_PAGE.encloses(frame.get_global_rect()), "and the frame stays on the page")

func test_six_items_fit_and_seven_scroll() -> void:
	for index: int in 6:
		InventoryManager.award_items(_quest_item("test_item_%d" % index, "Keepsake %d" % index), 1)
	var tab: Control = await _open_tab()
	assert_false(_rail(tab).visible, "six rows fit the list")
	InventoryManager.award_items(_quest_item("test_item_6", "Keepsake 6"), 1)
	await wait_process_frames(2)
	assert_eq(_rows(tab).size(), 7)
	assert_true(_rail(tab).visible, "the seventh scrolls")

#-----------------------------------------------------------------------------
# HOVER, CLICKS AND CHANGES
#-----------------------------------------------------------------------------

func test_hovering_a_row_marks_it_and_shows_it() -> void:
	_hold_map()
	var bell: QuestItemDefinitionData = _quest_item("test_bell", "Tarnished Shrine Bell")
	InventoryManager.award_items(bell, 1)
	var tab: Control = _tab()
	var rows: Array[JournalRow] = _rows(tab)
	rows[1].mouse_entered.emit()
	assert_true(rows[1].is_marked())
	assert_false(rows[0].is_marked())
	assert_eq(_details(tab).get_item(), bell)
	assert_eq(_right_title(tab).text, "Tarnished Shrine Bell")

func test_clicking_a_row_shows_it() -> void:
	_hold_map()
	var bell: QuestItemDefinitionData = _quest_item("test_bell", "Tarnished Shrine Bell")
	InventoryManager.award_items(bell, 1)
	var tab: Control = _tab()
	var rows: Array[JournalRow] = _rows(tab)
	rows[1].gui_input.emit(_left_press())
	assert_eq(_details(tab).get_item(), bell)
	assert_true(rows[1].is_marked())
	assert_false(rows[0].is_marked())

func test_details_stay_on_the_shown_item_when_the_bag_changes() -> void:   # Review Focus 3
	_hold_map()
	var bell: QuestItemDefinitionData = _quest_item("test_bell", "Tarnished Shrine Bell")
	InventoryManager.award_items(bell, 1)
	var tab: Control = _tab()
	_rows(tab)[1].hovered.emit(_rows(tab)[1])
	InventoryManager.award_items(_quest_item("test_key", "Rusted Key"), 1)   # an item arrives while the book is open
	assert_eq(_rows(tab).size(), 3, "the list was rebuilt")
	assert_eq(_details(tab).get_item(), bell)
	assert_true(_rows(tab)[1].is_marked(), "the marks follow the item to its new row")
	assert_false(_rows(tab)[0].is_marked())
	assert_false(_rows(tab)[2].is_marked())

func test_foraging_leaves_the_page_alone() -> void:   # Review Focus 3: a roll every 5 s
	_hold_map()
	var tab: Control = _tab()
	var row: JournalRow = _rows(tab)[0]
	InventoryManager.award_items(load("res://resources/items/materials/spirit_fern.tres") as MaterialDefinitionData, 3)
	assert_eq(_rows(tab)[0], row, "the quest items did not change, so the list was not rebuilt")
	assert_true(row.is_marked())

func test_the_shown_item_leaving_moves_to_the_first() -> void:   # Review Focus 4
	_hold_map()
	var bell: QuestItemDefinitionData = _quest_item("test_bell", "Tarnished Shrine Bell")
	InventoryManager.award_items(bell, 1)
	var tab: Control = _tab()
	_rows(tab)[1].hovered.emit(_rows(tab)[1])
	var inventory: InventoryData = InventoryManager.get_inventory()
	inventory.quest_items.erase(bell)   # handed in: nothing in InventoryManager takes a quest item back yet
	InventoryManager.inventory_changed.emit(inventory)
	assert_eq(_details(tab).get_item(), MAP)
	var rows: Array[JournalRow] = _rows(tab)
	assert_eq(rows.size(), 1)
	assert_true(rows[0].is_marked())
	assert_eq(_right_title(tab).text, "Refugee Camp Map")

func test_the_last_item_leaving_hides_the_details_and_its_marks() -> void:   # Review Focus 4
	_hold_map()
	var tab: Control = _tab()
	var inventory: InventoryData = InventoryManager.get_inventory()
	inventory.quest_items.erase(MAP)
	InventoryManager.inventory_changed.emit(inventory)
	assert_eq(_rows(tab).size(), 0)
	assert_false(_details(tab).visible)
	assert_null(_details(tab).get_item())
	assert_false((tab.get_node("%RightTitle") as Control).visible, "no item, so no name over the right page")
	assert_true((tab.get_node("%EmptyLabel") as Control).visible)

func test_open_page_shows_the_first_item() -> void:
	_hold_map()
	InventoryManager.award_items(_quest_item("test_bell", "Tarnished Shrine Bell"), 1)
	var tab: Control = _tab()
	_rows(tab)[1].hovered.emit(_rows(tab)[1])
	tab.open_page()
	assert_eq(_details(tab).get_item(), MAP)
	assert_true(_details(tab).visible)
	assert_true(_rows(tab)[0].is_marked())
	assert_false(_rows(tab)[1].is_marked())

func test_empty_journal_says_so() -> void:
	var tab: Control = await _open_tab()
	var empty: Label = tab.get_node("%EmptyLabel") as Label
	assert_true(empty.visible)
	assert_eq(empty.text, "No quest items yet.")
	assert_eq(empty.theme_type_variation, &"LabelBookDetail")
	assert_eq(empty.get_global_rect().position, Vector2(452, 334), "where the list would be")
	assert_eq(_rows(tab).size(), 0)
	assert_false(_details(tab).visible)
	assert_false((tab.get_node("%RightTitle") as Control).visible)

#-----------------------------------------------------------------------------
# THE ITEM'S PANEL
#-----------------------------------------------------------------------------

func test_details_show_where_it_came_from() -> void:
	_hold_map()
	var tab: Control = await _open_tab()
	assert_eq(_right_title(tab).text, "Refugee Camp Map")
	assert_eq(_detail_text(tab, "KindLabel"), "QUEST ITEM")
	assert_eq(_detail_text(tab, "FromLabel"), "From Old Vesh, in the broken shrine")
	assert_eq((_detail(tab, "Icon") as TextureRect).texture, MAP.icon)
	assert_eq(_detail_text(tab, "DropCap"), "A")
	var narrow: Label = _detail(tab, "NarrowText") as Label
	assert_true(narrow.text.begins_with("hand-drawn"), narrow.text)
	# The whole description fits beside the cap at 390 px, split as the Label wraps it.
	assert_eq(narrow.text, "hand-drawn map leading to a camp of survivors hidden in the valley.")
	assert_eq(narrow.get_line_count(), 2)
	assert_eq(_detail_text(tab, "RestText"), "")
	assert_false((_detail(tab, "RestText") as Control).visible)

func test_the_items_panel_lays_the_map_out_as_the_mockup_does() -> void:   # Ruling R17
	_hold_map()
	var tab: Control = await _open_tab()
	assert_eq((_detail(tab, "ItemPanel") as Control).get_global_rect(), Rect2(1008, 300, 468, 196), "spec: (1008, 300) to (1476, 496)")
	assert_eq((_detail(tab, "Icon").get_parent() as Control).get_global_rect(), Rect2(1024, 316, 72, 72), "the deep slot")
	assert_eq((_detail(tab, "Icon") as Control).get_global_rect(), Rect2(1028, 320, 64, 64))
	var kind: Label = _detail(tab, "KindLabel") as Label
	assert_eq(kind.get_global_rect().position.x, 1112.0)
	assert_eq(_baseline(kind), 350.0, "QUEST ITEM")
	var from: Label = _detail(tab, "FromLabel") as Label
	assert_eq(from.get_global_rect().position.x, 1112.0)
	assert_eq(_baseline(from), 380.0, "where it came from")
	var cap: Label = _detail(tab, "DropCap") as Label
	assert_eq(cap.get_global_rect().position.x, 1024.0)
	assert_eq(_baseline(cap), 452.0, "the drop cap stands two lines tall")
	var narrow: Label = _detail(tab, "NarrowText") as Label
	assert_eq(narrow.get_global_rect().position.x, 1064.0, "the narrow column beside the cap")
	assert_eq(narrow.get_global_rect().size.x, 390.0, "390 px wide, the width the split measured")
	assert_eq(_baseline(narrow), 436.0)
	assert_eq(_last_baseline(narrow), 462.0)

func test_a_long_description_runs_on_at_full_width() -> void:
	var bell: QuestItemDefinitionData = _quest_item("test_bell", "Tarnished Shrine Bell")
	bell.description = LONG_DESCRIPTION
	InventoryManager.award_items(bell, 1)
	var tab: Control = await _open_tab()
	var narrow: Label = _detail(tab, "NarrowText") as Label
	var rest: Label = _detail(tab, "RestText") as Label
	assert_eq(narrow.get_line_count(), 2, "two lines beside the cap")
	assert_true(rest.visible)
	assert_eq(rest.get_global_rect().position.x, 1024.0, "the rest under the cap, at full width")
	assert_eq(rest.get_global_rect().size.x, 434.0)
	assert_eq(_baseline(rest), _last_baseline(narrow) + 26.0, "one line pitch on from the narrow column")
	assert_eq(narrow.text + " " + rest.text, LONG_DESCRIPTION.substr(1).strip_edges(), "no word is lost")
	var panel: Rect2 = (_detail(tab, "ItemPanel") as Control).get_global_rect()
	assert_eq(panel.end.y - _last_baseline(rest), 34.0, "the panel grows, ending as far under its last line as the map's does")

func test_a_wide_capital_keeps_the_column_inside_the_panel() -> void:
	var bell: QuestItemDefinitionData = _quest_item("test_bell", "Tarnished Shrine Bell")
	bell.description = "When the wind turns, the old bell rings by itself and the whole valley hears it ring."
	InventoryManager.award_items(bell, 1)
	var tab: Control = await _open_tab()
	var narrow: Label = _detail(tab, "NarrowText") as Label
	assert_lte(narrow.get_global_rect().end.x, 1458.0, "the column stops at the text's right edge")
	assert_lte(narrow.get_line_count(), 2, "and the split wraps where the Label does")
	assert_eq((_detail(tab, "ItemPanel") as Control).get_global_rect().size.x, 468.0, "the panel keeps its width")

#-----------------------------------------------------------------------------
# THE QUEST'S PANEL
#-----------------------------------------------------------------------------

func test_finished_quest_ticks_every_step() -> void:
	_hold_map()
	var tab: Control = await _open_tab()
	var quest: QuestData = QuestManager.get_quest_data(CORE_QUEST_ID)
	assert_true((_detail(tab, "QuestPanel") as Control).visible)
	assert_eq(_detail_text(tab, "QuestCaption"), "QUEST")
	assert_eq(_detail_text(tab, "QuestName"), "Harden Your Core")
	assert_true((_detail(tab, "Seal") as Control).visible)
	assert_eq(_detail_text(tab, "Seal"), "DONE")
	assert_eq(_detail_text(tab, "Flavor"), quest.description)
	var rows: Array[QuestStepRow] = _step_rows(tab)
	assert_eq(rows.size(), 2)
	for index: int in rows.size():
		assert_true(_is_ticked(rows[index]), "step %d is ticked" % index)
		assert_eq((rows[index].get_node("%Text") as Label).text, quest.steps[index].description)
	assert_eq((rows[0].get_node("%Figure") as Label).text, "10 / 10", "a finished step reads its target")
	assert_false((rows[1].get_node("%Figure") as Control).is_visible_in_tree(), "an event step has no figure")

func test_the_quest_panel_lays_out_as_the_mockup_does() -> void:   # Ruling R17
	_hold_map()
	var tab: Control = await _open_tab()
	assert_eq((_detail(tab, "QuestPanel") as Control).get_global_rect(), Rect2(1008, 512, 468, 264), "spec: (1008, 512) to (1476, 776), 16 px under the item's panel")
	var caption: Label = _detail(tab, "QuestCaption") as Label
	assert_eq(caption.get_global_rect().position.x, 1024.0)
	assert_eq(_baseline(caption), 544.0, "QUEST")
	assert_eq((_detail(tab, "Seal") as Control).get_global_rect(), Rect2(1390, 526, 66, 26), "the mockup's seal at the top right")
	assert_eq(_baseline(_detail(tab, "Seal") as Label), 544.0, "DONE on QUEST's baseline, as the mockup prints it")
	var quest_name: Label = _detail(tab, "QuestName") as Label
	assert_eq(quest_name.get_global_rect().position.x, 1024.0)
	assert_eq(_baseline(quest_name), 580.0, "the quest's name")
	var flavor: Label = _detail(tab, "Flavor") as Label
	assert_eq(flavor.get_global_rect().position.x, 1024.0)
	assert_eq(flavor.get_global_rect().size.x, 434.0)
	assert_eq(flavor.get_line_count(), 2)
	assert_eq(_baseline(flavor), 610.0, "the flavour text")
	assert_eq(_last_baseline(flavor), 632.0)
	assert_eq((_detail(tab, "StepsRule") as Control).get_global_rect(), Rect2(1024, 668, 436, 4), "the pressed rule")
	var rows: Array[QuestStepRow] = _step_rows(tab)
	for index: int in rows.size():
		var top: float = 686.0 + 34.0 * index
		assert_eq((rows[index].get_node("%Tick") as Control).get_global_rect(), Rect2(1024, top, 22, 22), "step %d's tick box" % index)
		var text: Label = rows[index].get_node("%Text") as Label
		assert_eq(text.get_global_rect().position.x, 1062.0, "step %d's text" % index)
		assert_eq(_baseline(text), top + 20.0, "step %d's baseline" % index)
	var figure: Label = rows[0].get_node("%Figure") as Label
	assert_eq(figure.get_global_rect().end.x, 1458.0, "the figure right-aligned at the panel's text edge")
	assert_eq(_baseline(figure), 706.0, "on its step's baseline")

func test_quest_in_progress_shows_reached_steps_only() -> void:
	var bell: QuestItemDefinitionData = _quest_item("test_bell", "Tarnished Shrine Bell")
	var quest: QuestData = _start_quest_that_needs(bell, 1)
	InventoryManager.award_items(bell, 1)
	var tab: Control = await _open_tab()
	var row: JournalRow = _rows(tab)[0]
	assert_eq((row.get_node("%SecondLine") as Label).text, "The Broken Shrine", "the quest that needs it")
	var step: Label = row.get_node("%StepLabel") as Label
	assert_true(step.is_visible_in_tree())
	assert_eq(step.text, "Step 2 of 3")
	assert_false((row.get_node("%Seal") as Control).is_visible_in_tree())
	assert_eq(_detail_text(tab, "QuestName"), "The Broken Shrine")
	assert_false((_detail(tab, "Seal") as Control).visible, "not finished")
	var rows: Array[QuestStepRow] = _step_rows(tab)
	assert_eq(rows.size(), 2, "the step reached and the one before it; the third is not shown")
	assert_true(_is_ticked(rows[0]))
	assert_false(_is_ticked(rows[1]))
	assert_eq((rows[1].get_node("%Text") as Label).text, quest.steps[1].description)

func test_the_current_step_shows_how_far_along_it_is() -> void:   # the Goals board's figure
	var bell: QuestItemDefinitionData = _quest_item("test_bell", "Tarnished Shrine Bell")
	var quest: QuestData = _start_quest_that_needs(bell, 1)
	# The step the player is on measures Madra; the bell is needed a step later.
	var madra: UnlockConditionData = UnlockConditionData.new()
	madra.condition_id = "test_journal_madra"
	madra.condition_type = UnlockConditionData.ConditionType.RESOURCE_AMOUNT
	madra.target_value = 100.0
	madra.optional_params = {"resource_type": "madra"}
	quest.steps[2].completion_event_id = ""
	quest.steps[2].completion_conditions = quest.steps[1].completion_conditions
	quest.steps[1].completion_conditions = [madra] as Array[UnlockConditionData]
	InventoryManager.award_items(bell, 1)
	var tab: Control = await _open_tab()
	var rows: Array[QuestStepRow] = _step_rows(tab)
	assert_eq((rows[1].get_node("%Figure") as Label).text, "25 / 100", "a fresh save holds 25 Madra")
	assert_false(_is_ticked(rows[1]))

func test_item_without_a_quest_shows_its_source() -> void:
	var stone: QuestItemDefinitionData = _quest_item("test_stone", "Smooth River Stone", "A stranger")
	InventoryManager.award_items(stone, 1)
	var tab: Control = await _open_tab()
	var row: JournalRow = _rows(tab)[0]
	assert_eq((row.get_node("%SecondLine") as Label).text, "A stranger")
	assert_false((row.get_node("%Seal") as Control).is_visible_in_tree(), "nothing at the right")
	assert_false((row.get_node("%StepLabel") as Control).is_visible_in_tree())
	assert_false((_detail(tab, "QuestPanel") as Control).visible)
	assert_eq(_detail_text(tab, "FromLabel"), "From A stranger")

#-----------------------------------------------------------------------------
# LONG TEXT AND TITLES
#-----------------------------------------------------------------------------

func test_long_names_stay_inside_the_pages() -> void:   # Review Focus 1, ruling 2
	var lantern: QuestItemDefinitionData = _quest_item("test_lantern", LONG_NAME)
	_start_quest_that_needs(lantern, 1, LONG_QUEST_NAME)
	InventoryManager.award_items(lantern, 1)
	var tab: Control = await _open_tab()
	assert_eq(PageBounds.escaping_text(tab), [] as Array[String])
	assert_eq(PageBounds.scaled_text(tab), [] as Array[String])
	var row: JournalRow = _rows(tab)[0]
	assert_gt((row.get_node("%Name") as Label).get_line_count(), 1, "the row's name wraps")
	assert_gt(row.size.y, 72.0, "and the row grows")
	assert_gt(_right_title(tab).get_line_count(), 1, "the title wraps")
	var details: Rect2 = _details(tab).get_global_rect()
	assert_gte(details.position.y, (tab.get_node("%RightTitle") as Control).get_global_rect().end.y, "the details move down under the title's last line")
	assert_gt((_detail(tab, "QuestName") as Label).get_line_count(), 1, "the quest's name wraps")
	assert_true(PageBounds.RIGHT_PAGE.encloses(details), "and the panels stay on the page")

func test_wrapped_text_keeps_the_art_on_even_pixels() -> void:   # every line pitch is even; a padded line keeps the boxes so
	var lantern: QuestItemDefinitionData = _quest_item("test_lantern", LONG_NAME, "Old Vesh, who keeps the broken shrine above the valley's misty bamboo hollow")
	_start_quest_that_needs(lantern, 1, LONG_QUEST_NAME)
	InventoryManager.award_items(lantern, 1)
	InventoryManager.award_items(_quest_item("test_stone", "Smooth River Stone", "A stranger"), 1)
	var tab: Control = await _open_tab()
	var rows: Array[JournalRow] = _rows(tab)
	assert_gt((rows[0].get_node("%SecondLine") as Label).get_line_count(), 1, "the quest's name wraps under the item's")
	assert_eq(fmod(rows[0].size.y, 2.0), 0.0, "a grown row is an even height: %s" % rows[0].size.y)
	assert_eq(fmod((rows[1].get_node("%Well") as Control).get_global_rect().position.y, 2.0), 0.0, "so the next row's slot stays on an even y")
	assert_gt((_detail(tab, "FromLabel") as Label).get_line_count(), 1, "the source wraps")
	for panel_name: String in ["ItemPanel", "QuestPanel"]:
		var panel: Rect2 = (_detail(tab, panel_name) as Control).get_global_rect()
		assert_eq(fmod(panel.position.y, 2.0), 0.0, "%s starts on an even y: %s" % [panel_name, panel])
		assert_eq(fmod(panel.size.y, 2.0), 0.0, "%s is an even height: %s" % [panel_name, panel])
	for row: QuestStepRow in _step_rows(tab):
		assert_eq(fmod((row.get_node("%Tick") as Control).get_global_rect().position.y, 2.0), 0.0, "each tick box on an even y")

func test_a_quest_without_flavour_text_keeps_the_art_on_even_pixels() -> void:
	var bell: QuestItemDefinitionData = _quest_item("test_bell", "Tarnished Shrine Bell")
	_start_quest_that_needs(bell, 1).description = ""
	InventoryManager.award_items(bell, 1)
	var tab: Control = await _open_tab()
	assert_false((_detail(tab, "Flavor") as Control).is_visible_in_tree(), "no flavour text, no blank line")
	var panel: Rect2 = (_detail(tab, "QuestPanel") as Control).get_global_rect()
	assert_eq(fmod(panel.size.y, 2.0), 0.0, "an even height: %s" % panel)
	assert_eq(fmod((_detail(tab, "StepsRule") as Control).get_global_rect().position.y, 2.0), 0.0, "the rule on an even y")

func test_pages_have_their_titles() -> void:
	_hold_map()
	var tab: Control = await _open_tab()
	assert_eq((tab.get_node("LeftTitle").get_node("%TitleLabel") as Label).text, "Journal")
	assert_eq(_right_title(tab).text, "Refugee Camp Map")
	assert_eq(PageBounds.scaled_text(tab), [] as Array[String])

func test_the_right_title_is_centred_on_the_page() -> void:   # ruling 3: the spec's "title centre 1244"
	_hold_map()
	var tab: Control = await _open_tab()
	var title: Control = tab.get_node("%RightTitle") as Control
	assert_eq(title.get_global_rect().get_center().x, 1244.0)
	assert_eq(fmod(title.get_global_rect().size.x, 2.0), 0.0, "an even width")
	assert_eq(_baseline(_right_title(tab)), 262.0, "the page title's baseline")
