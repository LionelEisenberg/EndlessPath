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
const ENCOUNTER_ID_LABEL_SCENE: PackedScene = preload("res://scenes/tools/encounter_id_label.tscn")

# Forest tileset source id (matches AdventureTilemap.FOREST_ATLAS_SOURCE_ID).
const FOREST_ATLAS_SOURCE_ID: int = 8

# Pixel offset from a tile's center to where the encounter_id Label's
# top-left should sit. Half the label's 80px width to the left, 32px down
# so it lands below the 84px-tall encounter glyph.
const ID_LABEL_OFFSET: Vector2 = Vector2(-40, 32)

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

# The seed actually used by the most recent generation. When seed_value is
# non-zero this matches it; when seed_value is 0 we mint a fresh random
# seed via randi() and store it here so the stats label can show it —
# letting the designer copy the displayed seed back into seed_value to
# lock in a layout they liked.
var _last_used_seed: int = 0

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
		# Mint a fresh random seed but capture it so we can display it.
		# randomize() seeds globally but doesn't expose the value used.
		_last_used_seed = randi()
		seed(_last_used_seed)
	else:
		_last_used_seed = seed_value
		seed(seed_value)

	# The HexagonTileMapLayer addon only wires up its cube<->map conversion
	# callables inside _enter_tree() when NOT in editor mode. Force the setup
	# manually so cube_to_map / cube_to_local / cube_distance work here.
	_preview_tile_map._on_tileset_changed()

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

	# Show origin marker at Vector2.ZERO (which is cube_to_local(Vector3i.ZERO)
	# for a correctly-configured HexagonTileMapLayer at position 0,0).
	_origin_marker.position = _preview_tile_map.cube_to_local(Vector3i.ZERO)
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
		icon.position = _preview_tile_map.cube_to_local(coord)
		# EncounterIcon has @onready node refs — in @tool context, call after
		# add_child so _ready has fired. configure_for_type() is the public
		# entry point used by AdventureTilemap.
		icon.configure_for_type(encounter.encounter_type)

		# Drop the encounter_id under each icon so the designer can tell
		# similar-typed encounters apart (e.g. amorphous_spirit vs
		# starving_dreadbeast both render as the same combat glyph).
		var id_label: Label = ENCOUNTER_ID_LABEL_SCENE.instantiate()
		id_label.text = encounter.encounter_id
		id_label.position = _preview_tile_map.cube_to_local(coord) + ID_LABEL_OFFSET
		_icon_container.add_child(id_label)

#-----------------------------------------------------------------------------
# STATS
#-----------------------------------------------------------------------------

func _update_stats_label(tiles: Dictionary[Vector3i, AdventureEncounter]) -> void:
	var total: int = tiles.size()
	var counts: Dictionary[String, int] = {
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
		_last_used_seed,
	]
