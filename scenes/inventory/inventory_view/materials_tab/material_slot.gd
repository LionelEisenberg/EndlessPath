class_name MaterialSlot
extends TextureRect

## MaterialSlot
## Read-only grid slot for a material stack. Emits `clicked` when the
## player presses on it so the materials tab can swap the detail card.

signal clicked(slot: MaterialSlot, event: InputEvent)

@onready var _icon: TextureRect = %Icon
@onready var _count: Label = %Count

var _def: MaterialDefinitionData = null
var _qty: int = 0

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	_refresh()

## Populate the slot with a material definition + stack count.
func setup(def: MaterialDefinitionData, qty: int) -> void:
	_def = def
	_qty = qty
	if is_inside_tree():
		_refresh()

## Returns the material definition currently held by this slot.
func get_definition() -> MaterialDefinitionData:
	return _def

## Returns the quantity currently displayed.
func get_quantity() -> int:
	return _qty

func _on_gui_input(event: InputEvent) -> void:
	clicked.emit(self, event)

func _refresh() -> void:
	if _def == null:
		_icon.texture = null
		_count.text = ""
		return
	_icon.texture = _def.icon
	_count.text = "x%d" % _qty if _qty > 1 else ""
