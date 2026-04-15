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
@onready var _frame: Sprite2D = %Frame
@onready var _glyph: Sprite2D = %Glyph
@onready var _ornamental_ring: Sprite2D = %OrnamentalRing
@onready var _checkmark: Sprite2D = %Checkmark

const _GLYPH_COMBAT := preload("res://assets/sprites/adventure/encounter_glyphs/combat.png")
const _GLYPH_ELITE := preload("res://assets/sprites/adventure/encounter_glyphs/elite.png")
const _GLYPH_BOSS := preload("res://assets/sprites/adventure/encounter_glyphs/boss.png")
const _GLYPH_REST := preload("res://assets/sprites/adventure/encounter_glyphs/rest.png")
const _GLYPH_TREASURE := preload("res://assets/sprites/adventure/encounter_glyphs/treasure.png")
const _GLYPH_TRAP := preload("res://assets/sprites/adventure/encounter_glyphs/trap.png")
const _GLYPH_UNKNOWN := preload("res://assets/sprites/adventure/encounter_glyphs/unknown.png")

var _is_visited: bool = false
var _current_type: int = -1
var _boss_ring_tween: Tween
var _boss_breathe_tween: Tween

## Configures this icon to display the given encounter type.
## Returns false if the type should render no icon (NONE / unconfigured).
func configure_for_type(encounter_type: int) -> bool:
	_current_type = encounter_type
	_stop_boss_animation()
	_ornamental_ring.visible = false
	_frame.scale = Vector2(1, 1)
	_glyph.scale = Vector2(1, 1)

	match encounter_type:
		AdventureEncounter.EncounterType.COMBAT_REGULAR, AdventureEncounter.EncounterType.COMBAT_AMBUSH:
			_glyph.texture = _GLYPH_COMBAT
			_glyph.modulate = Color(0.85, 0.51, 0.44, 1.0)
			_frame.modulate = Color(0.55, 0.13, 0.13, 0.7)
			return true
		AdventureEncounter.EncounterType.COMBAT_ELITE:
			_glyph.texture = _GLYPH_ELITE
			_glyph.modulate = Color(0.88, 0.5, 0.88, 1.0)
			_frame.modulate = Color(0.4, 0.1, 0.45, 0.78)
			_frame.scale = Vector2(1.12, 1.12)
			return true
		AdventureEncounter.EncounterType.COMBAT_BOSS:
			_glyph.texture = _GLYPH_BOSS
			_glyph.modulate = Color(1.0, 0.94, 0.75, 1.0)
			_frame.modulate = Color(0.94, 0.31, 0.16, 0.95)
			_frame.scale = Vector2(1.65, 1.65)
			_glyph.scale = Vector2(1.5, 1.5)
			_ornamental_ring.visible = true
			_start_boss_animation()
			return true
		AdventureEncounter.EncounterType.REST_SITE:
			_glyph.texture = _GLYPH_REST
			_glyph.modulate = Color(0.55, 0.94, 0.65, 1.0)
			_frame.modulate = Color(0.08, 0.39, 0.24, 0.7)
			return true
		AdventureEncounter.EncounterType.TREASURE:
			_glyph.texture = _GLYPH_TREASURE
			_glyph.modulate = Color(1.0, 0.86, 0.31, 1.0)
			_frame.modulate = Color(0.63, 0.35, 0.0, 0.78)
			return true
		AdventureEncounter.EncounterType.TRAP:
			# Traps are hidden until visited
			if not _is_visited:
				return false
			_glyph.texture = _GLYPH_TRAP
			_glyph.modulate = Color(0.86, 0.39, 0.16, 1.0)
			_frame.modulate = Color(0.31, 0.0, 0.0, 0.78)
			return true
		AdventureEncounter.EncounterType.NONE:
			return false
		_:
			# Fallback: mystery icon
			_glyph.texture = _GLYPH_UNKNOWN
			_glyph.modulate = Color(0.71, 0.59, 0.94, 1.0)
			_frame.modulate = Color(0.24, 0.12, 0.47, 0.78)
			return true

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
		_dimmable.modulate.a = 0.45
		_checkmark.visible = true
	else:
		_dimmable.modulate.a = 1.0
		_checkmark.visible = false

## Returns the current configured type (used by tests).
func get_configured_type() -> int:
	return _current_type

func _start_boss_animation() -> void:
	_stop_boss_animation()
	_boss_ring_tween = create_tween()
	_boss_ring_tween.set_loops()
	_boss_ring_tween.tween_property(_ornamental_ring, "rotation", TAU, 20.0).set_trans(Tween.TRANS_LINEAR)
	_boss_ring_tween.tween_callback(func(): _ornamental_ring.rotation = 0.0)

	_boss_breathe_tween = create_tween()
	_boss_breathe_tween.set_loops()
	_boss_breathe_tween.set_trans(Tween.TRANS_SINE)
	_boss_breathe_tween.set_ease(Tween.EASE_IN_OUT)
	_boss_breathe_tween.tween_property(_frame, "scale", Vector2(1.78, 1.78), 0.9)
	_boss_breathe_tween.tween_property(_frame, "scale", Vector2(1.65, 1.65), 0.9)

func _stop_boss_animation() -> void:
	if _boss_ring_tween and _boss_ring_tween.is_valid():
		_boss_ring_tween.kill()
	if _boss_breathe_tween and _boss_breathe_tween.is_valid():
		_boss_breathe_tween.kill()
	if is_instance_valid(_ornamental_ring):
		_ornamental_ring.rotation = 0.0
