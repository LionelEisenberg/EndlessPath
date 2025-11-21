extends MarginContainer

func setup(label: String, texture: Texture2D, fill_color: Color) -> void:
	$InkbrushButton.setup(label, texture, fill_color)
	Log.debug(fill_color)
