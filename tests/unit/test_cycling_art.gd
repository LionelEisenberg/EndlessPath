extends GutTest

## Unit tests for the cycling view's lacquer art, the textures the later cycling
## work loads by path. Each texture has the size its scene is laid out for, and its
## art is opaque or clear: no halo, glow or soft edge (docs/STYLE_GUIDE.md rules 3
## and 9). The pellets also keep to their palettes.

const BOARD_PATH: String = "res://assets/ui/lacquer/cycling/lacquer_cyc_board_ai.png"
const BODY_PATH: String = "res://assets/ui/lacquer/cycling/lacquer_cyc_body_carved_ai.png"
const BALL_STRIP_PATH: String = "res://assets/ui/lacquer/cycling/lacquer_cyc_ball_strip_ai.png"
const BALL_RINGS_PATH: String = "res://assets/ui/lacquer/cycling/lacquer_cyc_ball_rings_ai.png"
const ZONE_STRIP_PATH: String = "res://assets/ui/lacquer/cycling/lacquer_cyc_zone_strip_ai.png"
const PELLET_BRASS_PATH: String = "res://assets/ui/lacquer/cycling/lacquer_cyc_pellet_brass_ai.png"
const PELLET_CREAM_PATH: String = "res://assets/ui/lacquer/cycling/lacquer_cyc_pellet_cream_ai.png"
const PELLET_TAN_PATH: String = "res://assets/ui/lacquer/cycling/lacquer_cyc_pellet_tan_ai.png"
const AUTO_PATH: String = "res://assets/ui/lacquer/cycling/lacquer_cyc_auto_ai.png"
const AUTO_ON_PATH: String = "res://assets/ui/lacquer/cycling/lacquer_cyc_auto_on_ai.png"
const TECH_FOUNDATION_PATH: String = "res://assets/ui/lacquer/icons/lacquer_ic_tech_foundation_ai.png"
const TECH_SMOOTH_PATH: String = "res://assets/ui/lacquer/icons/lacquer_ic_tech_smooth_ai.png"
const TECH_TORRENT_PATH: String = "res://assets/ui/lacquer/icons/lacquer_ic_tech_torrent_ai.png"

## The 560x1032 board art plus its 4 px drop shadow, baked on the right and bottom.
const BOARD_SIZE: Vector2i = Vector2i(564, 1036)
## The carved figure, re-traced at 1.048x its round-1 500 x 832.
const BODY_SIZE: Vector2i = Vector2i(524, 872)
## Eight swirl frames across and three breathing sizes down, each in a 68 px cell:
## the ball at 60, 64 and 68 px.
const BALL_STRIP_SIZE: Vector2i = Vector2i(544, 204)
const BALL_CELL: int = 68
## Four frames of 88: 0 is the brass ready ring, 1 the solid tan tracking ring, 2
## and 3 the ready ring grown by 4 and 8 px for the breathing ball.
const BALL_RINGS_SIZE: Vector2i = Vector2i(352, 88)
const RING_CELL: int = 88
## The tan of the tracking ring and of a zone's idle rim.
const TAN_HTML: String = "a89070"
## Six frames of 48: idle, active, spent, perfect, good, ok.
const ZONE_STRIP_SIZE: Vector2i = Vector2i(288, 48)
const PELLET_SIZE: Vector2i = Vector2i(12, 12)
## The raised toggle's 120x36 art plus its 2 px drop shadow. The pressed one has no
## shadow and is padded with clear px to the same size.
const AUTO_SIZE: Vector2i = Vector2i(122, 38)
const TECH_ICON_SIZE: Vector2i = Vector2i(32, 32)

## The only colours each pellet may use: its ramp and the ink outline.
const BRASS_PELLET_PALETTE: Array[String] = ["f0e8d8", "d4a84a", "a66834", "341e0e", "150909"]
const CREAM_PELLET_PALETTE: Array[String] = ["f0e8d8", "a89070", "7a654c", "150909"]
const TAN_PELLET_PALETTE: Array[String] = ["f0e8d8", "a89070", "7a654c", "341e0e", "150909"]

const PELLET_PATHS: Array[String] = [PELLET_BRASS_PATH, PELLET_CREAM_PATH, PELLET_TAN_PATH]
const TECH_ICON_PATHS: Array[String] = [TECH_FOUNDATION_PATH, TECH_SMOOTH_PATH, TECH_TORRENT_PATH]

## How many stray pixels a failure lists. The board has over half a million pixels, so a
## full list would bury the report.
const STRAYS_SHOWN: int = 5

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The imported texture at `path`. Fails the test and returns null when it is missing.
func _load_texture(path: String) -> Texture2D:
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	assert_not_null(texture, "texture exists: %s" % path)
	return texture

## Asserts the texture at `path` is `expected` px, the size its scene is laid out for.
func _assert_size(path: String, expected: Vector2i) -> void:
	var texture: Texture2D = _load_texture(path)
	if texture == null:
		return
	assert_eq(Vector2i(texture.get_width(), texture.get_height()), expected, path.get_file())

## Asserts every pixel of the texture at `path` is fully clear or fully opaque, and
## when `palette` is given, that every opaque pixel is one of its colours.
func _assert_opaque_or_clear(path: String, palette: Array[String] = []) -> void:
	var texture: Texture2D = _load_texture(path)
	if texture == null:
		return
	var image: Image = texture.get_image()
	var stray: Array[String] = []
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if is_zero_approx(pixel.a):
				continue
			var off_palette: bool = not palette.is_empty() and not palette.has(pixel.to_html(false))
			if not is_equal_approx(pixel.a, 1.0) or off_palette:
				stray.append("%d,%d %s" % [x, y, pixel.to_html()])
	var kinds: String = "translucent" if palette.is_empty() else "translucent or off-palette"
	assert_eq(stray.size(), 0, "%s: %d %s pixels, first %s" % [path.get_file(), stray.size(), kinds, stray.slice(0, STRAYS_SHOWN)])

#-----------------------------------------------------------------------------
# SIZE
#-----------------------------------------------------------------------------

func test_board_is_its_art_plus_the_baked_shadow() -> void:
	_assert_size(BOARD_PATH, BOARD_SIZE)

func test_body_keeps_its_drawn_size() -> void:
	_assert_size(BODY_PATH, BODY_SIZE)

func test_ball_strips_hold_their_frames() -> void:
	_assert_size(BALL_STRIP_PATH, BALL_STRIP_SIZE)
	_assert_size(BALL_RINGS_PATH, BALL_RINGS_SIZE)

func test_zone_strip_holds_its_six_frames() -> void:
	_assert_size(ZONE_STRIP_PATH, ZONE_STRIP_SIZE)

func test_pellets_are_twelve_px_square() -> void:
	for path: String in PELLET_PATHS:
		_assert_size(path, PELLET_SIZE)

## The pressed state swaps in for the raised one without a resize.
func test_auto_toggle_states_are_the_same_size() -> void:
	_assert_size(AUTO_PATH, AUTO_SIZE)
	_assert_size(AUTO_ON_PATH, AUTO_SIZE)

func test_technique_icons_are_thirty_two_px_square() -> void:
	for path: String in TECH_ICON_PATHS:
		_assert_size(path, TECH_ICON_SIZE)

## Returns the width of the opaque pixels in the `cell`-px frame at `origin`.
func _opaque_width(image: Image, origin: Vector2i, cell: int) -> int:
	var left: int = cell
	var right: int = -1
	for y: int in cell:
		for x: int in cell:
			if image.get_pixel(origin.x + x, origin.y + y).a > 0.0:
				left = mini(left, x)
				right = maxi(right, x)
	return right - left + 1

## Counts the steps round a ring, a degree apart, with no tan pixel between
## `inner` and `outer` px from `centre` in the frame at `origin`.
func _ring_gaps(image: Image, origin: Vector2i, centre: Vector2, inner: float, outer: float) -> int:
	var gaps: int = 0
	for step: int in 360:
		var direction: Vector2 = Vector2.from_angle(TAU * step / 360.0)
		var found: bool = false
		var radius: float = inner
		while radius <= outer and not found:
			var point: Vector2 = Vector2(origin) + centre + direction * radius
			found = image.get_pixel(int(point.x), int(point.y)).to_html(false) == TAN_HTML
			radius += 0.5
		if not found:
			gaps += 1
	return gaps

#-----------------------------------------------------------------------------
# PIXELS
#-----------------------------------------------------------------------------

## Each row of the ball strip is the ball one breath larger: 60, 64 and 68 px.
func test_the_ball_strip_rows_are_the_breathing_sizes() -> void:
	var image: Image = _load_texture(BALL_STRIP_PATH).get_image()
	for row: int in 3:
		assert_eq(_opaque_width(image, Vector2i(0, row * BALL_CELL), BALL_CELL), 60 + 4 * row, "row %d" % row)

## The ready ring grows with the ball, 4 px a breath.
func test_the_ready_ring_grows_with_the_breath() -> void:
	var image: Image = _load_texture(BALL_RINGS_PATH).get_image()
	var base: int = _opaque_width(image, Vector2i(0, 0), RING_CELL)
	assert_eq(_opaque_width(image, Vector2i(2 * RING_CELL, 0), RING_CELL), base + 4, "frame 2")
	assert_eq(_opaque_width(image, Vector2i(3 * RING_CELL, 0), RING_CELL), base + 8, "frame 3")

## The ball's tracking ring and a zone's idle rim are solid tan loops, with no gap
## anywhere round them (checkerboard dots on a circle read as broken).
func test_the_tracking_ring_and_the_idle_rim_are_unbroken() -> void:
	var rings: Image = _load_texture(BALL_RINGS_PATH).get_image()
	assert_eq(_ring_gaps(rings, Vector2i(RING_CELL, 0), Vector2(44.0, 44.0), 33.0, 36.0), 0, "the tracking ring")
	var zones: Image = _load_texture(ZONE_STRIP_PATH).get_image()
	assert_eq(_ring_gaps(zones, Vector2i(0, 0), Vector2(24.0, 24.0), 19.0, 22.0), 0, "the idle rim")

func test_brass_pellet_is_opaque_and_in_its_palette() -> void:
	_assert_opaque_or_clear(PELLET_BRASS_PATH, BRASS_PELLET_PALETTE)

func test_cream_pellet_is_opaque_and_in_its_palette() -> void:
	_assert_opaque_or_clear(PELLET_CREAM_PATH, CREAM_PELLET_PALETTE)

func test_tan_pellet_is_opaque_and_in_its_palette() -> void:
	_assert_opaque_or_clear(PELLET_TAN_PATH, TAN_PELLET_PALETTE)

func test_board_and_body_are_opaque_or_clear() -> void:
	_assert_opaque_or_clear(BOARD_PATH)
	_assert_opaque_or_clear(BODY_PATH)

func test_strips_are_opaque_or_clear() -> void:
	_assert_opaque_or_clear(BALL_STRIP_PATH)
	_assert_opaque_or_clear(BALL_RINGS_PATH)
	_assert_opaque_or_clear(ZONE_STRIP_PATH)

func test_toggles_are_opaque_or_clear() -> void:
	_assert_opaque_or_clear(AUTO_PATH)
	_assert_opaque_or_clear(AUTO_ON_PATH)

func test_technique_icons_are_opaque_or_clear() -> void:
	for path: String in TECH_ICON_PATHS:
		_assert_opaque_or_clear(path)
