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
## Currently only variant 0 (Hex_Forest_00_Basic) exists — all zones
## default to it. When additional forest variants are imported
## (Hex_Forest_01 through Hex_Forest_20), each one gets added as a new
## atlas source in scenes/tilemaps/tilemap_tileset.tres and its source
## id appended to ZoneTilemap.ZONE_TILE_VARIANT_SOURCE_IDS. Setting
## this field to the variant index picks that art per zone.
##
## See docs/zones/ZONES.md § Tile Variants for the full mapping and
## TODO list of remaining variants to import.
@export var tile_variant_index: int = 0
