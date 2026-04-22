extends Control

## Quest Items tab — renders a list of owned quest items with a shared
## ItemDescriptionPanel showing the currently-selected item. Empty state
## hides the description panel and shows a centered label instead.

@onready var list_vbox: VBoxContainer = %ListVBox
@onready var empty_label: Label = %EmptyLabel
@onready var description_panel: ItemDescriptionPanel = %ItemDescriptionPanel

var _row_scene: PackedScene = preload("res://scenes/inventory/inventory_view/quest_items_tab/quest_item_row.tscn")
var _selected_item: ItemDefinitionData = null

func _ready() -> void:
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_rebuild_rows(InventoryManager.get_quest_items())
	else:
		_rebuild_rows({})

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _rebuild_rows(quest_items: Dictionary) -> void:
	for child in list_vbox.get_children():
		child.queue_free()

	if quest_items.is_empty():
		empty_label.visible = true
		description_panel.visible = false
		description_panel.reset()
		_selected_item = null
		return

	empty_label.visible = false
	description_panel.visible = true

	var first_item: ItemDefinitionData = null
	for item in quest_items.keys():
		var row = _row_scene.instantiate()
		list_vbox.add_child(row)
		row.set_item(item)
		row.row_clicked.connect(_on_row_clicked)
		if first_item == null:
			first_item = item

	# Preserve selection across rebuilds if the item still exists;
	# otherwise fall back to the first row.
	if _selected_item == null or not quest_items.has(_selected_item):
		_selected_item = first_item
	_show_item(_selected_item)

func _show_item(item: ItemDefinitionData) -> void:
	if item == null:
		description_panel.reset()
		return
	description_panel.setup_from_definition(item)
	for row in list_vbox.get_children():
		if row.has_method("get_item") and row.has_method("set_selected"):
			row.set_selected(row.get_item() == item)

func _on_row_clicked(item: ItemDefinitionData) -> void:
	_selected_item = item
	_show_item(item)

func _on_inventory_changed(_inventory: InventoryData) -> void:
	_rebuild_rows(InventoryManager.get_quest_items())
