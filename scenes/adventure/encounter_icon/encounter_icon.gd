class_name EncounterIcon
extends Node2D

## EncounterIcon
## Renders an encounter glyph + frame at a tile center. Per-type configuration
## sets glyph texture, modulate color, frame size, and optional dramatic
## extras (boss ornamental ring, treasure sparkle).

@onready var _frame: Sprite2D = %Frame
@onready var _glyph: Sprite2D = %Glyph
@onready var _ornamental_ring: Sprite2D = %OrnamentalRing

const _GLYPH_COMBAT := preload("res://assets/sprites/adventure/encounter_glyphs/combat.png")
const _GLYPH_ELITE := preload("res://assets/sprites/adventure/encounter_glyphs/elite.png")
const _GLYPH_BOSS := preload("res://assets/sprites/adventure/encounter_glyphs/boss.png")
const _GLYPH_REST := preload("res://assets/sprites/adventure/encounter_glyphs/rest.png")
const _GLYPH_TREASURE := preload("res://assets/sprites/adventure/encounter_glyphs/treasure.png")
const _GLYPH_TRAP := preload("res://assets/sprites/adventure/encounter_glyphs/trap.png")
const _GLYPH_UNKNOWN := preload("res://assets/sprites/adventure/encounter_glyphs/unknown.png")

var _is_visited: bool = false
var _current_type: int = -1

## Configures this icon to display the given encounter type.
## Returns false if the type should render no icon (NONE / unconfigured).
func configure_for_type(encounter_type: int) -> bool:
	_current_type = encounter_type
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

## Marks this icon as visited (dimmed/desaturated, traps revealed).
func set_visited(visited: bool) -> void:
	_is_visited = visited
	if visited:
		modulate = Color(1, 1, 1, 0.45)
	else:
		modulate = Color(1, 1, 1, 1.0)
	# Re-run config so traps get revealed
	if _current_type != -1:
		configure_for_type(_current_type)

## Returns the current configured type (used by tests).
func get_configured_type() -> int:
	return _current_type
