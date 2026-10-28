class_name ItemDragPreview
extends Control

## ItemDragPreview
## The item that follows the cursor while a consumable is dragged onto, or
## between, the hotbar's slots: its 64 px icon, centred on the cursor. Godot
## draws a drag preview over the whole screen at its own scale, so the icon
## shows 1:1 like the icons pressed into the pages.

#-----------------------------------------------------------------------------
# COMPONENTS
#-----------------------------------------------------------------------------

@onready var _icon: TextureRect = %Icon

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _texture: Texture2D = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_icon.texture = _texture

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows `icon` in the preview. Works before or after the preview enters the
## tree.
func set_icon(icon: Texture2D) -> void:
	_texture = icon
	if is_node_ready():
		_icon.texture = icon
