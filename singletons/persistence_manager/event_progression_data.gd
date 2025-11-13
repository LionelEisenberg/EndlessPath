class_name EventProgressionData
extends Resource

@export var triggered_events: Array[String] = []

func _to_string() -> String:
	return "EventProgressionData(TriggeredEvents: %s)" % str(triggered_events)