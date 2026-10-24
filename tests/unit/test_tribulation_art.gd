extends GutTest

## Unit tests for the Tribulation's lacquer art, the textures the Tribulation card
## and board load by path. They are drawn by
## docs/superpowers/mockups/tribulation-lacquer/gen/kit_tribulation.py. Each texture
## has the size its scene is laid out for, and its art is opaque or clear and keeps
## to its palette: no halo, glow or soft edge (docs/STYLE_GUIDE.md rules 3 and 9).
## The ring keeps to the band rule the stage draws its spheres by, the cores grow
## by their radius, the board's middle stretches without a seam, and the card's rod
## is the goal rod less its flat middle.

const TRIBULATION_DIR: String = "res://assets/ui/lacquer/tribulation/"
const BOARD_PATH: String = TRIBULATION_DIR + "lacquer_trib_board9_ai.png"
const RING_STRIP_PATH: String = TRIBULATION_DIR + "lacquer_trib_ring_strip_ai.png"
const CORE_STRIP_PATH: String = TRIBULATION_DIR + "lacquer_trib_core_strip_ai.png"
const PIP_STRIP_PATH: String = TRIBULATION_DIR + "lacquer_trib_pip_strip_ai.png"
const ROD_CORE_EMPTY_PATH: String = "res://assets/ui/lacquer/lacquer_rod_core_empty_ai.png"
const ROD_CORE_FULL_PATH: String = "res://assets/ui/lacquer/lacquer_rod_core_full_ai.png"
const ROD_GOAL_EMPTY_PATH: String = "res://assets/ui/lacquer/lacquer_rod_goal_empty_ai.png"
const ROD_GOAL_FULL_PATH: String = "res://assets/ui/lacquer/lacquer_rod_goal_full_ai.png"
const DRAWER_FACE_PATH: String = "res://assets/ui/lacquer/lacquer_drawer9_ai.png"
const BOARD_STYLE_PATH: String = "res://assets/styleboxes/lacquer/trib_board9.tres"
const DRAWER_STYLE_PATH: String = "res://assets/styleboxes/lacquer/drawer9.tres"

## Every file with its size: the 160 px board plus its 4 px shadow, baked on the
## right and bottom; two ring frames of 272; 4 x 6 core frames of 128; two pips of
## 20; the goal rod's 280 px less the 128 px of its flat middle.
const SIZES: Dictionary[String, Vector2i] = {
	BOARD_PATH: Vector2i(164, 164),
	RING_STRIP_PATH: Vector2i(544, 272),
	CORE_STRIP_PATH: Vector2i(512, 768),
	PIP_STRIP_PATH: Vector2i(40, 20),
	ROD_CORE_EMPTY_PATH: Vector2i(152, 10),
	ROD_CORE_FULL_PATH: Vector2i(152, 10),
}

## The only colours each strip may use. The ring: ink and the brass ramp. The pips:
## the carved socket and the vermilion chip. The cores: the Madra ramp and the
## crack's vermilion (whole and cracked), the carved palette and the tan rim
## (spent), the brass ramp (passed), and the ink outline round them all.
const RING_PALETTE: Array[String] = ["150909", "d4a84a", "a66834", "f0e8d8"]
const PIP_PALETTE: Array[String] = ["150909", "110707", "612b2b", "692f2f", "a83c30", "7e2a22", "d4a84a"]
const CORE_PALETTE: Array[String] = [
	"150909", "110707", "e8f6fd", "bbd5e7", "849be4", "1c2f60", "16283e", "a83c30", "7e2a22",
	"230f0f", "462020", "612b2b", "a89070", "7a654c", "f0e8d8", "d4a84a", "a66834", "341e0e",
]

## One ring frame (136 art px) and its centre, the frame's middle corner.
const RING_CELL: int = 272
const RING_FRAMES: int = 2
const RING_CENTRE: Vector2 = Vector2(136, 136)
## The ring's band, ink at [63, 64), brass at [64, 66) and ink at [66, 67) art px,
## in screen px from the centre: [126, 134), with 0.1 px to spare.
const RING_INNER_PX: float = 126.0
const RING_OUTER_PX: float = 134.0
const RING_SPARE_PX: float = 0.1

## One core frame, 64 art px.
const CORE_CELL: int = 128
## Each column's core across, its ink outline included: 2 (r + 1) art px for the
## radii 17, 21, 25 and 29, at 2 px an art px.
const CORE_WIDTHS: Array[int] = [72, 88, 104, 120]

## The board's 9-slice middle in px: 28 art px of corner on every side (the right
## and bottom texture margins add the 4 px shadow), so the stretch spans [56, 104).
const BOARD_MIDDLE_FROM: int = 56
const BOARD_MIDDLE_TO: int = 104

## The card's rod keeps the goal rod's first and last 76 px and drops the 128 px
## of flat middle between them.
const ROD_KEPT: int = 76
const GOAL_ROD_RIGHT_FROM: int = 204
const ROD_HEIGHT: int = 10

## The styleboxes' margins, left, top, right and bottom. The board's slices are its
## 28 art px corners, plus the shadow on the right and bottom; the drawer face's
## are its 2 px rim and outline, plus its 2 px shadow.
const BOARD_TEXTURE_MARGINS: Array[float] = [56.0, 56.0, 60.0, 60.0]
const BOARD_CONTENT_MARGINS: Array[float] = [24.0, 20.0, 28.0, 24.0]
const DRAWER_TEXTURE_MARGINS: Array[float] = [4.0, 4.0, 6.0, 6.0]
const DRAWER_CONTENT_MARGINS: Array[float] = [20.0, 16.0, 22.0, 18.0]
const SIDES: Array[Side] = [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]

## How many stray pixels a failure lists. The core strip has over a third of a
## million pixels, so a full list would bury the report.
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

## The pixels of the imported texture at `path`, or null (after a failed assert)
## when it is missing.
func _load_image(path: String) -> Image:
	var texture: Texture2D = _load_texture(path)
	if texture == null:
		return null
	return texture.get_image()

## Asserts the texture at `path` is `expected` px, the size its scene is laid out for.
func _assert_size(path: String, expected: Vector2i) -> void:
	var texture: Texture2D = _load_texture(path)
	if texture == null:
		return
	assert_eq(Vector2i(texture.get_width(), texture.get_height()), expected, path.get_file())

## Asserts every pixel of the texture at `path` is fully clear or fully opaque, and
## when `palette` is given, that every opaque pixel is one of its colours.
func _assert_opaque_or_clear(path: String, palette: Array[String] = []) -> void:
	var image: Image = _load_image(path)
	if image == null:
		return
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

## The centre of the art pixel (the 2 x 2 block) that holds the screen pixel at
## (x, y). The band rule measures a cell from its centre, as the stage's 2 px cells do.
func _art_pixel_centre(x: int, y: int) -> Vector2:
	return Vector2(x - x % 2 + 1, y - y % 2 + 1)

## Two pixels are one colour when they match, or when both are fully clear (the
## import may leave different RGB under alpha 0).
func _same_colour(a: Color, b: Color) -> bool:
	if is_zero_approx(a.a) and is_zero_approx(b.a):
		return true
	return a.is_equal_approx(b)

## The RGBA8 bytes of `rect` in `image`, so two images compare whatever format
## their import kept.
func _region_bytes(image: Image, rect: Rect2i) -> PackedByteArray:
	var region: Image = image.get_region(rect)
	region.convert(Image.FORMAT_RGBA8)
	return region.get_data()

## Asserts the stylebox at `path` is a StyleBoxTexture over `texture_path` with
## these texture and content margins (left, top, right, bottom).
func _assert_stylebox(path: String, texture_path: String, texture_margins: Array[float], content_margins: Array[float]) -> void:
	var style: StyleBoxTexture = null
	if ResourceLoader.exists(path):
		style = load(path) as StyleBoxTexture
	assert_not_null(style, "%s loads as a StyleBoxTexture" % path.get_file())
	if style == null:
		return
	assert_not_null(style.texture, "%s has a texture" % path.get_file())
	if style.texture != null:
		assert_eq(style.texture.resource_path, texture_path, "%s texture" % path.get_file())
	for i: int in SIDES.size():
		assert_eq(style.get_texture_margin(SIDES[i]), texture_margins[i], "%s texture margin %d" % [path.get_file(), SIDES[i]])
		assert_eq(style.get_content_margin(SIDES[i]), content_margins[i], "%s content margin %d" % [path.get_file(), SIDES[i]])

#-----------------------------------------------------------------------------
# SIZE AND PALETTE
#-----------------------------------------------------------------------------

## Each texture has the size its scene is laid out for.
func test_sizes() -> void:
	for path: String in SIZES:
		_assert_size(path, SIZES[path])

## Every texture is opaque or clear, and the strips keep to their palettes.
func test_opaque_or_clear() -> void:
	_assert_opaque_or_clear(BOARD_PATH)
	_assert_opaque_or_clear(RING_STRIP_PATH, RING_PALETTE)
	_assert_opaque_or_clear(CORE_STRIP_PATH, CORE_PALETTE)
	_assert_opaque_or_clear(PIP_STRIP_PATH, PIP_PALETTE)
	_assert_opaque_or_clear(ROD_CORE_EMPTY_PATH)
	_assert_opaque_or_clear(ROD_CORE_FULL_PATH)

#-----------------------------------------------------------------------------
# GEOMETRY
#-----------------------------------------------------------------------------

## The ring lies on the band rule's [63, 67) art px, the ring the stage's spheres
## cross at R = 130 px: in both frames every opaque pixel lies 125.9 to 134.1 px from
## the centre, measured from its art pixel's centre, and no pixel of the band is clear.
func test_ring_band() -> void:
	var image: Image = _load_image(RING_STRIP_PATH)
	if image == null:
		return
	var stray: Array[String] = []
	var holes: Array[String] = []
	for frame: int in RING_FRAMES:
		for y: int in RING_CELL:
			for x: int in RING_CELL:
				var distance: float = _art_pixel_centre(x, y).distance_to(RING_CENTRE)
				var opaque: bool = image.get_pixel(frame * RING_CELL + x, y).a > 0.0
				var in_band: bool = distance >= RING_INNER_PX and distance < RING_OUTER_PX
				if opaque and (distance < RING_INNER_PX - RING_SPARE_PX or distance > RING_OUTER_PX + RING_SPARE_PX):
					stray.append("frame %d: %d,%d at %.2f px" % [frame, x, y, distance])
				elif in_band and not opaque:
					holes.append("frame %d: %d,%d at %.2f px" % [frame, x, y, distance])
	assert_eq(stray.size(), 0, "%d pixels off the band, first %s" % [stray.size(), stray.slice(0, STRAYS_SHOWN)])
	assert_eq(holes.size(), 0, "%d clear pixels in the band, first %s" % [holes.size(), holes.slice(0, STRAYS_SHOWN)])

## Each column of the whole core is one core radius larger: 72, 88, 104 and 120 px
## across with the outline.
func test_core_sizes() -> void:
	var image: Image = _load_image(CORE_STRIP_PATH)
	if image == null:
		return
	for column: int in CORE_WIDTHS.size():
		assert_eq(_opaque_width(image, Vector2i(column * CORE_CELL, 0), CORE_CELL), CORE_WIDTHS[column], "column %d" % column)

## The board's 9-slice middle is uniform, so the slices stretch on the grid without a
## seam: across [56, 104) every row is one colour, and down [56, 104) every column is.
func test_board_middle_is_uniform() -> void:
	var image: Image = _load_image(BOARD_PATH)
	if image == null:
		return
	var rows: Array[String] = []
	for y: int in image.get_height():
		var first: Color = image.get_pixel(BOARD_MIDDLE_FROM, y)
		for x: int in range(BOARD_MIDDLE_FROM, BOARD_MIDDLE_TO):
			if not _same_colour(image.get_pixel(x, y), first):
				rows.append("%d,%d" % [x, y])
	var columns: Array[String] = []
	for x: int in image.get_width():
		var first: Color = image.get_pixel(x, BOARD_MIDDLE_FROM)
		for y: int in range(BOARD_MIDDLE_FROM, BOARD_MIDDLE_TO):
			if not _same_colour(image.get_pixel(x, y), first):
				columns.append("%d,%d" % [x, y])
	assert_eq(rows.size(), 0, "%d pixels break a row of the middle, first %s" % [rows.size(), rows.slice(0, STRAYS_SHOWN)])
	assert_eq(columns.size(), 0, "%d pixels break a column of the middle, first %s" % [columns.size(), columns.slice(0, STRAYS_SHOWN)])

## Each core rod is the goal rod with its flat middle cut out: the goal rod's first
## 76 px, then its last 76 (from x 204), so the card's rod has the goal rod's ends.
func test_core_rod_is_the_goal_rod_less_its_middle() -> void:
	var pairs: Dictionary[String, String] = {
		ROD_CORE_EMPTY_PATH: ROD_GOAL_EMPTY_PATH,
		ROD_CORE_FULL_PATH: ROD_GOAL_FULL_PATH,
	}
	for core_path: String in pairs:
		var core: Image = _load_image(core_path)
		var goal: Image = _load_image(pairs[core_path])
		if core == null or goal == null:
			continue
		var left := Rect2i(0, 0, ROD_KEPT, ROD_HEIGHT)
		assert_eq(_region_bytes(core, left), _region_bytes(goal, left), "%s: the goal rod's first %d px" % [core_path.get_file(), ROD_KEPT])
		assert_eq(_region_bytes(core, Rect2i(ROD_KEPT, 0, ROD_KEPT, ROD_HEIGHT)),
				_region_bytes(goal, Rect2i(GOAL_ROD_RIGHT_FROM, 0, ROD_KEPT, ROD_HEIGHT)),
				"%s: the goal rod's last %d px" % [core_path.get_file(), ROD_KEPT])

#-----------------------------------------------------------------------------
# STYLEBOXES
#-----------------------------------------------------------------------------

## The board's stylebox slices the strapped board at its corners, and the drawer's
## slices the drawer face at its rim; both keep their baked shadows out of the stretch.
func test_styleboxes() -> void:
	_assert_stylebox(BOARD_STYLE_PATH, BOARD_PATH, BOARD_TEXTURE_MARGINS, BOARD_CONTENT_MARGINS)
	_assert_stylebox(DRAWER_STYLE_PATH, DRAWER_FACE_PATH, DRAWER_TEXTURE_MARGINS, DRAWER_CONTENT_MARGINS)
