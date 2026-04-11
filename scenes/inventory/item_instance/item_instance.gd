class_name ItemInstance
extends Control

## ItemInstance
## Displays an item icon. Used in inventory slots and item display slots.

@onready var item_icon: TextureRect = %ItemIcon

var item_instance_data: ItemInstanceData = null

## When true, the icon fills the entire parent control. When false, uses the
## default inventory offset centering. Set before adding to scene tree.
var use_full_rect: bool = false

func _ready() -> void:
	if use_full_rect:
		item_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		item_icon.offset_left = 0
		item_icon.offset_top = 0
		item_icon.offset_right = 0
		item_icon.offset_bottom = 0
		item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		set_anchors_preset(Control.PRESET_FULL_RECT)

## Set up the item icon from the given instance data.
func setup(d: ItemInstanceData) -> void:
	item_instance_data = d
	item_icon.texture = item_instance_data.item_definition.icon
