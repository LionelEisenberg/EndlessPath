extends TileMapLayer

signal zone_tile_clicked(tile_coord: Vector2i)

const MAIN_ATLAS_ID = 1

func set_cell_to_variant(id : int, cell : Vector2i):
	set_cell(cell, MAIN_ATLAS_ID, Vector2i(0,0), id)

func clear_cells():
	for pos in get_used_cells():
		set_cell(pos, MAIN_ATLAS_ID, Vector2i(0,0))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var tile_coord = local_to_map(get_local_mouse_position())
		# Only emit if there's actually a tile at this location
		if get_cell_source_id(tile_coord) != -1:
			zone_tile_clicked.emit(tile_coord)
