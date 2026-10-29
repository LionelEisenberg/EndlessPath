extends GutTest

## The Consumables tab pressed into the book's pages (spec: Consumables). The
## left page lists the stacks; the right page holds the hotbar and the details
## panel. The details follow the pointer and keep to the consumable the player
## picked.

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

func _hotbar_slot(tab: Control, index: int) -> HotbarSlot:
	return tab.get_node("%ConsumablesHotbar").get_node("SlotsRow").get_child(index) as HotbarSlot

func _details(tab: Control) -> ConsumableDetails:
	return tab.get_node("%ConsumableDetails") as ConsumableDetails

func _table_rows(tab: Control) -> Array[TableRow]:
	var rows: Array[TableRow] = []
	for node: Node in _details(tab).get_node("%Effects").get_children():
		rows.append(node as TableRow)
	return rows

#-----------------------------------------------------------------------------
# THE LIST
#-----------------------------------------------------------------------------

func test_rows_show_name_and_count() -> void:
	InventoryManager.award_items(CRUDE, 7)
	var tab: Control = _tab()
	var row: ConsumableRow = _rows(tab)[0]
	assert_eq((row.get_node("%Name") as Label).text, "Crude Scale")
	assert_eq((row.get_node("%Count") as Label).text, "×7")

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

func test_clicking_a_row_shows_it() -> void:
	InventoryManager.award_items(CRUDE, 1)
	var tea: ConsumableDefinitionData = _consumable("tea", "Spirit Tea")
	InventoryManager.award_items(tea, 1)
	var tab: Control = _tab()
	var rows: Array[ConsumableRow] = _rows(tab)
	rows[1].clicked.emit(rows[1], InputEventMouseButton.new())
	assert_eq(_details(tab).get_consumable(), tea)
	assert_true(rows[1].is_marked())

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
	assert_true((slot3.get_node("%Count") as Control).visible)
	assert_eq((slot3.get_node("%Count") as Label).text, "×7")
	var slot0: HotbarSlot = _hotbar_slot(tab, 0)
	assert_false((slot0.get_node("%Count") as Control).visible)

func test_drag_over_a_hotbar_slot_marks_it() -> void:
	InventoryManager.award_items(CRUDE, 1)
	var tab: Control = _tab()
	var slot: HotbarSlot = _hotbar_slot(tab, 1)
	slot._can_drop_data(Vector2.ZERO, {"consumable": CRUDE})
	assert_true(slot.is_marked())
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

func test_empty_pack_says_so() -> void:
	var tab: Control = await _open_tab()
	var empty: Label = tab.get_node("%EmptyLabel") as Label
	assert_true(empty.visible)
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

func test_long_names_stay_inside_the_pages() -> void:   # Review Focus 1
	InventoryManager.award_items(_consumable("long", LONG_NAME), 3)
	var tab: Control = await _open_tab()
	assert_eq(PageBounds.escaping_text(tab), [] as Array[String])
	var row: ConsumableRow = _rows(tab)[0]
	var name_label: Label = row.get_node("%Name") as Label
	assert_gt(name_label.get_line_count(), 1, "the name wraps")
	assert_gte((row.get_node("%Effect") as Control).get_global_rect().position.y, name_label.get_global_rect().end.y, "what it does moves down under the name")
	assert_gt(row.size.y, 72.0, "and the row grows")
	assert_gt((_details(tab).get_node("%NameLabel") as Label).get_line_count(), 1, "the details wrap it too")

#-----------------------------------------------------------------------------
# THE DETAILS PANEL
#-----------------------------------------------------------------------------

func test_details_print_the_effects_and_the_cooldown() -> void:   # Ruling R16
	InventoryManager.award_items(CRUDE, 1)
	var tab: Control = _tab()
	var rows: Array[TableRow] = _table_rows(tab)
	assert_eq(rows.size(), 2, "one row per effect, then the cooldown")
	assert_eq((rows[1].get_node("%Value") as RichTextLabel).text, "10 s")
	assert_eq((_details(tab).get_node("%Description") as Label).text, CRUDE.description)
	assert_eq((_details(tab).get_node("%Icon") as TextureRect).texture, CRUDE.icon)

func test_the_drag_preview_holds_the_icon() -> void:
	var preview: ItemDragPreview = DragPreviewScene.instantiate() as ItemDragPreview
	preview.set_icon(CRUDE.icon)
	add_child_autofree(preview)
	var icon: TextureRect = preview.get_node("%Icon") as TextureRect
	assert_eq(icon.texture, CRUDE.icon)
