class_name LockedZoneOverlay
extends Node2D

## LockedZoneOverlay
## The veiled tile over a locked or uncharted zone's hex on the zone map (kit
## §0, §4.6): the zone's tile in a palette veil with its dashed vermilion
## (locked) or dotted tan (uncharted) rim baked in, one step lighter while
## hovered, and a thin (hovered) or heavy (pinned) brass rim just inside it.
## Instanced per veiled zone by ZoneTilemap and laid on the cell's centre. The
## lock and "?" glyphs are drawn by the map markers, not here.
##
## The veil art bakes the demo zones' tiles (Stones for the locked zone,
## Mountains2 for the uncharted one); a zone with another tile needs its own.

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

@export_group("Veils")
@export var locked_texture: Texture2D
@export var locked_hover_texture: Texture2D
@export var uncharted_texture: Texture2D
@export var uncharted_hover_texture: Texture2D

@export_group("Inner rims")
## One art px of brass, then ink: the hovered veiled hex.
@export var hover_rim_texture: Texture2D
## Two art px of brass, then ink: the pinned veiled hex.
@export var pinned_rim_texture: Texture2D

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _tile: Sprite2D = %Tile
@onready var _rim: Sprite2D = %Rim

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _state: ZoneManager.ZoneMapState = ZoneManager.ZoneMapState.LOCKED
var _hovered: bool = false
var _pinned: bool = false

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_refresh()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows the veil for the zone's map state: LOCKED or UNCHARTED.
func setup(state: ZoneManager.ZoneMapState) -> void:
	_state = state
	_refresh()

## The map state the overlay was set up with.
func get_state() -> ZoneManager.ZoneMapState:
	return _state

## Hovered: the lighter veil and, unless pinned, the thin inner rim.
func set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_refresh()

## Pinned (its popover is pinned): the heavy inner rim, hovered or not.
func set_pinned(pinned: bool) -> void:
	_pinned = pinned
	_refresh()

## The veiled tile texture drawn now.
func get_tile_texture() -> Texture2D:
	return _pick_tile_texture()

## The inner rim texture drawn now, or null when no rim shows.
func get_rim_texture() -> Texture2D:
	return _pick_rim_texture()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _pick_tile_texture() -> Texture2D:
	if _state == ZoneManager.ZoneMapState.UNCHARTED:
		return uncharted_hover_texture if _hovered else uncharted_texture
	return locked_hover_texture if _hovered else locked_texture

func _pick_rim_texture() -> Texture2D:
	if _pinned:
		return pinned_rim_texture
	if _hovered:
		return hover_rim_texture
	return null

func _refresh() -> void:
	if not is_node_ready():
		return
	_tile.texture = _pick_tile_texture()
	var rim_texture: Texture2D = _pick_rim_texture()
	_rim.texture = rim_texture
	_rim.visible = rim_texture != null
