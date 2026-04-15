class_name FogVeilSprite
extends Sprite2D

## A swirling smoke + question mark overlay drawn on top of a tile that
## the player can SEE but doesn't yet know the contents of. Used by the
## adventure tilemap's fog of war system to mask revealed-but-unvisited
## neighbors of the player's current tile.
##
## The smoke spritesheet animation runs autonomously in _process; show
## or hide via the visible property and position via global_position.
## Each instance picks a random starting frame so adjacent veils don't
## visually sync.

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## Frame rate at which the smoke spritesheet cycles. Slow values feel
## ethereal/atmospheric; faster values feel more violent/chaotic. 6 FPS
## is a good starting point for a slow drift.
@export_range(1.0, 30.0, 0.5) var animation_fps: float = 6.0

#-----------------------------------------------------------------------------
# PRIVATE STATE
#-----------------------------------------------------------------------------

var _frame_time: float = 0.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	# Pick a random starting frame so adjacent fog veils don't sync up
	# visually — gives the impression of independent swirls.
	var total_frames := hframes * maxi(vframes, 1)
	if total_frames > 0:
		frame = randi() % total_frames
		_frame_time = float(frame) / animation_fps

func _process(delta: float) -> void:
	if not visible:
		return
	_frame_time += delta
	var total_frames := hframes * maxi(vframes, 1)
	if total_frames > 0:
		frame = int(_frame_time * animation_fps) % total_frames
