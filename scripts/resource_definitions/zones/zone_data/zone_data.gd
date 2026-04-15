class_name ZoneData
extends Resource

@export var zone_name: String = ""
@export var zone_id: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var zone_unlock_conditions: Array[UnlockConditionData] = []  # Conditions to unlock this zone
@export var all_actions: Array[ZoneActionData] = []  # All possible actions in this zone
@export var tilemap_location: Vector2i = Vector2i(0, 0)

## Index into the forest tile variant catalog. Selects which hex tile
## artwork is rendered for this zone on the overworld map.
##
## All Hex_Forest_NN variants are packed into a single atlas
## (assets/sprites/tilemap/hex_tiles/forest/hex_forest_atlas.png) by
## scenes/tilemaps/scripts/pack_hex_atlas.py. Setting this field to N
## picks the atlas cell at (N % FOREST_ATLAS_COLS, N / FOREST_ATLAS_COLS)
## for that zone. Valid range: 0..FOREST_VARIANT_COUNT-1
## (see ZoneTilemap constants). Variant 0 is the default Basic forest.
##
## See docs/zones/ZONES.md § Tile Variants for the full variant table.
@export var tile_variant_index: int = 0
