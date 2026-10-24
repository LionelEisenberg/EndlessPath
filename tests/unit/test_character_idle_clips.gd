extends GutTest

## The character's idle-motion clips (the zone map's foraging and Aura Well
## choreography in ZoneMapMath) last as long as the segments they play in, and
## every frame they show is a drawn cell of the robed character's sheet.

const CharacterScene: PackedScene = preload("res://scenes/characters/main_character/character_body_2d.tscn")

const IDLE_CLIPS: Array[StringName] = [&"meditate", &"teleport_in", &"teleport_out", &"forage_search", &"forage_present"]

var _character: CharacterBody2D
var _player: AnimationPlayer
var _sprite: Sprite2D

func before_each() -> void:
	_character = CharacterScene.instantiate()
	add_child_autofree(_character)
	_player = _character.get_node("AnimationPlayer") as AnimationPlayer
	_sprite = _character.get_node("Sprite2D") as Sprite2D

## The sheet frames a clip's Sprite2D:frame track shows.
func _frames_of(clip: StringName) -> Array[int]:
	var animation: Animation = _player.get_animation(clip)
	var track: int = animation.find_track(^"Sprite2D:frame", Animation.TYPE_VALUE)
	var frames: Array[int] = []
	for key: int in animation.track_get_key_count(track):
		frames.append(int(animation.track_get_key_value(track, key)))
	return frames

func test_every_idle_clip_exists() -> void:
	for clip: StringName in IDLE_CLIPS:
		assert_true(_player.has_animation(clip), "clip %s" % clip)

func test_forage_clips_fill_their_segments() -> void:
	var ends: Array[float] = ZoneMapMath.FORAGE_SEGMENT_ENDS
	assert_almost_eq(_player.get_animation(&"forage_search").length, ends[1] - ends[0], 0.0001, "the search")
	assert_almost_eq(_player.get_animation(&"forage_present").length, ends[3] - ends[2], 0.0001, "the find held up")

func test_aura_well_clips_fill_their_segments() -> void:
	var ends: Array[float] = ZoneMapMath.AURA_WELL_SEGMENT_ENDS
	assert_almost_eq(_player.get_animation(&"teleport_in").length, ends[0], 0.0001, "re-forming")
	assert_almost_eq(_player.get_animation(&"teleport_out").length, ends[2] - ends[1], 0.0001, "dissolving")
	var meditate: Animation = _player.get_animation(&"meditate")
	assert_almost_eq(meditate.length, ZoneMapMath.MEDITATE_SECONDS, 0.0001, "one breath")
	assert_eq(meditate.loop_mode, Animation.LOOP_LINEAR, "the breath repeats")
	var breaths: float = (ends[1] - ends[0]) / meditate.length
	assert_almost_eq(breaths, roundf(breaths), 0.0001, "a spot holds whole breaths")

func test_teleport_in_plays_the_dissolve_backwards() -> void:
	var out_frames: Array[int] = _frames_of(&"teleport_out")
	out_frames.reverse()
	assert_eq(_frames_of(&"teleport_in"), out_frames)

func test_idle_clips_show_drawn_cells() -> void:
	var sheet: Image = _sprite.texture.get_image()
	var cell: Vector2i = Vector2i(sheet.get_width() / _sprite.hframes, sheet.get_height() / _sprite.vframes)
	for clip: StringName in IDLE_CLIPS:
		for frame: int in _frames_of(clip):
			assert_lt(frame, _sprite.hframes * _sprite.vframes, "%s frame %d is on the sheet" % [clip, frame])
			var origin: Vector2i = Vector2i(frame % _sprite.hframes, frame / _sprite.hframes) * cell
			var used: Rect2i = sheet.get_region(Rect2i(origin, cell)).get_used_rect()
			assert_gt(used.get_area(), 0, "%s frame %d has art" % [clip, frame])
