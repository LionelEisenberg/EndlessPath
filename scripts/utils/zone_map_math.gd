class_name ZoneMapMath

## ZoneMapMath
## Pure helpers for the zone map: where the camera goes so the current zone's
## centre lands at screen (960, 702) at any zoom (the upper half of the screen
## is kept for the road ahead), where the camera may go so a zone stays in the
## free map window, the fog tier and art of a cell, and the character's idle
## motion: where it stands and which of its clips it plays while it forages or
## meditates at the Aura Well.
## "World" is the ZoneTilemap's own space, where one art pixel is one unit.
## Statics only.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Where the current zone's centre sits on screen (spec: Map scale and framing).
const ZONE_SCREEN_ANCHOR: Vector2 = Vector2(960, 702)

## The zone view's viewport size.
const VIEWPORT_SIZE: Vector2 = Vector2(1920, 1080)

## The free map window, in screen px: the map between the cabinet column, the
## zone chest, the top edge and the dock, where a zone centre leaves its whole
## hex in view at zoom 2. The camera clamp keeps at least one map zone's
## centre in it at every zoom.
const FREE_MAP_WINDOW: Rect2 = Rect2(546, 95, 828, 786)

## Fog tiers run 1 (next to a charted zone) to this, the darkest.
const MAX_FOG_TIER: int = 3

## Each fog tier's atlas (the kit's lacquer_fog_t*_atlas_ai.png) holds its
## natural-only pool in this order: Basic 0, Mountains1 1, Clearing1 2, Lake1 3,
## Lake2 4, Hole 5, Dead 6, Ravine 7, Cave 8.
const FOG_POOL_SIZE: int = 9
const FOG_ART_BASIC: int = 0
## Off the kit's cells, the share of fog cells that are plain Basic: about
## the kit's own (19 of its 31 fog cells).
const FOG_BASIC_PERCENT: int = 60

## The fog art kit §6.2 places by hand on the cells the default framing shows
## (its rows in KIT_FOG_ROWS); every other one of those cells is Basic.
const KIT_FOG_FEATURES: Dictionary[Vector2i, int] = {
	Vector2i(-1, -3): 2, Vector2i(1, -3): 5,
	Vector2i(-1, -2): 7, Vector2i(0, -2): 3, Vector2i(1, -2): 1,
	Vector2i(-2, -1): 4, Vector2i(1, -1): 6,
	Vector2i(-1, 0): 3, Vector2i(1, 0): 7, Vector2i(2, 0): 2,
	Vector2i(-2, 1): 8, Vector2i(0, 1): 4,
}
## Kit §6.2's 32 cells: per row, its first and last column.
const KIT_FOG_ROWS: Dictionary[int, Vector2i] = {
	-3: Vector2i(-3, 2), -2: Vector2i(-3, 3), -1: Vector2i(-3, 2), 0: Vector2i(-3, 3), 1: Vector2i(-3, 2),
}

## One foraging haul, in segments: the character walks west to -24 world px,
## kneels and searches the grass, walks home, and holds its find up at the
## stand as the haul comes in. Each segment's end in seconds, and the
## character's clip in it (forage_search and forage_present last exactly their
## segments).
const FORAGE_WANDER_SECONDS: float = 5.0
const FORAGE_SEGMENT_ENDS: Array[float] = [1.2, 3.0, 4.2, 5.0]
const FORAGE_ANIMATIONS: Array[StringName] = [&"walk_left", &"forage_search", &"walk_right", &"forage_present"]
const _WANDER_FAR_X: float = 24.0

## The Aura Well: the character meditates at a spot for three breaths, then
## dissolves into Madra and re-forms at the next spot, round and round. The
## spots are world px offsets from the stand, on Spirit Valley's grass and
## clear of the river, the action ring, the floater and the plate (the Aura
## Well is Spirit Valley's); the stand first. The last sits at the plateau's
## far edge: any lower and the floater would rise over it.
const AURA_WELL_SPOTS: Array[Vector2] = [Vector2(0, 0), Vector2(-51, -45), Vector2(-25, -72), Vector2(32, -78)]
## One spot, in segments: re-forming, three breaths, dissolving, gone. Each
## segment's end in seconds, and the character's clip in it (it is hidden
## while gone).
const AURA_WELL_SEGMENT_ENDS: Array[float] = [0.45, 7.65, 8.1, 8.4]
const AURA_WELL_ANIMATIONS: Array[StringName] = [&"teleport_in", &"meditate", &"teleport_out", &"teleport_out"]
const AURA_WELL_SPOT_SECONDS: float = 8.4
const _AURA_WELL_GONE_SEGMENT: int = 3
## One breath, the meditate clip's loop.
const MEDITATE_SECONDS: float = 2.4
## Where the Aura Well's motion starts: meditating at the stand, so the
## character sits down at once instead of first re-forming out of Madra.
const AURA_WELL_START_SECONDS: float = 0.45

#-----------------------------------------------------------------------------
# FRAMING
#-----------------------------------------------------------------------------

## The camera position (screen centre, offset zero) that puts the world point
## zone_world_centre at ZONE_SCREEN_ANCHOR on screen at the given zoom.
static func camera_position_for(zone_world_centre: Vector2, zoom: float) -> Vector2:
	return zone_world_centre - (ZONE_SCREEN_ANCHOR - VIEWPORT_SIZE / 2.0) / zoom

## The screen point a world point lands on for a camera at camera_position
## (its screen centre) and zoom.
static func world_to_screen(world: Vector2, camera_position: Vector2, zoom: float) -> Vector2:
	return (world - camera_position) * zoom + VIEWPORT_SIZE / 2.0

## The camera positions (its screen centre) that put the world point
## zone_world_centre inside FREE_MAP_WINDOW at the given zoom: 414 / zoom
## either side of it, 341 / zoom above it and 445 / zoom below it.
static func camera_window_for(zone_world_centre: Vector2, zoom: float) -> Rect2:
	var window_end_from_centre: Vector2 = FREE_MAP_WINDOW.end - VIEWPORT_SIZE / 2.0
	return Rect2(zone_world_centre - window_end_from_centre / zoom, FREE_MAP_WINDOW.size / zoom)

#-----------------------------------------------------------------------------
# HEX CELLS AND FOG
#-----------------------------------------------------------------------------

## Cube coordinates of a map cell. The zone map's TileSet is pointy-top with
## stacked rows offset horizontally (odd rows, negative ones too, sit half a
## hex right), the same conversion as the hexagon addon's stacked layout. It
## needs no TileMapLayer, so it works before the layer's conversions are set up.
static func cell_to_cube(cell: Vector2i) -> Vector3i:
	var x: int = cell.x - ((cell.y & ~1) >> 1)
	return Vector3i(x, cell.y, -x - cell.y)

## The fog art (an index into the fog pool) drawn on a cell: kit §6.2's
## hand-placed art on its 32 cells, so the default framing matches the mock,
## and past them Basic for about FOG_BASIC_PERCENT of cells and a natural
## feature for the rest, the same for the same cell every time.
static func fog_art_index(cell: Vector2i) -> int:
	if KIT_FOG_FEATURES.has(cell):
		return KIT_FOG_FEATURES[cell]
	if KIT_FOG_ROWS.has(cell.y) and cell.x >= KIT_FOG_ROWS[cell.y].x and cell.x <= KIT_FOG_ROWS[cell.y].y:
		return FOG_ART_BASIC
	return HexForestAtlas.pick_weighted_from(cell_to_cube(cell), FOG_POOL_SIZE, FOG_BASIC_PERCENT)

## The fog tier of a cell: its hex distance to the nearest charted zone,
## capped at MAX_FOG_TIER, and MAX_FOG_TIER when nothing is charted.
static func fog_tier(cell_cube: Vector3i, charted_cubes: Array[Vector3i]) -> int:
	var tier: int = MAX_FOG_TIER
	for charted: Vector3i in charted_cubes:
		tier = mini(tier, HexagonTileMap.cube_distance(cell_cube, charted))
	return tier

#-----------------------------------------------------------------------------
# FORAGING
#-----------------------------------------------------------------------------

## The character's x offset from its stand, in whole world px, at elapsed
## seconds into a foraging haul: west to -24 over the walk out, there through
## the search, home over the walk back, one world px (two screen px) a step.
static func forage_wander_x(elapsed: float) -> float:
	var t: float = fposmod(elapsed, FORAGE_WANDER_SECONDS)
	var walk_out_end: float = FORAGE_SEGMENT_ENDS[0]
	var search_end: float = FORAGE_SEGMENT_ENDS[1]
	var walk_back_end: float = FORAGE_SEGMENT_ENDS[2]
	if t < walk_out_end:
		return -floorf(t / walk_out_end * _WANDER_FAR_X)
	if t < search_end:
		return -_WANDER_FAR_X
	if t < walk_back_end:
		return -_WANDER_FAR_X + floorf((t - search_end) / (walk_back_end - search_end) * _WANDER_FAR_X)
	return 0.0

## The character's clip at elapsed seconds into a foraging haul.
static func forage_animation(elapsed: float) -> StringName:
	return FORAGE_ANIMATIONS[_segment_at(FORAGE_SEGMENT_ENDS, fposmod(elapsed, FORAGE_WANDER_SECONDS))]

## How far into its clip the character is at elapsed seconds into a foraging
## haul: the time since its segment began.
static func forage_animation_position(elapsed: float) -> float:
	return _time_into_segment(FORAGE_SEGMENT_ENDS, fposmod(elapsed, FORAGE_WANDER_SECONDS))

#-----------------------------------------------------------------------------
# AURA WELL
#-----------------------------------------------------------------------------

## One round of the Aura Well's spots, in seconds.
static func aura_well_cycle_seconds() -> float:
	return AURA_WELL_SPOT_SECONDS * AURA_WELL_SPOTS.size()

## The character's offset from its stand, in whole world px, at elapsed
## seconds into the Aura Well's motion: the spot it meditates at. It moves on
## at the end of each gap, as it starts to re-form.
static func aura_well_spot(elapsed: float) -> Vector2:
	var t: float = fposmod(elapsed, aura_well_cycle_seconds())
	return AURA_WELL_SPOTS[mini(floori(t / AURA_WELL_SPOT_SECONDS), AURA_WELL_SPOTS.size() - 1)]

## The character's clip at elapsed seconds into the Aura Well's motion.
static func aura_well_animation(elapsed: float) -> StringName:
	return AURA_WELL_ANIMATIONS[_segment_at(AURA_WELL_SEGMENT_ENDS, fposmod(elapsed, AURA_WELL_SPOT_SECONDS))]

## How far into its clip the character is at elapsed seconds into the Aura
## Well's motion; the breath loops, and the gap holds the dissolve's end.
static func aura_well_animation_position(elapsed: float) -> float:
	var t: float = fposmod(elapsed, AURA_WELL_SPOT_SECONDS)
	var segment: int = _segment_at(AURA_WELL_SEGMENT_ENDS, t)
	if segment == _AURA_WELL_GONE_SEGMENT:
		return AURA_WELL_SEGMENT_ENDS[2] - AURA_WELL_SEGMENT_ENDS[1]
	var into: float = _time_into_segment(AURA_WELL_SEGMENT_ENDS, t)
	return fposmod(into, MEDITATE_SECONDS) if AURA_WELL_ANIMATIONS[segment] == &"meditate" else into

## True while the character is gone between two spots (hidden).
static func is_aura_well_gone(elapsed: float) -> bool:
	return _segment_at(AURA_WELL_SEGMENT_ENDS, fposmod(elapsed, AURA_WELL_SPOT_SECONDS)) == _AURA_WELL_GONE_SEGMENT

#-----------------------------------------------------------------------------
# SEGMENTS
#-----------------------------------------------------------------------------

## The segment t falls in, given each segment's end; the last past them all.
static func _segment_at(ends: Array[float], t: float) -> int:
	for i: int in ends.size():
		if t < ends[i]:
			return i
	return ends.size() - 1

## The seconds since t's segment began.
static func _time_into_segment(ends: Array[float], t: float) -> float:
	var segment: int = _segment_at(ends, t)
	return t - (ends[segment - 1] if segment > 0 else 0.0)
