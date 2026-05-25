extends Control

## DiscardFlash
## Brief modal overlay shown when the TrashSlot destroys a previously-held
## item. Fades in, holds, fades out, and hides itself.

@onready var _name: Label = %ItemName

func _ready() -> void:
	visible = false
	add_to_group("DiscardFlashes")

## Show the flash with the discarded item name, then auto-hide.
func show_for(item_name: String) -> void:
	_name.text = item_name
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.05).from(0.0)
	tween.tween_interval(0.7)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func(): visible = false)
