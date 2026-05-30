class_name HotbarSlot
extends DropTargetSlot

## HotbarSlot
## One slot in the 4-slot combat hotbar. Displays the equipped consumable's
## icon and live stack count, plus a static keybind chip (1-4). Empty state
## shows a faint `+`. Emits `slot_clicked` on press; accepts a dragged
## consumable to equip (drop-target behavior inherited from DropTargetSlot).

signal slot_clicked(slot: HotbarSlot, event: InputEvent)
## Emitted when a consumable is dropped onto this slot (drag-and-drop equip).
signal consumable_dropped(def: ConsumableDefinitionData, slot_index: int)

const STYLE_EMPTY: StyleBox = preload("res://assets/styleboxes/inventory/hotbar_slot_empty.tres")
const STYLE_EQUIPPED: StyleBox = preload("res://assets/styleboxes/inventory/hotbar_slot_equipped.tres")

## Which slot this is in the hotbar (0..3). Sets the visual key chip.
@export var slot_index: int = 0:
	set(value):
		slot_index = value
		if _key_chip:
			_key_chip.text = str(value + 1)

@onready var _icon: TextureRect = %Icon
@onready var _plus: Label = %Plus
@onready var _count: Label = %Count
@onready var _key_chip: Label = %KeyChip

var _def: ConsumableDefinitionData = null

func _ready() -> void:
	super._ready()  # DropTargetSlot: clear hover highlight on mouse_exited
	gui_input.connect(_on_gui_input)
	_key_chip.text = str(slot_index + 1)
	setup(_def, 0)

## Show the consumable + count, or clear if def == null.
func setup(def: ConsumableDefinitionData, count: int) -> void:
	_def = def
	if _def == null:
		_icon.texture = null
		_count.text = ""
		_plus.visible = true
		add_theme_stylebox_override("panel", STYLE_EMPTY)
	else:
		_icon.texture = _def.icon
		_count.text = "x%d" % count
		_plus.visible = false
		add_theme_stylebox_override("panel", STYLE_EQUIPPED)

## Returns the consumable definition currently held by this slot.
func get_definition() -> ConsumableDefinitionData:
	return _def

func _on_gui_input(event: InputEvent) -> void:
	slot_clicked.emit(self, event)

#-----------------------------------------------------------------------------
# DROP TARGET (equip)
#-----------------------------------------------------------------------------

func _accepts(data: Variant) -> bool:
	return data is Dictionary and data.has("consumable")

func _on_dropped(data: Variant) -> void:
	consumable_dropped.emit(data["consumable"], slot_index)
