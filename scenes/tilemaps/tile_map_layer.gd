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
			Log.info(str(cube_distance((Vector3i.ZERO), _map_to_cube(tile_coord))))

## Convert horizontal stacked map coordinate to cube coordinate.
static func _map_to_cube(map_position: Vector2i) -> Vector3i:
	var l_x = map_position.x - ((map_position.y & ~1) >> 1)
	var l_y = map_position.y
	return Vector3i(l_x, l_y, -l_x - l_y)

## Convert cube coordinate to horizontal stacked map coordinate.
static func _cube_to_map(cube_position: Vector3i) -> Vector2i:
	var l_x = cube_position.x + ((cube_position.y & ~1) >> 1)
	var l_y = cube_position.y
	return Vector2i(l_x, l_y)

## Calculates the distance distance between two hexes in the hex grid.
static func cube_distance(a: Vector3i, b: Vector3i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y), abs(a.z - b.z))
