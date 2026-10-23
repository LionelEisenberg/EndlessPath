extends GutTest

## Unit tests for the Madra drain's pellets (MadraPellet), which fly from the
## cultivator's orb to the character when an adventure starts. Lacquer kit §1
## rules 4 and 6: an opaque pellet in the Madra ramp with an ink outline, no
## glow, halo or translucency, moving in 2 px steps.

const PELLET_SCENE_PATH: String = "res://scenes/zones/zone_transition/madra_pellet.tscn"
const PELLET_TEXTURE_PATH: String = "res://assets/ui/lacquer/lacquer_madra_pellet_ai.png"
## One of the cycling view's tier-coloured XP pellets (12x12, like the Madra one).
const BRASS_PELLET_TEXTURE_PATH: String = "res://assets/ui/lacquer/cycling/lacquer_cyc_pellet_brass_ai.png"

## Kit §2: the Madra ramp and ink, the only colours the pellet may use.
const PELLET_PALETTE: Array[String] = ["e8f6fd", "bbd5e7", "849be4", "1c2f60", "16283e", "150909"]

const FRAME: float = 1.0 / 60.0
## Off the grid on purpose: the pellet must still land on even px.
const START: Vector2 = Vector2(101.3, 57.7)
const TARGET: Vector2 = Vector2(731.6, 403.1)
const DURATION: float = 0.6
const CURVE_SPREAD: float = 120.0

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## A pellet in the tree whose frames the test steps by hand.
func _add_pellet() -> MadraPellet:
	var scene: PackedScene = load(PELLET_SCENE_PATH)
	var pellet: MadraPellet = scene.instantiate()
	add_child_autofree(pellet)
	pellet.set_process(false)
	return pellet

func _is_on_grid(point: Vector2) -> bool:
	return is_equal_approx(fposmod(point.x, 2.0), 0.0) and is_equal_approx(fposmod(point.y, 2.0), 0.0)

func _sprite(pellet: MadraPellet) -> Sprite2D:
	return pellet.get_node("%Sprite")

#-----------------------------------------------------------------------------
# LOOK
#-----------------------------------------------------------------------------

func test_pellet_is_the_lacquer_pellet_texture() -> void:
	var pellet: MadraPellet = _add_pellet()
	var sprite: Sprite2D = _sprite(pellet)
	assert_eq(sprite.texture.resource_path, PELLET_TEXTURE_PATH)
	assert_eq(sprite.texture.get_width() % 2, 0, "an even size, on the 2x grid")
	assert_eq(sprite.texture.get_height() % 2, 0)

## Every pixel is either fully clear or fully opaque, in the Madra ramp or ink:
## no halo, glow or soft edge.
func test_pellet_art_is_opaque_and_in_the_madra_ramp() -> void:
	var image: Image = (load(PELLET_TEXTURE_PATH) as Texture2D).get_image()
	var stray: Array[String] = []
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if is_zero_approx(pixel.a):
				continue
			if not is_equal_approx(pixel.a, 1.0) or not PELLET_PALETTE.has(pixel.to_html(false)):
				stray.append("%d,%d %s" % [x, y, pixel.to_html()])
	assert_eq(stray.size(), 0, "only opaque Madra-ramp and ink pixels: %s" % [stray])

func test_pellet_is_never_tinted_or_faded() -> void:
	var pellet: MadraPellet = _add_pellet()
	pellet.launch(START, TARGET, DURATION, CURVE_SPREAD)
	for frame: int in 20:
		pellet._process(FRAME)
		assert_eq(pellet.modulate, Color.WHITE)
		assert_eq(pellet.self_modulate, Color.WHITE)
		assert_eq(_sprite(pellet).modulate, Color.WHITE)
		assert_eq(_sprite(pellet).self_modulate, Color.WHITE)

## The sprite is centred on the pellet's point, its top-left on even px.
func test_pellet_art_is_centred_on_the_grid() -> void:
	var pellet: MadraPellet = _add_pellet()
	var sprite: Sprite2D = _sprite(pellet)
	assert_false(sprite.centered, "an explicit offset keeps the top-left even")
	assert_eq(sprite.position, -sprite.texture.get_size() / 2.0)
	assert_true(_is_on_grid(sprite.position))

## The cycling view's tier-coloured XP pellets are this pellet with other art.
## The sprite starts off centre because the scene already stands at (-6, -6),
## which a 12x12 texture would match even if the setter never moved it.
func test_set_texture_swaps_and_centres() -> void:
	var pellet: MadraPellet = _add_pellet()
	var sprite: Sprite2D = _sprite(pellet)
	sprite.position = Vector2.ZERO
	pellet.set_texture(load(BRASS_PELLET_TEXTURE_PATH))
	assert_eq(sprite.texture.resource_path, BRASS_PELLET_TEXTURE_PATH)
	assert_eq(sprite.position, Vector2(-6, -6))

#-----------------------------------------------------------------------------
# MOTION
#-----------------------------------------------------------------------------

func test_pellet_starts_on_the_grid() -> void:
	var pellet: MadraPellet = _add_pellet()
	pellet.launch(START, TARGET, DURATION, CURVE_SPREAD)
	assert_true(_is_on_grid(pellet.global_position), "start %s" % pellet.global_position)
	assert_lte(pellet.global_position.distance_to(START), 2.0, "at the start, give or take a step")

func test_pellet_moves_in_two_px_steps() -> void:
	var pellet: MadraPellet = _add_pellet()
	pellet.launch(START, TARGET, DURATION, CURVE_SPREAD)
	var off_grid: Array[Vector2] = []
	var moved: bool = false
	var last: Vector2 = pellet.global_position
	for frame: int in int(DURATION / FRAME) - 1:
		pellet._process(FRAME)
		if not _is_on_grid(pellet.global_position):
			off_grid.append(pellet.global_position)
		moved = moved or pellet.global_position != last
		last = pellet.global_position
	assert_true(moved, "precondition: the pellet flies")
	assert_eq(off_grid.size(), 0, "every frame on even px: %s" % [off_grid])

func test_pellet_lands_on_target_and_frees_itself() -> void:
	var pellet: MadraPellet = _add_pellet()
	pellet.launch(START, TARGET, DURATION, CURVE_SPREAD)
	for frame: int in int(DURATION / FRAME) + 2:
		pellet._process(FRAME)
	assert_lte(pellet.global_position.distance_to(TARGET), 2.0, "on the target, give or take a step")
	assert_true(_is_on_grid(pellet.global_position))
	assert_true(pellet.is_queued_for_deletion(), "the pellet frees itself on arrival")

#-----------------------------------------------------------------------------
# DRAIN
#-----------------------------------------------------------------------------

## ZoneTransition keeps its count and timing; what it launches is the pellet.
func test_the_adventure_drain_pours_pellets() -> void:
	var pellet: Node = autofree(ZoneTransition.DRAIN_PELLET_SCENE.instantiate())
	assert_true(pellet is MadraPellet)
