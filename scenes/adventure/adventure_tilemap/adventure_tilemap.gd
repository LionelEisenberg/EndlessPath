class_name AdventureTilemap
extends Node2D

## AdventureTilemap
## Manages the adventure map grid, tile visitation, character movement, and encounter triggers
## Handles pathfinding, tile visibility, and encounter processing

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal start_combat(choice: CombatChoice)
signal boss_defeated

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const EncounterIconScene := preload("res://scenes/adventure/encounter_icon/encounter_icon.tscn")
const FogVeilSpriteScene := preload("res://scenes/adventure/fog_veil_sprite.tscn")

# Tilemap tile source IDs
const BASE_TILE_SOURCE_ID = 0
const TRANSPARENT_TILE_VARIANT_ID = 4
## Dim dark-gray overlay variant painted on the highlight_map over
## visited-but-not-current tiles so the player can see where they've
## already been at a glance. Defined in tilemap_tileset.tres on the
## base_tile source as alternative id 5 with a ~35% alpha dark modulate.
const GRAY_OVERLAY_VARIANT_ID = 5

# Forest atlas (shared with ZoneTilemap). Multiple Hex_Forest_NN variants
# are packed into a single TileSetAtlasSource (sources/8) backed by
# hex_forest_atlas.png. Adventure tiles pick a deterministic-random cell
# per cube coord via _get_random_forest_atlas_coords() so the same tile
# always shows the same variant across re-renders. Keep these constants
# in sync with ZoneTilemap.FOREST_* and ATLAS_COLS in pack_hex_atlas.py.
const FOREST_ATLAS_SOURCE_ID := 8
const FOREST_ATLAS_COLS := 6
const FOREST_VARIANT_COUNT := 23

# Character movement speeds
const CHARACTER_MOVE_SPEED = 150.0
const INSTANT_MOVE_SPEED = 10000.0

# TODO: Calculate this dynamically based on terrain/stats instead of a constant
const MOVEMENT_STAMINA_COST = 5.0

# Fog-of-war shader array size (must match fog_of_war.gdshader MAX_CLEAR_POSITIONS)
const FOG_MAX_CLEAR_POSITIONS := 64

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
@onready var highlight_map: HexagonTileMapLayer = %AdventureHighlightMap
@onready var character_body: CharacterBody2D = %CharacterBody2D
@onready var encounter_info_panel: EncounterInfoPanel = %EncounterInfoPanel
@onready var _hover_selector: HexHoverSelector = %HoverSelector
@onready var _encounter_icon_container: Node2D = %EncounterIconContainer
@onready var _fog_veil_container: Node2D = %FogVeilContainer
@onready var _fog_rect: ColorRect = %FogOfWarRect
@onready var _path_preview: PathPreview = %PathPreview
@onready var _boss_flash_rect: ColorRect = %BossFlashRect

var _boss_revealed: bool = false

var _encounter_icons: Dictionary[Vector3i, EncounterIcon] = {}
var _fog_veil_sprites: Dictionary[Vector3i, FogVeilSprite] = {}

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var current_adventure_action_data: AdventureActionData = null
var adventure_map_generator: AdventureMapGenerator

## Main data structure for the adventure tilemap, key is the cube coordinate, value is the Adventure encounter
var _encounter_tile_dictionary: Dictionary[Vector3i, AdventureEncounter] = {}
var _visited_tile_dictionary: Dictionary[Vector3i, bool] = {}
var _highlight_tile_dictionary: Dictionary[Vector3i, HighlightType] = {}

## Visitation queue - tiles the character will visit in order
var _visitation_queue: Array[Vector3i] = []
var _current_tile: Vector3i = Vector3i.ZERO

var _is_movement_locked: bool = false
var _current_combat_choice: CombatChoice = null # Store for post-combat processing
var _current_dialogue_choice: DialogueChoice = null # Store for post-dialogue processing

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
	
	# Instantiate EncounterInfoPanel
	encounter_info_panel.visible = false
	encounter_info_panel.choice_selected.connect(_on_choice_selected)

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Starts the adventure with the given action data.
func start_adventure(action_data: AdventureActionData) -> void:
	Log.info("AdventureTilemap: Starting adventure: %s" % action_data.action_name)

	current_adventure_action_data = action_data

	# Generate the adventure_tile_dictionary
	adventure_map_generator.set_adventure_data(current_adventure_action_data.adventure_data)
	_encounter_tile_dictionary = adventure_map_generator.generate_adventure_map()
	
	_update_full_map()
	
	# Initialize starting position
	_current_tile = Vector3i.ZERO
	_boss_revealed = false
	_visit(_current_tile)

## Stops the current adventure and cleans up the map.
func stop_adventure() -> void:
	Log.info("AdventureTilemap: Stopping adventure")
	
	# Stop character movement
	character_body.stop_moving()
	character_body.global_position = Vector2.ZERO
	
	current_adventure_action_data = null
	full_map.clear()
	visible_map.clear()
	highlight_map.clear()
	for icon in _encounter_icons.values():
		icon.queue_free()
	_encounter_icons.clear()
	for veil in _fog_veil_sprites.values():
		veil.queue_free()
	_fog_veil_sprites.clear()
	_encounter_tile_dictionary.clear()
	_visited_tile_dictionary.clear()
	_highlight_tile_dictionary.clear()
	_visitation_queue.clear()
	_current_tile = Vector3i.ZERO
	_is_movement_locked = false
	encounter_info_panel.visible = false
	

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

		_complete_current_tile()
	else:
		if _current_combat_choice:
			_apply_effects(_current_combat_choice.failure_effects)
		# Usually failure means death/end of run, handled by ActionManager or PlayerResourceManager
	
	_current_combat_choice = null

## Returns the number of tiles the player has visited.
func get_visited_tile_count() -> int:
	return _visited_tile_dictionary.size()

## Returns the total number of tiles on the adventure map.
func get_total_tile_count() -> int:
	return _encounter_tile_dictionary.size()

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
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _visit(coord: Vector3i) -> void:
	# Snapshot the pre-arrival state so the encounter panel can still
	# distinguish "first visit" from "replay" after we promote the tile.
	var was_already_visited := _visited_tile_dictionary.has(coord)

	# Mark the tile visited the moment the player arrives — not after
	# resolution — so the fog veil clears and the encounter icon appears
	# immediately. The encounter panel flow below uses the pre-arrival
	# snapshot to decide whether to show the "already cleared" state.
	if not was_already_visited:
		_mark_tile_visited(coord)

	# Always show the panel if there's an encounter
	if _encounter_tile_dictionary.has(coord):
		var tile_encounter: AdventureEncounter = _encounter_tile_dictionary[coord]

		# Check for NoOpEncounter (or empty choices) and auto-complete
		if tile_encounter is NoOpEncounter or tile_encounter.choices.is_empty():
			Log.info("AdventureTilemap: Auto-completing NoOp/Empty encounter at %s" % coord)
			encounter_info_panel.visible = false
			_process_next_visitation()
			return

		encounter_info_panel.setup(tile_encounter, was_already_visited)
		encounter_info_panel.visible = true

		if not was_already_visited:
			_is_movement_locked = true
			_visitation_queue.clear() # Stop any further queued movement
	else:
		encounter_info_panel.visible = false

	if was_already_visited:
		_process_next_visitation()

func _on_choice_selected(choice: EncounterChoice) -> void:
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
		_complete_current_tile()

func _on_dialogue_ended(_resource: Resource = null) -> void:
	Log.info("AdventureTilemap: Dialogue ended")
	if _current_dialogue_choice:
		_apply_effects(_current_dialogue_choice.success_effects)
		_current_dialogue_choice = null
	_complete_current_tile()

func _complete_current_tile() -> void:
	_is_movement_locked = false
	encounter_info_panel.show_completed_state()
	_mark_tile_visited(_current_tile)

func _apply_effects(effects: Array[EffectData]) -> void:
	for effect in effects:
		if effect:
			effect.process() # TODO: Pass context if needed (player, etc.)

func _on_tile_clicked(coord: Vector2i) -> void:
	if _is_movement_locked:
		Log.info("AdventureTilemap: Movement locked. Complete the encounter first.")
		return
		
	Log.info("AdventureTilemap: Tile clicked: %s" % coord)
	
	# Don't allow new clicks if we're already processing a visitation queue
	if _visitation_queue.size() > 0 or character_body.is_moving:
		return
	
	# Get the target tile in cube coordinates
	var target_cube_coord = visible_map.map_to_cube(coord)
	
	# Calculate the path using hexagonal line drawing
	var path_cube_coords = visible_map.cube_pathfind(_current_tile, target_cube_coord)
	
	# Check stamina for the full path (approximation, actual deduction happens per step)
	var _total_cost = (path_cube_coords.size() - 1) * MOVEMENT_STAMINA_COST
	if PlayerManager.vitals_manager and PlayerManager.vitals_manager.current_stamina < MOVEMENT_STAMINA_COST:
		Log.info("AdventureTilemap: Not enough stamina to move!")
		# TODO: Show UI feedback
		return
	
	# Store as visitation queue (skip first tile as we're already there)
	if path_cube_coords.size() > 1:
		_visitation_queue = path_cube_coords.slice(1) # Skip current tile
		Log.info("AdventureTilemap: Created visitation queue with %d tiles" % _visitation_queue.size())
		_process_next_visitation()
	else:
		Log.info("AdventureTilemap: Path is empty or only contains current tile")

func _on_tile_hovered(tile_coord: Vector2i) -> void:
	if _is_movement_locked:
		_hover_selector.hide()
		return
	var target_cube := visible_map.map_to_cube(tile_coord)
	if not _visited_tile_dictionary.has(target_cube) and not _highlight_tile_dictionary.has(target_cube):
		# Hovering a fog-of-war tile — no path preview, no selector ring.
		_hover_selector.hide()
		_path_preview.clear_path()
		return

	# Snap the animated selector ring onto the hovered tile.
	_hover_selector.show_at(visible_map.map_to_local(tile_coord) + visible_map.position)

	# Compute path from current tile to hover target
	var path: Array[Vector3i] = visible_map.cube_pathfind(_current_tile, target_cube)
	var world_points: Array[Vector2] = []
	for c in path:
		var world_pos := full_map.cube_to_local(c) + full_map.position
		world_points.append(world_pos)
	_path_preview.show_path(world_points)

func _on_tile_unhovered() -> void:
	_hover_selector.hide()
	_path_preview.clear_path()

## Called when character completes movement to a tile
func _on_character_movement_completed() -> void:
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
	_update_fog_uniforms()
	_animate_reveal_stagger(newly_revealed)

func _animate_reveal_stagger(coords: Array[Vector3i]) -> void:
	var delay := 0.0
	for cube in coords:
		var icon: EncounterIcon = _encounter_icons.get(cube)
		if icon:
			icon.scale = Vector2(0.3, 0.3)
			icon.modulate.a = 0.0
			var tween := create_tween()
			tween.tween_interval(delay)
			tween.tween_property(icon, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			var alpha_tween := create_tween()
			alpha_tween.tween_interval(delay)
			alpha_tween.tween_property(icon, "modulate:a", 1.0, 0.3)

		# Boss-tile dramatic reveal (only the first time)
		if not _boss_revealed:
			var encounter: AdventureEncounter = _encounter_tile_dictionary.get(cube)
			if encounter and encounter.encounter_type == AdventureEncounter.EncounterType.COMBAT_BOSS:
				_boss_revealed = true
				_play_boss_reveal(cube)

		delay += 0.05

func _play_boss_reveal(boss_cube: Vector3i) -> void:
	# Hit-stop: slow time briefly
	Engine.time_scale = 0.25
	get_tree().create_timer(0.15 * 0.25).timeout.connect(func(): Engine.time_scale = 1.0)

	# Screen flash
	_boss_flash_rect.color = Color(0.55, 0.78, 1.0, 0.6)
	var flash_tween := create_tween()
	flash_tween.tween_property(_boss_flash_rect, "color:a", 0.0, 0.4)

	# Camera push toward boss
	var camera := get_viewport().get_camera_2d()
	if camera:
		var boss_world := full_map.cube_to_local(boss_cube) + full_map.position
		var current_pos := camera.global_position
		var push_target := current_pos.lerp(boss_world, 0.45)
		var push_tween := create_tween()
		push_tween.set_trans(Tween.TRANS_CUBIC)
		push_tween.set_ease(Tween.EASE_OUT)
		push_tween.tween_property(camera, "global_position", push_target, 0.5)
		push_tween.tween_property(camera, "global_position", current_pos, 0.7)

func _process(_delta: float) -> void:
	# Fog-of-war uniforms are in screen space, so they must be refreshed
	# every frame to stay in sync with camera pan/zoom.
	if current_adventure_action_data != null:
		_update_fog_uniforms()

func _update_fog_uniforms() -> void:
	if _fog_rect == null or _fog_rect.material == null:
		return

	var camera := get_viewport().get_camera_2d()
	var viewport_size := get_viewport_rect().size

	var positions: Array[Vector2] = []
	var tiles_to_clear: Array[Vector3i] = []
	for c in _visited_tile_dictionary.keys():
		tiles_to_clear.append(c)
	for c in _highlight_tile_dictionary.keys():
		tiles_to_clear.append(c)

	for c in tiles_to_clear:
		var world_pos := full_map.cube_to_local(c) + full_map.position
		var screen_pos: Vector2
		if camera:
			screen_pos = (world_pos - camera.global_position) * camera.zoom + viewport_size * 0.5
		else:
			screen_pos = world_pos
		positions.append(screen_pos)
		if positions.size() >= FOG_MAX_CLEAR_POSITIONS:
			Log.warn("AdventureTilemap: fog clear positions reached cap (%d)" % FOG_MAX_CLEAR_POSITIONS)
			break

	var clear_count := positions.size()
	# Pad to cap (shader uniform array is fixed-size)
	while positions.size() < FOG_MAX_CLEAR_POSITIONS:
		positions.append(Vector2(-99999, -99999))

	_fog_rect.material.set_shader_parameter("clear_positions", positions)
	_fog_rect.material.set_shader_parameter("clear_count", clear_count)

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

## Returns a deterministic forest atlas cell for the given cube coord.
## The same coord always returns the same variant, so the map looks
## consistent across re-renders, fog reveals, and adventure restarts
## (when the same map seed is used). Hashes the coord, takes posmod by
## the variant count to handle negative hash values, then splits into
## (col, row) for the FOREST_ATLAS_COLS-wide grid.
func _get_random_forest_atlas_coords(coord: Vector3i) -> Vector2i:
	var idx := posmod(hash(coord), FOREST_VARIANT_COUNT)
	@warning_ignore("integer_division")
	return Vector2i(idx % FOREST_ATLAS_COLS, idx / FOREST_ATLAS_COLS)

func _update_full_map() -> void:
	full_map.clear()
	for coord in _encounter_tile_dictionary.keys():
		full_map.set_cell_with_source_and_variant(BASE_TILE_SOURCE_ID, TRANSPARENT_TILE_VARIANT_ID, full_map.cube_to_map(coord))

func _update_visible_map() -> void:
	visible_map.clear()
	highlight_map.clear()
	# Don't clear _encounter_icons or _fog_veil_sprites up front — we diff
	# them below so visited icons persist across frames and smoothly switch
	# between current/completed visual states.

	var visible_coords: Array[Vector3i] = []
	for coord in _visited_tile_dictionary.keys():
		visible_coords.append(coord)

	var revealed_coords: Array[Vector3i] = []
	for highlight_coord in _highlight_tile_dictionary.keys():
		if _highlight_tile_dictionary[highlight_coord] == HighlightType.VISIBLE_NEIGHBOUR:
			visible_coords.append(highlight_coord)
			revealed_coords.append(highlight_coord)

	# Every visible tile renders as a deterministic-random forest variant
	# from the shared forest atlas. Encounter icons and fog veils get
	# overlaid on top in the loops below; NoOp tiles show only the forest
	# art and no icon.
	for coord in visible_coords:
		visible_map.set_cell_with_source_and_variant(FOREST_ATLAS_SOURCE_ID, 0, full_map.cube_to_map(coord), _get_random_forest_atlas_coords(coord))

	# Visited (non-current) tiles get a dim gray overlay on the highlight
	# map so the player can see where they've already been at a glance.
	# The current tile stays clean so "you are here" reads as fresh art.
	for coord in _visited_tile_dictionary.keys():
		if coord == _current_tile:
			continue
		highlight_map.set_cell_with_source_and_variant(BASE_TILE_SOURCE_ID, GRAY_OVERLAY_VARIANT_ID, full_map.cube_to_map(coord))

	# Visited tiles: spawn/update encounter icon and set completion state.
	# NoOp visited tiles get no icon at all.
	var visited_with_icon: Dictionary[Vector3i, bool] = {}
	for coord in _visited_tile_dictionary.keys():
		var encounter: AdventureEncounter = _encounter_tile_dictionary.get(coord)
		if not encounter or encounter is NoOpEncounter:
			_despawn_encounter_icon(coord)
			continue
		_update_cell_highlight(coord)
		var icon: EncounterIcon = _encounter_icons.get(coord)
		if icon:
			icon.set_completed(coord != _current_tile)
		visited_with_icon[coord] = true

	# Revealed neighbors: fog veils, except for the boss tile which is the
	# visible-while-fogged exception (player needs a long-term goal marker).
	var revealed_with_veil: Dictionary[Vector3i, bool] = {}
	for coord in revealed_coords:
		var encounter: AdventureEncounter = _encounter_tile_dictionary.get(coord)
		if encounter and encounter.encounter_type == AdventureEncounter.EncounterType.COMBAT_BOSS:
			# Boss exception: show the encounter icon, no fog veil
			_despawn_fog_veil(coord)
			_update_cell_highlight(coord)
			var icon: EncounterIcon = _encounter_icons.get(coord)
			if icon:
				icon.set_completed(false)
		else:
			# Normal revealed tile: fog veil hides the encounter type
			_despawn_encounter_icon(coord)
			_spawn_fog_veil(coord)
			revealed_with_veil[coord] = true

	# Despawn fog veils whose coord is no longer revealed (or transitioned to visited).
	var stale_veil_coords: Array[Vector3i] = []
	for coord in _fog_veil_sprites.keys():
		if not revealed_with_veil.has(coord):
			stale_veil_coords.append(coord)
	for coord in stale_veil_coords:
		_despawn_fog_veil(coord)

	# Despawn encounter icons whose coord is not visited-with-icon and not the revealed boss.
	var stale_icon_coords: Array[Vector3i] = []
	for coord in _encounter_icons.keys():
		var is_visited_icon := visited_with_icon.has(coord)
		var is_revealed_boss := false
		if revealed_coords.has(coord):
			var enc: AdventureEncounter = _encounter_tile_dictionary.get(coord)
			if enc and enc.encounter_type == AdventureEncounter.EncounterType.COMBAT_BOSS:
				is_revealed_boss = true
		if not is_visited_icon and not is_revealed_boss:
			stale_icon_coords.append(coord)
	for coord in stale_icon_coords:
		_despawn_encounter_icon(coord)

func _update_cell_highlight(coord: Vector3i) -> void:
	var encounter: AdventureEncounter = _encounter_tile_dictionary[coord]
	if not encounter:
		return

	var icon: EncounterIcon = _encounter_icons.get(coord)
	if icon == null:
		icon = EncounterIconScene.instantiate()
		_encounter_icon_container.add_child(icon)
		_encounter_icons[coord] = icon

	icon.position = full_map.cube_to_local(coord) + full_map.position
	icon.set_visited(_visited_tile_dictionary.has(coord))
	var should_show := icon.configure_for_type(encounter.encounter_type)
	icon.visible = should_show

## Spawns a FogVeilSprite at the given cube coord if one isn't already
## tracked. Called from _update_visible_map for revealed-but-not-visited
## tiles that aren't the boss exception.
func _spawn_fog_veil(coord: Vector3i) -> void:
	if _fog_veil_sprites.has(coord):
		return
	var veil: FogVeilSprite = FogVeilSpriteScene.instantiate()
	_fog_veil_container.add_child(veil)
	veil.position = full_map.cube_to_local(coord) + full_map.position
	_fog_veil_sprites[coord] = veil

## Despawns a FogVeilSprite for the given cube coord if one is tracked.
func _despawn_fog_veil(coord: Vector3i) -> void:
	var veil: FogVeilSprite = _fog_veil_sprites.get(coord)
	if veil == null:
		return
	veil.queue_free()
	_fog_veil_sprites.erase(coord)

## Despawns an EncounterIcon for the given cube coord if one is tracked.
func _despawn_encounter_icon(coord: Vector3i) -> void:
	var icon: EncounterIcon = _encounter_icons.get(coord)
	if icon == null:
		return
	icon.queue_free()
	_encounter_icons.erase(coord)
