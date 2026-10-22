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

#-----------------------------------------------------------------------------
# MAP
#-----------------------------------------------------------------------------

## Keeps the zone off the overworld map (ZoneManager.get_map_zones()) unless
## the dev panel shows hidden zones. The zone itself still exists, so saves
## that name it stay valid.
@export var hidden_on_map: bool = false

## Conditions for the zone to be charted. While any is unmet the map shows the
## zone as UNCHARTED (a dark veil and a "?"), whatever its unlock conditions
## say. Empty means charted from the start.
@export var chart_conditions: Array[UnlockConditionData] = []

## Short blocker shown on a locked or uncharted zone's map plate, e.g.
## "Tribulation Guardian". UnlockConditionData has no player-facing text.
@export var blocker_short_text: String = ""

## Full requirement sentence for the zone's map popover, e.g. "Defeat the
## Tribulation Guardian in The Shallow Woods".
@export_multiline var requirement_text: String = ""

## action_id of the card that the popover's "Show me ›" scrolls to. Empty
## means the popover has no "Show me" button.
@export var requirement_action_id: String = ""
