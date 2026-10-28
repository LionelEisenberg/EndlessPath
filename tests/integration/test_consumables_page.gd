extends GutTest

## The Consumables tab pressed into the book's pages (spec: Consumables). The
## left page lists the stacks, one row every 80 px, seven in view and the rest
## scrolling. The right page holds the hotbar with its keys printed under it,
## the printed hint, and the details panel. The details follow the pointer
## and keep to the consumable the player picked.

const InventoryViewScene: PackedScene = preload("res://scenes/inventory/inventory_view/inventory_view.tscn")
const DragPreviewScene: PackedScene = preload("res://scenes/inventory/pressed/item_drag_preview/item_drag_preview.tscn")
const CRUDE: ConsumableDefinitionData = preload("res://resources/items/consumables/crude_scale.tres")
const LONG_NAME: String = "Pill of the Thousand Quiet Mornings Beneath the Valley"

var _saved_inventory: InventoryData = null
var _view: MenuBookView = null

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

func before_each() -> void:
	_saved_inventory = PersistenceManager.save_game_data.inventory
	PersistenceManager.save_game_data.inventory = InventoryData.new()

func after_each() -> void:
	# The list and the details free the rows they replace a frame late: let
	# that frame pass so GUT counts no orphans.
	await wait_process_frames(1)
	PersistenceManager.save_game_data.inventory = _saved_inventory

## The inventory book's Consumables tab, before the book opens.
func _tab() -> Control:
	_view = InventoryViewScene.instantiate() as MenuBookView
	add_child_autofree(_view)
	return _view.find_child("ConsumablesTab", true, false) as Control

## The book lying open at the Consumables page, laid out. The page opens and
## shows as it does when a page turn lands on it.
func _open_tab() -> Control:
	var tab: Control = _tab()
	for page: Control in _view.tabs:
		page.visible = page == tab
	tab.open_page()
	_view._on_book_opened()
	await wait_process_frames(2)
	return tab

## A consumable of the test's own: it restores `madra` and has a cooldown.
func _consumable(id: String, item_name: String, madra: float = 10.0, cooldown: float = 5.0) -> ConsumableDefinitionData:
	var effect: ChangeVitalsEffectData = ChangeVitalsEffectData.new()
	effect.madra_change = madra
	var def: ConsumableDefinitionData = ConsumableDefinitionData.new()
	def.item_id = id
	def.item_name = item_name
	def.description = "A pill for the tests."
	def.effects.append(effect)
	def.cooldown_seconds = cooldown
	return def

## The list's rows, top to bottom (rows a rebuild replaced are left out).
func _rows(tab: Control) -> Array[ConsumableRow]:
	var rows: Array[ConsumableRow] = []
	for node: Node in (tab.get_node("%ConsumablesInventoryList") as InventoryList).get_slots():
		if not node.is_queued_for_deletion():
			rows.append(node as ConsumableRow)
	return rows

func _rail(tab: Control) -> ScrollRail:
	return tab.get_node("%ConsumablesInventoryList").get_node("ScrollRail") as ScrollRail

func _hotbar_slot(tab: Control, index: int) -> HotbarSlot:
	return tab.get_node("%ConsumablesHotbar").get_node("SlotsRow").get_child(index) as HotbarSlot

func _details(tab: Control) -> ConsumableDetails:
	return tab.get_node("%ConsumableDetails") as ConsumableDetails

func _table_rows(tab: Control) -> Array[TableRow]:
	var rows: Array[TableRow] = []
	for node: Node in _details(tab).get_node("%Effects").get_children():
		rows.append(node as TableRow)
	return rows

## Where the line holding the character at `index` sits on screen: the top of
## that line as the engine lays the Label out, plus the font's ascent.
func _baseline(label: Label, index: int = 0) -> float:
	var ascent: float = label.get_theme_font(&"font").get_ascent(label.get_theme_font_size(&"font_size"))
	return label.get_global_rect().position.y + label.get_character_bounds(index).position.y + ascent

## Where a RichTextLabel's first line sits on screen.
func _rich_baseline(text: RichTextLabel) -> float:
	var ascent: float = text.get_theme_font(&"normal_font").get_ascent(text.get_theme_font_size(&"normal_font_size"))
	return text.get_global_rect().position.y + text.get_line_offset(0) + ascent

#-----------------------------------------------------------------------------
# THE LIST
#-----------------------------------------------------------------------------

func test_rows_show_name_effect_and_count() -> void:
	InventoryManager.award_items(CRUDE, 7)
	var tab: Control = _tab()
	var row: ConsumableRow = _rows(tab)[0]
	assert_eq((row.get_node("%Name") as Label).text, "Crude Scale")
	assert_eq((row.get_node("%Effect") as RichTextLabel).text, "[color=#1c2f60]+20 Madra[/color] · 10 s cooldown")
	assert_eq((row.get_node("%Count") as Label).text, "×7")

func test_last_row_has_no_rule() -> void:
	InventoryManager.award_items(CRUDE, 1)
	InventoryManager.award_items(_consumable("tea", "Spirit Tea"), 1)
	var tab: Control = _tab()
	var rows: Array[ConsumableRow] = _rows(tab)
	assert_true((rows[0].get_node("%Rule") as Control).visible)
	assert_false((rows[1].get_node("%Rule") as Control).visible)

func test_eight_kinds_scroll() -> void:
	var tab: Control = await _open_tab()
	for index: int in 8:
		InventoryManager.award_items(_consumable("pill_%d" % index, "Pill %d" % index), 1)
	await wait_process_frames(2)
	assert_eq(_rows(tab).size(), 8)
	assert_true(_rail(tab).visible)

func test_seven_kinds_fit_without_scrolling() -> void:   # Ruling R14
	for index: int in 7:
		InventoryManager.award_items(_consumable("pill_%d" % index, "Pill %d" % index), 1)
	var tab: Control = await _open_tab()
	var rows: Array[ConsumableRow] = _rows(tab)
	assert_eq(rows.size(), 7)
	assert_eq(rows[6].size.y, 72.0, "the last row has no rule, so it keeps no room for one")
	assert_eq(rows[6].get_global_rect().end.y, 852.0, "the seventh slot ends where the groove does")
	assert_false(_rail(tab).visible, "seven rows fill the list exactly")

func test_rows_sit_where_the_spec_puts_them() -> void:   # Rulings R14, R17
	InventoryManager.award_items(CRUDE, 7)
	InventoryManager.award_items(_consumable("tea", "Spirit Tea"), 3)
	var tab: Control = await _open_tab()
	var rows: Array[ConsumableRow] = _rows(tab)
	var first: ConsumableRow = rows[0]
	assert_eq(first.get_global_rect(), Rect2(452, 300, 428, 80), "the slot area and its rule")
	assert_eq(rows[1].get_global_rect().position, Vector2(452, 380), "one row every 80 px")
	assert_eq((first.get_node("%Well") as Control).get_global_rect(), Rect2(452, 300, 72, 72), "the deep slot")
	assert_eq((first.get_node("%Icon") as Control).get_global_rect(), Rect2(456, 304, 64, 64))
	var name_label: Label = first.get_node("%Name") as Label
	assert_eq(name_label.get_global_rect().position.x, 540.0)
	assert_eq(_baseline(name_label), 330.0, "the name, baseline +30")
	var effect: RichTextLabel = first.get_node("%Effect") as RichTextLabel
	assert_eq(effect.get_global_rect().position.x, 540.0)
	assert_eq(_rich_baseline(effect), 356.0, "what it does, baseline +56")
	var count: Label = first.get_node("%Count") as Label
	assert_eq(count.get_global_rect().end.x, 876.0, "the count's right edge")
	assert_eq(_baseline(count), 346.0, "the count, baseline +46")
	assert_eq((first.get_node("%Rule") as Control).get_global_rect(), Rect2(452, 376, 428, 4), "the rule 4 px under the slot, touching the next one")
	assert_eq((first.get_node("%Marks") as Control).get_global_rect(), Rect2(444, 292, 440, 84), "the marks reach 8 px out at the top left and 4 px at the bottom right")

func test_the_groove_sits_beside_the_list() -> void:   # Rulings R3, R15, R17
	for index: int in 8:
		InventoryManager.award_items(_consumable("pill_%d" % index, "Pill %d" % index), 1)
	var tab: Control = await _open_tab()
	assert_eq((tab.get_node("%ConsumablesInventoryList") as Control).get_global_rect(), Rect2(452, 300, 452, 552))
	assert_eq(_rail(tab).get_global_rect(), Rect2(892, 300, 10, 552), "x 892 to 902, y 300 to 852")
	var thumb: Control = _rail(tab).get_node("%Grabber") as Control
	assert_eq(thumb.size, Vector2(4, 48))
	assert_eq(thumb.position.x, 2.0, "the thumb lies in the groove's floor, as in the mockup")

func test_the_list_frame_lets_the_marks_show_whole() -> void:   # Ruling R15
	InventoryManager.award_items(CRUDE, 1)
	var tab: Control = await _open_tab()
	var frame: Control = tab.get_node("ListFrame") as Control
	assert_true(frame.clip_contents, "the frame clips the rows")
	assert_eq(frame.get_global_rect(), Rect2(444, 292, 460, 568))
	var scroll: Control = tab.get_node("%ConsumablesInventoryList").get_node("%ScrollContainer") as Control
	assert_false(scroll.clip_contents, "the list itself does not")
	var row: ConsumableRow = _rows(tab)[0]
	assert_true(row.is_marked(), "the page opens on its first item")
	assert_true(frame.get_global_rect().encloses((row.get_node("%Marks") as Control).get_global_rect()), "its marks show whole")

#-----------------------------------------------------------------------------
# HOVER AND THE DETAILS
#-----------------------------------------------------------------------------

func test_hovering_a_row_marks_it_and_shows_it() -> void:
	InventoryManager.award_items(CRUDE, 1)
	InventoryManager.award_items(_consumable("tea", "Spirit Tea"), 1)
	var tab: Control = _tab()
	var rows: Array[ConsumableRow] = _rows(tab)
	rows[1].hovered.emit(rows[1])
	assert_true(rows[1].is_marked())
	assert_false(rows[0].is_marked())
	assert_eq((_details(tab).get_node("%NameLabel") as Label).text, "Spirit Tea")
	assert_eq((_details(tab).get_node("%KindLabel") as Label).text, "CONSUMABLE")

func test_clicking_a_row_shows_it() -> void:
	InventoryManager.award_items(CRUDE, 1)
	var tea: ConsumableDefinitionData = _consumable("tea", "Spirit Tea")
	InventoryManager.award_items(tea, 1)
	var tab: Control = _tab()
	var rows: Array[ConsumableRow] = _rows(tab)
	rows[1].clicked.emit(rows[1], InputEventMouseButton.new())
	assert_eq(_details(tab).get_consumable(), tea)
	assert_true(rows[1].is_marked())

func test_details_name_the_hotbar_slot() -> void:
	InventoryManager.award_items(CRUDE, 1)
	var tab: Control = _tab()
	InventoryManager.equip_consumable(CRUDE, 0)
	assert_eq((_details(tab).get_node("%KindLabel") as Label).text, "CONSUMABLE · IN SLOT 1")

func test_hovering_a_filled_hotbar_slot_shows_its_consumable() -> void:
	InventoryManager.award_items(CRUDE, 1)
	var tea: ConsumableDefinitionData = _consumable("tea", "Spirit Tea")
	InventoryManager.award_items(tea, 1)
	InventoryManager.equip_consumable(tea, 2)
	var tab: Control = _tab()
	var rows: Array[ConsumableRow] = _rows(tab)
	var slot2: HotbarSlot = _hotbar_slot(tab, 2)
	slot2.hovered.emit(slot2)
	assert_eq(_details(tab).get_consumable(), tea)
	assert_eq((_details(tab).get_node("%KindLabel") as Label).text, "CONSUMABLE · IN SLOT 3")
	assert_true(slot2.is_marked(), "the marks sit round the slot pointed at")
	assert_false(rows[0].is_marked(), "and leave the row shown before")
	assert_false(rows[1].is_marked())
	var slot0: HotbarSlot = _hotbar_slot(tab, 0)
	slot0.hovered.emit(slot0)
	assert_eq(_details(tab).get_consumable(), tea, "an empty slot changes nothing")
	assert_true(slot2.is_marked())
	assert_false(slot0.is_marked())

func test_hotbar_slot_shows_its_stack_on_a_tag() -> void:
	InventoryManager.award_items(CRUDE, 7)
	InventoryManager.equip_consumable(CRUDE, 3)
	var tab: Control = _tab()
	var slot3: HotbarSlot = _hotbar_slot(tab, 3)
	assert_eq((slot3.get_node("%Well") as TextureRect).texture, InventorySlot.DEEP_TEXTURE)
	assert_true((slot3.get_node("%Count") as Control).visible)
	assert_eq((slot3.get_node("%Count") as Label).text, "×7")
	var slot0: HotbarSlot = _hotbar_slot(tab, 0)
	assert_eq((slot0.get_node("%Well") as TextureRect).texture, InventorySlot.SHALLOW_TEXTURE)
	assert_false((slot0.get_node("%Count") as Control).visible)

func test_the_tag_sits_flush_right_and_two_px_up() -> void:   # Ruling R17 (M4)
	InventoryManager.award_items(CRUDE, 7)
	InventoryManager.equip_consumable(CRUDE, 0)
	var tab: Control = await _open_tab()
	var slot_rect: Rect2 = _hotbar_slot(tab, 0).get_global_rect()
	var tag_rect: Rect2 = (_hotbar_slot(tab, 0).get_node("%Count") as Control).get_global_rect()
	assert_eq(tag_rect.end, slot_rect.end - Vector2(0, 2))
	assert_eq(tag_rect.size.y, 20.0, "a one-line tag is as tall as its art")

func test_a_tag_keeps_to_even_pixels() -> void:   # the tag's art on the 2 px grid
	InventoryManager.award_items(CRUDE, 7)
	InventoryManager.equip_consumable(CRUDE, 0)
	var tab: Control = await _open_tab()
	var tag_rect: Rect2 = (_hotbar_slot(tab, 0).get_node("%Count") as Control).get_global_rect()
	assert_eq(tag_rect.size.x, 24.0, "×7 is 13 px of text and 10 of paper, 23, rounded up")
	assert_eq(fmod(tag_rect.position.x, 2.0), 0.0, "so the tag starts on an even x")
	assert_eq(tag_rect.end.x, 1112.0, "and stays flush with the slot's right edge")

func test_hotbar_keys_are_printed_under_the_slots() -> void:
	var tab: Control = await _open_tab()
	var keys: Node = tab.get_node("%ConsumablesHotbar").get_node("KeysRow")
	var texts: Array[String] = []
	for key: Node in keys.get_children():
		texts.append((key as Label).text)
	assert_eq(texts, ["1", "2", "3", "4"] as Array[String])
	var slot_xs: Array[float] = [1040.0, 1152.0, 1264.0, 1376.0]
	for index: int in 4:
		var slot_rect: Rect2 = _hotbar_slot(tab, index).get_global_rect()
		var key: Label = keys.get_child(index) as Label
		assert_eq(slot_rect, Rect2(slot_xs[index], 316, 72, 72), "slot %d" % (index + 1))
		assert_eq(key.get_global_rect().get_center().x, slot_rect.get_center().x, "key %d centred under its slot" % (index + 1))
		assert_eq(_baseline(key), 418.0, "key %d on the spec's baseline" % (index + 1))

func test_drag_over_a_hotbar_slot_marks_it_without_tinting() -> void:
	InventoryManager.award_items(CRUDE, 1)
	var tab: Control = _tab()
	var slot: HotbarSlot = _hotbar_slot(tab, 1)
	slot._can_drop_data(Vector2.ZERO, {"consumable": CRUDE})
	assert_true(slot.is_marked())
	assert_eq(slot.modulate, Color.WHITE)
	slot._notification(NOTIFICATION_DRAG_END)
	assert_false(slot.is_marked())

func test_a_drag_passing_the_shown_slot_leaves_its_marks() -> void:   # Ruling R17 (behaviour)
	InventoryManager.award_items(CRUDE, 1)
	InventoryManager.equip_consumable(CRUDE, 0)
	var tab: Control = _tab()
	var slot: HotbarSlot = _hotbar_slot(tab, 0)
	slot.hovered.emit(slot)
	slot._can_drop_data(Vector2.ZERO, {"consumable": CRUDE})
	slot._notification(NOTIFICATION_DRAG_END)
	assert_true(slot.is_marked(), "the details still show its consumable")

func test_the_marks_fall_back_to_the_row_when_the_slot_loses_its_consumable() -> void:   # Ruling R17 (behaviour)
	InventoryManager.award_items(CRUDE, 1)
	InventoryManager.equip_consumable(CRUDE, 0)
	var tab: Control = _tab()
	var slot: HotbarSlot = _hotbar_slot(tab, 0)
	slot.hovered.emit(slot)
	InventoryManager.unequip_consumable(0)
	assert_false(slot.is_marked())
	assert_true(_rows(tab)[0].is_marked())
	assert_eq(_details(tab).get_consumable(), CRUDE)
	assert_eq((_details(tab).get_node("%KindLabel") as Label).text, "CONSUMABLE")

func test_empty_pack_says_so() -> void:
	var tab: Control = await _open_tab()
	var empty: Label = tab.get_node("%EmptyLabel") as Label
	assert_true(empty.visible)
	assert_eq(empty.text, "No consumables yet.")
	assert_false(_details(tab).visible)
	assert_true((tab.get_node("%ConsumablesHotbar") as Control).visible)

func test_details_stay_on_the_shown_item_when_stacks_change() -> void:   # Review Focus 3
	InventoryManager.award_items(CRUDE, 1)
	var tea: ConsumableDefinitionData = _consumable("tea", "Spirit Tea")
	InventoryManager.award_items(tea, 1)
	var tab: Control = _tab()
	var rows: Array[ConsumableRow] = _rows(tab)
	rows[1].hovered.emit(rows[1])
	InventoryManager.award_items(CRUDE, 1)   # a purchase while the book is open
	assert_eq(_details(tab).get_consumable(), tea)
	var rebuilt: Array[ConsumableRow] = _rows(tab)
	assert_eq((rebuilt[0].get_node("%Count") as Label).text, "×2", "the list was rebuilt")
	assert_true(rebuilt[1].is_marked(), "the marks follow the item to its new row")
	assert_false(rebuilt[0].is_marked())

func test_using_up_the_shown_item_moves_to_the_first() -> void:   # Review Focus 4
	InventoryManager.award_items(CRUDE, 1)
	var tea: ConsumableDefinitionData = _consumable("tea", "Spirit Tea")
	InventoryManager.award_items(tea, 2)
	var tab: Control = _tab()
	var rows: Array[ConsumableRow] = _rows(tab)
	rows[1].hovered.emit(rows[1])
	while InventoryManager.get_inventory().consumables.has(tea):
		InventoryManager.use_consumable(tea)
	assert_eq(_details(tab).get_consumable(), CRUDE)
	var left: Array[ConsumableRow] = _rows(tab)
	assert_eq(left.size(), 1)
	assert_true(left[0].is_marked())
	for index: int in 4:
		assert_false(_hotbar_slot(tab, index).is_marked(), "no marks left behind on slot %d" % (index + 1))

func test_using_up_the_last_item_hides_the_details_and_its_marks() -> void:   # Review Focus 4
	InventoryManager.award_items(CRUDE, 1)
	InventoryManager.equip_consumable(CRUDE, 0)
	var tab: Control = _tab()
	var slot: HotbarSlot = _hotbar_slot(tab, 0)
	slot.hovered.emit(slot)
	assert_true(slot.is_marked())
	InventoryManager.use_consumable(CRUDE)
	assert_eq(_rows(tab).size(), 0)
	assert_false(_details(tab).visible)
	assert_null(_details(tab).get_consumable())
	assert_false(slot.is_marked(), "no marks left behind")
	assert_true((tab.get_node("%EmptyLabel") as Control).visible)

func test_open_page_shows_the_first_item() -> void:
	InventoryManager.award_items(CRUDE, 1)
	InventoryManager.award_items(_consumable("tea", "Spirit Tea"), 1)
	var tab: Control = _tab()
	var rows: Array[ConsumableRow] = _rows(tab)
	rows[1].hovered.emit(rows[1])
	tab.open_page()
	assert_eq(_details(tab).get_consumable(), CRUDE)
	assert_true(_details(tab).visible)
	assert_true(_rows(tab)[0].is_marked())

func test_huge_stack_fits_its_row() -> void:   # Review Focus 2
	InventoryManager.award_items(CRUDE, 1234567)
	InventoryManager.equip_consumable(CRUDE, 0)
	var tab: Control = await _open_tab()
	var row: ConsumableRow = _rows(tab)[0]
	var count: Label = row.get_node("%Count") as Label
	assert_eq(count.text, "×1234567")
	assert_eq(PageBounds.escaping_text(tab), [] as Array[String])
	assert_lte((row.get_node("%Effect") as Control).get_global_rect().end.x, count.get_global_rect().position.x, "the text stops short of the count")
	var slot: HotbarSlot = _hotbar_slot(tab, 0)
	assert_true(slot.get_global_rect().encloses((slot.get_node("%Count") as Control).get_global_rect()), "the tag fits on its slot")

func test_long_names_stay_inside_the_pages() -> void:   # Review Focus 1
	InventoryManager.award_items(_consumable("long", LONG_NAME), 3)
	var tab: Control = await _open_tab()
	assert_eq(PageBounds.escaping_text(tab), [] as Array[String])
	assert_eq(PageBounds.scaled_text(tab), [] as Array[String])
	var row: ConsumableRow = _rows(tab)[0]
	var name_label: Label = row.get_node("%Name") as Label
	assert_gt(name_label.get_line_count(), 1, "the name wraps")
	assert_gte((row.get_node("%Effect") as Control).get_global_rect().position.y, name_label.get_global_rect().end.y, "what it does moves down under the name")
	assert_gt(row.size.y, 72.0, "and the row grows")
	assert_gt((_details(tab).get_node("%NameLabel") as Label).get_line_count(), 1, "the details wrap it too")

func test_pages_have_their_titles() -> void:
	var tab: Control = await _open_tab()
	assert_eq((tab.get_node("LeftTitle").get_node("%TitleLabel") as Label).text, "Consumables")
	assert_eq((tab.get_node("RightTitle").get_node("%TitleLabel") as Label).text, "Hotbar")
	assert_eq(PageBounds.scaled_text(tab), [] as Array[String])

#-----------------------------------------------------------------------------
# THE HINT AND THE DETAILS PANEL
#-----------------------------------------------------------------------------

func test_the_hint_prints_two_lines_on_the_spec_baselines() -> void:   # Ruling R17 (M1, M2)
	var tab: Control = await _open_tab()
	var first: Label = tab.get_node("HintLine1") as Label
	var second: Label = tab.get_node("HintLine2") as Label
	assert_eq(first.text, "Drag a consumable onto a slot to carry it into combat.")
	assert_eq(second.text, "Click a slot to empty it.")
	for line: Label in [first, second]:
		assert_eq(line.theme_type_variation, &"LabelBookDetail")
		assert_eq(line.get_line_count(), 1)
		assert_eq(line.get_global_rect().get_center().x, 1244.0, "centred on the right page")
	assert_eq(_baseline(first), 456.0)
	assert_eq(_baseline(second), 478.0)
	var rule: Control = tab.get_node("HintRule") as Control
	assert_eq(rule.get_global_rect().position.y + (rule.size.y - 4.0) / 2.0, 498.0, "the pressed rule draws at y 498")
	assert_eq(rule.get_global_rect().size.x, 468.0)

func test_details_print_the_effects_and_the_cooldown() -> void:   # Ruling R16
	InventoryManager.award_items(CRUDE, 1)
	var tab: Control = _tab()
	var rows: Array[TableRow] = _table_rows(tab)
	assert_eq(rows.size(), 2, "one row per effect, then the cooldown")
	assert_eq((rows[0].get_node("%Label") as Label).text, "RESTORES")
	assert_eq((rows[0].get_node("%Value") as RichTextLabel).text, "[color=#1c2f60]+20 Madra[/color]")
	assert_eq((rows[1].get_node("%Label") as Label).text, "COOLDOWN")
	assert_eq((rows[1].get_node("%Value") as RichTextLabel).text, "10 s")
	assert_eq((rows[0].get_node("%Value") as RichTextLabel).theme_type_variation, &"RichTextBookValue")
	assert_eq((_details(tab).get_node("%Description") as Label).text, CRUDE.description)
	assert_eq((_details(tab).get_node("%Hint") as Label).text, "Drag it onto the hotbar")
	assert_eq((_details(tab).get_node("%Icon") as TextureRect).texture, CRUDE.icon)

func test_decimal_amounts_keep_their_madra_ink() -> void:   # Rulings 1 and 2
	InventoryManager.award_items(_consumable("dew", "Dew Pill", 7.5, 2.5), 1)
	var tab: Control = _tab()
	var rows: Array[TableRow] = _table_rows(tab)
	var effect: String = (rows[0].get_node("%Value") as RichTextLabel).text
	assert_true(effect.begins_with("[color=#1c2f60]+7"), "the amount is in Madra ink: " + effect)
	assert_true(effect.contains(LacquerText.DECIMAL_POINT_BBCODE), "its decimal point is set")
	assert_false(effect.contains("[lb]"), "and no colour tag is escaped")
	assert_eq((rows[1].get_node("%Value") as RichTextLabel).text, "2" + LacquerText.DECIMAL_POINT_BBCODE + "5 s")

func test_details_lay_the_crude_scale_out_as_the_mockup_does() -> void:   # Rulings R16, R17
	InventoryManager.award_items(CRUDE, 7)
	InventoryManager.equip_consumable(CRUDE, 0)
	var tab: Control = await _open_tab()
	var details: ConsumableDetails = _details(tab)
	assert_eq(details.get_global_rect(), Rect2(1008, 512, 468, 312), "spec: (1008, 512) to (1476, 824)")
	assert_eq((details.get_node("%Icon").get_parent() as Control).get_global_rect(), Rect2(1024, 528, 72, 72), "the deep slot")
	var name_label: Label = details.get_node("%NameLabel") as Label
	assert_eq(name_label.get_global_rect().position.x, 1112.0)
	assert_eq(_baseline(name_label), 568.0, "the name")
	assert_eq(_baseline(details.get_node("%KindLabel") as Label), 594.0, "CONSUMABLE · IN SLOT 1, 26 px under it")
	var rows: Array[TableRow] = _table_rows(tab)
	for index: int in rows.size():
		var baseline: float = 640.0 + 30.0 * index
		assert_eq(_baseline(rows[index].get_node("%Label") as Label), baseline, "row %d's label" % index)
		assert_eq(_rich_baseline(rows[index].get_node("%Value") as RichTextLabel), baseline, "row %d's value" % index)
		assert_eq((rows[index].get_node("%Value") as Control).get_global_rect().end.x, 1458.0, "row %d's value ends at the column's edge" % index)
		assert_eq((rows[index].get_node("%Rule") as Control).get_global_rect(), Rect2(1024, baseline + 8.0, 436, 4), "row %d's rule clears the descenders" % index)
	var description: Label = details.get_node("%Description") as Label
	assert_eq(description.get_line_count(), 3)
	assert_eq(_baseline(description), 712.0, "the description")
	assert_eq(_baseline(details.get_node("%Hint") as Label), 806.0, "the hint")

func test_the_drag_preview_holds_a_64_px_icon_on_the_cursor() -> void:
	var preview: ItemDragPreview = DragPreviewScene.instantiate() as ItemDragPreview
	preview.set_icon(CRUDE.icon)
	add_child_autofree(preview)
	var icon: TextureRect = preview.get_node("%Icon") as TextureRect
	assert_eq(icon.texture, CRUDE.icon)
	assert_eq(icon.get_rect(), Rect2(-32, -32, 64, 64), "centred on the cursor")
