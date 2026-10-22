class_name ZoneHexMarker
extends Node2D

## ZoneHexMarker
## The rim over a charted, unlocked zone's hex on the zone map (kit §0, §6.1):
## the lacquer collar and brass rim on the current zone, a dull brass hairline
## on an open zone you are not in, and the brighter hover rim in its place
## while that open hex is hovered. Instanced per zone by ZoneTilemap and laid
## on the cell's centre; the textures are the tile's own size (map space).

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## Brass rim plus lacquer collar on the grout, for the zone you are in.
@export var current_texture: Texture2D
## Dull brass hairline, for an open zone you are not in.
@export var open_texture: Texture2D
## Brighter brass rim, for an open zone you can travel to while it is hovered.
@export var hover_texture: Texture2D

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _rim: Sprite2D = %Rim

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _state: ZoneManager.ZoneMapState = ZoneManager.ZoneMapState.OPEN
var _hovered: bool = false

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_refresh()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows the rim for the zone's map state: CURRENT or OPEN.
func setup(state: ZoneManager.ZoneMapState) -> void:
	_state = state
	_refresh()

## The map state the marker was set up with.
func get_state() -> ZoneManager.ZoneMapState:
	return _state

## Swaps the open hairline for the hover rim while hovered. The current
## zone's rim does not change on hover (its plate text brightens instead).
func set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_refresh()

## The rim texture drawn now.
func get_rim_texture() -> Texture2D:
	return _pick_texture()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _pick_texture() -> Texture2D:
	if _state == ZoneManager.ZoneMapState.CURRENT:
		return current_texture
	return hover_texture if _hovered else open_texture

func _refresh() -> void:
	if not is_node_ready():
		return
	_rim.texture = _pick_texture()
