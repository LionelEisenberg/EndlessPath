extends GutTest

## Unit tests for the adventure map's heavier current-hex rim
## (assets/ui/lacquer/map/lacquer_hex_current_heavy_ai.png) against the zone
## map's (lacquer_hex_current_ai.png), which it replaces on the adventure map
## only. The zone rim is four rings around the hex: cream and brass, brass, ink,
## a lacquer collar. The heavy one has two more px of brass: rings 1 to 4 brass,
## ring 5 ink, ring 6 the collar, the first two rings just inside the hex's edge
## so that the ink and the collar stay where the zone rim's are and the file
## stays the tile's size. Made by docs/superpowers/mockups/adventure-view-lacquer/gen/hex_rim.py
## (build_all.py, then import_adventure_kit.py).

const HEAVY_PATH: String = "res://assets/ui/lacquer/map/lacquer_hex_current_heavy_ai.png"
const ZONE_PATH: String = "res://assets/ui/lacquer/map/lacquer_hex_current_ai.png"

## One tile of the forest atlas, which the rim lies over.
const TILE_SIZE: Vector2i = Vector2i(164, 190)

## The kit's colours a rim uses, by role.
const CREAM: Color = Color("#F0E8D8")
const BRASS: Color = Color("#D4A84A")
const BRASS_SHADE: Color = Color("#A66834")
const INK: Color = Color("#150909")
const COLLAR_LIT: Color = Color("#692F2F")
const COLLAR: Color = Color("#2C1414")

## The column through the hex's top and bottom corners and the row through its
## flat sides' middle, where the rings are easiest to read.
const MIDDLE_COLUMN: int = 81
const MIDDLE_ROW: int = 95

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The pixels of a texture under res://, or null (after a failed assert) when
## the file is missing or was never imported.
func _load_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		fail_test("%s is missing or not imported" % path)
		return null
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		fail_test("%s did not load as a texture" % path)
		return null
	return texture.get_image()

func _is_brass(pixel: Color) -> bool:
	return pixel.a > 0.0 and (pixel.is_equal_approx(CREAM) or pixel.is_equal_approx(BRASS) or pixel.is_equal_approx(BRASS_SHADE))

func _is_ink_or_collar(pixel: Color) -> bool:
	return pixel.a > 0.0 and (pixel.is_equal_approx(INK) or pixel.is_equal_approx(COLLAR_LIT) or pixel.is_equal_approx(COLLAR))

## How many brass pixels the image has in `count` pixels from `start` along
## `step`: the brass of one side of the rim.
func _brass_along(image: Image, start: Vector2i, step: Vector2i, count: int) -> int:
	var brass: int = 0
	for index: int in count:
		if _is_brass(image.get_pixelv(start + step * index)):
			brass += 1
	return brass

#-----------------------------------------------------------------------------
# THE FILE
#-----------------------------------------------------------------------------

func test_heavy_rim_is_the_tiles_size() -> void:
	var heavy: Image = _load_image(HEAVY_PATH)
	var zone: Image = _load_image(ZONE_PATH)
	if heavy == null or zone == null:
		return
	assert_eq(heavy.get_size(), TILE_SIZE, "164x190: it lies on a hex as the zone rim does")
	assert_eq(zone.get_size(), TILE_SIZE, "precondition: the zone rim is the tile's size")

func test_heavy_rim_uses_only_the_kits_rim_colours() -> void:
	var image: Image = _load_image(HEAVY_PATH)
	if image == null:
		return
	var palette: Dictionary = {}
	for colour: Color in [CREAM, BRASS, BRASS_SHADE, INK, COLLAR_LIT, COLLAR]:
		palette[colour.to_rgba32()] = true
	var stray: Dictionary = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if is_zero_approx(pixel.a):
				continue
			if not (is_equal_approx(pixel.a, 1.0) and palette.has(pixel.to_rgba32())):
				stray[pixel.to_html()] = int(stray.get(pixel.to_html(), 0)) + 1
	assert_eq(stray.size(), 0, "every visible pixel is an opaque colour of the zone rim, stray colours and how many: %s" % [stray])

#-----------------------------------------------------------------------------
# THE RINGS
#-----------------------------------------------------------------------------

## The ink and the collar are the zone rim's, pixel for pixel: the heavy rim
## reaches no further out than the zone rim does, so it never covers more of the
## grout than the zone rim does.
func test_the_ink_and_the_collar_lie_where_the_zone_rims_do() -> void:
	var heavy: Image = _load_image(HEAVY_PATH)
	var zone: Image = _load_image(ZONE_PATH)
	if heavy == null or zone == null:
		return
	var missing: int = 0
	var extra: int = 0
	var zone_outer: int = 0
	for y: int in TILE_SIZE.y:
		for x: int in TILE_SIZE.x:
			var zone_pixel: Color = zone.get_pixel(x, y)
			var heavy_pixel: Color = heavy.get_pixel(x, y)
			if _is_ink_or_collar(zone_pixel):
				zone_outer += 1
				if not (_is_ink_or_collar(heavy_pixel) and heavy_pixel.is_equal_approx(zone_pixel)):
					missing += 1
			elif _is_ink_or_collar(heavy_pixel):
				extra += 1
	assert_gt(zone_outer, 0, "precondition: the zone rim has an ink ring and a collar")
	assert_eq(missing, 0, "every ink and collar pixel of the zone rim is the same in the heavy rim")
	assert_eq(extra, 0, "and the heavy rim has no ink or collar anywhere else")

## Two more rings of brass on every side. On the flat sides the rings run
## straight, so along the row through their middle each side has the zone rim's
## brass plus exactly two px. At the top and bottom corners the rings run
## diagonally and the Chebyshev rings (the kit's, as the zone rim's) are deeper
## along the column through the corner, so there it has at least two more.
func test_the_brass_is_two_rings_heavier_on_every_side() -> void:
	var heavy: Image = _load_image(HEAVY_PATH)
	var zone: Image = _load_image(ZONE_PATH)
	if heavy == null or zone == null:
		return
	@warning_ignore("integer_division")
	var half_row: int = TILE_SIZE.x / 2
	@warning_ignore("integer_division")
	var half_column: int = TILE_SIZE.y / 2
	var flat_sides: Dictionary = {
		"left": [Vector2i(0, MIDDLE_ROW), Vector2i(1, 0), half_row],
		"right": [Vector2i(TILE_SIZE.x - 1, MIDDLE_ROW), Vector2i(-1, 0), half_row],
	}
	for side: String in flat_sides:
		var line: Array = flat_sides[side]
		var zone_brass: int = _brass_along(zone, line[0], line[1], line[2])
		var heavy_brass: int = _brass_along(heavy, line[0], line[1], line[2])
		assert_eq(zone_brass, 2, "precondition: the zone rim has 2 px of brass on its %s side" % side)
		assert_eq(heavy_brass, zone_brass + 2, "the heavy rim has exactly 2 px more on its %s side" % side)
	var corners: Dictionary = {
		"top": [Vector2i(MIDDLE_COLUMN, 0), Vector2i(0, 1), half_column],
		"bottom": [Vector2i(MIDDLE_COLUMN, TILE_SIZE.y - 1), Vector2i(0, -1), half_column],
	}
	for corner: String in corners:
		var line: Array = corners[corner]
		var zone_brass: int = _brass_along(zone, line[0], line[1], line[2])
		var heavy_brass: int = _brass_along(heavy, line[0], line[1], line[2])
		assert_eq(zone_brass, 2, "precondition: the zone rim has 2 px of brass at its %s corner" % corner)
		assert_gte(heavy_brass, zone_brass + 2, "the heavy rim has at least 2 px more at its %s corner" % corner)

## Counted from the outside along the middle row of the left (lit) side: the
## collar, the ink, then three rings of brass and the cream highlight inside
## them, so that the highlight is the band's inner edge, as on the zone rim.
func test_the_lit_side_runs_collar_ink_brass_then_the_cream_highlight() -> void:
	var image: Image = _load_image(HEAVY_PATH)
	if image == null:
		return
	var expected: Array[Color] = [COLLAR_LIT, INK, BRASS, BRASS, BRASS, CREAM]
	for index: int in expected.size():
		assert_true(image.get_pixel(index, MIDDLE_ROW).is_equal_approx(expected[index]),
			"pixel %d in from the left edge is %s, not %s" % [index, expected[index].to_html(), image.get_pixel(index, MIDDLE_ROW).to_html()])
	assert_true(is_zero_approx(image.get_pixel(expected.size(), MIDDLE_ROW).a), "inside the highlight the tile shows")

## The shadow side (right): the shaded brass four rings deep, the ink and the
## collar.
func test_the_shadow_side_runs_shaded_brass_ink_collar() -> void:
	var image: Image = _load_image(HEAVY_PATH)
	if image == null:
		return
	var right: int = TILE_SIZE.x - 1
	var expected: Array[Color] = [COLLAR, INK, BRASS_SHADE, BRASS_SHADE, BRASS_SHADE, BRASS_SHADE]
	for index: int in expected.size():
		assert_true(image.get_pixel(right - index, MIDDLE_ROW).is_equal_approx(expected[index]),
			"pixel %d in from the right edge is %s, not %s" % [index, expected[index].to_html(), image.get_pixel(right - index, MIDDLE_ROW).to_html()])
	assert_true(is_zero_approx(image.get_pixel(right - expected.size(), MIDDLE_ROW).a), "inside the brass the tile shows")
