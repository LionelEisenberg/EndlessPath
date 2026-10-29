extends GutTest

## Unit test for the veil atlas the adventure view's lacquer rework imports
## (hex_forest_veil_atlas_ai.png, made by the scripts in
## docs/superpowers/mockups/adventure-view-lacquer/gen/: build_all.py, then
## import_adventure_kit.py). AdventureTilemap draws a revealed tile from it at the
## cell HexForestAtlas.pick() names in the user's forest atlas, so the two atlases
## must hold tiles in the same cells.

const FOREST_DIR: String = "res://assets/sprites/tilemap/hex_tiles/forest/"
const FOREST_ATLAS_PATH: String = FOREST_DIR + "hex_forest_atlas.png"
const VEIL_ATLAS_PATH: String = FOREST_DIR + "hex_forest_veil_atlas_ai.png"

## One tile of the forest atlas (the tileset's region size). The atlas is a
## grid of these, 23 of them used.
const FOREST_CELL: Vector2i = Vector2i(164, 190)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The pixels of a texture under res://, or null (after a failed assert) when
## the file is missing or was never imported.
func _load_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		fail_test("%s is missing or not imported" % path)
		return null
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		fail_test("%s did not load as a texture" % path)
		return null
	return texture.get_image()

#-----------------------------------------------------------------------------
# VEIL ATLAS
#-----------------------------------------------------------------------------

## The veil atlas keeps the forest atlas' layout, so a HexForestAtlas.pick()
## cell holds a tile in both, and the unused cell stays empty in both.
func test_veil_atlas_matches_the_forest_atlas() -> void:
	var forest: Image = _load_image(FOREST_ATLAS_PATH)
	var veil: Image = _load_image(VEIL_ATLAS_PATH)
	if forest == null or veil == null:
		return
	assert_eq(veil.get_size(), forest.get_size(), "the veil atlas is the forest atlas' size")
	@warning_ignore("integer_division")
	var rows: int = forest.get_height() / FOREST_CELL.y
	@warning_ignore("integer_division")
	var columns: int = forest.get_width() / FOREST_CELL.x
	for row: int in rows:
		for column: int in columns:
			var cell := Rect2i(column * FOREST_CELL.x, row * FOREST_CELL.y, FOREST_CELL.x, FOREST_CELL.y)
			assert_eq(veil.get_region(cell).get_used_rect().has_area(), forest.get_region(cell).get_used_rect().has_area(),
				"cell (%d, %d) is filled in the veil atlas exactly when it is in the forest atlas" % [column, row])
