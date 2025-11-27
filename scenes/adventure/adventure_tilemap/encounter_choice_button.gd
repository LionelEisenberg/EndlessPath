extends MarginContainer

signal button_pressed

func setup(label: String, texture: Texture2D, fill_color: Color) -> void:
	$InkbrushButton.setup(label, texture, fill_color)
	$InkbrushButton.pressed.connect(button_pressed.emit)
