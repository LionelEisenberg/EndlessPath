class_name ZoneActionData
extends Resource

enum ActionType {
	FORAGE,
	ADVENTURE,
	NPC_DIALOGUE,
	MERCHANT,
	TRAIN_STATS,
	CYCLING,
	ZONE_EVENT,  # Story/scripted events
	QUEST_GIVER
}

@export var action_id: String = ""
@export var action_name: String = ""
@export var action_type: ActionType = ActionType.FORAGE
@export var description: String = ""
@export var icon: Texture2D
@export var unlock_conditions: Array[UnlockConditionData] = []
@export var max_completions: int = 0  # 0 = unlimited, 1 = one-time, N = can be completed N times
@export var success_effects: Array[EffectData] = []
@export var failure_effects: Array[EffectData] = []


## toString function
func _to_string() -> String:
	return "ZoneActionData(action_id: %s, action_name: %s, action_type: %s, description: %s, icon: %s, unlock_conditions: %s, max_completions: %s)" % [
		action_id,
		action_name,
		action_type,
		description,
		icon,
		unlock_conditions,
		max_completions
	]
