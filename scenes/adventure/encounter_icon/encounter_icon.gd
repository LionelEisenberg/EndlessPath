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

const _GLYPH_COMBAT := preload("res://assets/ui_images/stat_icons/combat_icon.png")
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
	_glyph.scale = Vector2(1, 1)

	match encounter_type:
		AdventureEncounter.EncounterType.COMBAT_REGULAR, AdventureEncounter.EncounterType.COMBAT_AMBUSH:
			_glyph.texture = _GLYPH_COMBAT
			return true
		AdventureEncounter.EncounterType.COMBAT_ELITE:
			_glyph.texture = _GLYPH_ELITE
			return true
		AdventureEncounter.EncounterType.COMBAT_BOSS:
			_glyph.texture = _GLYPH_BOSS
			_start_boss_animation()
			return true
		AdventureEncounter.EncounterType.REST_SITE:
			_glyph.texture = _GLYPH_REST
			return true
		AdventureEncounter.EncounterType.TREASURE:
			_glyph.texture = _GLYPH_TREASURE
			return true
		AdventureEncounter.EncounterType.TRAP:
			_glyph.texture = _GLYPH_TRAP
			return true
		AdventureEncounter.EncounterType.NONE:
			return false
		_:
			# Fallback: mystery icon
			_glyph.texture = _GLYPH_UNKNOWN
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
		_dimmable.modulate.a = 0.90
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

	_boss_breathe_tween = create_tween()
	_boss_breathe_tween.set_loops()
	_boss_breathe_tween.set_trans(Tween.TRANS_SINE)
	_boss_breathe_tween.set_ease(Tween.EASE_IN_OUT)

func _stop_boss_animation() -> void:
	if _boss_ring_tween and _boss_ring_tween.is_valid():
		_boss_ring_tween.kill()
	if _boss_breathe_tween and _boss_breathe_tween.is_valid():
		_boss_breathe_tween.kill()
