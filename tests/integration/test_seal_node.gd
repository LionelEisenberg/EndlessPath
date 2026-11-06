extends GutTest

## Integration tests for SealNode, one seal on a cycling technique's path: the
## socket's look as it waits, shows its seal, opens and fizzles; the plate of
## arrows over it; each key lighting the next arrow; and a wrong key, which
## flashes the arrows red, shakes the plate and starts the seal over. The node's
## clock is stepped with advance(), as the technique steps it.

const SEAL_SCENE: PackedScene = preload("res://scenes/cycling/cycling_technique/seal_node.tscn")
const UP := CyclingRules.Arrow.UP
const LEFT := CyclingRules.Arrow.LEFT
const DOWN := CyclingRules.Arrow.DOWN
const RIGHT := CyclingRules.Arrow.RIGHT
const FRAME: float = 1.0 / 60.0

var _seal: SealNode = null

func before_each() -> void:
	_seal = add_child_autofree(SEAL_SCENE.instantiate()) as SealNode
	_seal.setup(2.0)

func after_each() -> void:
	_seal = null

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _plate() -> Control:
	return _seal.get_node("%Plate") as Control

func _glyph(slot: int) -> LacquerStripRect:
	return _seal.get_node("%%Glyph%d" % (slot + 1)) as LacquerStripRect

func _socket_frame() -> int:
	return (_seal.get_node("%Socket") as LacquerStripRect).get_frame().x

## The frame each glyph shows: its arrow's column and its look's row.
func _glyph_frames() -> Array[Vector2i]:
	var frames: Array[Vector2i] = []
	for slot: int in CyclingRules.SEAL_LENGTH:
		frames.append(_glyph(slot).get_frame())
	return frames

## Steps the node's clock `seconds`, a frame at a time.
func _step(seconds: float) -> void:
	for i: int in roundi(seconds / FRAME):
		_seal.advance(FRAME)

func _show() -> void:
	var arrows: Array[int] = [UP, RIGHT, DOWN]
	_seal.show_seal(arrows)

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_a_new_node_waits() -> void:
	assert_eq(_seal.get_state(), SealNode.State.IDLE)
	assert_eq(_seal.arrive_seconds, 2.0)
	assert_eq(_socket_frame(), SealNode.State.IDLE, "the tan socket")
	assert_false(_plate().visible, "no seal shows yet")

func test_showing_a_seal_shows_its_arrows() -> void:
	_show()
	assert_eq(_seal.get_state(), SealNode.State.SHOWING)
	assert_eq(_socket_frame(), SealNode.State.SHOWING, "the green rim")
	assert_true(_plate().visible)
	assert_eq(_seal.get_arrows(), [UP, RIGHT, DOWN] as Array[int])
	assert_eq(_glyph_frames(), [
		Vector2i(UP, SealNode.Look.NEXT),
		Vector2i(RIGHT, SealNode.Look.WAITING),
		Vector2i(DOWN, SealNode.Look.WAITING),
	] as Array[Vector2i], "the first arrow is next, the rest wait")

func test_the_right_keys_open_it() -> void:
	_show()
	assert_true(_seal.press(UP))
	assert_eq(_glyph_frames(), [
		Vector2i(UP, SealNode.Look.DONE),
		Vector2i(RIGHT, SealNode.Look.NEXT),
		Vector2i(DOWN, SealNode.Look.WAITING),
	] as Array[Vector2i], "the first lit, the second next")
	assert_true(_seal.press(RIGHT))
	assert_true(_seal.press(DOWN))
	assert_eq(_seal.get_state(), SealNode.State.OPEN)
	assert_eq(_socket_frame(), SealNode.State.OPEN, "the node fills green")
	assert_true(_plate().visible, "the plate stays a moment, every arrow lit")
	_step(SealNode.OPEN_PLATE_SECONDS - 2.0 * FRAME)
	assert_true(_plate().visible)
	_step(3.0 * FRAME)
	assert_false(_plate().visible, "then it goes")

func test_a_wrong_key_starts_it_over() -> void:
	_show()
	var rest: Vector2 = _plate().position
	assert_true(_seal.press(UP))
	assert_false(_seal.press(LEFT), "a wrong key")
	assert_eq(_seal.get_keyed(), 0, "the seal starts over")
	assert_eq(_seal.get_state(), SealNode.State.SHOWING)
	for frame: Vector2i in _glyph_frames():
		assert_eq(frame.y, SealNode.Look.WRONG, "every arrow flashes red")
	var shaken: bool = false
	for i: int in roundi(SealNode.CRACK_SECONDS / FRAME) - 1:
		_seal.advance(FRAME)
		shaken = shaken or _plate().position != rest
	assert_true(shaken, "the plate shakes")
	_step(2.0 * FRAME)
	assert_eq(_plate().position, rest, "and settles back")
	assert_eq(_glyph_frames(), [
		Vector2i(UP, SealNode.Look.NEXT),
		Vector2i(RIGHT, SealNode.Look.WAITING),
		Vector2i(DOWN, SealNode.Look.WAITING),
	] as Array[Vector2i], "the first arrow is next again")

func test_a_key_during_the_flash_counts() -> void:
	_show()
	assert_false(_seal.press(LEFT))
	assert_true(_seal.press(UP), "the first arrow, while the arrows are still red")
	assert_eq(_seal.get_keyed(), 1)
	assert_eq(_glyph_frames(), [
		Vector2i(UP, SealNode.Look.DONE),
		Vector2i(RIGHT, SealNode.Look.NEXT),
		Vector2i(DOWN, SealNode.Look.WAITING),
	] as Array[Vector2i], "the flash ends at once")

func test_keys_outside_a_showing_seal_do_nothing() -> void:
	assert_false(_seal.press(UP), "a waiting node")
	assert_eq(_seal.get_state(), SealNode.State.IDLE)
	_show()
	for arrow: int in [UP, RIGHT, DOWN]:
		_seal.press(arrow)
	assert_false(_seal.press(UP), "an open node")
	assert_eq(_seal.get_state(), SealNode.State.OPEN)
	_seal.reset()
	_show()
	_seal.fizzle()
	assert_false(_seal.press(UP), "a spent node")
	assert_eq(_seal.get_state(), SealNode.State.SPENT)

func test_fizzle_and_burst() -> void:
	_show()
	_seal.fizzle()
	assert_eq(_seal.get_state(), SealNode.State.SPENT)
	assert_eq(_socket_frame(), SealNode.State.SPENT, "cracked and dark")
	assert_false(_plate().visible)
	_seal.reset()
	assert_eq(_seal.get_state(), SealNode.State.IDLE)
	assert_eq(_socket_frame(), SealNode.State.IDLE)
	_show()
	for arrow: int in [UP, RIGHT, DOWN]:
		_seal.press(arrow)
	_seal.burst()
	assert_eq(_seal.get_state(), SealNode.State.OPEN, "the ball passed: it stays green")
	assert_false(_plate().visible)
	_seal.reset()
	assert_eq(_seal.get_state(), SealNode.State.IDLE)
	assert_false(_plate().visible)
