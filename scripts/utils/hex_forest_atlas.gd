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

## Returns an index in [0, pool_size) for the given cube coord, the same for
## the same coord every time. The zone map's fog uses it to pick a cell from a
## tier's 9-cell atlas of natural tiles. Returns 0 for an empty pool.
static func pick_from(coord: Vector3i, pool_size: int) -> int:
	if pool_size <= 0:
		return 0
	return posmod(hash(coord), pool_size)

## Returns an index in [0, pool_size) for the given cube coord, the same for
## the same coord every time: 0 (the pool's plain tile) for about first_percent
## of coords, else one of the other tiles, evenly. Returns 0 for a pool of one
## tile or none.
static func pick_weighted_from(coord: Vector3i, pool_size: int, first_percent: int) -> int:
	if pool_size <= 1:
		return 0
	var roll: int = hash(coord)
	if posmod(roll, 100) < first_percent:
		return 0
	@warning_ignore("integer_division")
	return 1 + posmod(roll / 100, pool_size - 1)
