class_name ZoneData
extends Resource

@export var zone_name: String = ""
@export var zone_id: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var zone_unlock_conditions: Array[UnlockConditionData] = []  # Conditions to unlock this zone
@export var all_actions: Array[ZoneActionData] = []  # All possible actions in this zone
@export var tilemap_location: Vector2i = Vector2i(0, 0)
