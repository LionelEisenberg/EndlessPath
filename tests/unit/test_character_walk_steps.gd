extends GutTest

## Unit tests for the player character's walk in whole px. Lacquer kit §0 and
## §1 rule 6: the zone map's travel walk is 328 screen px in 0.6 s in
## steps(164), so at the zone camera's zoom 2 the character stands on whole
## world px every frame while keeping its pace. The adventure map, whose zoom 1
## draws the character at 2x, asks for 2 px steps (walk_snap_px). A character
## that asks for neither walks smoothly.

const CharacterScene: PackedScene = preload("res://scenes/characters/main_character/character_body_2d.tscn")

const FRAME: float = 1.0 / 60.0
## ZoneTilemap.CHARACTER_MOVE_SPEED, written out: the test checks the pace.
const ZONE_WALK_SPEED: float = 275.0
const START: Vector2 = Vector2(480.0, 370.0)
## Spirit Valley to Test Zone: 164 world px due west (kit §0: 960 to 632 on
## screen at zoom 2), and a slanted walk for good measure.
const WEST_WALK: Vector2 = Vector2(-164.0, 0.0)
const SLANTED_WALK: Vector2 = Vector2(46.0, -155.0)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A character at START whose physics frames the test steps by hand.
func _add_character(whole_px: bool) -> CharacterBody2D:
	var character: CharacterBody2D = CharacterScene.instantiate()
	add_child_autofree(character)
	character.set_physics_process(false)
	character.snap_walk_to_whole_px = whole_px
	character.global_position = START
	return character

func _is_whole(point: Vector2) -> bool:
	return point == point.round()

## Walks by `walk` from START, one physics frame at a time, and returns every
## position the character stood on, the last one at arrival.
func _walk(character: CharacterBody2D, walk: Vector2) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	character.move_to_position(START + walk, ZONE_WALK_SPEED)
	for frame: int in 120:
		character._physics_process(FRAME)
		positions.append(character.global_position)
		if not character.is_moving:
			break
	return positions

func _off_grid(positions: Array[Vector2]) -> Array[Vector2]:
	return positions.filter(func(point: Vector2) -> bool: return not _is_whole(point))

#-----------------------------------------------------------------------------
# WHOLE PX
#-----------------------------------------------------------------------------

func test_walk_west_stands_on_whole_px_every_frame() -> void:
	var positions: Array[Vector2] = _walk(_add_character(true), WEST_WALK)
	assert_gt(positions.size(), 2, "precondition: the walk takes several frames")
	assert_eq(_off_grid(positions).size(), 0, "off the grid: %s" % [_off_grid(positions)])

func test_slanted_walk_stands_on_whole_px_every_frame() -> void:
	var positions: Array[Vector2] = _walk(_add_character(true), SLANTED_WALK)
	assert_gt(positions.size(), 2, "precondition: the walk takes several frames")
	assert_eq(_off_grid(positions).size(), 0, "off the grid: %s" % [_off_grid(positions)])

## The steps change where the character is drawn, not how fast it goes: an
## adjacent zone still takes about 0.6 s, and the walk ends on the stand.
func test_walk_in_whole_px_keeps_its_pace() -> void:
	var character: CharacterBody2D = _add_character(true)
	var positions: Array[Vector2] = _walk(character, WEST_WALK)
	assert_false(character.is_moving, "the walk ended")
	assert_eq(positions.back(), START + WEST_WALK, "on the stand")
	var seconds: float = positions.size() * FRAME
	assert_almost_eq(seconds, 0.6, 0.05, "164 px at 275 px/s")

## A second target mid-walk turns the walk from where it was, whole px still.
func test_retarget_mid_walk_stays_on_whole_px() -> void:
	var character: CharacterBody2D = _add_character(true)
	character.move_to_position(START + WEST_WALK, ZONE_WALK_SPEED)
	for frame: int in 10:
		character._physics_process(FRAME)
	var positions: Array[Vector2] = []
	character.move_to_position(START + SLANTED_WALK, ZONE_WALK_SPEED)
	for frame: int in 120:
		character._physics_process(FRAME)
		positions.append(character.global_position)
		if not character.is_moving:
			break
	assert_eq(_off_grid(positions).size(), 0, "off the grid: %s" % [_off_grid(positions)])
	assert_eq(positions.back(), START + SLANTED_WALK, "ends on the new stand")

## In 2 px steps (the adventure map) the character stands on even px every
## frame of the walk, and still ends exactly on its target, odd as it may be.
func test_walk_in_two_px_steps_stands_on_even_px_every_frame() -> void:
	var character: CharacterBody2D = _add_character(true)
	character.walk_snap_px = 2.0
	var positions: Array[Vector2] = _walk(character, SLANTED_WALK)
	assert_eq(positions.back(), START + SLANTED_WALK, "on the target, whose y is odd")
	var walking: Array[Vector2] = positions.slice(0, positions.size() - 1)
	assert_gt(walking.size(), 2, "precondition: the walk takes several frames")
	var off_even: Array[Vector2] = walking.filter(func(point: Vector2) -> bool: return point != (point / 2.0).round() * 2.0)
	assert_eq(off_even.size(), 0, "off the 2 px grid: %s" % [off_even])

#-----------------------------------------------------------------------------
# DEFAULT
#-----------------------------------------------------------------------------

func test_walk_is_smooth_unless_asked() -> void:
	var character: CharacterBody2D = CharacterScene.instantiate()
	autofree(character)
	assert_false(character.snap_walk_to_whole_px, "the character walks smoothly unless its map asks for whole px")
	assert_eq(character.walk_snap_px, 1.0, "in whole px steps when asked, unless the map asks for larger ones")
