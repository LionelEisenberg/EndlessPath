class_name InventorySlot
extends TextureRect

## InventorySlot
## One 72 px slot pressed into the Equipment page. It holds at most one
## ItemInstance, whose icon fills the slot inside a 4 px margin. A slot that
## holds an item is pressed deep, an empty one shallow. The filter can leave
## the slot's item out: it then sits in a shallow slot, its icon faded into the
## paper. Printer's marks (%Marks) sit round the slot the details show, or the
## slot a dragged item would land in. Emits clicked for every gui_input event.

signal clicked(slot: InventorySlot, event: InputEvent)

## A slot that holds an item: pressed deep into the page.
const DEEP_TEXTURE: Texture2D = preload("res://assets/sprites/ui/book/pressed/pressed_slot_deep_ai.png")
## An empty slot, or one whose item the filter leaves out: pressed shallow.
const SHALLOW_TEXTURE: Texture2D = preload("res://assets/sprites/ui/book/pressed/pressed_slot_shallow_ai.png")
## Mixes a left-out item's icon towards the paper colour (opaque, never alpha).
const _FADE_MATERIAL: Material = preload("res://assets/shaders/paper_fade_material.tres")

@onready var item_instance_scene: PackedScene = preload("res://scenes/inventory/item_instance/item_instance.tscn")
@onready var _marks: Panel = %Marks

var item_instance: ItemInstance = null

## True while the filter leaves this slot's item out.
var _filtered_out: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gui_input.connect(_on_gui_input)
	_update_slot()

func _on_gui_input(event: InputEvent) -> void:
	clicked.emit(self, event)

## Sets up the slot with the given item data.
func setup(data: ItemInstanceData) -> void:
	if item_instance != null:
		# Already showing exactly this item — nothing to rebuild.
		if item_instance.item_instance_data == data:
			return
		# Different item (or now empty): drop the old visual immediately so a
		# page flip that re-binds this slot to an empty global index doesn't keep
		# showing the previous page's item / occupied texture.
		remove_child(item_instance)
		item_instance.queue_free()
		item_instance = null

	if data != null:
		item_instance = item_instance_scene.instantiate()
		add_child(item_instance)
		item_instance.setup(data)

	_update_slot()

## Removes and returns the item instance from the slot.
func grab_item() -> Control:
	if item_instance == null:
		return null

	var grabbed_instance = item_instance
	remove_child(item_instance)
	item_instance = null
	_update_slot()
	return grabbed_instance

## Places an item instance into the slot.
func equip_item(instance: Control) -> void:
	# If we already have an item, this should probably be handled by the caller (swap),
	# but for safety let's free it if it exists and wasn't grabbed.
	if item_instance != null:
		item_instance.queue_free()

	item_instance = instance

	if item_instance.get_parent():
		item_instance.get_parent().remove_child(item_instance)

	add_child(item_instance)
	# Reset position in case it was dragged
	item_instance.position = Vector2.ZERO

	_update_slot()

## Shows or hides the printer's marks round the slot.
func set_marked(marked: bool) -> void:
	_marks.visible = marked

## True while the printer's marks sit round the slot.
func is_marked() -> bool:
	return _marks.visible

## Leaves the slot's item out of the filter (faded into the paper, in a shallow
## slot) or puts it back. An empty slot counts as left out under any filter
## but the one that matches everything.
func set_filtered_out(filtered_out: bool) -> void:
	_filtered_out = filtered_out
	_update_slot()

## True while the filter leaves the slot's item out.
func is_filtered_out() -> bool:
	return _filtered_out

func _update_slot() -> void:
	texture = DEEP_TEXTURE if item_instance != null and not _filtered_out else SHALLOW_TEXTURE
	if item_instance != null:
		item_instance.item_icon.material = _FADE_MATERIAL if _filtered_out else null
