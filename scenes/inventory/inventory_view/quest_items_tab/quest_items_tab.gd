extends Control

## Journal tab — renders quest items as rich rows with a shared
## QuestJournalCard on the right page. Empty state hides the card and
## shows a centered label instead.

const JournalRowScene := preload("res://scenes/inventory/inventory_view/quest_items_tab/journal_row.tscn")

@onready var list_vbox: VBoxContainer = %ListVBox
@onready var empty_label: Label = %EmptyLabel
@onready var journal_card: PanelContainer = %QuestJournalCard

var _selected: ItemDefinitionData = null

func _ready() -> void:
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
		_rebuild(InventoryManager.get_quest_items())
	else:
		_rebuild({})

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _rebuild(quest_items: Dictionary) -> void:
	for child in list_vbox.get_children():
		child.queue_free()

	if quest_items.is_empty():
		empty_label.visible = true
		journal_card.visible = false
		if journal_card.has_method("reset"):
			journal_card.reset()
		_selected = null
		return

	empty_label.visible = false
	journal_card.visible = true

	var first: ItemDefinitionData = null
	for def in quest_items.keys():
		var row: Button = JournalRowScene.instantiate()
		list_vbox.add_child(row)
		row.set_item(def)
		row.row_clicked.connect(_on_row_clicked)
		if first == null:
			first = def

	if _selected == null or not quest_items.has(_selected):
		_selected = first
	_show_item(_selected)

func _show_item(def: ItemDefinitionData) -> void:
	if def == null:
		if journal_card.has_method("reset"):
			journal_card.reset()
		return
	if journal_card.has_method("setup_from_definition"):
		journal_card.setup_from_definition(def)
	for row in list_vbox.get_children():
		if row.has_method("set_selected") and row.has_method("get_item"):
			row.set_selected(row.get_item() == def)

func _on_row_clicked(def: ItemDefinitionData) -> void:
	_selected = def
	_show_item(def)

func _on_inventory_changed(_inv: InventoryData) -> void:
	_rebuild(InventoryManager.get_quest_items())
