class_name StoryRouteData extends Resource

## StoryRouteData
## The story route: the canonical playthrough as beats in the order they play, plus the
## content it deliberately leaves out. The route only ever runs on a fresh save, beat by
## beat, so each step meets the state it was written for. One file holds it,
## resources/dev/story_route.tres.

#-----------------------------------------------------------------------------
# DATA
#-----------------------------------------------------------------------------

## The beats, in the order they play.
@export var beats: Array[StoryBeatData] = []
## The quests the route leaves unfinished on purpose. The coverage test expects every
## other quest completed.
@export var optional_quest_ids: Array[String] = []
## The actions the route never makes available on purpose. The coverage test expects
## every other action of every zone to be available after some step.
@export var excluded_action_ids: Array[String] = []

#-----------------------------------------------------------------------------
# FINDING BEATS AND STEPS
#-----------------------------------------------------------------------------

## The beat with this id, or null when the route has none. "" names no beat.
func find_beat(beat_id: String) -> StoryBeatData:
	if beat_id == "":
		return null
	for beat: StoryBeatData in beats:
		if beat.beat_id == beat_id:
			return beat
	return null

## Every step of every beat up to and including this one, in order: what takes a fresh
## save to that point of the story. Empty for "" and for an id the route has no beat
## for, never the whole route.
func steps_through(beat_id: String) -> Array[DevStepData]:
	var steps: Array[DevStepData] = []
	if find_beat(beat_id) == null:
		return steps
	for beat: StoryBeatData in beats:
		steps.append_array(beat.steps)
		if beat.beat_id == beat_id:
			break
	return steps

#-----------------------------------------------------------------------------
# VALIDATE
#-----------------------------------------------------------------------------

## Everything wrong with the route, one line each; empty when it is sound: a beat with no
## id, a beat id used twice, a listed quest or action the content does not have, and
## each step's own errors (DevStepData.validate()), each starting with its beat.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Array[String] = []
	for index: int in beats.size():
		var beat: StoryBeatData = beats[index]
		var label: String = beat.beat_id
		if beat.beat_id == "":
			label = "beat %d" % (index + 1)
			errors.append("%s has no beat_id" % label)
		elif seen_ids.has(beat.beat_id):
			errors.append("beat_id %s is used by more than one beat" % beat.beat_id)
		else:
			seen_ids.append(beat.beat_id)
		for step: DevStepData in beat.steps:
			for error: String in step.validate():
				errors.append("%s: %s" % [label, error])
	for quest_id: String in optional_quest_ids:
		if QuestManager.get_quest_data(quest_id) == null:
			errors.append("optional_quest_ids lists %s, which is not a quest" % quest_id)
	for action_id: String in excluded_action_ids:
		if ZoneManager.get_action_by_id(action_id) == null:
			errors.append("excluded_action_ids lists %s, which is not an action" % action_id)
	return errors
