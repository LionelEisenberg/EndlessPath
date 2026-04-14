class_name TileStateOverlay
extends Node2D

## TileStateOverlay
## Pools Sprite2D overlays per cube coordinate to render the 5 tile states
## (HIDDEN, REVEAL, VISITED, CURRENT, HOVER_TARGET) as visual layers above
## the existing AdventureVisibleMap tilemap. State transitions are animated
## via Tweens. No tilemap data is touched.

enum TileState {
	HIDDEN,
	REVEAL,
	VISITED,
	CURRENT,
	HOVER_TARGET,
}

const _AURA_TEXTURE := preload("res://assets/sprites/atmosphere/aura_glow.png")

var _overlays: Dictionary[Vector3i, Sprite2D] = {}
var _states: Dictionary[Vector3i, int] = {}

## Sets the state of a tile at the given cube coordinate.
## Creates the overlay if it does not exist.
## world_pos is the tile center in the parent's local coordinate space.
func set_tile_state(cube: Vector3i, state: int, world_pos: Vector2) -> void:
	var sprite: Sprite2D = _overlays.get(cube)
	if sprite == null:
		sprite = _make_sprite()
		_overlays[cube] = sprite
		add_child(sprite)
	sprite.position = world_pos
	_apply_state(sprite, state)
	_states[cube] = state

## Removes the overlay at the given cube coordinate.
func remove_tile(cube: Vector3i) -> void:
	var sprite: Sprite2D = _overlays.get(cube)
	if sprite == null:
		return
	sprite.queue_free()
	_overlays.erase(cube)
	_states.erase(cube)

## Removes all overlays.
func clear_all() -> void:
	for sprite in _overlays.values():
		sprite.queue_free()
	_overlays.clear()
	_states.clear()

## Returns the current state for a tile, or -1 if not tracked.
func get_state(cube: Vector3i) -> int:
	return _states.get(cube, -1)

## Returns the number of tracked overlays. Used by tests.
func get_overlay_count() -> int:
	return _overlays.size()

func _make_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _AURA_TEXTURE
	sprite.scale = Vector2(0.55, 0.55)
	sprite.modulate = Color(1, 1, 1, 0)
	return sprite

func _apply_state(sprite: Sprite2D, state: int) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	match state:
		TileState.HIDDEN:
			tween.tween_property(sprite, "modulate", Color(0.1, 0.13, 0.22, 0.5), 0.15)
			tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.15)
		TileState.REVEAL:
			tween.tween_property(sprite, "modulate", Color(0.55, 0.71, 0.95, 0.7), 0.15)
			tween.tween_property(sprite, "scale", Vector2(0.55, 0.55), 0.15)
		TileState.VISITED:
			tween.tween_property(sprite, "modulate", Color(0.35, 0.45, 0.62, 0.45), 0.15)
			tween.tween_property(sprite, "scale", Vector2(0.55, 0.55), 0.15)
		TileState.CURRENT:
			tween.tween_property(sprite, "modulate", Color(0.7, 0.88, 1.0, 0.95), 0.15)
			tween.tween_property(sprite, "scale", Vector2(0.85, 0.85), 0.15)
		TileState.HOVER_TARGET:
			tween.tween_property(sprite, "modulate", Color(0.85, 0.95, 1.0, 1.0), 0.08)
			tween.tween_property(sprite, "scale", Vector2(0.65, 0.65), 0.08)
