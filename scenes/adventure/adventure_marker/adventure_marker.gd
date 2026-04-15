class_name AdventureMarker
extends Node2D

## A map-pin style marker that floats above the tile the player is
## currently standing on, displaying the tile's encounter glyph inside
## the pin's circular head. Wraps a reusable EncounterIcon instance so
## glyph selection, boss-skull animation, and completed-state visuals
## (dim + checkmark) are shared with the flat encounter icons on the
## rest of the map — no duplicated logic here.
##
## Use show_at(world_pos, encounter_type, completed) to position and
## configure the marker in one call; hide() (inherited from CanvasItem)
## to hide it.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Vertical offset from the tile center to the marker's pin point.
## Negative y is up in screen space — the pin floats above the tile so
## it doesn't block the player character sprite underneath.
const TILE_OFFSET_Y: float = -35.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

## The embedded EncounterIcon scene instance. Scaled down in the .tscn
## so the marker version reads as a smaller callout compared to the
## flat icons on the rest of the map.
@onready var _encounter_icon: EncounterIcon = %InnerEncounterIcon

#-----------------------------------------------------------------------------
# PRIVATE STATE
#-----------------------------------------------------------------------------

## Cached encounter type so we don't re-run configure_for_type on every
## _update_visible_map call — re-running would kill and restart the
## boss spritesheet tween on every render, causing a visible hitch.
var _last_type: int = -1

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Positions the marker at world_pos (should be the tile center) and
## configures the inner EncounterIcon for the given encounter type.
## Makes the marker visible. Applies TILE_OFFSET_Y so the pin point
## floats above the tile, not dead-center on the character.
##
## When `completed` is true, the inner icon renders in its completed
## visual state (Dimmable wrapper at ~0.9 alpha, checkmark badge
## visible) so revisiting a previously-resolved encounter tile looks
## "done" while the player is standing on it.
##
## Safe to call repeatedly with the same type — the EncounterIcon's
## boss-animation tween is only reset when the type actually changes.
func show_at(world_pos: Vector2, encounter_type: int, completed: bool = false) -> void:
	global_position = world_pos + Vector2(0.0, TILE_OFFSET_Y)
	if encounter_type != _last_type:
		_encounter_icon.configure_for_type(encounter_type)
		_last_type = encounter_type
	_encounter_icon.set_completed(completed)
	visible = true
