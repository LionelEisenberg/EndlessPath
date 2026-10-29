extends GutTest

## The character's idle-motion clips, which the zone map's foraging and Aura Well
## choreography in ZoneMapMath plays by name, are on its AnimationPlayer.

const CharacterScene: PackedScene = preload("res://scenes/characters/main_character/character_body_2d.tscn")

const IDLE_CLIPS: Array[StringName] = [&"meditate", &"teleport_in", &"teleport_out", &"forage_search", &"forage_present"]

var _character: CharacterBody2D
var _player: AnimationPlayer

func before_each() -> void:
	_character = CharacterScene.instantiate()
	add_child_autofree(_character)
	_player = _character.get_node("AnimationPlayer") as AnimationPlayer

func test_every_idle_clip_exists() -> void:
	for clip: StringName in IDLE_CLIPS:
		assert_true(_player.has_animation(clip), "clip %s" % clip)
