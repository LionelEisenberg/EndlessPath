extends Button

## One row in the Quest Items tab — icon + name. Emits row_clicked with its
## own item when pressed so the parent tab can update the selected item.

signal row_clicked(item: ItemDefinitionData)

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel

var _item: ItemDefinitionData = null

func _ready() -> void:
	pressed.connect(_on_pressed)
	_refresh()

## Populates the row with the given item.
func set_item(value: ItemDefinitionData) -> void:
	_item = value
	if is_inside_tree():
		_refresh()

## Returns the item currently shown on this row.
func get_item() -> ItemDefinitionData:
	return _item

## Visually marks the row as selected (or not).
func set_selected(value: bool) -> void:
	modulate = Color(1.0, 1.0, 1.0) if not value else Color(1.3, 1.3, 0.8)

func _refresh() -> void:
	if _item == null:
		icon_rect.texture = null
		name_label.text = ""
		return
	icon_rect.texture = _item.icon
	name_label.text = _item.item_name

func _on_pressed() -> void:
	row_clicked.emit(_item)
