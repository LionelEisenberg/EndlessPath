@tool
class_name TabBanner
extends TextureRect

## Reusable inventory tab signage: a ribbon texture with a centered, crisp
## signage Label. Set `title` (and optionally `title_font_size`) per-instance.
## These are root export properties, so — unlike property overrides on the
## instanced Label child — they survive editor saves AND apply at runtime.

## Text shown on the ribbon.
@export var title: String = "Equipment":
	set(value):
		title = value
		_apply()

## Title font size. 0 keeps the theme variant's default size; set a smaller
## even value when a longer word needs to fit the ribbon (even values stay
## pixel-crisp at the Label's 0.5 scale).
@export var title_font_size: int = 0:
	set(value):
		title_font_size = value
		_apply()

@onready var _title: Label = %Title

func _ready() -> void:
	_apply()

## Push the exported values onto the Label.
func _apply() -> void:
	if not is_node_ready():
		return
	_title.text = title
	if title_font_size > 0:
		_title.add_theme_font_size_override("font_size", title_font_size)
	else:
		_title.remove_theme_font_size_override("font_size")
