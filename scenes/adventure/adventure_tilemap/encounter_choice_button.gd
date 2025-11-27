extends MarginContainer

signal button_pressed

## Sets up the button with label, texture, and color.
func setup(label: String, texture: Texture2D, fill_color: Color) -> void:
	%InkbrushButton.setup(label, texture, fill_color)
	%InkbrushButton.pressed.connect(button_pressed.emit)
