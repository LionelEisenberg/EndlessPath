@tool
extends HexagonTileMapLayer

signal tile_clicked(tile_coord: Vector2i)
signal tile_hovered(tile_coord: Vector2i)
signal tile_unhovered()

const HEX_TILE_OFFSET: Vector2 = Vector2(-82, -95)

var _last_hovered_coord: Vector2i = Vector2i(-9999, -9999)

## Sets a tile cell from a TileSet atlas source. Defaults atlas_coords to
## (0, 0) so single-cell sources (like the adventure tilemap's
## tile_horizontal.png) keep their existing call sites. Multi-cell atlas
## sources (like the forest hex_forest_atlas) pass explicit coords to
## pick which cell to render. variant_id selects an alternative tile
## (e.g. dimmed/transparent state) on the chosen cell.
func set_cell_with_source_and_variant(source_id: int, variant_id: int, cell_coords: Vector2, atlas_coords: Vector2i = Vector2i.ZERO) -> void:
	set_cell(cell_coords, source_id, atlas_coords, variant_id)
	_draw_debug()
	pathfinding_generate_points()

func _ready() -> void:
	if position != HEX_TILE_OFFSET:
		Log.warn("HexagonalTileMapLayer: TileMapLayer is not in the right position, it won't look right!")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var tile_coord := local_to_map(get_local_mouse_position())
		if get_cell_source_id(tile_coord) != -1:
			tile_clicked.emit(tile_coord)
	elif event is InputEventMouseMotion:
		var tile_coord := local_to_map(get_local_mouse_position())
		if get_cell_source_id(tile_coord) != -1:
			if tile_coord != _last_hovered_coord:
				_last_hovered_coord = tile_coord
				tile_hovered.emit(tile_coord)
		else:
			if _last_hovered_coord != Vector2i(-9999, -9999):
				_last_hovered_coord = Vector2i(-9999, -9999)
				tile_unhovered.emit()

func cube_pathfind(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var from_id := pathfinding_get_point_id(cube_to_map(from))
	var to_id := pathfinding_get_point_id(cube_to_map(to))

	var path := astar.get_id_path(from_id, to_id)
	var cube_path : Array[Vector3i] = []

	for point_id in path:
		cube_path.append(local_to_cube(astar.get_point_position(point_id)))

	return cube_path
