extends GutTest

## Integration test: before the aura_well_discovered event fires, the Aura Well
## training action must NOT be in the available actions list for Spirit Valley.
## After the event fires, it must BE available.

const ZONE_ID: String = "SpiritValley"
const ACTION_ID: String = "aura_well_training"
const DISCOVERY_EVENT: String = "aura_well_discovered"

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	# Discovering the Aura Well starts it (the first idle unlock auto-starts),
	# so stop it or its tick timer runs into the next test.
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _has_aura_well_action() -> bool:
	var actions: Array = ZoneManager.get_available_actions(ZONE_ID)
	for a in actions:
		if a.action_id == ACTION_ID:
			return true
	return false

func test_aura_well_action_hidden_before_discovery() -> void:
	assert_false(_has_aura_well_action(), "Aura Well training must be gated before discovery event")

func test_aura_well_action_visible_after_discovery() -> void:
	EventManager.trigger_event(DISCOVERY_EVENT)
	assert_true(_has_aura_well_action(), "Aura Well training must be available after discovery event")
