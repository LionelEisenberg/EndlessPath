class_name HotbarSlot
extends DropTargetSlot

## HotbarSlot
## One slot of the combat hotbar, pressed into the Hotbar page. Filled, it is a
## deep slot showing the equipped consumable's icon, with its stack count on a
## paper tag at the bottom right; empty, a shallow slot. Printer's marks sit
## round it while the details show its consumable, and while a dragged
## consumable hovers it, the slot that would take the drop. Emits slot_clicked
## for every gui_input event and hovered when the pointer enters; accepts a
## dragged consumable to equip (drop-target behaviour inherited from
## DropTargetSlot).

signal slot_clicked(slot: HotbarSlot, event: InputEvent)
## Emitted when a consumable is dropped onto this slot. `from_slot` is the source
## hotbar slot for a slot-to-slot move, or -1 when the drag came from the list.
signal consumable_dropped(def: ConsumableDefinitionData, slot_index: int, from_slot: int)
## Emitted when the pointer enters the slot.
signal hovered(slot: HotbarSlot)

const _DRAG_PREVIEW_SCENE: PackedScene = preload("res://scenes/inventory/pressed/item_drag_preview/item_drag_preview.tscn")

## Which slot this is in the hotbar (0..3).
@export var slot_index: int = 0

@onready var _well: TextureRect = %Well
@onready var _icon: TextureRect = %Icon
@onready var _count: PaperTag = %Count
@onready var _marks: Panel = %Marks

var _def: ConsumableDefinitionData = null
## True while the details show this slot's consumable.
var _marked: bool = false
## True while a dragged consumable hovers the slot.
var _drop_target: bool = false

func _ready() -> void:
	super._ready()  # DropTargetSlot: clear the drop highlight on mouse_exited
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	setup(_def, 0)

## Show the consumable and its stack count, or empty the slot if def == null.
func setup(def: ConsumableDefinitionData, count: int) -> void:
	_def = def
	var filled: bool = _def != null
	_well.texture = InventorySlot.DEEP_TEXTURE if filled else InventorySlot.SHALLOW_TEXTURE
	_icon.texture = _def.icon if filled else null
	_count.visible = filled
	if filled:
		_count.set_count(count)

## Returns the consumable definition currently held by this slot.
func get_definition() -> ConsumableDefinitionData:
	return _def

## Shows or hides the printer's marks the details put round the slot whose
## consumable they show. A drag passing over the slot leaves them in place.
func set_marked(marked: bool) -> void:
	_marked = marked
	_show_marks()

## True while printer's marks sit round the slot: the details show its
## consumable, or a dragged consumable hovers it.
func is_marked() -> bool:
	return _marks.visible

func _on_gui_input(event: InputEvent) -> void:
	slot_clicked.emit(self, event)

func _on_mouse_entered() -> void:
	hovered.emit(self)

func _show_marks() -> void:
	if not is_node_ready():
		return
	_marks.visible = _marked or _drop_target

#-----------------------------------------------------------------------------
# DRAG SOURCE (re-order between slots)
#-----------------------------------------------------------------------------

## Drag an equipped consumable out of this slot to move/swap it with another
## slot. Empty slots aren't draggable. The preview is the list rows' too.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if _def == null:
		return null
	var preview: ItemDragPreview = _DRAG_PREVIEW_SCENE.instantiate() as ItemDragPreview
	preview.set_icon(_def.icon)
	set_drag_preview(preview)
	return {"consumable": _def, "from_slot": slot_index}

#-----------------------------------------------------------------------------
# DROP TARGET (equip from list / receive a moved slot)
#-----------------------------------------------------------------------------

func _accepts(data: Variant) -> bool:
	return data is Dictionary and data.has("consumable")

func _on_dropped(data: Variant) -> void:
	consumable_dropped.emit(data["consumable"], slot_index, data.get("from_slot", -1))

## Marks the slot while a dragged consumable hovers it, in place of the tint
## DropTargetSlot gives by default.
func _set_drop_hover(target: bool) -> void:
	_drop_target = target
	_show_marks()
