class_name StoryBeatData extends Resource

## StoryBeatData
## One point on the story route: the steps that take a save from the beat before it to
## this one. A beat only uses step kinds; it never edits save fields directly.

## The id a preset's story_through names the beat by. Unique in its route.
@export var beat_id: String = ""
## What the panel calls the beat.
@export var title: String = ""
## The steps that play the beat, in order, on a save that has played every beat before it.
@export var steps: Array[DevStepData] = []
## The id of the event or unlock condition that marks the beat reached in real play, or
## "" when nothing does. It feeds the play stats and the route's coverage test, and never
## controls a build.
@export var reached_when: String = ""
