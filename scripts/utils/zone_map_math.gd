class_name ZoneMapMath

## ZoneMapMath
## Pure helpers for the zone map: where the camera goes so the current zone's
## centre lands at screen (960, 702) at any zoom (the upper half of the screen
## is kept for the road ahead), where the camera may go so a zone stays in the
## free map window, the fog tier of a cell, the foraging wander and the Aura
## Well's bob.
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

## One foraging haul, over which the character wanders west and back: out to
## -24 world px by 1.5 s (30%), back to -8 by 3.25 s (65%), home at 5 s.
const FORAGE_WANDER_SECONDS: float = 5.0
const _WANDER_OUT_END: float = 1.5
const _WANDER_BACK_END: float = 3.25
const _WANDER_FAR_X: float = 24.0
const _WANDER_TURN_X: float = 8.0

## One cycle of the Aura Well's bob (mock: bob 2.4 s steps(2, end)): four
## steps of 0.6 s at these world px offsets (screen 0, -2, -4, -2).
const TRAINING_BOB_SECONDS: float = 2.4
const _BOB_STEPS_Y: Array[float] = [0.0, -1.0, -2.0, -1.0]
## Absorbs float error at step boundaries (1.8 s is not an exact multiple of 0.6).
const _BOB_STEP_EPSILON: float = 0.000001

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

## The fog tier of a cell: its hex distance to the nearest charted zone,
## capped at MAX_FOG_TIER, and MAX_FOG_TIER when nothing is charted.
static func fog_tier(cell_cube: Vector3i, charted_cubes: Array[Vector3i]) -> int:
	var tier: int = MAX_FOG_TIER
	for charted: Vector3i in charted_cubes:
		tier = mini(tier, HexagonTileMap.cube_distance(cell_cube, charted))
	return tier

#-----------------------------------------------------------------------------
# FORAGING WANDER
#-----------------------------------------------------------------------------

## The character's x offset from its stand, in whole world px, at elapsed
## seconds into a foraging haul: west to -24 by 30% of the haul, back to -8 by
## 65%, home at the end, one world px (two screen px) a step (kit §0).
static func forage_wander_x(elapsed: float) -> float:
	var t: float = fposmod(elapsed, FORAGE_WANDER_SECONDS)
	if t < _WANDER_OUT_END:
		return -floorf(t / _WANDER_OUT_END * _WANDER_FAR_X)
	if t < _WANDER_BACK_END:
		var back_steps: float = _WANDER_FAR_X - _WANDER_TURN_X
		return -_WANDER_FAR_X + floorf((t - _WANDER_OUT_END) / (_WANDER_BACK_END - _WANDER_OUT_END) * back_steps)
	return -_WANDER_TURN_X + floorf((t - _WANDER_BACK_END) / (FORAGE_WANDER_SECONDS - _WANDER_BACK_END) * _WANDER_TURN_X)

#-----------------------------------------------------------------------------
# TRAINING BOB
#-----------------------------------------------------------------------------

## The character's y offset from its stand, in whole world px, at elapsed
## seconds into the Aura Well's bob: 0, -1, -2, -1, a step every 0.6 s,
## repeating every 2.4 s (two screen px a step).
static func training_bob_y(elapsed: float) -> float:
	var step_seconds: float = TRAINING_BOB_SECONDS / _BOB_STEPS_Y.size()
	var t: float = fposmod(elapsed, TRAINING_BOB_SECONDS)
	var step: int = floori(t / step_seconds + _BOB_STEP_EPSILON) % _BOB_STEPS_Y.size()
	return _BOB_STEPS_Y[step]
