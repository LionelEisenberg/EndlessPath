extends GutTest

## The Materials tab pressed into the book's pages (spec: Materials). The left
## page holds the same 6 × 6 page of slots as Equipment, with no caption over
## it: each material in a deep slot with its count on a paper tag, the rest of
## the page shallow, and past 36 kinds the page scrolls. The right page's title
## is the material's name; under it the details panel shows how many the player
## has, printed at its top right, the description and the zones it is found in.
## The details follow the pointer and keep to the material the player picked.

const InventoryViewScene: PackedScene = preload("res://scenes/inventory/inventory_view/inventory_view.tscn")
const SPIRIT_FERN: MaterialDefinitionData = preload("res://resources/items/materials/spirit_fern.tres")
const DEWDROP_TEAR: MaterialDefinitionData = preload("res://resources/items/materials/dewdrop_tear.tres")
## The condition Spring Forest Foraging unlocks on.
const FORAGING_UNLOCK_ID: String = "q_fill_core_completed"
## Forty characters: two lines of the right page's title.
const LONG_NAME: String = "Dew of the Thousand Quiet Valley Morning"
## From the description's last baseline to the table's first: the mockup's
## Spirit Fern, 462 to 556. Every material keeps it (Ruling R21).
const TABLE_GAP: float = 94.0
## More than two lines at the description's 434 px.
const LONG_DESCRIPTION: String = "A fern that drinks the valley's aura. Its fronds curl toward a cultivator's core, and its roots remember every storm that has crossed the valley since the old sect fell."

var _saved_save: SaveGameData = null
var _view: MenuBookView = null

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

func before_each() -> void:
	_saved_save = PersistenceManager.save_game_data
	_use_save(SaveGameData.new())
	_unlock_foraging()

func after_each() -> void:
	# The grid and the details free the slots and rows they replace a frame
	# late: let that frame pass so GUT counts no orphans.
	await wait_process_frames(1)
	_use_save(_saved_save)

## Swaps in `save` and tells the managers to re-bind, as a fresh save does.
func _use_save(save: SaveGameData) -> void:
	PersistenceManager.save_game_data = save
	PersistenceManager.save_data_reset.emit()

func _unlock_foraging() -> void:
	PersistenceManager.save_game_data.unlock_progression.unlocked_condition_ids.append(FORAGING_UNLOCK_ID)

## Fills the bag as the mockup does: Spirit Fern ×4600, then Dewdrop Tear ×3300.
func _gather_both() -> void:
	InventoryManager.award_items(SPIRIT_FERN, 4600)
	InventoryManager.award_items(DEWDROP_TEAR, 3300)

## Puts `kinds` materials of the test's own in the bag, one of each, before
## the view is built.
func _stock_kinds(kinds: int) -> void:
	for index: int in kinds:
		InventoryManager.get_material_items()[_material("moss_%d" % index, "Moss %d" % index)] = 1

## A material of the test's own, which no loot table lists.
func _material(id: String, item_name: String) -> MaterialDefinitionData:
	var def: MaterialDefinitionData = MaterialDefinitionData.new()
	def.item_id = id
	def.item_name = item_name
	def.description = "A material for the tests."
	return def

## The inventory book's Materials tab, before the book opens.
func _tab() -> Control:
	_view = InventoryViewScene.instantiate() as MenuBookView
	add_child_autofree(_view)
	return _view.find_child("MaterialsTab", true, false) as Control

## The book lying open at the Materials page, laid out. The page opens and
## shows as it does when a page turn lands on it.
func _open_tab() -> Control:
	var tab: Control = _tab()
	for page: Control in _view.tabs:
		page.visible = page == tab
	tab.open_page()
	_view._on_book_opened()
	await wait_process_frames(2)
	return tab

## The grid's slots in order: the materials first, then the page's empty slots.
func _slots(tab: Control) -> Array[MaterialSlot]:
	var slots: Array[MaterialSlot] = []
	for node: Node in (tab.get_node("%MaterialsInventoryGrid") as InventoryGrid).get_slots():
		slots.append(node as MaterialSlot)
	return slots

func _rail(tab: Control) -> ScrollRail:
	return tab.get_node("%MaterialsInventoryGrid").get_node("ScrollRail") as ScrollRail

func _details(tab: Control) -> MaterialDetails:
	return tab.get_node("%MaterialDetails") as MaterialDetails

func _right_title(tab: Control) -> Label:
	return tab.get_node("%RightTitle").get_node("%TitleLabel") as Label

func _amount(tab: Control) -> String:
	return (_details(tab).get_node("%CountLabel") as Label).text

func _table_rows(tab: Control) -> Array[TableRow]:
	var rows: Array[TableRow] = []
	for node: Node in _details(tab).get_node("%Sources").get_children():
		rows.append(node as TableRow)
	return rows

## The details' table as [caption, value] pairs, top to bottom.
func _table(tab: Control) -> Array:
	var pairs: Array = []
	for row: TableRow in _table_rows(tab):
		pairs.append([(row.get_node("%Label") as Label).text, (row.get_node("%Value") as RichTextLabel).text])
	return pairs

## The description's last baseline on screen.
func _description_end(tab: Control) -> float:
	var description: Label = _details(tab).get_node("%Description") as Label
	return _baseline(description, description.text.length() - 1)

## From the description's last baseline to the table's first, on screen.
func _gap_over_table(tab: Control) -> float:
	return _baseline(_table_rows(tab)[0].get_node("%Label") as Label) - _description_end(tab)

## Where the line holding the character at `index` sits on screen: the top of
## that line as the engine lays the Label out, plus the font's ascent.
func _baseline(label: Label, index: int = 0) -> float:
	var ascent: float = label.get_theme_font(&"font").get_ascent(label.get_theme_font_size(&"font_size"))
	return label.get_global_rect().position.y + label.get_character_bounds(index).position.y + ascent

## Where a RichTextLabel's first line sits on screen.
func _rich_baseline(text: RichTextLabel) -> float:
	var ascent: float = text.get_theme_font(&"normal_font").get_ascent(text.get_theme_font_size(&"normal_font_size"))
	return text.get_global_rect().position.y + text.get_line_offset(0) + ascent

## A left press, as the slot's gui_input passes it on.
func _left_press() -> InputEventMouseButton:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	return press

#-----------------------------------------------------------------------------
# THE PAGE OF SLOTS
#-----------------------------------------------------------------------------

func test_slots_carry_their_counts_on_tags() -> void:
	_gather_both()
	var tab: Control = _tab()
	var slots: Array[MaterialSlot] = _slots(tab)
	assert_eq((slots[0].get_node("%Count") as Label).text, "×4600")
	assert_eq((slots[1].get_node("%Count") as Label).text, "×3300")

func test_the_page_is_a_full_six_by_six() -> void:   # spec: the same 6 × 6 page as Equipment
	_gather_both()
	var tab: Control = _tab()
	var slots: Array[MaterialSlot] = _slots(tab)
	assert_eq(slots.size(), 36, "two materials, then 34 empty slots")
	for index: int in 2:
		assert_eq(slots[index].texture, InventorySlot.DEEP_TEXTURE, "material %d sits in a deep slot" % index)
		assert_true((slots[index].get_node("%Count") as Control).visible)
	assert_eq((slots[0].get_node("%Icon") as TextureRect).texture, SPIRIT_FERN.icon)
	for index: int in range(2, 36):
		var slot: MaterialSlot = slots[index]
		assert_null(slot.get_definition())
		assert_eq(slot.texture, InventorySlot.SHALLOW_TEXTURE, "slot %d is empty, so shallow" % index)
		assert_null((slot.get_node("%Icon") as TextureRect).texture)
		assert_false((slot.get_node("%Count") as Control).visible, "slot %d has no tag" % index)

func test_pieces_sit_where_the_spec_puts_them() -> void:
	_gather_both()
	var tab: Control = await _open_tab()
	assert_eq((tab.get_node("%MaterialsInventoryGrid") as Control).get_global_rect(), Rect2(452, 334, 452, 452))
	var slots: Array[MaterialSlot] = _slots(tab)
	assert_eq(slots[0].get_global_rect(), Rect2(452, 334, 72, 72), "the first slot")
	assert_eq(slots[1].get_global_rect().position, Vector2(528, 334), "a 76 px pitch across")
	assert_eq(slots[6].get_global_rect().position, Vector2(452, 410), "and down")
	assert_eq(slots[35].get_global_rect().end, Vector2(904, 786), "six by six fill the grid")
	assert_eq((slots[0].get_node("%Icon") as Control).get_global_rect(), Rect2(456, 338, 64, 64), "the icon at +4, +4")
	var tag: Rect2 = (slots[0].get_node("%Count") as Control).get_global_rect()
	assert_eq(tag, Rect2(474, 382, 48, 20), "the mockup's tag: 2 px in from the right, 4 up from the bottom")
	assert_eq(_baseline(slots[0].get_node("%Count") as Label), 398.0, "its count on the mockup's baseline, the slot's top + 64")
	var second_tag: Rect2 = (slots[1].get_node("%Count") as Control).get_global_rect()
	assert_eq(second_tag.end, Vector2(598, 402), "every tag sits the same way on its slot")
	assert_eq(fmod(second_tag.position.x, 2.0), 0.0, "and starts on an even x")
	assert_eq((slots[0].get_node("%Marks") as Control).get_global_rect(), Rect2(446, 328, 84, 84), "marks 6 px outside the slot")

## 2026-10-28 review: no "N KINDS" caption; the row over the grid stays empty,
## kept for a selector.
func test_no_caption_over_the_grid() -> void:
	InventoryManager.award_items(SPIRIT_FERN, 3)
	var tab: Control = _tab()
	assert_null(tab.find_child("KindsLabel", true, false))

func test_more_than_36_kinds_scroll() -> void:
	_stock_kinds(36)
	var tab: Control = await _open_tab()
	assert_false(_rail(tab).visible, "36 kinds fill the page exactly")
	InventoryManager.award_items(SPIRIT_FERN, 1)   # the 37th
	await wait_process_frames(2)
	assert_eq(_slots(tab).size(), 42, "a seventh row, filled out with empty slots")
	assert_true(_rail(tab).visible)
	var rail: Rect2 = _rail(tab).get_global_rect()
	assert_eq(rail, Rect2(908, 334, 10, 452), "the groove beside the grid, as tall as it")
	assert_true((tab.get_node("GridFrame") as Control).get_global_rect().encloses(rail), "the frame shows it whole")

func test_the_grid_frame_lets_the_marks_show_whole() -> void:   # Ruling R15
	_stock_kinds(36)
	var tab: Control = await _open_tab()
	var frame: Control = tab.get_node("GridFrame") as Control
	assert_true(frame.clip_contents, "the frame clips the grid")
	assert_eq(frame.get_global_rect(), Rect2(446, 328, 472, 464), "the grid grown by the marks' reach, and the groove's room")
	var scroll: Control = tab.get_node("%MaterialsInventoryGrid").get_node("%ScrollContainer") as Control
	assert_false(scroll.clip_contents, "the grid itself does not")
	var slots: Array[MaterialSlot] = _slots(tab)
	assert_true(slots[0].is_marked(), "the page opens on its first item")
	assert_true(frame.get_global_rect().encloses((slots[0].get_node("%Marks") as Control).get_global_rect()), "its marks show whole")
	slots[35].hovered.emit(slots[35])
	assert_true(slots[35].is_marked())
	assert_true(frame.get_global_rect().encloses((slots[35].get_node("%Marks") as Control).get_global_rect()), "so do the last slot's")

func test_no_trash_on_the_materials_page() -> void:
	_gather_both()
	var tab: Control = _tab()
	assert_null(tab.find_child("TrashSlot", true, false))

func test_empty_page_says_so() -> void:
	var tab: Control = await _open_tab()
	var empty: Label = tab.get_node("%EmptyLabel") as Label
	assert_true(empty.visible)
	assert_eq(empty.text, "Nothing gathered yet.")
	assert_eq(_slots(tab).size(), 0, "the line takes the grid's place")
	assert_false(_details(tab).visible)
	assert_null(_details(tab).get_shown_material())
	assert_false((tab.get_node("%RightTitle") as Control).visible, "no material, so no name over the right page")

#-----------------------------------------------------------------------------
# THE DETAILS
#-----------------------------------------------------------------------------

func test_hovering_dewdrop_describes_it() -> void:
	_gather_both()
	var tab: Control = _tab()
	var slots: Array[MaterialSlot] = _slots(tab)
	slots[1].hovered.emit(slots[1])
	assert_eq(_right_title(tab).text, "Dewdrop Tear")
	assert_eq(_amount(tab), "3,300")
	assert_eq(_table(tab), [["FOUND IN", "Spirit Valley"]], "where to find it: its zones, nothing more")
	assert_eq((_details(tab).get_node("%Description") as Label).text, DEWDROP_TEAR.description)
	assert_eq((_details(tab).get_node("%Icon") as TextureRect).texture, DEWDROP_TEAR.icon)
	assert_eq((_details(tab).get_node("%KindLabel") as Label).text, "MATERIAL")
	assert_eq((_table_rows(tab)[0].get_node("%Value") as RichTextLabel).theme_type_variation, &"RichTextBookValue")
	assert_true(slots[1].is_marked(), "the marks sit round the slot pointed at")
	assert_false(slots[0].is_marked(), "and leave the one shown before")

func test_clicking_a_slot_shows_it() -> void:
	_gather_both()
	var tab: Control = _tab()
	var slots: Array[MaterialSlot] = _slots(tab)
	slots[1].clicked.emit(slots[1], _left_press())
	assert_eq(_details(tab).get_shown_material(), DEWDROP_TEAR)
	assert_true(slots[1].is_marked())
	assert_false(slots[0].is_marked())

func test_hovering_an_empty_slot_changes_nothing() -> void:
	_gather_both()
	var tab: Control = _tab()
	var slots: Array[MaterialSlot] = _slots(tab)
	slots[1].hovered.emit(slots[1])
	slots[20].hovered.emit(slots[20])
	slots[20].clicked.emit(slots[20], _left_press())
	assert_eq(_details(tab).get_shown_material(), DEWDROP_TEAR, "the details keep the last material")
	assert_true(slots[1].is_marked())
	assert_false(slots[20].is_marked())

func test_foraging_keeps_the_shown_material() -> void:   # Review Focus 3
	_gather_both()
	var tab: Control = _tab()
	var slots: Array[MaterialSlot] = _slots(tab)
	slots[1].hovered.emit(slots[1])
	InventoryManager.award_items(SPIRIT_FERN, 5)   # a foraging roll while the book is open
	assert_eq(_details(tab).get_shown_material(), DEWDROP_TEAR)
	assert_eq(_right_title(tab).text, "Dewdrop Tear")
	assert_eq(_amount(tab), "3,300")
	var rebuilt: Array[MaterialSlot] = _slots(tab)
	assert_eq((rebuilt[0].get_node("%Count") as Label).text, "×4605", "the grid was rebuilt")
	assert_true(rebuilt[1].is_marked(), "the marks follow the material to its new slot")
	assert_false(rebuilt[0].is_marked())

func test_count_follows_its_stack() -> void:
	_gather_both()
	var tab: Control = _tab()
	var slots: Array[MaterialSlot] = _slots(tab)
	slots[1].hovered.emit(slots[1])
	InventoryManager.award_items(DEWDROP_TEAR, 5)
	assert_eq(_amount(tab), "3,305")

func test_a_material_leaving_the_bag_gives_way_to_the_first() -> void:   # Review Focus 4
	_gather_both()
	var tab: Control = _tab()
	var slots: Array[MaterialSlot] = _slots(tab)
	slots[1].hovered.emit(slots[1])
	# Nothing spends materials yet; a future crafting verb would do this.
	var inventory: InventoryData = InventoryManager.get_inventory()
	inventory.materials.erase(DEWDROP_TEAR)
	InventoryManager.inventory_changed.emit(inventory)
	assert_eq(_details(tab).get_shown_material(), SPIRIT_FERN)
	assert_eq(_right_title(tab).text, "Spirit Fern")
	var left: Array[MaterialSlot] = _slots(tab)
	assert_true(left[0].is_marked())
	for index: int in range(1, left.size()):
		assert_false(left[index].is_marked(), "no marks left behind on slot %d" % index)
	inventory.materials.erase(SPIRIT_FERN)
	InventoryManager.inventory_changed.emit(inventory)
	assert_false(_details(tab).visible, "the last one gone, the details hide")
	assert_true((tab.get_node("%EmptyLabel") as Control).visible)

func test_open_page_shows_the_first_material() -> void:
	_gather_both()
	var tab: Control = _tab()
	var slots: Array[MaterialSlot] = _slots(tab)
	slots[1].hovered.emit(slots[1])
	tab.open_page()
	assert_eq(_details(tab).get_shown_material(), SPIRIT_FERN)
	assert_true(_details(tab).visible)
	assert_true(_slots(tab)[0].is_marked())
	assert_eq(_right_title(tab).text, "Spirit Fern")

func test_sources_are_worked_out_when_the_page_opens() -> void:   # spec: Data the tabs read
	PersistenceManager.save_game_data.unlock_progression.unlocked_condition_ids.erase(FORAGING_UNLOCK_ID)
	_gather_both()
	var tab: Control = await _open_tab()
	var sources: Control = _details(tab).get_node("%Sources") as Control
	assert_true(_details(tab).is_visible_in_tree())
	assert_false(sources.is_visible_in_tree(), "foraging is locked: no source to show")
	_unlock_foraging()
	tab.open_page()
	assert_true(sources.is_visible_in_tree(), "opening the page again finds it")
	assert_eq(_table_rows(tab).size(), 1, "its one zone")

func test_a_material_without_sources_hides_the_table() -> void:
	InventoryManager.award_items(_material("moon_moss", "Moon Moss"), 2)
	var tab: Control = await _open_tab()
	assert_eq(_details(tab).get_shown_material().item_name, "Moon Moss")
	assert_true(_details(tab).is_visible_in_tree(), "the panel still shows the material")
	assert_false((_details(tab).get_node("%Sources") as Control).is_visible_in_tree(), "but not the table")
	assert_eq(_table_rows(tab).size(), 0)

func test_a_material_without_sources_ends_under_its_description() -> void:   # Ruling R21
	InventoryManager.award_items(_material("moon_moss", "Moon Moss"), 2)
	var tab: Control = await _open_tab()
	var below: float = _details(tab).get_global_rect().end.y - _description_end(tab)
	assert_lte(below, 26.0, "the table's gap goes with it: no blank lines under the description")

func test_dewdrop_keeps_the_same_gap_over_its_table() -> void:   # Ruling R21
	_gather_both()
	var tab: Control = await _open_tab()
	var slots: Array[MaterialSlot] = _slots(tab)
	slots[1].hovered.emit(slots[1])
	await wait_process_frames(2)
	assert_eq(_details(tab).get_shown_material(), DEWDROP_TEAR)
	assert_eq(_gap_over_table(tab), TABLE_GAP, "Spirit Fern's gap, under Dewdrop's own description")

func test_the_table_follows_the_description_at_the_same_gap() -> void:   # Ruling R21
	# Two materials Spring Forest Foraging lists, since they share Spirit
	# Fern's item_id: one with a one-line description, one with a long one.
	var short: MaterialDefinitionData = _material("SpiritFern", "Short Fern")
	short.description = "A fern."
	var long: MaterialDefinitionData = _material("SpiritFern", "Long Fern")
	long.description = LONG_DESCRIPTION
	InventoryManager.award_items(short, 1)
	InventoryManager.award_items(long, 1)
	var tab: Control = await _open_tab()
	var description: Label = _details(tab).get_node("%Description") as Label
	assert_eq(description.get_line_count(), 1)
	assert_eq(_gap_over_table(tab), TABLE_GAP, "a shorter description pulls the table up")
	var short_end: float = _details(tab).get_global_rect().end.y
	var slots: Array[MaterialSlot] = _slots(tab)
	slots[1].hovered.emit(slots[1])
	await wait_process_frames(2)
	var long_lines: int = description.get_line_count()
	assert_gt(long_lines, 2, "the long description wraps past two lines")
	assert_eq(_gap_over_table(tab), TABLE_GAP, "and a longer one pushes it down")
	assert_eq(_details(tab).get_global_rect().end.y - short_end, 26.0 * (long_lines - 1), "the panel grows by the extra lines' pitch")

func test_details_lay_spirit_fern_out_as_the_mockup_does() -> void:   # Ruling R17
	_gather_both()
	var tab: Control = await _open_tab()
	var details: MaterialDetails = _details(tab)
	assert_eq(details.get_global_rect(), Rect2(1008, 300, 468, 286), "the spec's (1008, 300), one row shorter than its table of three")
	assert_eq((details.get_node("%Icon").get_parent() as Control).get_global_rect(), Rect2(1024, 316, 72, 72), "the deep slot")
	var kind: Label = details.get_node("%KindLabel") as Label
	assert_eq(kind.get_global_rect().position.x, 1114.0, "MATERIAL 2 px in, its ink at the mockup's x 1114 (Ruling R22)")
	assert_eq(_baseline(kind), 350.0, "MATERIAL")
	# 2026-10-28 review: printed in ink, with no tag and no ×.
	var count: Label = details.get_node("%CountLabel") as Label
	assert_eq(count.text, "4,600")
	assert_eq(count.get_global_rect().end.x, 1458.0, "the count at the top right, on the text's right edge")
	assert_eq(_baseline(count), 350.0, "on MATERIAL's baseline")
	var description: Label = details.get_node("%Description") as Label
	assert_eq(description.get_global_rect().position.x, 1024.0)
	assert_eq(description.get_line_count(), 2)
	assert_eq(_baseline(description), 436.0, "the description")
	assert_eq(_gap_over_table(tab), TABLE_GAP, "the gap every material keeps over its table")
	var rows: Array[TableRow] = _table_rows(tab)
	assert_eq(rows.size(), 1, "FOUND IN, Spirit Valley")
	for index: int in rows.size():
		var baseline: float = 556.0 + 30.0 * index
		assert_eq(_baseline(rows[index].get_node("%Label") as Label), baseline, "row %d's label" % index)
		assert_eq(_rich_baseline(rows[index].get_node("%Value") as RichTextLabel), baseline, "row %d's value" % index)
		assert_eq((rows[index].get_node("%Value") as Control).get_global_rect().end.x, 1458.0, "row %d's value ends at the column's edge" % index)
		assert_eq((rows[index].get_node("%Rule") as Control).get_global_rect(), Rect2(1024, baseline + 8.0, 436, 4), "row %d's rule" % index)

func test_huge_counts_fit() -> void:   # Review Focus 2
	InventoryManager.award_items(SPIRIT_FERN, 1234567)
	var tab: Control = await _open_tab()
	var slot: MaterialSlot = _slots(tab)[0]
	var tag: Label = slot.get_node("%Count") as Label
	assert_eq(tag.text, "×1234567")
	assert_true(slot.get_global_rect().encloses(tag.get_global_rect()), "the tag fits on its slot")
	assert_eq(_amount(tab), "1,234,567")
	assert_eq(PageBounds.escaping_text(tab), [] as Array[String])

func test_long_names_stay_inside_the_pages() -> void:   # Review Focus 1, ruling 2
	InventoryManager.award_items(_material("long", LONG_NAME), 3)
	var tab: Control = await _open_tab()
	assert_eq(PageBounds.escaping_text(tab), [] as Array[String])
	assert_eq(PageBounds.scaled_text(tab), [] as Array[String])
	var title: Control = tab.get_node("%RightTitle") as Control
	assert_eq(_right_title(tab).get_line_count(), 2, "the name wraps")
	var details: Rect2 = _details(tab).get_global_rect()
	assert_gte(details.position.y, title.get_global_rect().end.y, "the details move down under the title's last line")
	assert_true(PageBounds.RIGHT_PAGE.encloses(details), "and stay on the page")

func test_pages_have_their_titles() -> void:
	_gather_both()
	var tab: Control = await _open_tab()
	assert_eq((tab.get_node("LeftTitle").get_node("%TitleLabel") as Label).text, "Materials")
	assert_eq(_right_title(tab).text, "Spirit Fern")
	assert_eq(PageBounds.scaled_text(tab), [] as Array[String])

func test_the_right_title_is_centred_on_the_page() -> void:   # the spec's "title centre 1244"
	_gather_both()
	var tab: Control = await _open_tab()
	var title: Control = tab.get_node("%RightTitle") as Control
	assert_eq(title.get_global_rect().get_center().x, 1244.0)
	assert_eq(fmod(title.get_global_rect().size.x, 2.0), 0.0, "an even width")
	assert_eq((title.get_node("%Ornament") as Control).get_global_rect().get_center().x, 1244.0, "and its ornament under it")
	assert_eq(_baseline(_right_title(tab)), 262.0, "the page title's baseline")
