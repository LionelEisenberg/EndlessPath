extends GutTest

## Every NPC dialogue action jumps to a label its timeline holds. A misspelled
## label raises no error in play: Dialogic's jump stays where it is, and the talk
## plays the wrong lines (DIALOGUE.md, Bugs). Each timeline is found the way
## Dialogic.start() finds it, by name through the [dialogic] dtl_directory
## registry in project.godot, and read with Dialogic's own parser, so the labels
## are the ones its jump compares against.

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Every NPC dialogue action of every zone.
func _npc_actions() -> Array[NpcDialogueActionData]:
	var actions: Array[NpcDialogueActionData] = []
	for zone: ZoneData in ZoneManager.get_all_zones():
		for action: ZoneActionData in zone.all_actions:
			if action is NpcDialogueActionData:
				actions.append(action)
	return actions

## The names of the labels in the timeline the registry gives this name, in
## timeline order. Empty when the registry has no such timeline.
func _labels_of(timeline_name: String) -> Array[String]:
	var labels: Array[String] = []
	var timeline: DialogicTimeline = DialogicResourceUtil.get_timeline_resource(timeline_name)
	if timeline == null:
		return labels
	timeline.process()
	for event: Variant in timeline.events:
		if event is DialogicLabelEvent:
			labels.append((event as DialogicLabelEvent).name)
	return labels

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_every_npc_action_jumps_to_a_label_of_its_timeline() -> void:
	var actions: Array[NpcDialogueActionData] = _npc_actions()
	assert_gt(actions.size(), 0, "precondition: the zones have NPC dialogue actions")
	for action: NpcDialogueActionData in actions:
		var timeline_name: String = action.dialogue_timeline_name
		assert_true(DialogicResourceUtil.timeline_resource_exists(timeline_name),
			"%s: the registry has its timeline %s" % [action.action_id, timeline_name])
		if action.dialogue_timeline_label_jump.is_empty():
			continue
		assert_has(_labels_of(timeline_name), action.dialogue_timeline_label_jump,
			"%s: %s holds its label" % [action.action_id, timeline_name])
