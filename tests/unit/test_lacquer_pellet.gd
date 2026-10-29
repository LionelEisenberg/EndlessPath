extends GutTest

## Unit tests for LacquerPellet, the pellet the Madra drain, the cycling view
## and the tribulation send. It flies to its target, delivers once as it lands
## (or as it is taken out early), and frees itself once its spark is over.

const PELLET_SCENE_PATH: String = "res://scenes/common/lacquer/lacquer_pellet/lacquer_pellet.tscn"

const FRAME: float = 1.0 / 60.0
const START: Vector2 = Vector2(101.3, 57.7)
const TARGET: Vector2 = Vector2(731.6, 403.1)
const DURATION: float = 0.6
const BOW: float = 120.0

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A pellet in the tree whose frames the test steps by hand.
func _add_pellet() -> LacquerPellet:
	var scene: PackedScene = load(PELLET_SCENE_PATH)
	var pellet: LacquerPellet = scene.instantiate()
	add_child_autofree(pellet)
	pellet.set_process(false)
	return pellet

## A pellet sent along a plain arc from START to TARGET.
func _flying_pellet() -> LacquerPellet:
	var pellet: LacquerPellet = _add_pellet()
	pellet.fly(PelletFlight.arc(START, TARGET, DURATION, BOW))
	return pellet

#-----------------------------------------------------------------------------
# MOTION
#-----------------------------------------------------------------------------

func test_pellet_lands_on_target() -> void:
	var pellet: LacquerPellet = _flying_pellet()
	pellet._process(DURATION - FRAME)
	assert_false(pellet.has_landed(), "still flying a frame short")
	pellet._process(FRAME * 1.5)
	assert_true(pellet.has_landed())
	assert_lte(pellet.global_position.distance_to(TARGET), 2.0, "on the target, give or take a step")

func test_pellet_frees_itself_once_the_spark_is_over() -> void:
	var pellet: LacquerPellet = _flying_pellet()
	pellet._process(DURATION + LacquerPellet.SPARK_SECONDS - FRAME)
	assert_false(pellet.is_queued_for_deletion(), "still sparking")
	pellet._process(FRAME * 1.5)
	assert_true(pellet.is_queued_for_deletion(), "gone once the spark is over")

#-----------------------------------------------------------------------------
# DELIVERY
#-----------------------------------------------------------------------------

func test_delivers_once_as_it_lands() -> void:
	var pellet: LacquerPellet = _flying_pellet()
	watch_signals(pellet)
	pellet._process(DURATION - FRAME)
	assert_signal_not_emitted(pellet, "delivered", "not while it flies")
	pellet._process(FRAME * 1.5)
	assert_signal_emit_count(pellet, "delivered", 1, "as it lands")
	pellet._process(LacquerPellet.SPARK_STEP)
	assert_signal_emit_count(pellet, "delivered", 1, "and never again while it sparks")

## A pellet freed in flight (a hidden cycling board frees its pellets) still
## delivers, so what it carried is not lost.
func test_delivers_when_taken_out_before_it_lands() -> void:
	var pellet: LacquerPellet = _flying_pellet()
	watch_signals(pellet)
	pellet._process(0.2)
	remove_child(pellet)
	assert_signal_emit_count(pellet, "delivered", 1)
	pellet.free()

func test_a_landed_pellet_does_not_deliver_again_as_it_goes() -> void:
	var pellet: LacquerPellet = _flying_pellet()
	watch_signals(pellet)
	pellet._process(DURATION + FRAME)
	remove_child(pellet)
	assert_signal_emit_count(pellet, "delivered", 1)
	pellet.free()

## Added to the tree but never sent, the pellet stays where it is.
func test_a_pellet_with_no_flight_waits() -> void:
	var pellet: LacquerPellet = _add_pellet()
	pellet._process(1.0)
	assert_false(pellet.has_landed())
	assert_false(pellet.is_queued_for_deletion())

#-----------------------------------------------------------------------------
# DRAIN
#-----------------------------------------------------------------------------

## ZoneTransition keeps its count and timing; what it launches is the pellet.
func test_the_adventure_drain_pours_pellets() -> void:
	var pellet: Node = autofree(ZoneTransition.DRAIN_PELLET_SCENE.instantiate())
	assert_true(pellet is LacquerPellet)
