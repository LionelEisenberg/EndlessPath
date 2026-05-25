extends Button

## JournalRow
## One quest item entry in the Journal tab's left-page list. Icon disc
## + name + truncated description + wax seal. Wax seal currently always
## renders as "active" until a QuestManager exists.

signal row_clicked(item: ItemDefinitionData)

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _sub: Label = %Sub

var _item: ItemDefinitionData = null

func _ready() -> void:
	pressed.connect(_on_pressed)
	_refresh()

## Populate this row with a quest item definition.
func set_item(value: ItemDefinitionData) -> void:
	_item = value
	if is_inside_tree():
		_refresh()

## Return the item shown on this row (or null if none).
func get_item() -> ItemDefinitionData:
	return _item

## Toggle the visual "selected" highlight.
func set_selected(value: bool) -> void:
	modulate = Color(1.0, 1.0, 1.0) if not value else Color(1.3, 1.25, 0.85)

func _refresh() -> void:
	if _item == null:
		_icon.texture = null
		_name.text = ""
		_sub.text = ""
		return
	_icon.texture = _item.icon
	_name.text = _item.item_name
	var desc: String = _item.description
	_sub.text = desc if desc.length() < 60 else desc.substr(0, 60) + "…"

func _on_pressed() -> void:
	row_clicked.emit(_item)
