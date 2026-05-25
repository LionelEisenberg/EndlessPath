extends Control

## DiscardFlash
## Brief modal overlay shown when the TrashSlot destroys a previously-held
## item. Fades in, holds, fades out, and hides itself.

@onready var _name: Label = %ItemName

var _tween: Tween = null

func _ready() -> void:
	visible = false
	add_to_group("DiscardFlashes")

## Show the flash with the discarded item name, then auto-hide.
func show_for(item_name: String) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_name.text = item_name
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.05).from(0.0)
	_tween.tween_interval(0.7)
	_tween.tween_property(self, "modulate:a", 0.0, 0.18)
	_tween.tween_callback(func(): visible = false)
