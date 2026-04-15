class_name HexHoverSelector
extends Sprite2D

## A hex-shaped animated selector ring that frames the tile under the
## mouse cursor on a tilemap. Encapsulates the spritesheet-cycle
## animation so multiple tilemaps (zone, adventure) can share the same
## hover feedback without each one duplicating the per-frame timer logic.
##
## Usage:
##   - Drop hex_hover_selector.tscn into your scene as a sibling of the
##     tilemap layer (must be a child of a Node2D in the same world space)
##   - In the tilemap's hover handler, call show_at(world_pos) to make
##     the selector visible and snap it onto a tile
##   - Call hide() (the built-in CanvasItem method) when the cursor
##     leaves a valid tile

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## Frame rate at which the spritesheet cycles when the selector is
## visible. The texture's hframes/vframes determine the total frame
## count; this value just controls how fast we step through them.
@export_range(1.0, 30.0, 0.5) var hover_fps: float = 8.0

#-----------------------------------------------------------------------------
# PRIVATE STATE
#-----------------------------------------------------------------------------

var _hover_frame_time: float = 0.0

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Snaps the selector onto a tile by setting its global position, then
## makes it visible. If the selector wasn't already visible, the frame
## animation restarts from frame 0 so the cycle always begins cleanly
## on a new tile (no mid-cycle resume when hopping between tiles).
func show_at(world_pos: Vector2) -> void:
	global_position = world_pos
	if not visible:
		_hover_frame_time = 0.0
		frame = 0
	visible = true

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	_hover_frame_time += delta
	var total_frames := hframes * maxi(vframes, 1)
	if total_frames > 0:
		frame = int(_hover_frame_time * hover_fps) % total_frames
