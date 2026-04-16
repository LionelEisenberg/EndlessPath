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
## ethereal/atmospheric; faster values feel more violent/chaotic. 2.5 FPS
## gives a calm, almost-static drift; the 25 distinct frames cycle every
## 10 seconds, slow enough that adjacent frames blend perceptually.
@export_range(0.25, 30.0, 0.25) var animation_fps: float = 2.5

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

## Fades self_modulate alpha to zero over the given duration and then
## queue_frees this veil. Used by the adventure tilemap's fog-of-war
## diff when a revealed tile transitions to visited or falls out of
## reveal range — the smoke should dissipate, not pop.
func fade_and_free(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "self_modulate:a", 0.0, duration)
	tween.tween_callback(queue_free)
