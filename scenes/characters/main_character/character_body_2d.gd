extends CharacterBody2D

@export var is_debug_mode : bool = false

# Movement variables
var target_position: Vector2 = Vector2.ZERO
var move_speed: float = 0.0
var is_moving: bool = false
var movement_threshold: float = 5.0  # Distance at which we consider arrival

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _physics_process(_delta: float) -> void:
	if is_moving:
		_update_movement()


func _unhandled_input(event: InputEvent) -> void:
	if is_debug_mode and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Get the global mouse position and move the character there
			var click_position = get_global_mouse_position()
			move_to_position(click_position, move_speed if move_speed > 0 else 200.0)

## Moves the character to the given position at the specified speed.
## Automatically plays the appropriate walk animation based on direction.
func move_to_position(new_position: Vector2, speed: float) -> void:
	target_position = new_position
	move_speed = speed
	is_moving = true

	# Determine and play the appropriate walk animation
	_play_directional_animation()

## Updates the character's position each frame during movement.
func _update_movement() -> void:
	var direction = (target_position - global_position).normalized()
	var distance = global_position.distance_to(target_position)

	# Check if we've reached the target
	if distance <= movement_threshold:
		global_position = target_position
		_stop_movement()
		return

	# Move towards the target
	velocity = direction * move_speed
	move_and_slide()

## Plays the walk animation that corresponds to the movement direction.
## Supports all 8 cardinal directions (N, NE, E, SE, S, SW, W, NW).
func _play_directional_animation() -> void:
	if not is_moving:
		return

	var direction = (target_position - global_position).normalized()

	# Calculate the angle in degrees (0 = right, 90 = down, 180 = left, 270 = up)
	var angle = rad_to_deg(direction.angle())

	# Normalize angle to 0-360 range
	if angle < 0:
		angle += 360

	# Determine which animation to play based on angle
	# Each direction gets a 45-degree slice
	if angle >= 337.5 or angle < 22.5:
		# East (Right)
		animation_player.play("walk_right")
	elif angle >= 22.5 and angle < 67.5:
		# Southeast (Down-Right)
		animation_player.play("walk_down_right")
	elif angle >= 67.5 and angle < 112.5:
		# South (Down)
		animation_player.play("walk_down")
	elif angle >= 112.5 and angle < 157.5:
		# Southwest (Down-Left)
		animation_player.play("walk_down_left")
	elif angle >= 157.5 and angle < 202.5:
		# West (Left)
		animation_player.play("walk_left")
	elif angle >= 202.5 and angle < 247.5:
		# Northwest (Up-Left)
		animation_player.play("walk_up_left")
	elif angle >= 247.5 and angle < 292.5:
		# North (Up)
		animation_player.play("walk_up")
	elif angle >= 292.5 and angle < 337.5:
		# Northeast (Up-Right)
		animation_player.play("walk_up_right")

## Stops the character's movement and animation.
func _stop_movement() -> void:
	is_moving = false
	velocity = Vector2.ZERO
	animation_player.play("RESET")
