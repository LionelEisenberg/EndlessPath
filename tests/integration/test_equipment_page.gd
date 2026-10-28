extends GutTest

## The Equipment tab pressed into the book's pages (spec: Equipment): a 6x6 page
## of 72 px slots under the filter words, a footer with the page slots, the
## count and the discard slot, the gear figure with its six slots, and the
## details panel that follows the pointer and keeps to the item the player
## picked.

const InventoryViewScene: PackedScene = preload("res://scenes/inventory/inventory_view/inventory_view.tscn")
const DAGGER: EquipmentDefinitionData = preload("res://resources/items/equipment/spirit_valley/makeshift_dagger.tres")
const COWL: EquipmentDefinitionData = preload("res://resources/items/equipment/spirit_valley/cultivators_cowl.tres")
const ROBES: EquipmentDefinitionData = preload("res://resources/items/equipment/spirit_valley/reinforced_robes.tres")
const NECKLACE: EquipmentDefinitionData = preload("res://resources/items/equipment/spirit_valley/dreadbeast_tooth_necklace.tres")
const BARK: EquipmentDefinitionData = preload("res://resources/items/equipment/spirit_valley/scripted_bark.tres")
const SWORD: EquipmentDefinitionData = preload("res://resources/items/equipment/spirit_valley/iron_shortsword.tres")

var _saved_inventory: InventoryData = null
var _view: MenuBookView = null

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

func before_each() -> void:
	_saved_inventory = PersistenceManager.save_game_data.inventory
	PersistenceManager.save_game_data.inventory = InventoryData.new()

func after_each() -> void:
	# PaginationBar.setup() and the details' bonus rows free what they replace
	# a frame late: let that frame pass so GUT counts no orphans.
	await wait_process_frames(1)
	PersistenceManager.save_game_data.inventory = _saved_inventory

## The inventory book's Equipment tab, before the book opens.
func _tab() -> Control:
	_view = InventoryViewScene.instantiate() as MenuBookView
	add_child_autofree(_view)
	return _view.find_child("EquipmentTab", true, false) as Control

## The Equipment tab with the book lying open and its pages laid out.
func _open_tab() -> Control:
	var tab: Control = _tab()
	_view._on_book_opened()
	await wait_process_frames(2)
	return tab

func _details(tab: Control) -> EquipmentDetails:
	return tab.get_node("%EquipmentDetails") as EquipmentDetails

func _gear_slot(tab: Control, slot_name: String) -> GearSlot:
	return tab.get_node("%GearSelector").find_child(slot_name, true, false) as GearSlot

func _instance(def: EquipmentDefinitionData) -> ItemInstanceData:
	var instance: ItemInstanceData = ItemInstanceData.new()
	instance.item_definition = def
	return instance

func _motion(at: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	return event

## Where the line holding the character at `index` sits on screen: the top of
## that line as the engine lays the Label out (its alignment and wrapping
## included), plus the font's ascent.
func _baseline(label: Label, index: int = 0) -> float:
	var ascent: float = label.get_theme_font(&"font").get_ascent(label.get_theme_font_size(&"font_size"))
	return label.get_global_rect().position.y + label.get_character_bounds(index).position.y + ascent

func _press(button: MouseButton, at: Vector2 = Vector2.ZERO) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = at
	event.global_position = at
	return event

#-----------------------------------------------------------------------------
# THE LEFT PAGE
#-----------------------------------------------------------------------------

func test_page_is_six_by_six_slots_of_72_px() -> void:
	var tab: Control = await _open_tab()
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	assert_eq(slots.size(), 36)
	assert_eq(slots[0].size, Vector2(72, 72))
	assert_eq(slots[1].position.x - slots[0].position.x, 76.0)

func test_pieces_sit_where_the_spec_puts_them() -> void:
	var tab: Control = await _open_tab()
	var title: Label = tab.get_node("LeftTitle").get_node("%TitleLabel") as Label
	assert_eq(title.get_global_rect().position.y, 224.0, "the title's baseline at 262")
	var words: Control = tab.get_node("%FilterWords") as Control
	assert_eq(_baseline(words.get_node("%Word0") as Label), 316.0, "the filter on the caption row's baseline")
	assert_eq(_baseline(words.get_node("%Word1") as Label), 316.0, "every word, in use or not")
	assert_eq((words.get_node("%Word0") as Control).get_global_rect(), Rect2(502, 294, 44, 26), "the word in use, its lozenge pressed where the mockup draws it: (502, 294) to (546, 320)")
	assert_eq((tab.equipment_grid as Control).get_global_rect(), Rect2(452, 334, 452, 452))
	assert_eq((tab.get_node("%PaginationBar") as Control).get_global_rect(), Rect2(452, 796, 452, 72))
	assert_eq((tab.get_node("%GearSelector") as Control).get_global_rect(), Rect2(1008, 300, 468, 268))
	assert_eq((tab.get_node("%EquipmentDetails") as Control).get_global_rect(), Rect2(1008, 606, 468, 272))
	assert_eq(_gear_slot(tab, "HeadGearSlot").get_global_rect(), Rect2(1016, 300, 72, 72))
	assert_eq(_gear_slot(tab, "MainWeaponGearSlot").get_global_rect().position, Vector2(1016, 398))
	assert_eq(_gear_slot(tab, "Accessory1GearSlot").get_global_rect().position, Vector2(1016, 496))
	assert_eq(_gear_slot(tab, "ArmorGearSlot").get_global_rect().position, Vector2(1400, 300))
	assert_eq(_gear_slot(tab, "OffhandGearSlot").get_global_rect().position, Vector2(1400, 398))
	assert_eq(_gear_slot(tab, "Accessory2GearSlot").get_global_rect().position, Vector2(1400, 496))

func test_filter_words_print_the_categories_and_start_on_all() -> void:
	var tab: Control = _tab()
	var words: FilterWords = tab.get_node("%FilterWords") as FilterWords
	var texts: Array[String] = []
	for index: int in 4:
		texts.append((words.get_node("%%Word%d" % index) as Label).text)
	assert_eq(texts, ["ALL", "WEAPONS", "ARMOR", "ACCESSORIES"] as Array[String])
	assert_eq(words.get_selected(), 0)
	assert_eq((words.get_node("%Word0") as Label).theme_type_variation, &"LabelBookFilterOn")
	assert_eq((words.get_node("%Word1") as Label).theme_type_variation, &"LabelBookFilter")

func test_filter_words_sit_on_the_2_px_grid() -> void:
	var tab: Control = await _open_tab()
	var words: FilterWords = tab.get_node("%FilterWords") as FilterWords
	var row_left: float = INF
	var row_right: float = -INF
	for index: int in 4:
		var rect: Rect2 = (words.get_node("%%Word%d" % index) as Control).get_global_rect()
		assert_eq(fmod(rect.position.x, 2.0), 0.0, "word %d, and its lozenge, starts on an even x" % index)
		assert_eq(fmod(rect.size.x, 2.0), 0.0, "word %d is an even width" % index)
		row_left = minf(row_left, rect.position.x)
		row_right = maxf(row_right, rect.end.x)
	assert_almost_eq((row_left + row_right) / 2.0, 678.0, 1.0, "the row stays centred on the left page")

func test_clicking_a_word_selects_it() -> void:
	var tab: Control = _tab()
	var words: FilterWords = tab.get_node("%FilterWords") as FilterWords
	var word2: Label = words.get_node("%Word2") as Label
	watch_signals(words)
	word2.gui_input.emit(_press(MOUSE_BUTTON_LEFT))
	assert_eq(words.get_selected(), 2)
	assert_signal_emitted_with_parameters(words, "option_changed", [2])
	assert_eq(word2.theme_type_variation, &"LabelBookFilterOn")
	assert_eq((words.get_node("%Word0") as Label).theme_type_variation, &"LabelBookFilter")

func test_a_shorter_filter_hides_the_words_it_does_not_use() -> void:
	var tab: Control = _tab()
	var words: FilterWords = tab.get_node("%FilterWords") as FilterWords
	watch_signals(words)
	words.select(3)
	words.set_options(PackedStringArray(["ALL", "WEAPONS"]))
	assert_true((words.get_node("%Word1") as Label).visible)
	assert_false((words.get_node("%Word2") as Label).visible)
	assert_false((words.get_node("%Word3") as Label).visible)
	assert_eq(words.get_selected(), 0, "a new set of words starts on the first")
	assert_signal_not_emitted(words, "option_changed")

func test_count_is_the_bag_against_its_capacity() -> void:
	var tab: Control = _tab()
	for def: EquipmentDefinitionData in [DAGGER, COWL, ROBES]:
		InventoryManager.award_items(def, 1)
	assert_eq((tab.get_node("%PaginationBar").get_node("%CountLabel") as Label).text, "3 / 72")

func test_count_ends_16_px_before_the_discard_slot() -> void:   # Ruling R2
	var tab: Control = await _open_tab()
	var count: Label = tab.get_node("%PaginationBar").get_node("%CountLabel") as Label
	assert_eq(tab.trash_slot.get_global_rect(), Rect2(832, 796, 72, 72))
	assert_eq(count.get_global_rect().end.x, 816.0)

func test_five_pages_fit_the_footer() -> void:                     # Review Focus 5
	var tab: Control = await _open_tab()
	var inventory: InventoryData = InventoryManager.get_inventory()
	inventory.unlocked_equipment_pages = 5
	InventoryManager.inventory_changed.emit(inventory)
	await wait_process_frames(2)
	var bar: PaginationBar = tab.get_node("%PaginationBar") as PaginationBar
	var count: Label = bar.get_node("%CountLabel") as Label
	assert_eq(bar.page_buttons.get_child_count(), 5)
	assert_eq(count.text, "0 / 180")
	assert_eq(PageBounds.escaping_text(bar), [] as Array[String])
	assert_true(PageBounds.LEFT_PAGE.encloses(bar.get_global_rect()))
	var last_page: Control = bar.page_buttons.get_child(4) as Control
	assert_lt(last_page.get_global_rect().end.x, count.get_global_rect().position.x, "the page slots stop short of the count")

func test_page_buttons_press_the_shown_page_deep() -> void:
	var tab: Control = await _open_tab()
	var bar: PaginationBar = tab.get_node("%PaginationBar") as PaginationBar
	var first: TextureButton = bar.page_buttons.get_child(0) as TextureButton
	var second: TextureButton = bar.page_buttons.get_child(1) as TextureButton
	assert_eq(first.size, Vector2(28, 28))
	assert_eq(first.get_global_rect().position.y, 818.0)
	assert_true(first.button_pressed)
	assert_false(second.button_pressed)
	assert_eq(first.texture_pressed.resource_path, "res://assets/sprites/ui/book/pressed/pressed_page_deep_ai.png")
	assert_eq(first.texture_normal.resource_path, "res://assets/sprites/ui/book/pressed/pressed_page_shallow_ai.png")
	assert_eq((second.get_node("PageNumber") as Label).text, "2")

func test_footer_prints_on_one_baseline_with_its_slots_on_the_grid() -> void:
	var tab: Control = await _open_tab()
	var bar: PaginationBar = tab.get_node("%PaginationBar") as PaginationBar
	assert_eq(_baseline(bar.get_node("%PageLabel") as Label), 838.0, "PAGE")
	assert_eq(_baseline(bar.get_node("%CountLabel") as Label), 838.0, "the count")
	for button: Node in bar.page_buttons.get_children():
		var page_slot: Control = button as Control
		assert_eq(_baseline(page_slot.get_node("PageNumber") as Label), 838.0, "page %d's number" % (page_slot.get_index() + 1))
		assert_eq(fmod(page_slot.get_global_rect().position.x, 2.0), 0.0, "page %d's slot sits on the 2 px grid" % (page_slot.get_index() + 1))

func test_footer_prints_page_where_the_mockup_does() -> void:   # Ruling R17: the spec says only "at the left"
	var tab: Control = await _open_tab()
	var bar: PaginationBar = tab.get_node("%PaginationBar") as PaginationBar
	assert_eq((bar.get_node("%PageLabel") as Control).get_global_rect().end.x, 536.0, "PAGE ends at the mockup's x 536")
	assert_eq((bar.page_buttons.get_child(0) as Control).get_global_rect().position.x, 556.0, "the first page slot 20 px after it")
	assert_eq((bar.page_buttons.get_child(1) as Control).get_global_rect().position.x, 592.0, "the next at a 36 px pitch")

func test_discard_slot_shows_its_cross_only_when_empty() -> void:
	var tab: Control = _tab()
	var trash: TrashSlot = tab.trash_slot
	assert_true((trash.get_node("%Cross") as Control).visible)
	assert_eq(trash.texture, InventorySlot.SHALLOW_TEXTURE)
	trash.accept(_instance(DAGGER))
	assert_false((trash.get_node("%Cross") as Control).visible)
	assert_eq(trash.texture, InventorySlot.DEEP_TEXTURE)

func test_a_slot_is_deep_only_while_it_holds_an_item() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	assert_eq(slots[0].texture, InventorySlot.DEEP_TEXTURE)
	assert_eq(slots[1].texture, InventorySlot.SHALLOW_TEXTURE)
	assert_eq(_gear_slot(tab, "HeadGearSlot").texture, InventorySlot.SHALLOW_TEXTURE, "an empty gear slot is shallow too")

#-----------------------------------------------------------------------------
# THE GEAR PAGE
#-----------------------------------------------------------------------------

func test_main_hand_sits_left_of_the_figure() -> void:
	var tab: Control = await _open_tab()
	var plate_mid: float = (tab.get_node("%GearSelector").get_node("Plate") as Control).get_global_rect().get_center().x
	assert_lt(_gear_slot(tab, "MainWeaponGearSlot").get_global_rect().get_center().x, plate_mid)
	assert_gt(_gear_slot(tab, "ArmorGearSlot").get_global_rect().get_center().x, plate_mid)

func test_each_gear_slot_is_named_under_it() -> void:
	var tab: Control = await _open_tab()
	var names: Dictionary[String, String] = {
		"HeadGearSlot": "HEAD", "MainWeaponGearSlot": "MAIN HAND", "Accessory1GearSlot": "ACCESSORY",
		"ArmorGearSlot": "BODY", "OffhandGearSlot": "OFF HAND", "Accessory2GearSlot": "ACCESSORY",
	}
	var captions: Array[Label] = []
	for child: Node in tab.get_node("%GearSelector").get_children():
		if child is Label:
			captions.append(child as Label)
	assert_eq(captions.size(), 6)
	for slot_name: String in names:
		var slot_rect: Rect2 = _gear_slot(tab, slot_name).get_global_rect()
		var found: bool = false
		for caption: Label in captions:
			var rect: Rect2 = caption.get_global_rect()
			# Ruling R9: the spec's baseline, slot top + 94.
			if is_equal_approx(rect.get_center().x, slot_rect.get_center().x) and is_equal_approx(_baseline(caption), slot_rect.position.y + 94.0):
				found = true
				assert_eq(caption.text, names[slot_name], slot_name)
				assert_eq(caption.theme_type_variation, &"LabelBookCaps", slot_name)
		assert_true(found, "%s has its name centred under it, its baseline 94 px down the slot" % slot_name)

#-----------------------------------------------------------------------------
# HOVER AND DRAG
#-----------------------------------------------------------------------------

func test_hovering_an_item_marks_it_and_shows_it() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	var slot0: InventorySlot = tab.equipment_grid.get_slots()[0]
	tab._on_slot_input(slot0, _motion(Vector2.ZERO))
	assert_true(slot0.is_marked())
	assert_eq((_details(tab).get_node("%NameLabel") as Label).text, "Makeshift Dagger")

func test_hovering_an_empty_slot_keeps_the_last_item() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	tab._on_slot_input(slots[0], _motion(Vector2.ZERO))
	tab._on_slot_input(slots[5], _motion(Vector2.ZERO))
	assert_true(slots[0].is_marked())
	assert_false(slots[5].is_marked())
	assert_eq(_details(tab).get_item(), InventoryManager.get_inventory().equipment[0])

func test_drag_marks_only_a_slot_that_would_take_the_item() -> void:
	var tab: Control = await _open_tab()
	InventoryManager.award_items(DAGGER, 1)
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	var main_hand: GearSlot = _gear_slot(tab, "MainWeaponGearSlot")
	var head: GearSlot = _gear_slot(tab, "HeadGearSlot")
	var origin: Vector2 = slots[0].get_global_rect().get_center()
	tab._on_slot_input(slots[0], _press(MOUSE_BUTTON_LEFT, origin))
	assert_true(tab.is_dragging, "the dagger is picked up")
	assert_eq(tab.dragged_item.size, Vector2(72, 72))
	assert_eq(tab.dragged_item.z_index, 10)
	assert_eq(tab.dragged_item.global_position, origin + Vector2(-36, -36), "held by its centre")
	assert_false(slots[0].is_marked(), "the slot it left is empty, so unmarked")
	tab._input(_motion(main_hand.get_global_rect().get_center()))
	assert_true(main_hand.is_marked(), "the main hand would take the dagger")
	tab._input(_motion(head.get_global_rect().get_center()))
	assert_false(head.is_marked(), "the head would refuse it")
	assert_false(main_hand.is_marked(), "the last target is unmarked")
	tab._input(_motion(origin))
	assert_false(slots[0].is_marked(), "nor is the slot it came from a target")
	tab._input(_motion(slots[1].get_global_rect().get_center()))
	assert_true(slots[1].is_marked(), "another grid slot would take it")
	tab._input(_motion(tab.trash_slot.get_global_rect().get_center()))
	assert_true(tab.trash_slot.is_marked(), "so would the discard slot")
	assert_false(slots[1].is_marked())
	tab._drop_item(Vector2(-100, -100))   # dropped on nothing: it goes back
	assert_false(tab.trash_slot.is_marked(), "the drop clears the target")
	await wait_process_frames(2)
	assert_true(slots[0].is_marked(), "the marks are back on the dagger")

func test_worn_gear_over_a_mismatched_item_marks_nothing() -> void:   # Ruling R13
	var tab: Control = await _open_tab()
	for def: EquipmentDefinitionData in [DAGGER, COWL, SWORD]:
		InventoryManager.award_items(def, 1)
	var inventory: InventoryData = InventoryManager.get_inventory()
	var dagger: ItemInstanceData = inventory.equipment[0]
	InventoryManager.equip_item(dagger, EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, 0)
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	var main_hand: GearSlot = _gear_slot(tab, "MainWeaponGearSlot")
	tab._on_slot_input(main_hand, _press(MOUSE_BUTTON_LEFT, main_hand.get_global_rect().get_center()))
	assert_true(tab.is_dragging, "the worn dagger is picked up")
	tab._input(_motion(slots[1].get_global_rect().get_center()))
	assert_false(slots[1].is_marked(), "the cowl can't go to the main hand, so a drop there is refused")
	tab._input(_motion(slots[2].get_global_rect().get_center()))
	assert_true(slots[2].is_marked(), "the shortsword fits the main hand: the two would swap")
	tab._input(_motion(slots[0].get_global_rect().get_center()))
	assert_true(slots[0].is_marked(), "an empty slot takes it")
	tab._drop_item(slots[1].get_global_rect().get_center())
	assert_eq(inventory.equipped_gear.get(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND), dagger, "dropped on the cowl, the dagger goes back to the main hand")
	assert_eq((inventory.equipment.get(1) as ItemInstanceData).item_definition, COWL, "and the cowl stays put")

func test_a_gear_origin_drag_back_over_its_own_slot_marks_nothing() -> void:   # Ruling R13
	var tab: Control = await _open_tab()
	InventoryManager.award_items(DAGGER, 1)
	InventoryManager.equip_item(InventoryManager.get_inventory().equipment[0], EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, 0)
	var main_hand: GearSlot = _gear_slot(tab, "MainWeaponGearSlot")
	var centre: Vector2 = main_hand.get_global_rect().get_center()
	tab._on_slot_input(main_hand, _press(MOUSE_BUTTON_LEFT, centre))
	tab._input(_motion(tab.equipment_grid.get_slots()[3].get_global_rect().get_center()))
	tab._input(_motion(centre))
	assert_false(main_hand.is_marked(), "the slot it came from is never a target")

func test_an_item_out_of_the_discard_slot_marks_the_slot_it_would_fill() -> void:   # Ruling R13
	var tab: Control = await _open_tab()
	InventoryManager.award_items(DAGGER, 1)
	InventoryManager.award_items(COWL, 1)
	var robes: ItemInstanceData = _instance(ROBES)
	var trash: TrashSlot = tab.trash_slot
	trash.accept(robes)
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	tab._on_slot_input(trash, _press(MOUSE_BUTTON_LEFT, trash.get_global_rect().get_center()))
	assert_true(tab.is_dragging, "the robes are picked up out of the discard slot")
	tab._input(_motion(slots[0].get_global_rect().get_center()))
	assert_false(slots[0].is_marked(), "the dagger holds that slot: the robes wouldn't land there")
	assert_true(slots[2].is_marked(), "they would land in the bag's first free slot")
	tab._input(_motion(slots[7].get_global_rect().get_center()))
	assert_true(slots[7].is_marked(), "dropped on an empty slot, they land in it")
	assert_false(slots[2].is_marked())
	tab._input(_motion(trash.get_global_rect().get_center()))
	assert_false(trash.is_marked(), "nor is the discard slot they came out of a target")
	tab._drop_item(slots[0].get_global_rect().get_center())
	assert_eq(InventoryManager.get_inventory().equipment.get(2), robes, "dropped on the dagger, the robes land in the first free slot")

func test_an_item_out_of_the_discard_slot_marks_nothing_when_it_would_land_out_of_sight() -> void:   # Ruling R13
	var tab: Control = await _open_tab()
	InventoryManager.award_items(DAGGER, InventoryData.SLOTS_PER_PAGE)   # the page shown is full
	var trash: TrashSlot = tab.trash_slot
	trash.accept(_instance(ROBES))
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	tab._on_slot_input(trash, _press(MOUSE_BUTTON_LEFT, trash.get_global_rect().get_center()))
	tab._input(_motion(slots[0].get_global_rect().get_center()))
	var marked: Array[InventorySlot] = slots.filter(func(slot: InventorySlot) -> bool: return slot.is_marked())
	assert_eq(marked.size(), 0, "the first free slot is on the next page, so nothing on this one is marked")

func test_a_drop_moves_the_marks_to_where_the_item_lands() -> void:
	var tab: Control = await _open_tab()
	InventoryManager.award_items(DAGGER, 1)
	var dagger: ItemInstanceData = InventoryManager.get_inventory().equipment[0]
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	var landing: Vector2 = slots[7].get_global_rect().get_center()
	tab._on_slot_input(slots[0], _press(MOUSE_BUTTON_LEFT, slots[0].get_global_rect().get_center()))
	tab._input(_motion(landing))
	tab._drop_item(landing)
	await wait_process_frames(2)
	assert_eq(InventoryManager.get_inventory().equipment.get(7), dagger)
	assert_true(slots[7].is_marked())
	assert_false(slots[0].is_marked())
	assert_eq(_details(tab).get_item(), dagger)

func test_wearing_the_shown_item_moves_its_marks_to_the_gear_slot() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	tab._on_slot_input(slots[0], _press(MOUSE_BUTTON_RIGHT))   # a right-click wears it
	await wait_process_frames(2)
	assert_true(_gear_slot(tab, "MainWeaponGearSlot").is_marked())
	assert_false(slots[0].is_marked())
	assert_eq((_details(tab).get_node("%Hint") as Label).text, "Right-click to take it off")

#-----------------------------------------------------------------------------
# THE DETAILS
#-----------------------------------------------------------------------------

func test_details_print_the_slot_the_bonuses_and_the_hint() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	tab.open_page()
	var details: EquipmentDetails = _details(tab)
	assert_eq((details.get_node("%SlotLabel") as Label).text, "MAIN HAND")
	assert_eq((details.get_node("%Icon") as TextureRect).texture, DAGGER.icon)
	var rows: Node = details.get_node("%Bonuses")
	assert_eq(rows.get_child_count(), 1, "two bonuses share a row")
	var row: BonusRow = rows.get_child(0) as BonusRow
	assert_eq((row.get_node("%LeftName") as Label).text, "STRENGTH")
	assert_eq((row.get_node("%LeftValue") as Label).text, "+3")
	assert_eq((row.get_node("%RightName") as Label).text, "AGILITY")
	assert_eq((row.get_node("%RightValue") as Label).text, "+2")
	assert_eq((details.get_node("%Description") as Label).text, DAGGER.description)
	assert_eq((details.get_node("%Hint") as Label).text, "Right-click to wear it")

func test_a_lone_bonus_leaves_the_right_half_empty() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(BARK, 1)
	tab.open_page()
	var row: BonusRow = _details(tab).get_node("%Bonuses").get_child(0) as BonusRow
	assert_eq((row.get_node("%LeftName") as Label).text, "BODY")
	assert_false((row.get_node("%RightName") as Label).visible)
	assert_false((row.get_node("%RightValue") as Label).visible)

func test_longest_item_fits_with_its_hint() -> void:
	var tab: Control = await _open_tab()
	InventoryManager.award_items(NECKLACE, 1)
	tab.open_page()
	await wait_process_frames(2)
	var details: EquipmentDetails = _details(tab)
	var name_label: Label = details.get_node("%NameLabel") as Label
	assert_eq(name_label.text, "Dreadbeast Tooth Necklace")
	assert_eq(name_label.get_line_count(), 2)
	assert_eq(details.get_node("%Bonuses").get_child_count(), 1)
	assert_true((details.get_node("%Hint") as Label).visible)
	assert_eq(details.size.y, 272.0, "the panel keeps its height")
	assert_eq(PageBounds.escaping_text(tab), [] as Array[String])

func test_long_names_wrap_inside_the_panel_and_drop_the_hint() -> void:   # Review Focus 1
	var tab: Control = await _open_tab()
	var long_def: EquipmentDefinitionData = NECKLACE.duplicate() as EquipmentDefinitionData
	long_def.item_name = "Pill of the Thousand Quiet Mornings Beneath the Valley"
	InventoryManager.award_items(long_def, 1)
	tab.open_page()
	await wait_process_frames(2)
	var details: EquipmentDetails = _details(tab)
	assert_gt((details.get_node("%NameLabel") as Label).get_line_count(), 2, "the name wraps")
	assert_false((details.get_node("%Hint") as Label).visible, "the hint gives way")
	assert_eq(details.size.y, 272.0, "the panel keeps its height")
	assert_eq(PageBounds.escaping_text(tab), [] as Array[String])

func test_hint_gives_way_first() -> void:
	# The text must end at least 24 px above the hint's line: by content y 208,
	# where the necklace's ends. The header is the name column, 64 + 34 per extra
	# line, but never under the 72 px icon slot; the bonuses take 16 + 28 per row
	# + 6 between rows; the description 40 + 26 per extra line.
	assert_true(EquipmentDetails.wants_hint(2, 2, 2), "the necklace: 98 + 44 + 66 = 208")
	assert_true(EquipmentDetails.wants_hint(4, 0, 1), "166 + 0 + 40 = 206")
	assert_true(EquipmentDetails.wants_hint(1, 4, 1), "72 + 78 + 40 = 190")
	assert_true(EquipmentDetails.wants_hint(1, 2, 3), "72 + 44 + 92 = 208: one line of name less pays for one of description")
	assert_false(EquipmentDetails.wants_hint(2, 4, 2), "98 + 78 + 66 = 242")
	assert_false(EquipmentDetails.wants_hint(2, 3, 2), "a third bonus takes a second row: 242")
	assert_false(EquipmentDetails.wants_hint(2, 4, 1), "98 + 78 + 40 = 216")
	assert_false(EquipmentDetails.wants_hint(2, 2, 3), "98 + 44 + 92 = 234")
	assert_false(EquipmentDetails.wants_hint(3, 2, 1), "132 + 44 + 40 = 216")
	assert_false(EquipmentDetails.wants_hint(1, 2, 4), "72 + 44 + 118 = 234")
	assert_false(EquipmentDetails.wants_hint(2, 5, 1), "98 + 112 + 40 = 250")

func test_the_hint_rule_reads_the_laid_out_panel() -> void:
	var tab: Control = await _open_tab()
	var details: EquipmentDetails = _details(tab)
	var four_bonuses: EquipmentDefinitionData = NECKLACE.duplicate() as EquipmentDefinitionData
	four_bonuses.attribute_bonuses = {0: 2.0, 1: 3.0, 2: 4.0, 3: 5.0}
	var long_name: EquipmentDefinitionData = NECKLACE.duplicate() as EquipmentDefinitionData
	long_name.item_name = "Pill of the Thousand Quiet Mornings Beneath the Valley"
	for def: EquipmentDefinitionData in [NECKLACE, DAGGER, BARK, four_bonuses, long_name]:
		details.show_item(_instance(def), false)
		await wait_process_frames(2)
		var name_lines: int = (details.get_node("%NameLabel") as Label).get_line_count()
		var description: Label = details.get_node("%Description") as Label
		var expected: int = EquipmentDetails._text_height(name_lines, BookText.bonus_pairs(def).size(), description.get_line_count())
		assert_eq(description.get_global_rect().end.y - 622.0, float(expected), "%s's text ends where wants_hint() reckons" % def.item_name)
		for row: Node in details.get_node("%Bonuses").get_children():
			var rule_y: float = (row.get_node("Rule") as Control).get_global_rect().position.y
			assert_eq(fmod(rule_y, 2.0), 0.0, "%s's rule at %d is on an even pixel" % [def.item_name, rule_y])
	assert_eq((details.get_node("%Hint") as Label).get_global_rect().position.y - 622.0, 232.0, "the hint's line")

func test_details_lay_the_longest_item_out_as_the_spec_does() -> void:   # Ruling R10
	var tab: Control = await _open_tab()
	InventoryManager.award_items(NECKLACE, 1)
	tab.open_page()
	await wait_process_frames(2)
	var details: EquipmentDetails = _details(tab)
	var name_label: Label = details.get_node("%NameLabel") as Label
	var row: BonusRow = details.get_node("%Bonuses").get_child(0) as BonusRow
	assert_eq((details.get_node("%Icon").get_parent() as Control).get_global_rect(), Rect2(1024, 622, 72, 72), "the item's deep slot")
	assert_eq(name_label.get_global_rect().position.x, 1112.0)
	assert_eq(_baseline(name_label), 654.0, "the name's first line")
	assert_eq(_baseline(name_label, name_label.text.find("Necklace")), 688.0, "and its second")
	assert_eq(_baseline(details.get_node("%SlotLabel") as Label), 714.0, "the slot, 26 px under the name's last line")
	assert_eq((details.get_node("%SlotLabel") as Control).get_global_rect().position.x, 1114.0, "2 px in, its ink under the name's at the mockup's x 1114 (Ruling R22)")
	assert_eq(_baseline(row.get_node("%LeftValue") as Label), 752.0, "the first bonus row")
	assert_eq(_baseline(row.get_node("%LeftName") as Label), 752.0, "its attribute on the same line")
	assert_eq((row.get_node("Rule") as Control).get_global_rect().position.y, 760.0, "the pressed rule 8 px under it, as the mockup rules it")
	assert_eq(_baseline(details.get_node("%Description") as Label), 798.0, "the description")
	assert_eq(_baseline(details.get_node("%Hint") as Label), 866.0, "the hint, at the panel's foot")

func test_a_shorter_item_flows_up_from_the_same_gaps() -> void:   # Ruling R10
	var tab: Control = await _open_tab()
	InventoryManager.award_items(DAGGER, 1)
	tab.open_page()
	await wait_process_frames(2)
	var details: EquipmentDetails = _details(tab)
	var row: BonusRow = details.get_node("%Bonuses").get_child(0) as BonusRow
	assert_eq((details.get_node("%NameLabel") as Label).get_line_count(), 1)
	assert_eq(_baseline(details.get_node("%SlotLabel") as Label), 680.0, "26 px under the one line of name")
	assert_eq(_baseline(row.get_node("%LeftValue") as Label), 726.0, "16 px under the 72 px icon slot, 26 px higher than the necklace's")
	assert_eq((row.get_node("Rule") as Control).get_global_rect().position.y, 734.0, "the rule 8 px under it, on an even pixel")
	assert_eq(_baseline(details.get_node("%Hint") as Label), 866.0, "the hint stays at the foot")

func test_open_page_shows_the_first_item() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	InventoryManager.award_items(COWL, 1)
	var dagger: ItemInstanceData = InventoryManager.get_inventory().equipment[0]
	tab.open_page()
	assert_eq(_details(tab).get_item(), dagger)
	assert_true(_details(tab).visible)
	assert_true(tab.equipment_grid.get_slots()[0].is_marked())

func test_open_page_falls_back_to_worn_gear_then_hides() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(COWL, 1)
	var cowl: ItemInstanceData = InventoryManager.get_inventory().equipment[0]
	InventoryManager.equip_item(cowl, EquipmentDefinitionData.EquipmentSlot.HEAD, 0)
	tab.open_page()
	assert_eq(_details(tab).get_item(), cowl)
	assert_true(_gear_slot(tab, "HeadGearSlot").is_marked())
	var empty: InventoryData = InventoryData.new()
	PersistenceManager.save_game_data.inventory = empty
	InventoryManager.inventory_changed.emit(empty)
	tab.open_page()
	assert_false(_details(tab).visible)
	assert_null(_details(tab).get_item())
	assert_false(_gear_slot(tab, "HeadGearSlot").is_marked(), "no marks left behind")

func test_open_page_takes_worn_gear_in_the_figures_order() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(ROBES, 1)
	InventoryManager.award_items(DAGGER, 1)
	var inventory: InventoryData = InventoryManager.get_inventory()
	var robes: ItemInstanceData = inventory.equipment[0]
	var dagger: ItemInstanceData = inventory.equipment[1]
	InventoryManager.equip_item(robes, EquipmentDefinitionData.EquipmentSlot.ARMOR, 0)
	InventoryManager.equip_item(dagger, EquipmentDefinitionData.EquipmentSlot.MAIN_HAND, 1)
	tab.open_page()
	assert_eq(_details(tab).get_item(), dagger, "the main hand comes before the body")
	assert_eq((_details(tab).get_node("%Hint") as Label).text, "Right-click to take it off")

func test_details_keep_to_the_picked_item_when_the_bag_changes() -> void:   # Review Focus 3
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	InventoryManager.award_items(COWL, 1)
	var cowl: ItemInstanceData = InventoryManager.get_inventory().equipment[1]
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	tab._on_slot_input(slots[1], _motion(Vector2.ZERO))
	InventoryManager.award_items(ROBES, 1)   # a purchase while the book is open
	await wait_process_frames(2)
	assert_eq(_details(tab).get_item(), cowl)
	assert_true(slots[1].is_marked())
	assert_false(slots[0].is_marked())

func test_the_marks_leave_the_page_with_the_item() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	var dagger: ItemInstanceData = InventoryManager.get_inventory().equipment[0]
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	var bar: PaginationBar = tab.get_node("%PaginationBar") as PaginationBar
	tab._on_slot_input(slots[0], _motion(Vector2.ZERO))
	bar.page_selected.emit(1)
	await wait_process_frames(1)
	assert_false(slots[0].is_marked(), "the dagger is on the other page")
	assert_eq(_details(tab).get_item(), dagger, "the details keep it")
	bar.page_selected.emit(0)
	await wait_process_frames(1)
	assert_true(slots[0].is_marked(), "back on its page, so marked again")

func test_discarding_the_shown_item_moves_on() -> void:            # Review Focus 4
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	InventoryManager.award_items(COWL, 1)
	var inventory: InventoryData = InventoryManager.get_inventory()
	var dagger: ItemInstanceData = inventory.equipment[0]
	var cowl: ItemInstanceData = inventory.equipment[1]
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	tab._on_slot_input(slots[0], _motion(Vector2.ZERO))
	assert_eq(_details(tab).get_item(), dagger)
	# A discard erases the item from the bag and announces the change.
	inventory.equipment.erase(0)
	InventoryManager.inventory_changed.emit(inventory)
	await wait_process_frames(2)
	assert_ne(_details(tab).get_item(), dagger)
	assert_eq(_details(tab).get_item(), cowl, "the page's first item")
	assert_false(slots[0].is_marked() and slots[0].item_instance == null, "no marks on an empty slot")
	assert_true(slots[1].is_marked())

func test_pages_have_their_titles_and_draw_text_at_1x() -> void:
	var tab: Control = await _open_tab()
	assert_eq((tab.get_node("LeftTitle").get_node("%TitleLabel") as Label).text, "Equipment")
	assert_eq((tab.get_node("RightTitle").get_node("%TitleLabel") as Label).text, "Gear")
	assert_eq(PageBounds.scaled_text(tab), [] as Array[String])

func test_the_right_title_is_centred_on_the_page() -> void:   # the spec's "title centre 1244"
	var tab: Control = await _open_tab()
	var title: Control = tab.get_node("RightTitle") as Control
	assert_eq(title.get_global_rect().get_center().x, 1244.0, "over the figure's middle")
	assert_eq(fmod(title.get_global_rect().size.x, 2.0), 0.0, "an even width")
	assert_eq((title.get_node("%Ornament") as Control).get_global_rect().get_center().x, 1244.0, "and its ornament under it")
