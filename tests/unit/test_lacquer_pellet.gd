extends GutTest

## Unit tests for LacquerPellet, the opaque pellet the Madra drain, the cycling
## view and the tribulation send. Lacquer kit §1 rules 4 and 6: every look is a
## frame of one strip in one ramp and the ink, no glow, halo, alpha or tint, and
## the pellet and its tail stand on even px. It condenses, flies with its tail,
## sparks where it lands and frees itself.

const PELLET_SCENE_PATH: String = "res://scenes/common/lacquer/lacquer_pellet/lacquer_pellet.tscn"
const STRIP_PATH: String = "res://assets/ui/lacquer/lacquer_pellet_strip_ai.png"
## The zone kit's Madra pellet: the strip's full frame in the Madra row is this art.
const KIT_PELLET_PATH: String = "res://assets/ui/lacquer/lacquer_madra_pellet_ai.png"

## The strip: 8 frames of 20x20 across, a row per ramp down.
const STRIP_COLUMNS: int = 8
const FRAME_SIZE: int = 20

## Kit §2: each row's ramp and the ink, the only colours that row may use, in the
## order of LacquerPellet.Ramp.
const RAMP_PALETTES: Array = [
	["e8f6fd", "bbd5e7", "849be4", "1c2f60", "150909"],
	["f0e8d8", "d4a84a", "a66834", "341e0e", "150909"],
	["f0e8d8", "a89070", "7a654c", "150909"],
	["f0e8d8", "a89070", "7a654c", "341e0e", "150909"],
]

const FRAME: float = 1.0 / 60.0
## Off the grid on purpose: the pellet must still land on even px.
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

func _is_on_grid(point: Vector2) -> bool:
	return is_equal_approx(fposmod(point.x, 2.0), 0.0) and is_equal_approx(fposmod(point.y, 2.0), 0.0)

func _sprite(pellet: LacquerPellet, node_name: String = "Sprite") -> Sprite2D:
	return pellet.get_node("%" + node_name)

func _sprites(pellet: LacquerPellet) -> Array[Sprite2D]:
	return [_sprite(pellet), _sprite(pellet, "TailNear"), _sprite(pellet, "TailFar")]

## A pixel as it shows: any clear pixel is plain clear.
func _seen(pixel: Color) -> Color:
	return Color(0, 0, 0, 0) if is_zero_approx(pixel.a) else pixel

#-----------------------------------------------------------------------------
# LOOK
#-----------------------------------------------------------------------------

func test_every_sprite_shows_a_frame_of_the_strip() -> void:
	var pellet: LacquerPellet = _add_pellet()
	for sprite: Sprite2D in _sprites(pellet):
		assert_eq(sprite.texture.resource_path, STRIP_PATH, sprite.name)
		assert_eq(sprite.hframes, STRIP_COLUMNS, sprite.name)
		assert_eq(sprite.vframes, LacquerPellet.Ramp.size(), "a row per ramp")
	var strip: Texture2D = load(STRIP_PATH)
	assert_eq(strip.get_size(), Vector2(STRIP_COLUMNS * FRAME_SIZE, LacquerPellet.Ramp.size() * FRAME_SIZE))

## Every pixel of a row is fully clear or fully opaque, in its ramp or the ink: no
## halo, glow or soft edge.
func test_each_row_is_opaque_and_in_its_ramp() -> void:
	var image: Image = (load(STRIP_PATH) as Texture2D).get_image()
	var stray: Array[String] = []
	for y: int in image.get_height():
		var palette: Array = RAMP_PALETTES[y / FRAME_SIZE]
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if is_zero_approx(pixel.a):
				continue
			if not is_equal_approx(pixel.a, 1.0) or not palette.has(pixel.to_html(false)):
				stray.append("%d,%d %s" % [x, y, pixel.to_html()])
	assert_eq(stray.size(), 0, "only opaque ramp and ink pixels: %s" % [stray.slice(0, 5)])

## The strip is drawn on the 2x grid: every art px is a 2x2 block of one colour.
## A clear pixel counts as clear whatever its colour: the importer's alpha-border
## fix tints clear pixels that touch opaque ones.
func test_strip_is_on_the_two_px_grid() -> void:
	var image: Image = (load(STRIP_PATH) as Texture2D).get_image()
	var broken: int = 0
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			var pixel: Color = _seen(image.get_pixel(x, y))
			if _seen(image.get_pixel(x + 1, y)) != pixel or _seen(image.get_pixel(x, y + 1)) != pixel or _seen(image.get_pixel(x + 1, y + 1)) != pixel:
				broken += 1
	assert_eq(broken, 0, "no art px split across the grid")

## The full Madra frame is the zone kit's pellet, unchanged, centred in its frame.
func test_full_frame_is_the_kit_pellet() -> void:
	var kit: Image = (load(KIT_PELLET_PATH) as Texture2D).get_image()
	var strip: Image = (load(STRIP_PATH) as Texture2D).get_image()
	var inset: int = (FRAME_SIZE - kit.get_width()) / 2
	var different: int = 0
	for y: int in kit.get_height():
		for x: int in kit.get_width():
			var column: int = LacquerPellet.FULL_FRAME * FRAME_SIZE
			if strip.get_pixel(column + inset + x, inset + y) != kit.get_pixel(x, y):
				different += 1
	assert_eq(different, 0)

## Each frame is centred on the pellet's point, its top-left on even px.
func test_art_is_centred_on_the_grid() -> void:
	var pellet: LacquerPellet = _add_pellet()
	for sprite: Sprite2D in _sprites(pellet):
		assert_false(sprite.centered, "an explicit offset keeps the top-left even")
		assert_eq(sprite.offset, -Vector2(FRAME_SIZE, FRAME_SIZE) / 2.0, sprite.name)
		assert_true(_is_on_grid(sprite.offset))

func test_pellet_is_never_tinted_or_faded() -> void:
	var pellet: LacquerPellet = _flying_pellet()
	for frame: int in int((DURATION + LacquerPellet.SPARK_SECONDS) / FRAME):
		pellet._process(FRAME)
		assert_eq(pellet.modulate, Color.WHITE)
		assert_eq(pellet.self_modulate, Color.WHITE)
		for sprite: Sprite2D in _sprites(pellet):
			assert_eq(sprite.modulate, Color.WHITE)
			assert_eq(sprite.self_modulate, Color.WHITE)

func test_set_ramp_moves_every_sprite_to_its_row() -> void:
	var pellet: LacquerPellet = _flying_pellet()
	pellet.set_ramp(LacquerPellet.Ramp.CREAM)
	assert_eq(pellet.get_ramp(), LacquerPellet.Ramp.CREAM)
	pellet._process(0.2)
	for sprite: Sprite2D in _sprites(pellet):
		assert_eq(sprite.frame_coords.y, LacquerPellet.Ramp.CREAM, sprite.name)

func test_a_new_pellet_is_madra() -> void:
	assert_eq(_add_pellet().get_ramp(), LacquerPellet.Ramp.MADRA)

#-----------------------------------------------------------------------------
# ITS LIFE IN FRAMES
#-----------------------------------------------------------------------------

## A seed, then the small pellet, then the full one; once landed, the spark's
## frames in order, holding the last.
func test_frames_condense_then_fly_then_spark() -> void:
	assert_eq(LacquerPellet.frame_at(0.0, DURATION), LacquerPellet.SEED_FRAME)
	assert_eq(LacquerPellet.frame_at(0.03, DURATION), LacquerPellet.SEED_FRAME)
	assert_eq(LacquerPellet.frame_at(0.05, DURATION), LacquerPellet.SMALL_FRAME)
	assert_eq(LacquerPellet.frame_at(0.09, DURATION), LacquerPellet.FULL_FRAME)
	assert_eq(LacquerPellet.frame_at(0.59, DURATION), LacquerPellet.FULL_FRAME)
	assert_eq(LacquerPellet.frame_at(0.6, DURATION), LacquerPellet.SPARK_FRAMES[0])
	assert_eq(LacquerPellet.frame_at(0.66, DURATION), LacquerPellet.SPARK_FRAMES[1])
	assert_eq(LacquerPellet.frame_at(0.71, DURATION), LacquerPellet.SPARK_FRAMES[2])
	assert_eq(LacquerPellet.frame_at(5.0, DURATION), LacquerPellet.SPARK_FRAMES[2])

func test_pellet_starts_as_a_seed_with_no_tail() -> void:
	var pellet: LacquerPellet = _flying_pellet()
	assert_eq(_sprite(pellet).frame_coords.x, LacquerPellet.SEED_FRAME)
	assert_false(_sprite(pellet, "TailNear").visible)
	assert_false(_sprite(pellet, "TailFar").visible)

## Once it is full-sized, each half of the tail stands at the pellet's own point
## its lag ago, a smaller, darker frame, on even px.
func test_tail_trails_behind_in_flight() -> void:
	var pellet: LacquerPellet = _add_pellet()
	var flight: PelletFlight = PelletFlight.arc(START, TARGET, DURATION, BOW)
	pellet.fly(flight)
	pellet._process(0.4)
	var near: Sprite2D = _sprite(pellet, "TailNear")
	var far: Sprite2D = _sprite(pellet, "TailFar")
	assert_true(near.visible and far.visible, "the tail shows in flight")
	assert_eq(near.frame_coords.x, LacquerPellet.TAIL_NEAR_FRAME)
	assert_eq(far.frame_coords.x, LacquerPellet.TAIL_FAR_FRAME)
	assert_eq(near.global_position, flight.point_at(0.4 - LacquerPellet.TAIL_NEAR_LAG))
	assert_eq(far.global_position, flight.point_at(0.4 - LacquerPellet.TAIL_FAR_LAG))
	assert_ne(far.global_position, pellet.global_position, "a pellet in full flight leaves its tail behind")
	assert_true(_is_on_grid(near.global_position) and _is_on_grid(far.global_position))

func test_tail_hides_once_landed() -> void:
	var pellet: LacquerPellet = _flying_pellet()
	pellet._process(DURATION)
	assert_false(_sprite(pellet, "TailNear").visible)
	assert_false(_sprite(pellet, "TailFar").visible)

#-----------------------------------------------------------------------------
# MOTION
#-----------------------------------------------------------------------------

func test_pellet_starts_on_the_grid() -> void:
	var pellet: LacquerPellet = _flying_pellet()
	assert_true(_is_on_grid(pellet.global_position), "start %s" % pellet.global_position)
	assert_lte(pellet.global_position.distance_to(START), 2.0, "at the start, give or take a step")

func test_pellet_and_tail_move_in_two_px_steps() -> void:
	var pellet: LacquerPellet = _flying_pellet()
	var off_grid: Array[Vector2] = []
	var moved: bool = false
	var last: Vector2 = pellet.global_position
	for frame: int in int(DURATION / FRAME) - 1:
		pellet._process(FRAME)
		for sprite: Sprite2D in _sprites(pellet):
			if not _is_on_grid(sprite.global_position):
				off_grid.append(sprite.global_position)
		moved = moved or pellet.global_position != last
		last = pellet.global_position
	assert_true(moved, "precondition: the pellet flies")
	assert_eq(off_grid.size(), 0, "every frame on even px: %s" % [off_grid])

func test_pellet_lands_on_target_and_sparks_there() -> void:
	var pellet: LacquerPellet = _flying_pellet()
	pellet._process(DURATION - FRAME)
	assert_false(pellet.has_landed(), "still flying a frame short")
	pellet._process(FRAME * 1.5)
	assert_true(pellet.has_landed())
	assert_lte(pellet.global_position.distance_to(TARGET), 2.0, "on the target, give or take a step")
	assert_true(_is_on_grid(pellet.global_position))
	assert_eq(_sprite(pellet).frame_coords.x, LacquerPellet.SPARK_FRAMES[0])
	var landed_at: Vector2 = pellet.global_position
	pellet._process(LacquerPellet.SPARK_STEP)
	assert_eq(pellet.global_position, landed_at, "it sparks where it landed")

func test_pellet_frees_itself_once_the_spark_is_over() -> void:
	var pellet: LacquerPellet = _flying_pellet()
	pellet._process(DURATION + LacquerPellet.SPARK_SECONDS - FRAME)
	assert_false(pellet.is_queued_for_deletion(), "still sparking")
	pellet._process(FRAME * 1.5)
	assert_true(pellet.is_queued_for_deletion(), "gone once the spark is over")

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
