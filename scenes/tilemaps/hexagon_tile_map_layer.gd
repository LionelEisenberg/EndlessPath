@tool
extends HexagonTileMapLayer

signal tile_clicked(tile_coord: Vector2i)

func set_cell_with_source_and_variant(source_id : int, variant_id: int, cell_coords: Vector2) -> void:
	set_cell(cell_coords, source_id, Vector2i(0, 0), variant_id)
	_draw_debug()
	pathfinding_generate_points()

func _ready() -> void:
	if position != Vector2(-82, -95):
		Log.warn("HexagonalTileMapLayer: TileMapLayer is not in the right position, it won't look right!")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var tile_coord = local_to_map(get_local_mouse_position())
		
		# Only emit if there's actually a tile at this location
		if get_cell_source_id(tile_coord) != -1:
			tile_clicked.emit(tile_coord)

func cube_pathfind(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var from_id = pathfinding_get_point_id(cube_to_map(from))
	var to_id = pathfinding_get_point_id(cube_to_map(to))
	
	var path = astar.get_id_path(from_id, to_id)
	var cube_path : Array[Vector3i] = []
	
	for point_id in path:
		cube_path.append(local_to_cube(astar.get_point_position(point_id)))
	
	return cube_path
