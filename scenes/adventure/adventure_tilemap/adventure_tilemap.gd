class_name AdventureTilemap
extends Node2D

## AdventureTilemap
## Manages the adventure map grid, tile visitation, character movement, and encounter triggers
## Handles pathfinding, tile visibility, and encounter processing
## Announces what happens on the map (arrivals, resolutions, refused walks, the
## boss reveal, redraws) through signals, and answers the boards' questions about
## the map through getters.
##
## Draws the map in the zone map's lacquer look at a fixed zoom 1 (spec: The
## map): the map ground; fog in three tiers around the tiles the player sees,
## out past the map's reach, so the map's shape stays hidden; visited tiles in
## the forest atlas and revealed ones in its veil; the current hex's brass rim
## and a hover rim; the route dots of a hovered or committed walk; and the
## character at 2x with the kit's shadow, walking in even px under a camera
## that follows it with the current hex's centre at screen (960, 470). The
## encounters are marked by the lacquer coins of the AdventureMapMarkers layer,
## a child that reads this map's getters and signals.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal start_combat(choice: CombatChoice)
signal boss_defeated

## The player arrived on a tile: every arrival, the start tile and tiles with
## nothing on them included, announced once the tile counts as visited.
## `encounter` is the tile's encounter (null when the map has none there),
## `first_visit` whether the tile was unvisited until now, and `summary` the line
## its resolved encounter left behind ("" until it is resolved).
signal tile_entered(coord: Vector3i, encounter: AdventureEncounter, first_visit: bool, summary: String)
## The encounter on `coord` was resolved; `summary` says how (see summary_for()).
signal encounter_resolved(coord: Vector3i, summary: String)
## The visited or revealed tiles changed: the map was redrawn, or cleared when
## the adventure stopped.
signal map_changed
## A walk could not start, or stopped partway. `reason` is REFUSED_STAMINA or
## REFUSED_ENCOUNTER, and the player's log says why in words.
signal walk_refused(reason: StringName)
## The boss tile came into view for the first time this adventure.
signal boss_revealed(coord: Vector3i)

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The hover rim over a visited tile: the bright brass rim (map space, the
## tile's own size).
@export var hover_rim_texture: Texture2D
## The hover rim over a revealed tile: an inner rim inside its veil's dotted one.
@export var hover_in_rim_texture: Texture2D

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

# Tilemap tile source IDs
const BASE_TILE_SOURCE_ID = 0
const TRANSPARENT_TILE_VARIANT_ID = 4

# Forest atlas source id — variants are picked via HexForestAtlas.pick().
# Keep in sync with ZoneTilemap.FOREST_ATLAS_SOURCE_ID.
const FOREST_ATLAS_SOURCE_ID := 8
## The forest atlas's veil (hex_forest_veil_atlas_ai.png): the same 23 variants
## at the same atlas coordinates in the kit's uncharted veil ramp, with its
## dotted rim, for the tiles the player has revealed but not visited.
const VEIL_ATLAS_SOURCE_ID: int = 9

## The fog covers every cell this many tiles past the map's reach
## (AdventureData.max_distance_from_start) from the start, so the screen stays
## covered wherever the camera follows the player.
const FOG_MARGIN: int = 8

## The camera's offset from the character it follows: at zoom 1 it puts the
## current hex's centre at screen (960, 470), clear of the dock.
const CAMERA_OFFSET: Vector2 = Vector2(0, 70)

# Character movement speeds
const CHARACTER_MOVE_SPEED = 150.0

# TODO: Calculate this dynamically based on terrain/stats instead of a constant
const MOVEMENT_STAMINA_COST = 5.0

## walk_refused reason: too little Stamina for a step.
const REFUSED_STAMINA: StringName = &"stamina"
## walk_refused reason: an unresolved encounter on the current tile holds the
## player until a choice is made.
const REFUSED_ENCOUNTER: StringName = &"encounter"

## The player's log line for REFUSED_STAMINA (%d: the Stamina a step costs).
const TOO_TIRED_LINE: String = "Too tired to walk · %d Stamina a step"
## The player's log line for REFUSED_ENCOUNTER.
const CHOOSE_FIRST_LINE: String = "Choose what to do here first"

#-----------------------------------------------------------------------------
# ENUMS
#-----------------------------------------------------------------------------

enum HighlightType {
	VISIBLE_NEIGHBOUR,
}

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var full_map: HexagonTileMapLayer = %AdventureFullMap
@onready var visible_map: HexagonTileMapLayer = %AdventureVisibleMap
@onready var character_body: CharacterBody2D = %CharacterBody2D
@onready var _fog_map: HexagonTileMapLayer = %AdventureFogMap
@onready var _current_rim: Sprite2D = %CurrentRim
@onready var _hover_rim: Sprite2D = %HoverRim
@onready var _route: AdventureRoute = %AdventureRoute
@onready var _camera: Camera2D = %Camera2D

var _boss_revealed: bool = false

## DEV-only visual override: when true, every encounter tile renders with
## its forest art (revealed tiles lose their veil) and its glyph coin, and
## the fog leaves every map tile. _visited_tile_dictionary and
## _highlight_tile_dictionary are untouched so progression, stats, and
## encounter-resolution logic are unaffected.
var _dev_reveal_all: bool = false

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var current_adventure_action_data: AdventureActionData = null
var adventure_map_generator: AdventureMapGenerator

## Main data structure for the adventure tilemap, key is the cube coordinate, value is the Adventure encounter
var _encounter_tile_dictionary: Dictionary[Vector3i, AdventureEncounter] = {}
var _visited_tile_dictionary: Dictionary[Vector3i, bool] = {}
var _highlight_tile_dictionary: Dictionary[Vector3i, HighlightType] = {}
## Tiles whose encounter has been resolved (won fight, looted treasure,
## finished dialogue, etc.). Separate from _visited_tile_dictionary
## because we want the "completed" visual (the carved coin) to
## apply the moment the encounter is resolved, even while the player is
## still standing on the tile. NoOp tiles never end up in here — there's
## nothing to complete.
var _completed_encounter_tiles: Dictionary[Vector3i, bool] = {}
## The one line each resolved encounter left behind (see summary_for()), by tile.
## Cleared when the adventure stops.
var _tile_summaries: Dictionary[Vector3i, String] = {}

## Visitation queue - tiles the character will visit in order
var _visitation_queue: Array[Vector3i] = []
var _current_tile: Vector3i = Vector3i.ZERO

var _is_movement_locked: bool = false
var _current_combat_choice: CombatChoice = null # Store for post-combat processing
var _current_dialogue_choice: DialogueChoice = null # Store for post-dialogue processing

## When the player clicks a tile to commit to a destination, the route
## locks in and the hover rim snaps onto that tile — neither moves in
## response to hovering until the player arrives, gets hijacked by an
## unvisited encounter along the way, runs out of Stamina, or the
## adventure ends. Each arrival along the way lays the route again from
## the tile reached, so it walks forward with the player. See
## _check_committed_arrival and _release_committed_destination.
var _committed_destination: Vector3i = Vector3i.ZERO
var _has_committed_destination: bool = false

## The tile the hover rim was last put on.
var _hover_rim_tile: Vector3i = Vector3i.ZERO

## The boss reveal's camera push while it runs, or null.
var _camera_push_tween: Tween = null

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	Log.info("AdventureTilemap: Initializing")
	
	if visible_map:
		visible_map.tile_clicked.connect(_on_tile_clicked)
		visible_map.tile_hovered.connect(_on_tile_hovered)
		visible_map.tile_unhovered.connect(_on_tile_unhovered)
	else:
		Log.critical("AdventureTilemap: Visible map is missing!")
	
	if character_body:
		character_body.movement_completed.connect(_on_character_movement_completed)
	else:
		Log.critical("AdventureTilemap: CharacterBody2D is missing!")
	
	adventure_map_generator = AdventureMapGenerator.new()
	adventure_map_generator.set_tile_map(full_map)
	
	# The camera follows the character at zoom 1 (its default; no zoom
	# controller), offset so the current hex sits above the dock.
	_camera.offset = CAMERA_OFFSET

## While a walk is committed, hides the route dots the character has passed.
func _process(_delta: float) -> void:
	if _has_committed_destination:
		_route.hide_passed(character_body.position)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Starts the adventure with the given action data, on a freshly generated map.
func start_adventure(action_data: AdventureActionData) -> void:
	Log.info("AdventureTilemap: Starting adventure: %s" % action_data.action_name)

	# Generate the adventure_tile_dictionary
	adventure_map_generator.set_adventure_data(action_data.adventure_data)
	start_adventure_on_map(action_data, adventure_map_generator.generate_adventure_map())

## Starts the adventure with the given action data on a map that already exists
## (cube coordinate to encounter; the start tile is Vector3i.ZERO). The tilemap
## plays on its own copy of the dictionary, so stopping the adventure leaves the
## caller's alone.
func start_adventure_on_map(action_data: AdventureActionData, encounters: Dictionary[Vector3i, AdventureEncounter]) -> void:
	current_adventure_action_data = action_data
	_encounter_tile_dictionary = encounters.duplicate()
	# A new run has no fight or talk under way, whatever the last one ended in
	# (a boss win ends the run before its fight lets go of its choice), so
	# select_choice() takes its picks; and no talk left playing resolves its tiles.
	_current_combat_choice = null
	_current_dialogue_choice = null
	if DialogueManager and DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)

	_update_full_map()
	
	# Initialize starting position
	_current_tile = Vector3i.ZERO
	_boss_revealed = false
	_visit(_current_tile)

## Stops the current adventure and cleans up the map.
func stop_adventure() -> void:
	Log.info("AdventureTilemap: Stopping adventure")
	
	# The run is over from here on, and the teardown must not change it.
	# stop_moving() ends the hop under way and announces it
	# (movement_completed): with a run on, that is an arrival, which would visit
	# the tile the character stands nearest, reveal the boss and tell the boards.
	# So the run goes first, and the rest of the walk is dropped before the
	# character stops, or a walk still queued would set off its next hop now and
	# land after the teardown.
	current_adventure_action_data = null
	_visitation_queue.clear()
	_release_committed_destination()
	character_body.stop_moving()
	character_body.global_position = Vector2.ZERO
	
	full_map.clear()
	visible_map.clear()
	_encounter_tile_dictionary.clear()
	_visited_tile_dictionary.clear()
	_highlight_tile_dictionary.clear()
	_completed_encounter_tiles.clear()
	_tile_summaries.clear()
	_current_tile = Vector3i.ZERO
	_is_movement_locked = false
	_current_rim.hide()
	_hover_rim.hide()
	_stop_camera_push()
	_draw_fog()
	map_changed.emit()
	

## Handles the result of a combat encounter.
func handle_combat_result(successful: bool, gold_earned: int = 0) -> void:
	Log.info("AdventureTilemap: Combat ended - Success: %s, Gold: %d" % [successful, gold_earned])
	
	if successful:
		# Award gold alongside other effects
		if gold_earned > 0:
			ResourceManager.add_gold(gold_earned)
		
		if _current_combat_choice:
			_apply_effects(_current_combat_choice.success_effects)
			
			if _current_combat_choice.is_boss:
				boss_defeated.emit()
				Log.info("AdventureTilemap: Boss defeated! Adventure Successful.")
				ActionManager.stop_action(true)
				return

		_complete_current_tile(summary_for(_current_combat_choice, gold_earned))
	else:
		if _current_combat_choice:
			_apply_effects(_current_combat_choice.failure_effects)
		# Usually failure means death/end of run, handled by ActionManager or PlayerResourceManager
	
	_current_combat_choice = null

## Resolves the player's pick on the encounter they stand on: a combat choice
## starts the fight (start_combat), a dialogue choice starts its timeline, and any
## other choice applies its success effects and resolves the tile at once.
## A pick while a fight or a talk it started is under way, or once the tile is
## resolved, is ignored: the chest stays up through a fight, so a second press
## on a drawer must not start a second one.
func select_choice(choice: EncounterChoice) -> void:
	if _current_combat_choice != null or _current_dialogue_choice != null:
		Log.info("AdventureTilemap: Choice ignored while a fight or a talk is under way: %s" % choice.label)
		return
	if is_tile_completed(_current_tile):
		Log.info("AdventureTilemap: Choice ignored, the encounter here is resolved: %s" % choice.label)
		return
	Log.info("AdventureTilemap: Choice selected: %s" % choice.label)

	if choice is CombatChoice:
		_current_combat_choice = choice
		start_combat.emit(choice)
		# Combat view will take over. _stop_combat will be called when done.

	elif choice is DialogueChoice:
		if DialogueManager:
			_current_dialogue_choice = choice
			DialogueManager.start_timeline(choice.timeline_name)
			DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
		else:
			Log.error("AdventureTilemap: DialogueManager missing!")

	else:
		# Standard choice (e.g. Loot, Leave)
		_apply_effects(choice.success_effects)
		_complete_current_tile(summary_for(choice, 0))

## Returns the number of tiles the player has visited.
func get_visited_tile_count() -> int:
	return _visited_tile_dictionary.size()

## Returns the total number of tiles on the adventure map.
func get_total_tile_count() -> int:
	return _encounter_tile_dictionary.size()

## DEV-only: toggle a visual override that renders every encounter tile as
## revealed (forest + glyph coin, no veil) and lifts the fog off every map tile.
## Does not touch _visited_tile_dictionary, so progression, stats, and
## encounter-resolution remain accurate. Called from the dev panel.
func set_dev_reveal_all(enabled: bool) -> void:
	if _dev_reveal_all == enabled:
		return
	_dev_reveal_all = enabled
	if current_adventure_action_data == null:
		return
	_update_visible_map()

## Returns the total number of combat encounters on the map.
func get_total_combat_count() -> int:
	var count: int = 0
	for encounter in _encounter_tile_dictionary.values():
		if encounter.encounter_type in [
			AdventureEncounter.EncounterType.COMBAT_REGULAR,
			AdventureEncounter.EncounterType.COMBAT_BOSS,
			AdventureEncounter.EncounterType.COMBAT_ELITE,
			AdventureEncounter.EncounterType.COMBAT_AMBUSH,
		]:
			count += 1
	return count

#-----------------------------------------------------------------------------
# PUBLIC METHODS - Map Queries
#-----------------------------------------------------------------------------

## Returns the cube coordinate of the tile the player stands on.
func get_current_tile() -> Vector3i:
	return _current_tile

## Returns the encounter placed on `coord`, or null when the map has no tile there.
func get_encounter_at(coord: Vector3i) -> AdventureEncounter:
	return _encounter_tile_dictionary.get(coord)

## Returns true when the player has been on the tile.
func is_tile_visited(coord: Vector3i) -> bool:
	return _visited_tile_dictionary.has(coord)

## Returns true when the tile is in view without having been visited: it touches
## a visited tile. The dev override (set_dev_reveal_all) does not change this.
func is_tile_revealed(coord: Vector3i) -> bool:
	return _highlight_tile_dictionary.has(coord)

## Returns true when the encounter on the tile has been resolved.
func is_tile_completed(coord: Vector3i) -> bool:
	return _completed_encounter_tiles.has(coord)

## Returns the line the tile's resolved encounter left behind, or "" when it has
## not been resolved (see summary_for()).
func get_tile_summary(coord: Vector3i) -> String:
	return _tile_summaries.get(coord, "")

## Returns every tile the player can see: the visited ones, then the revealed
## ones. Under the dev override (set_dev_reveal_all), every tile on the map.
func get_seen_tiles() -> Array[Vector3i]:
	var seen: Array[Vector3i] = []
	if _dev_reveal_all:
		seen.assign(_encounter_tile_dictionary.keys())
		return seen
	seen.assign(_visited_tile_dictionary.keys())
	for coord in _highlight_tile_dictionary.keys():
		seen.append(coord)
	return seen

## Returns true while the dev override shows the whole map.
func is_dev_reveal_all() -> bool:
	return _dev_reveal_all

## Returns the tile's centre in the tilemap's own space, where the character and
## the camera live.
func get_tile_world_centre(coord: Vector3i) -> Vector2:
	return full_map.cube_to_local(coord) + full_map.position

## Returns the fog tier (1-3) drawn on the tile, or -1 when it has no fog: a
## tile the player sees, one past the fog's reach, or any tile while no
## adventure runs.
func get_fog_tier_at(coord: Vector3i) -> int:
	return _fog_map.get_cell_source_id(full_map.cube_to_map(coord))

#-----------------------------------------------------------------------------
# PUBLIC METHODS - Summaries
#-----------------------------------------------------------------------------

## Returns the one line a resolved encounter leaves on its tile. A won fight reads
## "Won · <gold> gold", or "Won" when it paid nothing. Any other choice lists what
## its success effects say, joined with " · ", leaving out an effect that has
## nothing to say (empty text, or only its debug string), and reads "Done" when
## nothing is left. No choice reads as a choice with no effects.
static func summary_for(choice: EncounterChoice, gold_earned: int) -> String:
	if choice is CombatChoice:
		if gold_earned > 0:
			return "Won · %d gold" % gold_earned
		return "Won"
	var parts: PackedStringArray = PackedStringArray()
	if choice != null:
		for effect in choice.success_effects:
			if effect == null:
				continue
			var text: String = effect.describe()
			if text.is_empty() or text == str(effect):
				continue
			parts.append(text)
	if parts.is_empty():
		return "Done"
	return " · ".join(parts)

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _visit(coord: Vector3i) -> void:
	# Snapshot the pre-arrival state so the arrival can still tell the boards
	# "first visit" from "replay" after we promote the tile.
	var was_already_visited := _visited_tile_dictionary.has(coord)

	# Mark the tile visited the moment the player arrives — not after
	# resolution — so its veil and fog lift and its coin shows the
	# encounter's glyph immediately. The arrival below carries the
	# pre-arrival snapshot, so the chest can show the "already cleared"
	# state. On revisits we skip _mark_tile_visited (nothing new to compute)
	# but still need to re-render so the current rim and the coin that
	# rides above the player follow the player to the new _current_tile.
	if not was_already_visited:
		_mark_tile_visited(coord)
	else:
		_update_visible_map()

	# If this arrival is the committed destination, drop the lock so the
	# route clears; partway, the route is laid again from this tile.
	_check_committed_arrival()

	if _encounter_tile_dictionary.has(coord):
		var tile_encounter: AdventureEncounter = _encounter_tile_dictionary[coord]

		# Check for NoOpEncounter (or empty choices) and auto-complete
		if tile_encounter is NoOpEncounter or tile_encounter.choices.is_empty():
			Log.info("AdventureTilemap: Auto-completing NoOp/Empty encounter at %s" % coord)
			_announce_arrival(coord, not was_already_visited)
			_process_next_visitation()
			return

		if not was_already_visited:
			_is_movement_locked = true
			_visitation_queue.clear() # Stop any further queued movement
			# An unvisited encounter just hijacked the trip mid-route —
			# abandon the committed destination. After resolving the
			# encounter the player will need to click again to decide
			# where to go next.
			_release_committed_destination()

	_announce_arrival(coord, not was_already_visited)

	if was_already_visited:
		_process_next_visitation()

## Tells the boards the player arrived on `coord`. Called once the tile is marked
## visited and the lock on an unresolved encounter is set, and before the walk
## goes on to its next tile, so the boards hear the arrivals of one walk in order.
func _announce_arrival(coord: Vector3i, first_visit: bool) -> void:
	tile_entered.emit(coord, _encounter_tile_dictionary.get(coord), first_visit, _tile_summaries.get(coord, ""))

func _on_dialogue_ended(_resource: Resource = null) -> void:
	Log.info("AdventureTilemap: Dialogue ended")
	var choice: DialogueChoice = _current_dialogue_choice
	if choice:
		_apply_effects(choice.success_effects)
		_current_dialogue_choice = null
	_complete_current_tile(summary_for(choice, 0))

## Resolves the encounter on the tile the player stands on: unlocks movement,
## remembers `summary` for the tile and tells the boards (encounter_resolved).
func _complete_current_tile(summary: String) -> void:
	_is_movement_locked = false
	# Promote the tile to "encounter completed" BEFORE re-rendering so
	# its coin turns carved immediately — not only once the player moves
	# off to another tile.
	_completed_encounter_tiles[_current_tile] = true
	_tile_summaries[_current_tile] = summary
	_mark_tile_visited(_current_tile)
	encounter_resolved.emit(_current_tile, summary)

func _apply_effects(effects: Array[EffectData]) -> void:
	for effect in effects:
		if effect:
			effect.process() # TODO: Pass context if needed (player, etc.)

## Tells the boards why a walk cannot start or go on (walk_refused) and puts the
## reason in the player's log.
func _refuse_walk(reason: StringName, log_line: String) -> void:
	LogManager.log_message(log_line)
	walk_refused.emit(reason)

func _on_tile_clicked(coord: Vector2i) -> void:
	if _is_movement_locked:
		Log.info("AdventureTilemap: Movement locked. Complete the encounter first.")
		_refuse_walk(REFUSED_ENCOUNTER, CHOOSE_FIRST_LINE)
		return

	# Resolve the encounter on the clicked tile so logs name what's there —
	# helpful alongside the dev "Show Whole Map" toggle for scouting.
	var target_cube_coord = visible_map.map_to_cube(coord)
	var clicked_encounter: AdventureEncounter = _encounter_tile_dictionary.get(target_cube_coord)
	var encounter_label: String = "(no encounter)"
	if clicked_encounter != null:
		if clicked_encounter.encounter_name.is_empty():
			encounter_label = clicked_encounter.encounter_id if not clicked_encounter.encounter_id.is_empty() else "(unnamed)"
		else:
			encounter_label = clicked_encounter.encounter_name
	Log.info("AdventureTilemap: Tile clicked: %s [%s]" % [coord, encounter_label])

	# Don't allow new clicks if we're already processing a visitation queue
	if _visitation_queue.size() > 0 or character_body.is_moving:
		return
	
	# Calculate the path using hexagonal line drawing
	var path_cube_coords = visible_map.cube_pathfind(_current_tile, target_cube_coord)
	
	# Check stamina for one step; the deduction happens per step.
	if PlayerManager.vitals_manager and PlayerManager.vitals_manager.current_stamina < MOVEMENT_STAMINA_COST:
		Log.info("AdventureTilemap: Not enough stamina to move!")
		_refuse_walk(REFUSED_STAMINA, TOO_TIRED_LINE % int(MOVEMENT_STAMINA_COST))
		return
	
	# Store as visitation queue (skip first tile as we're already there)
	if path_cube_coords.size() > 1:
		_visitation_queue = path_cube_coords.slice(1) # Skip current tile
		Log.info("AdventureTilemap: Created visitation queue with %d tiles" % _visitation_queue.size())

		# Commit to this destination: the route and the hover rim both
		# lock onto the clicked tile until arrival. Put the rim there
		# explicitly in case the click landed without a prior hover event,
		# and lay the exact route the walk will take.
		_committed_destination = target_cube_coord
		_has_committed_destination = true
		_show_hover_rim(target_cube_coord)
		_route.set_route(_tile_centres(path_cube_coords))

		_process_next_visitation()
	else:
		Log.info("AdventureTilemap: Path is empty or only contains current tile")

## Hovering a tile the player sees shows the hover rim on it and the route to
## it from the current tile. Over fog, over the current tile and while a choice
## waits, neither shows.
func _on_tile_hovered(tile_coord: Vector2i) -> void:
	# While a destination is committed, the route and the hover rim stay
	# locked onto the clicked tile — hovering anything else is a no-op
	# until the player arrives or the trip gets aborted.
	if _has_committed_destination:
		return
	var target_cube := visible_map.map_to_cube(tile_coord)
	if _is_movement_locked or target_cube == _current_tile or not get_seen_tiles().has(target_cube):
		_clear_hover()
		return
	_show_hover_rim(target_cube)
	_route.set_route(_tile_centres(visible_map.cube_pathfind(_current_tile, target_cube)))

func _on_tile_unhovered() -> void:
	# Mouse leaving a tile mid-trip must not clear the locked route or the
	# locked rim — those are pinned to the committed destination and only
	# release on arrival / abort.
	if _has_committed_destination:
		return
	_clear_hover()

## Puts the hover rim on the tile: the bright rim over a tile drawn in the
## forest atlas, the inner rim over one drawn in its veil.
func _show_hover_rim(coord: Vector3i) -> void:
	_hover_rim_tile = coord
	_hover_rim.texture = hover_in_rim_texture if _is_tile_veiled(coord) else hover_rim_texture
	_hover_rim.position = get_tile_world_centre(coord)
	_hover_rim.show()

## Hides the hover rim and takes the route away.
func _clear_hover() -> void:
	_hover_rim.hide()
	_route.clear()

## Fires on every tile arrival via _visit. If the player has reached the
## committed destination, drops the commit and clears the route. On
## intermediate arrivals the route is laid again from the tile reached,
## along the rest of the queued walk.
func _check_committed_arrival() -> void:
	if not _has_committed_destination:
		return
	if _current_tile == _committed_destination:
		_release_committed_destination()
		return
	var rest_of_walk: Array[Vector3i] = [_current_tile]
	rest_of_walk.append_array(_visitation_queue)
	_route.set_route(_tile_centres(rest_of_walk))

## Drops the committed-destination state and clears the route. Called on
## arrival at the destination, when an unvisited encounter hijacks the trip
## mid-route, when the player runs out of stamina mid-route, and when the
## adventure tears down. The hover rim stays where it is until the next
## hover event, unless it now sits on the current tile or a choice waits.
func _release_committed_destination() -> void:
	_has_committed_destination = false
	_committed_destination = Vector3i.ZERO
	_route.clear()
	if _is_movement_locked or _hover_rim_tile == _current_tile:
		_hover_rim.hide()

## Called when character completes movement to a tile. A hop that ends with no
## run on (stop_adventure() cuts it short) arrives nowhere.
func _on_character_movement_completed() -> void:
	if current_adventure_action_data == null:
		return

	# Update current tile position
	var reached_tile = _get_current_tile_from_character_position()
	
	if reached_tile != _current_tile:
		_current_tile = reached_tile
		Log.info("AdventureTilemap: Character reached tile: %s" % _current_tile)
		
		_visit(_current_tile)

func _mark_tile_visited(coord: Vector3i) -> void:
	var previous_highlights := _highlight_tile_dictionary.keys()
	_visited_tile_dictionary[coord] = true
	_highlight_tile_dictionary.clear()

	for c in _visited_tile_dictionary.keys():
		for neighbour in full_map.cube_neighbors(c):
			if neighbour in _encounter_tile_dictionary.keys() and neighbour not in _visited_tile_dictionary.keys():
				_highlight_tile_dictionary[neighbour] = HighlightType.VISIBLE_NEIGHBOUR

	# Find newly-revealed neighbors (in new highlights but not old)
	var newly_revealed: Array[Vector3i] = []
	for c in _highlight_tile_dictionary.keys():
		if not previous_highlights.has(c):
			newly_revealed.append(c)

	_update_visible_map()
	_check_boss_reveal(newly_revealed)

## Boss-tile dramatic reveal, only the first time the boss tile is among the
## tiles that just came into view. Called after the redraw, so the boss's coin
## (drawn by map_changed) exists when boss_revealed tells the coin layer to shake it.
func _check_boss_reveal(coords: Array[Vector3i]) -> void:
	if _boss_revealed:
		return
	for cube in coords:
		var encounter: AdventureEncounter = _encounter_tile_dictionary.get(cube)
		if encounter and encounter.encounter_type == AdventureEncounter.EncounterType.COMBAT_BOSS:
			_boss_revealed = true
			boss_revealed.emit(cube)
			_play_boss_reveal(cube)
			return

func _play_boss_reveal(boss_cube: Vector3i) -> void:
	# Hit-stop: slow time briefly
	Engine.time_scale = 0.25
	get_tree().create_timer(0.15 * 0.25).timeout.connect(func(): Engine.time_scale = 1.0)

	# Camera push toward the boss and back: 45% of the way from the camera
	# to the boss tile, eased through the camera's offset, so the camera
	# stays on the character even when the walk goes on meanwhile.
	var push: Vector2 = (get_tile_world_centre(boss_cube) - _camera.global_position) * 0.45
	_stop_camera_push()
	_camera_push_tween = create_tween()
	_camera_push_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_push_tween.set_ease(Tween.EASE_OUT)
	_camera_push_tween.tween_property(_camera, "offset", CAMERA_OFFSET + push, 0.5)
	_camera_push_tween.tween_property(_camera, "offset", CAMERA_OFFSET, 0.7)

## Ends the boss reveal's camera push at once (if one runs) and puts the
## camera back on its offset.
func _stop_camera_push() -> void:
	if _camera_push_tween != null and _camera_push_tween.is_valid():
		_camera_push_tween.kill()
	_camera_push_tween = null
	_camera.offset = CAMERA_OFFSET

## Process the next tile in the visitation queue
func _process_next_visitation() -> void:
	if _visitation_queue.size() == 0:
		Log.info("AdventureTilemap: Visitation queue empty, movement complete")
		return
	
	# Get next tile to visit
	var next_tile = _visitation_queue[0] # Peek first
	
	# Check stamina before moving
	if PlayerManager.vitals_manager:
		if PlayerManager.vitals_manager.current_stamina >= MOVEMENT_STAMINA_COST:
			PlayerManager.vitals_manager.apply_vitals_change(0, -MOVEMENT_STAMINA_COST, 0)
		else:
			Log.info("AdventureTilemap: Out of stamina, stopping movement.")
			_visitation_queue.clear()
			_release_committed_destination()
			_refuse_walk(REFUSED_STAMINA, TOO_TIRED_LINE % int(MOVEMENT_STAMINA_COST))
			return

	_visitation_queue.pop_front() # Actually remove it
	
	# Convert to world position and move character
	var map_coord = visible_map.cube_to_map(next_tile)
	var world_pos = visible_map.map_to_local(map_coord) + visible_map.position
	
	Log.info("AdventureTilemap: Moving to next tile: %s (%d remaining in queue)" % [next_tile, _visitation_queue.size()])
	character_body.move_to_position(world_pos, CHARACTER_MOVE_SPEED * (1 + 0.2 * (_visitation_queue.size() + 1)))

## Gets the character's current tile coordinate from their world position
func _get_current_tile_from_character_position() -> Vector3i:
	var char_world_pos = character_body.global_position - visible_map.position
	var char_map_coord = visible_map.local_to_map(char_world_pos)
	return visible_map.map_to_cube(char_map_coord)

func _update_full_map() -> void:
	full_map.clear()
	for coord in _encounter_tile_dictionary.keys():
		full_map.set_cell_with_source_and_variant(BASE_TILE_SOURCE_ID, TRANSPARENT_TILE_VARIANT_ID, full_map.cube_to_map(coord))

func _update_visible_map() -> void:
	visible_map.clear()

	var visible_coords: Array[Vector3i] = []
	for coord in _visited_tile_dictionary.keys():
		visible_coords.append(coord)

	for highlight_coord in _highlight_tile_dictionary.keys():
		if _highlight_tile_dictionary[highlight_coord] == HighlightType.VISIBLE_NEIGHBOUR:
			visible_coords.append(highlight_coord)

	# DEV reveal: pull every remaining encounter tile into the visible set so
	# it paints forest art (and, in the coin layer, its glyph coin), without
	# mutating the visited/highlight dicts that drive game state.
	if _dev_reveal_all:
		for coord in _encounter_tile_dictionary.keys():
			if _visited_tile_dictionary.has(coord) or _highlight_tile_dictionary.has(coord):
				continue
			visible_coords.append(coord)

	# Every visible tile renders its deterministic-random forest variant:
	# visited and dev-revealed tiles from the shared forest atlas, revealed
	# tiles from its veil at the same atlas coordinates. What each tile holds
	# is the coin layer's to show (AdventureMapMarkers, on map_changed).
	for coord in visible_coords:
		var source_id: int = VEIL_ATLAS_SOURCE_ID if _is_tile_veiled(coord) else FOREST_ATLAS_SOURCE_ID
		visible_map.set_cell_with_source_and_variant(source_id, 0, full_map.cube_to_map(coord), HexForestAtlas.pick(coord))

	_draw_fog()
	_place_current_rim()
	map_changed.emit()

## True when the tile draws in the forest atlas's veil: revealed and not yet
## visited, unless the dev override shows the whole map.
func _is_tile_veiled(coord: Vector3i) -> bool:
	return _highlight_tile_dictionary.has(coord) and not _dev_reveal_all

## Fills every cell within the fog's reach of the start (the map's reach plus
## FOG_MARGIN) that the player does not see with fog, its tier the hex distance
## to the nearest seen tile (capped at 3), its art from the tier's pool, as
## ZoneTilemap fills its fog. Unseen map tiles look like any other fog. Leaves
## the layer empty while no adventure runs. The fog layer has its own TileSet,
## so the cells come from the map layers' conversion.
func _draw_fog() -> void:
	_fog_map.clear()
	if current_adventure_action_data == null:
		return
	var seen: Array[Vector3i] = get_seen_tiles()
	var seen_set: Dictionary[Vector3i, bool] = {}
	for coord: Vector3i in seen:
		seen_set[coord] = true
	var reach: int = current_adventure_action_data.adventure_data.max_distance_from_start + FOG_MARGIN
	for cube: Vector3i in HexagonTileMap.cube_range(Vector3i.ZERO, reach):
		if seen_set.has(cube):
			continue
		var cell: Vector2i = full_map.cube_to_map(cube)
		_fog_map.set_cell(cell, ZoneMapMath.fog_tier(cube, seen), Vector2i(ZoneMapMath.fog_art_index(cell), 0))

## Puts the current hex's brass rim on the tile the player stands on.
func _place_current_rim() -> void:
	_current_rim.position = get_tile_world_centre(_current_tile)
	_current_rim.show()

## The tiles' centres in the tilemap's space, in the same order.
func _tile_centres(coords: Array[Vector3i]) -> Array[Vector2]:
	var centres: Array[Vector2] = []
	for coord: Vector3i in coords:
		centres.append(get_tile_world_centre(coord))
	return centres
