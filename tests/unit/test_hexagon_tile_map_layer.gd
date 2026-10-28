extends GutTest

## The project's hex map layer (scenes/tilemaps/hexagon_tile_map_layer.gd, which
## extends the addon's HexagonTileMapLayer) sets itself up as it enters the tree,
## whenever that is. The addon's other way to set a layer up is its tileset's
## `changed` signal, sent just after the tileset loads, and a layer that enters the
## tree any later (one of the main scene a dev session switch loads again) never
## hears it. So such a layer converts between cube and map coordinates, knows the
## hexes around one and finds paths only through its own set-up.
##
## Each test reads the layer at once, before any frame passes, and calls no
## `tile_set.emit_changed()`: whatever the layer knows then comes from its own
## `_ready()`. GUT fails a test on any error, so a pass also means none was
## logged (a layer without its set-up logs one for each conversion).

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The layer scene both maps instance. Preloading it loads the shared tileset with
## this script, long before any test builds a layer.
const HexLayerScene := preload("res://scenes/tilemaps/hexagon_tile_map_layer.tscn")
const HexLayerScript := preload("res://scenes/tilemaps/hexagon_tile_map_layer.gd")

const START := Vector3i(0, 0, 0)
## The six hexes around START.
const AROUND_START: Array[Vector3i] = [
	Vector3i(1, -1, 0), Vector3i(1, 0, -1), Vector3i(0, 1, -1),
	Vector3i(-1, 1, 0), Vector3i(-1, 0, 1), Vector3i(0, -1, 1),
]
## Hexes near and far from START, in every direction.
const SOME_HEXES: Array[Vector3i] = [
	Vector3i(1, -1, 0), Vector3i(-2, 1, 1), Vector3i(3, -1, -2),
	Vector3i(-4, 5, -1), Vector3i(6, -6, 0),
]
## Two hexes from START. The hex between them, GAP, has no tile, so the only way
## from START to GOAL is WAY_AROUND, three steps.
const GOAL := Vector3i(2, -2, 0)
const GAP := Vector3i(1, -1, 0)
const WAY_AROUND: Array[Vector3i] = [START, Vector3i(1, 0, -1), Vector3i(2, -1, -1), GOAL]

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A layer of the project's layer scene, placed as both maps place theirs, with
## pathfinding set before it enters the tree, as a scene sets it, added to the
## tree.
func _build_layer(pathfinding: bool) -> HexagonTileMapLayer:
	var layer: HexagonTileMapLayer = HexLayerScene.instantiate()
	layer.position = HexLayerScript.HEX_TILE_OFFSET
	layer.pathfinding_enabled = pathfinding
	add_child_autofree(layer)
	return layer

#-----------------------------------------------------------------------------
# A LAYER BUILT AFTER THE TILESET LOADED
#-----------------------------------------------------------------------------

func test_a_layer_built_after_the_tileset_loaded_converts_cube_and_map_coordinates() -> void:
	var layer := _build_layer(false)

	assert_eq(layer.cube_to_map(START), Vector2i.ZERO, "the start hex is the cell (0, 0)")
	var cells: Array[Vector2i] = []
	for cube: Vector3i in AROUND_START:
		cells.append(layer.cube_to_map(cube))
	var cells_around: Array[Vector2i] = layer.get_surrounding_cells(Vector2i.ZERO)
	cells.sort()
	cells_around.sort()
	assert_eq(cells, cells_around, "the six hexes around the start are the six cells the engine puts around (0, 0)")
	for cube: Vector3i in SOME_HEXES:
		assert_eq(layer.map_to_cube(layer.cube_to_map(cube)), cube, "%s comes back from its cell" % cube)

## The adventure map marks the hexes around each tile it visits this way.
func test_a_layer_built_after_the_tileset_loaded_knows_the_six_hexes_around_one() -> void:
	var layer := _build_layer(false)

	var around: Array[Vector3i] = layer.cube_neighbors(START)

	var expected: Array[Vector3i] = AROUND_START.duplicate()
	around.sort()
	expected.sort()
	assert_eq(around, expected, "the six hexes around the start")

## Painted as the adventure paints its map, a tile at a time, on a layer with
## pathfinding on, as the adventure's visible map has it, which finds its walks.
func test_a_layer_built_after_the_tileset_loaded_finds_a_path() -> void:
	var layer := _build_layer(true)
	for cube: Vector3i in WAY_AROUND:
		layer.set_cell_with_source_and_variant(AdventureTilemap.BASE_TILE_SOURCE_ID, 0, layer.cube_to_map(cube))
	assert_eq(layer.get_cell_source_id(layer.cube_to_map(GAP)), -1, "precondition: the hex between START and GOAL has no tile")

	assert_eq(layer.cube_pathfind(START, GOAL), WAY_AROUND, "the path goes around the gap, a tile at a time")
