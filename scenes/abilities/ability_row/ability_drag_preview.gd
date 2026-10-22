class_name AbilityDragPreview
extends Control

## The ability icon that follows the cursor while an ability is dragged onto
## (or between) loadout slots in the Abilities book.

@onready var _icon: TextureRect = %Icon

var _texture: Texture2D = null

func _ready() -> void:
	_icon.texture = _texture

## Shows the given icon. Works before or after the preview enters the tree.
func setup(icon: Texture2D) -> void:
	_texture = icon
	if is_node_ready():
		_icon.texture = icon
