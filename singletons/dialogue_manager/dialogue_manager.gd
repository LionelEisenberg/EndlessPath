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
		Log.critical("DialogueManager: Dialogic not available")

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Start a Dialogic timeline by timeline name/ID.
func start_timeline(timeline_name: String, label_or_idx:Variant = "") -> void:
	Log.info("DialogueManager: Starting timeline: %s" % timeline_name)
	
	Dialogic.start(timeline_name,label_or_idx)
	get_viewport().set_input_as_handled()
	dialogue_started.emit(timeline_name)
	current_timeline_name = timeline_name

## Ends the running timeline at once, without Dialogic's ending timeline, and
## forgets it. Does nothing while no timeline runs. Dialogic still sends
## timeline_ended a frame later, and dialogue_ended follows it, so a caller that
## must not hear that end disconnects from dialogue_ended first. A timeline
## started in this same frame has not begun yet (Dialogic begins it at the end of
## the frame, once its new layout is ready): timeline_ended then comes at once,
## and the timeline still plays.
func end_dialogue_now() -> void:
	if current_timeline_name == "":
		return
	current_timeline_name = ""
	Dialogic.end_timeline(true)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_timeline_ended() -> void:
	Log.info("DialogueManager: Timeline ended")
	
	dialogue_ended.emit()
	current_timeline_name = ""
