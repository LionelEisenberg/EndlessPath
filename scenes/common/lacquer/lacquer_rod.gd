@tool
class_name LacquerRod
extends Control

## A stepped lacquer progress rod (lacquer kit §4.3): the empty groove, the
## full rod clipped to width 2 + 2k, and a 2 px end cap at x = 2k once
## k >= 2, where k = round(fraction x steps). The rod shows at its file size
## and moves in whole 2 px steps, never scaled or eased.
## Kit rods: the Now strip's (rod_now, 144 steps), milestone (rod_goal, 138)
## and adventure Madra (rod_adv, 74).
## It runs in the editor (@tool), so a placed rod shows its groove at its
## size; the editor shows it empty.

## The empty groove; the rod takes its size.
@export var empty_texture: Texture2D = null:
	set(value):
		empty_texture = value
		update_minimum_size()
		_apply_textures()

## The full rod, drawn over the groove and clipped to the step.
@export var full_texture: Texture2D = null:
	set(value):
		full_texture = value
		_apply_textures()

## The 2 px lit end of the fill.
@export var end_texture: Texture2D = null:
	set(value):
		end_texture = value
		_apply_textures()

## Steps from empty to full.
@export var steps: int = 1:
	set(value):
		steps = maxi(1, value)
		_apply_step()

@onready var _empty: TextureRect = %Empty
@onready var _full_clip: Control = %FullClip
@onready var _full: TextureRect = %Full
@onready var _end: TextureRect = %End

var _fraction: float = 0.0
var _step: int = 0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_apply_textures()
	_apply_step()

func _get_minimum_size() -> Vector2:
	return empty_texture.get_size() if empty_texture != null else Vector2.ZERO

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Fills the rod to fraction (clamped to 0-1), rounded to a whole step.
func set_fraction(fraction: float) -> void:
	_fraction = clampf(fraction, 0.0, 1.0)
	_apply_step()

## Returns the step shown, from 0 to steps.
func get_step() -> int:
	return _step

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _apply_textures() -> void:
	if not is_node_ready():
		return
	_empty.texture = empty_texture
	_full.texture = full_texture
	_end.texture = end_texture
	_apply_step()

func _apply_step() -> void:
	_step = roundi(_fraction * steps)
	if not is_node_ready():
		return
	var height: float = full_texture.get_height() if full_texture != null else 0.0
	_full_clip.size = Vector2(2 + 2 * _step, height)
	_end.position = Vector2(2 * _step, 0)
	_end.visible = _step >= 2
