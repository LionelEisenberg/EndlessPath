extends Node

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal event_triggered(event_id: String)

#-----------------------------------------------------------------------------
# VARIABLES
#-----------------------------------------------------------------------------

var live_save_data: SaveGameData

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	live_save_data = PersistenceManager.save_game_data

#-----------------------------------------------------------------------------
# EVENT MANAGEMENT
#-----------------------------------------------------------------------------

## Triggers an event if it hasn't been triggered before. Emits event_triggered signal.
func trigger_event(event_id: String) -> void:
	if event_id not in live_save_data.event_progression.triggered_events:
		live_save_data.event_progression.triggered_events.append(event_id)
		event_triggered.emit(event_id)

## Returns true if the event has been triggered, false otherwise.
func has_event_triggered(event_id: String) -> bool:
	return event_id in live_save_data.event_progression.triggered_events
