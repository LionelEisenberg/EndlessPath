extends GutTest

## The Equipment tab pressed into the book's pages (spec: Equipment): the page
## of slots under the filter words, a footer with the page slots, the count and
## the discard slot, the gear figure with its six slots, and the details panel
## that follows the pointer and keeps to the item the player picked.

const InventoryViewScene: PackedScene = preload("res://scenes/inventory/inventory_view/inventory_view.tscn")
const DAGGER: EquipmentDefinitionData = preload("res://resources/items/equipment/spirit_valley/makeshift_dagger.tres")
const COWL: EquipmentDefinitionData = preload("res://resources/items/equipment/spirit_valley/cultivators_cowl.tres")
const ROBES: EquipmentDefinitionData = preload("res://resources/items/equipment/spirit_valley/reinforced_robes.tres")
const NECKLACE: EquipmentDefinitionData = preload("res://resources/items/equipment/spirit_valley/dreadbeast_tooth_necklace.tres")
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

func test_clicking_a_word_selects_it() -> void:
	var tab: Control = _tab()
	var words: FilterWords = tab.get_node("%FilterWords") as FilterWords
	var word2: Label = words.get_node("%Word2") as Label
	watch_signals(words)
	word2.gui_input.emit(_press(MOUSE_BUTTON_LEFT))
	assert_eq(words.get_selected(), 2)
	assert_signal_emitted_with_parameters(words, "option_changed", [2])

## 2026-10-28 review: every visit to the page starts unfiltered.
func test_opening_the_page_resets_the_filter() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	var words: FilterWords = tab.get_node("%FilterWords") as FilterWords
	(words.get_node("%Word2") as Label).gui_input.emit(_press(MOUSE_BUTTON_LEFT))   # ARMOR
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	assert_true(slots[0].is_filtered_out(), "the dagger is not armour")
	tab.open_page()
	assert_eq(words.get_selected(), 0, "back on ALL")
	assert_false(slots[0].is_filtered_out(), "nothing is faded")

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

func test_the_shown_pages_button_is_pressed() -> void:
	var tab: Control = await _open_tab()
	var bar: PaginationBar = tab.get_node("%PaginationBar") as PaginationBar
	var first: TextureButton = bar.page_buttons.get_child(0) as TextureButton
	var second: TextureButton = bar.page_buttons.get_child(1) as TextureButton
	assert_true(first.button_pressed)
	assert_false(second.button_pressed)

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

#-----------------------------------------------------------------------------
# THE DETAILS
#-----------------------------------------------------------------------------

func test_details_print_the_slot_and_the_bonuses() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	tab.open_page()
	var details: EquipmentDetails = _details(tab)
	assert_eq((details.get_node("%SlotLabel") as Label).text, "MAIN HAND")
	assert_eq((details.get_node("%Icon") as TextureRect).texture, DAGGER.icon)
	var row: BonusRow = details.get_node("%Bonuses").get_child(0) as BonusRow
	assert_eq((row.get_node("%LeftBonus") as Label).text, "+3 Strength")
	assert_eq((row.get_node("%RightBonus") as Label).text, "+2 Agility")
	assert_eq((details.get_node("%Description") as Label).text, DAGGER.description)

func test_long_names_wrap_inside_the_panel() -> void:   # Review Focus 1
	var tab: Control = await _open_tab()
	var long_def: EquipmentDefinitionData = NECKLACE.duplicate() as EquipmentDefinitionData
	long_def.item_name = "Pill of the Thousand Quiet Mornings Beneath the Valley"
	InventoryManager.award_items(long_def, 1)
	tab.open_page()
	await wait_process_frames(2)
	var details: EquipmentDetails = _details(tab)
	assert_gt((details.get_node("%NameLabel") as Label).get_line_count(), 2, "the name wraps")
	assert_eq(PageBounds.escaping_text(tab), [] as Array[String])

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

func test_discarding_the_shown_item_by_a_drop_moves_on() -> void:   # Review Focus 4
	var tab: Control = await _open_tab()
	InventoryManager.award_items(DAGGER, 1)
	InventoryManager.award_items(COWL, 1)
	var inventory: InventoryData = InventoryManager.get_inventory()
	var dagger: ItemInstanceData = inventory.equipment[0]
	var cowl: ItemInstanceData = inventory.equipment[1]
	var slots: Array[InventorySlot] = tab.equipment_grid.get_slots()
	var trash: TrashSlot = tab.trash_slot
	var over_trash: Vector2 = trash.get_global_rect().get_center()
	tab._on_slot_input(slots[0], _press(MOUSE_BUTTON_LEFT, slots[0].get_global_rect().get_center()))
	tab._input(_motion(over_trash))
	tab._drop_item(over_trash)
	await wait_process_frames(2)
	assert_eq(trash.get_held(), dagger, "the dagger is held in the discard slot")
	assert_eq(_details(tab).get_item(), cowl, "the details move on to the page's first item, though the discard slot holds the dagger")
	assert_true(slots[1].is_marked())
	assert_false(trash.is_marked(), "no marks are left on the discard slot")

func test_pointing_at_the_discard_slot_shows_its_item() -> void:
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	var robes: ItemInstanceData = _instance(ROBES)
	var trash: TrashSlot = tab.trash_slot
	trash.accept(robes)
	tab._on_slot_input(trash, _motion(Vector2.ZERO))
	assert_eq(_details(tab).get_item(), robes)
	assert_true(trash.is_marked())

func test_the_discard_slots_item_stays_shown_while_the_bag_changes() -> void:   # Review Focus 3
	var tab: Control = _tab()
	InventoryManager.award_items(DAGGER, 1)
	var robes: ItemInstanceData = _instance(ROBES)
	var trash: TrashSlot = tab.trash_slot
	trash.accept(robes)
	tab._on_slot_input(trash, _motion(Vector2.ZERO))
	InventoryManager.inventory_changed.emit(InventoryManager.get_inventory())   # as a foraging roll does every 5 s
	await wait_process_frames(2)
	assert_eq(_details(tab).get_item(), robes, "the details keep the item pointed at")
	assert_true(trash.is_marked(), "and so do the marks")
	assert_false(tab.equipment_grid.get_slots()[0].is_marked(), "the page's first item gets none")
