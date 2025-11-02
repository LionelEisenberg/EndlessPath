class_name ZoneData
extends Resource

@export var zone_name: String = ""
@export var zone_id: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var unlock_conditions: Array[UnlockConditionData] = []  # Conditions to unlock this zone
@export var available_actions: Array[ZoneActionData] = []  # All possible actions in this zone
@export var initial_unlocked_actions: Array[String] = []  # Action IDs available from start
@export var tilemap_location: Vector2i = Vector2i(0, 0)
