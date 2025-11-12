extends Node

## Signals
signal dialogue_ended
signal dialogue_started(timeline_name: String)

## Private variables
var current_timeline_name: String = ""

func _ready() -> void:
	if Dialogic:
		Dialogic.timeline_ended.connect(_on_timeline_ended)
	else:
		printerr("DialogueManager: Dialogic not available")

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Start a Dialogic timeline by timeline name/ID.
func start_timeline(timeline_name: String) -> void:
	print("DialogueManager: Starting timeline: %s" % timeline_name)
	
	Dialogic.start(timeline_name)
	get_viewport().set_input_as_handled()
	dialogue_started.emit(timeline_name)
	current_timeline_name = timeline_name


#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_timeline_ended() -> void:
	print("DialogueManager: Timeline ended")
	
	dialogue_ended.emit()
	current_timeline_name = ""
