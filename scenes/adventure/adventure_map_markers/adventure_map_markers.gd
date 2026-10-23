class_name AdventureMapMarkers
extends Node2D

## AdventureMapMarkers
## The adventure map's coins (spec: The map, Coins), drawn over the map in screen
## space, as MapMarkers draws the zone map's plates and glyphs.
## A coin (EncounterCoin) marks every tile the player sees that has something to
## show: a "?" on a revealed tile (an empty one too, so a coin never gives away
## an empty tile), the encounter's glyph once the tile is visited, a carved coin
## once it is resolved, and the boss's own coin from the moment its tile comes
## into view, shaking as it does. A visited empty tile has none. Under the dev
## panel's Show Whole Map every unvisited encounter tile shows its glyph.
## The layer is a node of the map's own canvas, not a canvas layer, so the
## character can draw over it: its z index (50) puts it over the tiles, the rims,
## the fog and the route (all at 0) and under the character's shadow and the
## character (99 and 100), and the character walks over a coin instead of behind
## it. It stays in screen space all the same: in every placement pass its
## transform is set to the inverse of the viewport's canvas transform (the
## camera's), so its children draw in the viewport's own px, crisp and at their
## own size at any zoom, and a coin's position is where it is drawn.
## Every frame each coin follows its hex through the map's canvas transform and
## sits 8 px above the hex's centre, or COIN_RISE_HERE on the hex the player
## stands on, clear of the character's head. Coins keep their size at the map's
## zoom 1 and show and go outright: no pop-in, stagger or fade.
## Instanced by AdventureTilemap, which it reads through map. The camera that
## follows the map's character moves when the character does, ahead of _process,
## and when a tween eases its offset (the boss reveal's push), after it. So the
## coins are placed in _process and again just before the frame is drawn
## (RenderingServer.frame_pre_draw), and never trail the tiles.
## It redraws on the map's map_changed and encounter_resolved, and keeps the
## coins that are still wanted, so a shake or an animated glyph is never cut off
## or started over by a redraw. No coin takes the pointer: the hexes under the
## coins stay hoverable and clickable.

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The adventure map the coins follow.
@export var map: AdventureTilemap

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## How far a coin's centre sits above its hex's centre, in px.
const COIN_RISE: float = 8.0
## The same on the hex the player stands on. The game's character stands on its
## tile's centre with its head 16 px above it, higher than the mock-up draws it,
## so the coin rises 56 to keep 14 px clear of the head.
const COIN_RISE_HERE: float = 56.0
## From a coin's top-left to the centre of its 52 px disc.
const COIN_CENTRE: Vector2 = Vector2(26, 26)

const EncounterCoinScene: PackedScene = preload("res://scenes/adventure/adventure_map_markers/encounter_coin/encounter_coin.tscn")

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The coin on each tile that has one.
var _coins: Dictionary[Vector3i, EncounterCoin] = {}

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	if map == null:
		return
	map.map_changed.connect(rebuild)
	map.encounter_resolved.connect(_on_encounter_resolved)
	map.boss_revealed.connect(_on_boss_revealed)
	# A tween moves the camera after this frame's _process (the boss reveal's
	# camera push does), so the coins are put over their hexes once more just
	# before the frame is drawn. Placed in _process alone they would trail the
	# tiles by a frame while the camera eases.
	RenderingServer.frame_pre_draw.connect(_place_coins)
	rebuild()

func _process(_delta: float) -> void:
	_place_coins()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Brings the coins in line with the map: a coin on each tile the player sees
## that needs one, showing the face the map's state calls for; a coin whose tile
## no longer needs one goes at once. A coin that stays is set up again, which
## leaves its animation and shake alone.
func rebuild() -> void:
	var wanted: Dictionary[Vector3i, bool] = {}
	if map != null:
		for coord: Vector3i in map.get_seen_tiles():
			var visited: bool = map.is_tile_visited(coord)
			# Dev revealed: shown only by the dev override, not yet visited.
			var dev_revealed: bool = map.is_dev_reveal_all() and not visited
			var encounter: AdventureEncounter = map.get_encounter_at(coord)
			if not EncounterCoin.needs_coin(encounter, visited, dev_revealed):
				continue
			wanted[coord] = true
			_show_coin(coord, encounter, EncounterCoin.face_for(encounter, visited, map.is_tile_completed(coord), dev_revealed))
	for coord: Vector3i in _coins.keys():
		if not wanted.has(coord):
			_remove_coin(coord)
	_place_coins()

## The coin on the tile, or null when it has none.
func get_coin(coord: Vector3i) -> EncounterCoin:
	return _coins.get(coord, null) as EncounterCoin

## How many coins are on the map.
func get_coin_count() -> int:
	return _coins.size()

#-----------------------------------------------------------------------------
# BUILDING
#-----------------------------------------------------------------------------

## Puts the tile's coin in the layer (instancing it when it has none) and sets it
## up for the face and the encounter's glyph. A question mark carries no glyph.
func _show_coin(coord: Vector3i, encounter: AdventureEncounter, face: EncounterCoin.Face) -> void:
	var coin: EncounterCoin = _coins.get(coord, null) as EncounterCoin
	if coin == null:
		coin = EncounterCoinScene.instantiate() as EncounterCoin
		add_child(coin)
		_coins[coord] = coin
	if face == EncounterCoin.Face.UNKNOWN:
		coin.setup(face, null, Vector2i.ZERO, 1, 0.0)
		return
	var type: AdventureEncounter.EncounterType = encounter.encounter_type
	var cleared: bool = face == EncounterCoin.Face.CLEARED
	coin.setup(
		face,
		EncounterCoin.glyph_for(type, cleared),
		EncounterCoin.glyph_frame_size_for(type),
		EncounterCoin.glyph_frames_for(type, cleared),
		EncounterCoin.frame_seconds_for(type))

## Takes the tile's coin off the map. It hides now and is freed at the end of the
## frame, so it is never left as an orphan.
func _remove_coin(coord: Vector3i) -> void:
	var coin: EncounterCoin = _coins[coord]
	_coins.erase(coord)
	coin.hide()
	coin.queue_free()

#-----------------------------------------------------------------------------
# PLACEMENT
#-----------------------------------------------------------------------------

## Puts every coin over its hex: the disc's centre COIN_RISE above the hex's
## screen centre (COIN_RISE_HERE on the hex the player stands on), the 54 px
## frame's top-left 26 px up and left of that, in whole px. The layer first
## stands in screen space: its transform cancels the viewport's canvas
## transform, so a coin's position is its screen position. Runs every frame
## in _process and again just before the frame is drawn.
func _place_coins() -> void:
	if _coins.is_empty() or map == null or not map.is_inside_tree() or not map.is_node_ready():
		return
	global_transform = get_viewport().get_canvas_transform().affine_inverse()
	var canvas: Transform2D = map.get_global_transform_with_canvas()
	var here: Vector3i = map.get_current_tile()
	for coord: Vector3i in _coins:
		var rise: float = COIN_RISE_HERE if coord == here else COIN_RISE
		_coins[coord].position = ((canvas * map.get_tile_world_centre(coord)) - COIN_CENTRE - Vector2(0, rise)).round()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## A resolved tile's coin turns carved (map_changed has usually just said so).
func _on_encounter_resolved(_coord: Vector3i, _summary: String) -> void:
	rebuild()

## The boss tile came into view: its coin shakes.
func _on_boss_revealed(coord: Vector3i) -> void:
	var coin: EncounterCoin = get_coin(coord)
	if coin != null:
		coin.shake()
