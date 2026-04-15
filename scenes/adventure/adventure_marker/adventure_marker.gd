class_name AdventureMarker
extends Node2D

## A map-pin style marker that floats above the tile the player is
## currently standing on, displaying the tile's encounter glyph inside
## the pin's circular head. Replaces the old "flat encounter icon on
## the current tile" layout so the player's position on the hex grid
## isn't obscured by the icon they're about to interact with.
##
## Use show_at(world_pos, encounter_type) to position and configure
## the marker in one call; hide() (inherited) to hide it.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const _GLYPH_COMBAT := preload("res://assets/ui_images/stat_icons/combat_icon.png")
const _GLYPH_ELITE := preload("res://assets/sprites/adventure/encounter_glyphs/elite.png")
const _GLYPH_BOSS := preload("res://assets/sprites/adventure/encounter_glyphs/boss_spritesheet.png")
const _GLYPH_REST := preload("res://assets/sprites/adventure/encounter_glyphs/rest.png")
const _GLYPH_TREASURE := preload("res://assets/sprites/adventure/encounter_glyphs/treasure.png")
const _GLYPH_TRAP := preload("res://assets/sprites/adventure/encounter_glyphs/trap.png")
const _GLYPH_UNKNOWN := preload("res://assets/sprites/adventure/encounter_glyphs/unknown.png")

## Standard rendered size for encounter glyphs, in pixels. Matches
## EncounterIcon.ICON_TARGET_SIZE — this is the "reference size" that
## a flat encounter icon on a visited tile uses.
const ICON_TARGET_SIZE: float = 84.0

## Fraction of ICON_TARGET_SIZE the marker renders its inner glyph at,
## so the version inside the pin reads as a smaller, tighter callout
## while flat encounter icons on the map stay at full reference size.
## Also applied as a scale on the MarkerCheckmark sprite in the tscn
## so the check badge shrinks in lockstep with the glyph.
const MARKER_SCALE_FACTOR: float = 0.7

## Vertical offset from the tile center to the marker's pin point.
## Negative y is up in screen space — the pin floats above the tile so
## it doesn't block the player character sprite underneath.
const TILE_OFFSET_Y: float = -35.0

## Frame count for the animated boss glyph spritesheet.
const BOSS_SPRITESHEET_HFRAMES: int = 7

## Duration of one full boss spritesheet cycle.
const BOSS_ANIMATION_DURATION: float = 1.4

## Alpha applied to the glyph when the marker is showing a
## previously-resolved encounter. Matches EncounterIcon's set_completed
## dim value so a tile looks the same whether the player is standing on
## it (marker) or walked away (flat icon).
const COMPLETED_GLYPH_ALPHA: float = 0.9

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _glyph: Sprite2D = %MarkerGlyph
@onready var _checkmark: Sprite2D = %MarkerCheckmark

#-----------------------------------------------------------------------------
# PRIVATE STATE
#-----------------------------------------------------------------------------

var _boss_tween: Tween
var _current_type: int = -1

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Positions the marker at world_pos (should be the tile center) and
## configures the inner glyph for the given encounter type. Makes the
## marker visible. Applies TILE_OFFSET_Y so the pin point floats above
## the tile, not dead-center on the character. Safe to call repeatedly
## — the boss animation tween only restarts when the type actually
## changes, so same-type calls don't thrash.
##
## When `completed` is true, the glyph inside the marker is dimmed and
## the checkmark badge is shown, so revisiting a previously-resolved
## encounter tile looks "done" even while the player is standing on it.
func show_at(world_pos: Vector2, encounter_type: int, completed: bool = false) -> void:
	global_position = world_pos + Vector2(0.0, TILE_OFFSET_Y)
	if encounter_type != _current_type:
		_configure_for_type(encounter_type)
	_set_completed(completed)
	visible = true

## Applies the completed visual state to the marker contents (glyph +
## checkmark). The pin sprite stays at full opacity either way — only
## the inner icon reflects the encounter's "done" state.
func _set_completed(completed: bool) -> void:
	if completed:
		_glyph.modulate.a = COMPLETED_GLYPH_ALPHA
		_checkmark.visible = true
	else:
		_glyph.modulate.a = 1.0
		_checkmark.visible = false

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

## Swaps the glyph texture and kicks off boss-specific animation.
## Mirrors EncounterIcon.configure_for_type but doesn't track a
## completed/checkmark state — the marker is only ever shown on the
## active tile, which by definition isn't done yet.
func _configure_for_type(encounter_type: int) -> void:
	_current_type = encounter_type
	_stop_boss_animation()
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
		_:
			_glyph.texture = _GLYPH_UNKNOWN

	_apply_icon_scale()

func _apply_icon_scale() -> void:
	if _glyph.texture == null:
		return
	var tex_size := _glyph.texture.get_size()
	var hf := maxi(_glyph.hframes, 1)
	var vf := maxi(_glyph.vframes, 1)
	var frame_size := Vector2(tex_size.x / float(hf), tex_size.y / float(vf))
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return
	var effective_size := ICON_TARGET_SIZE * MARKER_SCALE_FACTOR
	_glyph.scale = Vector2(effective_size / frame_size.x, effective_size / frame_size.y)

func _start_boss_animation() -> void:
	_stop_boss_animation()
	var total_frames := _glyph.hframes * maxi(_glyph.vframes, 1)
	if total_frames <= 1:
		return
	_boss_tween = create_tween()
	_boss_tween.set_loops()
	_boss_tween.tween_method(_apply_boss_frame, 0.0, float(total_frames), BOSS_ANIMATION_DURATION)

func _stop_boss_animation() -> void:
	if _boss_tween and _boss_tween.is_valid():
		_boss_tween.kill()

func _apply_boss_frame(f: float) -> void:
	if not is_instance_valid(_glyph):
		return
	var total_frames := _glyph.hframes * maxi(_glyph.vframes, 1)
	if total_frames <= 0:
		return
	_glyph.frame = int(f) % total_frames
