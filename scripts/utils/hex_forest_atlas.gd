class_name HexForestAtlas

## Deterministic variant picker for the shared hex forest atlas.
## Multiple Hex_Forest_NN variants are packed into a single
## TileSetAtlasSource backed by hex_forest_atlas.png. Both the in-game
## adventure tilemap and editor-only preview tools map a cube coord to
## the same atlas cell so the same tile always shows the same variant
## across re-renders, fog reveals, and adventure restarts.
##
## Keep FOREST_ATLAS_COLS and FOREST_VARIANT_COUNT in sync with
## ATLAS_COLS in pack_hex_atlas.py and the asset itself.

const FOREST_ATLAS_COLS: int = 6
const FOREST_VARIANT_COUNT: int = 23

## Returns the atlas (col, row) for the given cube coord. Hashes the
## coord, takes posmod by the variant count to handle negative hash
## values, then splits into (col, row) for the FOREST_ATLAS_COLS-wide
## grid.
static func pick(coord: Vector3i) -> Vector2i:
	var idx: int = posmod(hash(coord), FOREST_VARIANT_COUNT)
	@warning_ignore("integer_division")
	return Vector2i(idx % FOREST_ATLAS_COLS, idx / FOREST_ATLAS_COLS)
