class_name EncounterIcon
extends Node2D

## EncounterIcon
## Renders an encounter glyph + frame at a tile center. Per-type configuration
## sets glyph texture, modulate color, frame size, and optional dramatic
## extras (boss ornamental ring, treasure sparkle).
##
## Visual states:
## - Default (just visited or revealed boss): full opacity, no checkmark
## - Completed (visited and player moved away): Dimmable parent at 0.45
##   alpha, Checkmark badge visible
##
## set_visited() is independent and only drives trap-encounter reveal.

@onready var _dimmable: Node2D = %Dimmable
@onready var _glyph: Sprite2D = %Glyph
@onready var _checkmark: Sprite2D = %Checkmark

const _GLYPH_COMBAT := preload("res://assets/sprites/ui/stat_icons/combat_icon.png")
const _GLYPH_ELITE := preload("res://assets/sprites/adventure/encounter_glyphs/elite.png")
const _GLYPH_BOSS := preload("res://assets/sprites/adventure/encounter_glyphs/boss_spritesheet.png")
const _GLYPH_REST := preload("res://assets/sprites/adventure/encounter_glyphs/rest.png")
const _GLYPH_TREASURE := preload("res://assets/sprites/adventure/encounter_glyphs/treasure.png")
const _GLYPH_TRAP := preload("res://assets/sprites/adventure/encounter_glyphs/trap.png")
const _GLYPH_UNKNOWN := preload("res://assets/sprites/adventure/encounter_glyphs/unknown.png")

## Target rendered size for every encounter glyph, in pixels. Each
## texture is scaled up (or down) to this size uniformly so encounter
## icons feel consistent regardless of their source resolution. For
## spritesheet glyphs (e.g. boss_spritesheet.png) the calculation uses
## the per-frame size, not the whole spritesheet width.
const ICON_TARGET_SIZE: float = 84.0

## Frame count for the animated boss glyph spritesheet. Keep in sync
## with the source asset: boss_spritesheet.png is a 448x64 strip of
## 7 frames at 64x64 each.
const BOSS_SPRITESHEET_HFRAMES: int = 7

## Duration of one full cycle through the boss spritesheet frames.
## Longer = calmer breathing animation.
const BOSS_ANIMATION_DURATION: float = 1.4

var _is_visited: bool = false
var _current_type: int = -1
var _boss_ring_tween: Tween
var _boss_breathe_tween: Tween

## Configures this icon to display the given encounter type.
## Returns false if the type should render no icon (NONE / unconfigured).
func configure_for_type(encounter_type: int) -> bool:
	_current_type = encounter_type
	_stop_boss_animation()
	# Reset spritesheet frame count in case a previous configure left us
	# on the boss's multi-frame state. Non-boss glyphs are single-frame
	# textures and should render with hframes/vframes = 1.
	_glyph.hframes = 1
	_glyph.vframes = 1
	_glyph.frame = 0

	match encounter_type:
		AdventureEncounter.EncounterType.COMBAT_REGULAR, AdventureEncounter.EncounterType.COMBAT_AMBUSH:
			_glyph.texture = _GLYPH_COMBAT
		AdventureEncounter.EncounterType.COMBAT_ELITE:
			_glyph.texture = _GLYPH_ELITE
		AdventureEncounter.EncounterType.COMBAT_BOSS:
			_glyph.texture = _GLYPH_BOSS
			_glyph.hframes = BOSS_SPRITESHEET_HFRAMES
			_start_boss_animation()
		AdventureEncounter.EncounterType.REST_SITE:
			_glyph.texture = _GLYPH_REST
		AdventureEncounter.EncounterType.TREASURE:
			_glyph.texture = _GLYPH_TREASURE
		AdventureEncounter.EncounterType.TRAP:
			_glyph.texture = _GLYPH_TRAP
		AdventureEncounter.EncounterType.NONE:
			return false
		_:
			# Fallback: mystery icon
			_glyph.texture = _GLYPH_UNKNOWN

	_apply_icon_scale()
	return true

## Scales the glyph sprite so its rendered frame measures ICON_TARGET_SIZE
## pixels on each side. Handles spritesheet textures by dividing out
## hframes/vframes, so a 448x64 boss strip with hframes=7 treats the
## frame as 64x64 rather than 448x64.
func _apply_icon_scale() -> void:
	if _glyph.texture == null:
		return
	var tex_size := _glyph.texture.get_size()
	var hf := maxi(_glyph.hframes, 1)
	var vf := maxi(_glyph.vframes, 1)
	var frame_size := Vector2(tex_size.x / float(hf), tex_size.y / float(vf))
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return
	_glyph.scale = Vector2(ICON_TARGET_SIZE / frame_size.x, ICON_TARGET_SIZE / frame_size.y)

## Marks this icon as visited so traps get revealed on the next
## configure_for_type call. Does NOT change the visual opacity — use
## set_completed() for the "visited + moved on" visual state.
func set_visited(visited: bool) -> void:
	_is_visited = visited
	# Re-run config so traps get revealed
	if _current_type != -1:
		configure_for_type(_current_type)

## Sets the icon's "visited + moved on" visual state. When completed,
## the encounter icon is dimmed to roughly half opacity via the Dimmable
## wrapper and a green checkmark badge appears in the bottom-right.
## Used by adventure_tilemap to mark tiles the player has cleared.
func set_completed(completed: bool) -> void:
	if completed:
		_dimmable.modulate.a = 0.90
		_checkmark.visible = true
	else:
		_dimmable.modulate.a = 1.0
		_checkmark.visible = false

## Returns the current configured type (used by tests).
func get_configured_type() -> int:
	return _current_type

## Cycles the boss glyph spritesheet frames on a loop. The tween drives
## _apply_boss_frame with a float that's truncated to an int each tick,
## so fractional time values step cleanly between frames without
## interpolating through partial frame indices.
func _start_boss_animation() -> void:
	_stop_boss_animation()
	var total_frames := _glyph.hframes * maxi(_glyph.vframes, 1)
	if total_frames <= 1:
		return
	_boss_ring_tween = create_tween()
	_boss_ring_tween.set_loops()
	_boss_ring_tween.tween_method(_apply_boss_frame, 0.0, float(total_frames), BOSS_ANIMATION_DURATION)

func _stop_boss_animation() -> void:
	if _boss_ring_tween and _boss_ring_tween.is_valid():
		_boss_ring_tween.kill()
	if _boss_breathe_tween and _boss_breathe_tween.is_valid():
		_boss_breathe_tween.kill()

## Tween callback for the boss spritesheet cycle. Clamps the incoming
## float to a valid frame index on the glyph. Guards against the tween
## firing after the node has been freed mid-cycle.
func _apply_boss_frame(f: float) -> void:
	if not is_instance_valid(_glyph):
		return
	var total_frames := _glyph.hframes * maxi(_glyph.vframes, 1)
	if total_frames <= 0:
		return
	_glyph.frame = int(f) % total_frames
