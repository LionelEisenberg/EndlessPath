extends MarginContainer

signal button_pressed

## Sets up the button with label, texture, and color.
func setup(label: String, texture: Texture2D, fill_color: Color, is_disabled: bool) -> void:
	$InkbrushButton.setup(label, texture, fill_color)
	$InkbrushButton.pressed.connect(button_pressed.emit)
	$InkbrushButton.disabled = is_disabled
