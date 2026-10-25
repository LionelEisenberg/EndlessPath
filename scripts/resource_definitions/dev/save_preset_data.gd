class_name SavePresetData extends Resource

## SavePresetData
## A save preset: a starting point for a dev session. A recipe preset names a beat of the
## story route and adds steps of its own; a snapshot preset embeds a whole save, and
## usually names no beat. The route's steps run first, then the preset's own, on a fresh
## save or on top of the snapshot.

#-----------------------------------------------------------------------------
# DATA
#-----------------------------------------------------------------------------

## The id the launch option --preset=<id>, the pin and the panel name the preset by.
## Unique among presets.
@export var preset_id: String = ""
## What the panel calls the preset.
@export var title: String = ""
## What the preset gives the player, in a sentence or two, for the panel.
@export_multiline var description: String = ""
## The id of the story route's beat to start from: the steps of every beat up to and
## including it run first. "" starts with no beat's steps.
@export var story_through: String = ""
## The preset's own steps, which run after the route's.
@export var steps: Array[DevStepData] = []
## A whole save to start from instead of a fresh one, or null for a recipe preset.
@export var snapshot: SaveGameData = null

#-----------------------------------------------------------------------------
# VALIDATE
#-----------------------------------------------------------------------------

## Everything wrong with the preset, one line each; empty when it is sound: no id, no
## title, a story_through the route has no beat for, each step's own errors
## (DevStepData.validate()), and a snapshot a newer build wrote, which this build can
## neither migrate nor write back. `route` is where story_through is looked up.
func validate(route: StoryRouteData) -> PackedStringArray:
	var errors := PackedStringArray()
	if preset_id == "":
		errors.append("preset_id is empty")
	if title == "":
		errors.append("title is empty")
	if story_through != "" and (route == null or route.find_beat(story_through) == null):
		errors.append("story_through %s is not a beat of the route" % story_through)
	for step: DevStepData in steps:
		errors.append_array(step.validate())
	if snapshot != null and snapshot.is_from_newer_build():
		errors.append("the snapshot was written by a newer build (save version %d; this build knows %d)" % [snapshot.save_version, SaveGameData.CURRENT_VERSION])
	return errors
