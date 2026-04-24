@tool
class_name MapPreview
extends Node2D

## Editor-only tool for previewing adventure map generation.
## Open scenes/tools/map_preview.tscn in the Godot editor, drop an
## AdventureData.tres into the adventure_data slot, then press the
## Generate button in the inspector. The generated map is rendered in
## the 2D editor viewport using the same forest tileset and encounter
## glyphs as the in-game adventure view.
##
## Seed = 0  → fresh random layout on each press.
## Seed != 0 → deterministic (same seed + same data = same map).

const ENCOUNTER_ICON_SCENE: PackedScene = preload("res://scenes/adventure/encounter_icon/encounter_icon.tscn")

# Forest tileset source id (matches AdventureTilemap.FOREST_ATLAS_SOURCE_ID).
const FOREST_ATLAS_SOURCE_ID: int = 8

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _preview_tile_map: HexagonTileMapLayer = %PreviewTileMap
@onready var _icon_container: Node2D = %EncounterIconContainer
@onready var _origin_marker: Node2D = %OriginMarker
@onready var _stats_label: Label = %StatsLabel

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The adventure config to preview. Drag a .tres here.
@export var adventure_data: AdventureData

## 0 = random every press; non-zero = deterministic.
@export var seed_value: int = 0

@export_tool_button("Generate", "Play") var generate_button: Callable = _generate
@export_tool_button("Clear", "Remove") var clear_button: Callable = _clear

#-----------------------------------------------------------------------------
# GENERATE
#-----------------------------------------------------------------------------

func _generate() -> void:
	if not Engine.is_editor_hint():
		return
	if adventure_data == null:
		push_warning("MapPreview: no adventure_data set")
		return

	var errors: Array[String] = adventure_data.validate()
	if errors.size() > 0:
		for err in errors:
			push_error("MapPreview: %s" % err)
		return

	if seed_value == 0:
		randomize()
	else:
		seed(seed_value)

	var generator := AdventureMapGenerator.new()
	generator.set_adventure_data(adventure_data)
	generator.set_tile_map(_preview_tile_map)
	var tiles: Dictionary[Vector3i, AdventureEncounter] = generator.generate_adventure_map()

	if tiles.is_empty():
		push_warning("MapPreview: generator returned empty map")
		return

	_render(tiles)
	_update_stats_label(tiles)

#-----------------------------------------------------------------------------
# CLEAR
#-----------------------------------------------------------------------------

func _clear() -> void:
	if not Engine.is_editor_hint():
		return
	_preview_tile_map.clear()
	for child in _icon_container.get_children():
		child.queue_free()
	_origin_marker.visible = false
	_stats_label.text = ""

#-----------------------------------------------------------------------------
# RENDER
#-----------------------------------------------------------------------------

func _render(tiles: Dictionary[Vector3i, AdventureEncounter]) -> void:
	# Clear previous frame
	_preview_tile_map.clear()
	for child in _icon_container.get_children():
		child.queue_free()

	# Paint base tiles
	for coord in tiles.keys():
		_preview_tile_map.set_cell_with_source_and_variant(
			FOREST_ATLAS_SOURCE_ID,
			0,
			_preview_tile_map.cube_to_map(coord),
			HexForestAtlas.pick(coord),
		)

	# Show origin marker at Vector2.ZERO (which is cube_to_world(Vector3i.ZERO)
	# for a correctly-configured HexagonTileMapLayer at position 0,0).
	_origin_marker.position = _preview_tile_map.cube_to_world(Vector3i.ZERO)
	_origin_marker.visible = true

	# Spawn encounter icons for every non-NoOp tile
	for coord in tiles.keys():
		var encounter: AdventureEncounter = tiles[coord]
		if encounter is NoOpEncounter:
			continue
		if encounter.encounter_type == AdventureEncounter.EncounterType.NONE:
			continue
		var icon: EncounterIcon = ENCOUNTER_ICON_SCENE.instantiate()
		_icon_container.add_child(icon)
		icon.position = _preview_tile_map.cube_to_world(coord)
		# EncounterIcon has @onready node refs — in @tool context, call after
		# add_child so _ready has fired. configure_for_type() is the public
		# entry point used by AdventureTilemap.
		icon.configure_for_type(encounter.encounter_type)

#-----------------------------------------------------------------------------
# STATS
#-----------------------------------------------------------------------------

func _update_stats_label(tiles: Dictionary[Vector3i, AdventureEncounter]) -> void:
	var total: int = tiles.size()
	var counts: Dictionary = {
		"combat": 0,
		"elite": 0,
		"boss": 0,
		"rest": 0,
		"treasure": 0,
		"trap": 0,
		"noop": 0,
	}
	for coord in tiles.keys():
		var enc: AdventureEncounter = tiles[coord]
		if enc is NoOpEncounter:
			counts["noop"] += 1
			continue
		match enc.encounter_type:
			AdventureEncounter.EncounterType.COMBAT_REGULAR, AdventureEncounter.EncounterType.COMBAT_AMBUSH:
				counts["combat"] += 1
			AdventureEncounter.EncounterType.COMBAT_ELITE:
				counts["elite"] += 1
			AdventureEncounter.EncounterType.COMBAT_BOSS:
				counts["boss"] += 1
			AdventureEncounter.EncounterType.REST_SITE:
				counts["rest"] += 1
			AdventureEncounter.EncounterType.TREASURE:
				counts["treasure"] += 1
			AdventureEncounter.EncounterType.TRAP:
				counts["trap"] += 1

	_stats_label.text = "%d tiles · %d combat · %d elite · %d boss · %d rest · %d treasure · %d trap · %d walk · seed: %d" % [
		total,
		counts["combat"],
		counts["elite"],
		counts["boss"],
		counts["rest"],
		counts["treasure"],
		counts["trap"],
		counts["noop"],
		seed_value,
	]
