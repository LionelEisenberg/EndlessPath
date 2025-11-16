extends TileMapLayer

signal tile_clicked(tile_coord: Vector2i)

func set_cell_with_source_and_variant(source_id : int, variant_id: int, cell_coords: Vector2) -> void:
	set_cell(cell_coords, source_id, Vector2i(0, 0), variant_id)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var tile_coord = local_to_map(get_local_mouse_position())
		# Only emit if there's actually a tile at this location
		if get_cell_source_id(tile_coord) != -1:
			tile_clicked.emit(tile_coord)
