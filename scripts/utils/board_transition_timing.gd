class_name BoardTransitionTiming
extends RefCounted

## BoardTransitionTiming
## Pure timing for the board open and close transition, in milliseconds from
## the start of the open (the close plays the same timeline backwards). Where
## the camera is, how far the board has grown, how far down the dock has
## stepped, how far each chest row has slid and how tall the chest is, and how
## far each HUD board has moved off the screen, each at a given time; and where
## the camera goes so the cultivator lands under the board.
## The camera and the board move smoothly; every other move is stepped, at
## constant speed in whole 2 px steps (snap_even). Statics only.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The camera eases from the start to here.
const CAMERA_END_MS: float = 480.0
## The camera ends at this multiple of the zoom the player had.
const CAMERA_ZOOM_FACTOR: float = 1.5
## The camera brings the cultivator to this far below the board's centre, in
## screen px.
const CULTIVATOR_BELOW_CENTRE: float = 70.0

## The dock steps off the bottom of the screen from the start to here.
const DOCK_END_MS: float = 140.0

## The board scales from BOARD_START_SCALE to full size between these, and is
## hidden before BOARD_START_MS.
const BOARD_START_MS: float = 200.0
const BOARD_END_MS: float = 520.0
const BOARD_START_SCALE: float = 0.03

## The chest swap (cycling only): the activity rows step out before
## CHEST_SWAP_MS, then the technique rows step in and the chest changes
## height between CHEST_SWAP_MS and CHEST_END_MS.
const CHEST_SWAP_MS: float = 300.0
const CHEST_END_MS: float = 540.0
## One row takes this long to cross, going out and coming in.
const ROW_OUT_MS: float = 120.0
const ROW_IN_MS: float = 140.0
## The most one row waits for the one before it, going out and coming in; it
## is less when many rows would not otherwise fit their window.
const OUT_STAGGER_MAX: float = 20.0
const IN_STAGGER_MAX: float = 25.0

## One HUD board (the Tribulation's Goals and log) takes this long to leave,
## and starts this long after the one before it.
const HUD_MS: float = 160.0
const HUD_STAGGER: float = 40.0

#-----------------------------------------------------------------------------
# TIME
#-----------------------------------------------------------------------------

## How long the open takes: to the end of the chest swap if the board swaps
## its chest (cycling), else to the end of the board's growth.
static func duration_ms(swaps_chest: bool) -> float:
	return CHEST_END_MS if swaps_chest else BOARD_END_MS

## How far t_ms is from start_ms to end_ms, from 0 to 1, held at either end.
static func segment(t_ms: float, start_ms: float, end_ms: float) -> float:
	return clampf((t_ms - start_ms) / (end_ms - start_ms), 0.0, 1.0)

## value rounded to the nearest even number: stepped moves go in 2 px steps.
static func snap_even(value: float) -> float:
	return roundf(value / 2.0) * 2.0

#-----------------------------------------------------------------------------
# CAMERA AND BOARD
#-----------------------------------------------------------------------------

## How far the camera has come from where the player left it to its end
## framing, from 0 to 1, easing in and out (cubic). It weights the zoom and
## the position alike.
static func camera_weight(t_ms: float) -> float:
	return _ease_in_out_cubic(segment(t_ms, 0.0, CAMERA_END_MS))

## True from the moment the board appears.
static func is_board_shown(t_ms: float) -> bool:
	return t_ms >= BOARD_START_MS

## The board's scale, from BOARD_START_SCALE to 1, easing out (cubic).
static func board_scale(t_ms: float) -> float:
	return lerpf(BOARD_START_SCALE, 1.0, _ease_out_cubic(segment(t_ms, BOARD_START_MS, BOARD_END_MS)))

#-----------------------------------------------------------------------------
# DOCK
#-----------------------------------------------------------------------------

## How far down the dock has stepped, from 0 to travel.
static func dock_offset(t_ms: float, travel: float) -> float:
	return snap_even(travel * segment(t_ms, 0.0, DOCK_END_MS))

#-----------------------------------------------------------------------------
# CHEST SWAP
#-----------------------------------------------------------------------------

## How long each activity row waits for the one before it to start out, for
## row_count rows: OUT_STAGGER_MAX, less if the last row would not be across
## by CHEST_SWAP_MS.
static func out_stagger(row_count: int) -> float:
	if row_count <= 1:
		return 0.0
	return minf(OUT_STAGGER_MAX, (CHEST_SWAP_MS - ROW_OUT_MS) / (row_count - 1))

## How long each technique row waits for the one before it to start in, for
## row_count rows: IN_STAGGER_MAX, less if the last row would not be in by
## CHEST_END_MS.
static func in_stagger(row_count: int) -> float:
	if row_count <= 1:
		return 0.0
	return minf(IN_STAGGER_MAX, (CHEST_END_MS - CHEST_SWAP_MS - ROW_IN_MS) / (row_count - 1))

## How far activity row index (of row_count) has slid out, from 0 to travel.
static func row_out_offset(t_ms: float, index: int, row_count: int, travel: float) -> float:
	var start_ms: float = index * out_stagger(row_count)
	return snap_even(travel * segment(t_ms, start_ms, start_ms + ROW_OUT_MS))

## How far technique row index (of row_count) still has to slide in, from
## travel down to 0.
static func row_in_offset(t_ms: float, index: int, row_count: int, travel: float) -> float:
	var start_ms: float = CHEST_SWAP_MS + index * in_stagger(row_count)
	return snap_even(travel * (1.0 - segment(t_ms, start_ms, start_ms + ROW_IN_MS)))

## The chest's height, stepping from from_height to to_height between
## CHEST_SWAP_MS and CHEST_END_MS.
static func chest_height(t_ms: float, from_height: float, to_height: float) -> float:
	return snap_even(lerpf(from_height, to_height, segment(t_ms, CHEST_SWAP_MS, CHEST_END_MS)))

#-----------------------------------------------------------------------------
# HUD BOARDS
#-----------------------------------------------------------------------------

## How far HUD board index has moved off the screen, from 0 to travel.
static func hud_offset(t_ms: float, index: int, travel: float) -> float:
	var start_ms: float = index * HUD_STAGGER
	return snap_even(travel * segment(t_ms, start_ms, start_ms + HUD_MS))

#-----------------------------------------------------------------------------
# FRAMING
#-----------------------------------------------------------------------------

## The screen point the camera brings the cultivator to for a board occupying
## board_rect: its horizontal centre, CULTIVATOR_BELOW_CENTRE under its
## vertical centre.
static func cultivator_target(board_rect: Rect2) -> Vector2:
	return board_rect.get_center() + Vector2(0.0, CULTIVATOR_BELOW_CENTRE)

## The camera position (its screen centre) that puts the world point
## world_point at screen_point at the given zoom.
static func push_camera_position(world_point: Vector2, screen_point: Vector2, zoom: float) -> Vector2:
	return world_point - (screen_point - ZoneMapMath.VIEWPORT_SIZE / 2.0) / zoom

#-----------------------------------------------------------------------------
# EASING
#-----------------------------------------------------------------------------

## Cubic ease in and out of u, 0 to 1.
static func _ease_in_out_cubic(u: float) -> float:
	if u < 0.5:
		return 4.0 * u * u * u
	return 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0

## Cubic ease out of u, 0 to 1.
static func _ease_out_cubic(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)
