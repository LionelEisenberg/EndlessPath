extends GutTest

## Unit tests for the textures PR 1 of the adventure view's lacquer rework
## imports: the screen pieces in assets/ui/lacquer/ with their hard shadows
## baked in, the veil atlas that mirrors the user's forest atlas, and the
## spent encounter glyphs. They are made by the scripts in
## docs/superpowers/mockups/adventure-view-lacquer/gen/ (build_all.py, then
## import_adventure_kit.py).

const LACQUER_DIR: String = "res://assets/ui/lacquer/"
const GLYPH_DIR: String = "res://assets/sprites/adventure/encounter_glyphs/"
const FOREST_DIR: String = "res://assets/sprites/tilemap/hex_tiles/forest/"
const FOREST_ATLAS_PATH: String = FOREST_DIR + "hex_forest_atlas.png"
const VEIL_ATLAS_PATH: String = FOREST_DIR + "hex_forest_veil_atlas_ai.png"

## One tile of the forest atlas (the tileset's region size). The atlas is a
## grid of these, 23 of them used.
const FOREST_CELL: Vector2i = Vector2i(164, 190)

## Every screen piece with its size, shadow included: the tech dock and the
## plain board carry a 4 px shadow, the slot and keycap 2 px, and each of the
## four coins in the marker tokens strip its own 2 px. The other pieces are
## recessed or inset, so they cast none.
const SCREEN_PIECES: Dictionary[String, Vector2i] = {
	"lacquer_tdock_ai.png": Vector2i(480, 140),
	"lacquer_slot_ai.png": Vector2i(82, 82),
	"lacquer_keycap_ai.png": Vector2i(24, 24),
	"lacquer_cast_tray_ai.png": Vector2i(476, 44),
	"lacquer_timer_ai.png": Vector2i(88, 36),
	"lacquer_timer_low_ai.png": Vector2i(88, 36),
	"lacquer_board9_ai.png": Vector2i(28, 28),
	"lacquer_socket_buff_ai.png": Vector2i(40, 40),
	"lacquer_socket_glyph_ai.png": Vector2i(48, 48),
	"lacquer_mini_health_ai.png": Vector2i(16, 16),
	"lacquer_mini_stamina_ai.png": Vector2i(16, 16),
	"lacquer_mini_hourglass_ai.png": Vector2i(16, 16),
	"lacquer_orb_health_ai.png": Vector2i(80, 80),
	"lacquer_marker_tokens_ai.png": Vector2i(216, 54),
	"lacquer_rod_stamina_empty_ai.png": Vector2i(240, 10),
	"lacquer_rod_stamina_full_ai.png": Vector2i(240, 10),
	"lacquer_rod_stamina_end_ai.png": Vector2i(2, 10),
	"lacquer_rod_cast_empty_ai.png": Vector2i(240, 10),
	"lacquer_rod_cast_full_ai.png": Vector2i(240, 10),
	"lacquer_rod_cast_end_ai.png": Vector2i(2, 10),
}

## The uncharted veil's ramp, dark to light, and the two tans of the dotted rim
## laid over it. A veiled tile uses nothing else.
const VEIL_COLOURS: Array[Color] = [
	Color("#0B1211"), Color("#16211F"), Color("#1C2927"), Color("#243431"), Color("#2D3F3B"),
	Color("#A89070"), Color("#7A654C"),
]

## The encounter kinds that have a spent (cleared) glyph for the coin.
const SPENT_GLYPH_KINDS: Array[String] = ["combat", "elite", "rest", "boss", "treasure", "trap"]

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

## Two pixels are one colour when they match, or when both are fully clear
## (the import may leave different RGB under alpha 0).
func _same_colour(a: Color, b: Color) -> bool:
	if is_zero_approx(a.a) and is_zero_approx(b.a):
		return true
	return a.is_equal_approx(b)

## How many 2x2 blocks of the image, counted from its top-left corner, are not
## one colour. The image must have an even width and height.
func _count_ragged_blocks(image: Image) -> int:
	var ragged: int = 0
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			var corner: Color = image.get_pixel(x, y)
			if not (_same_colour(corner, image.get_pixel(x + 1, y))
					and _same_colour(corner, image.get_pixel(x, y + 1))
					and _same_colour(corner, image.get_pixel(x + 1, y + 1))):
				ragged += 1
	return ragged

#-----------------------------------------------------------------------------
# SCREEN PIECES
#-----------------------------------------------------------------------------

func test_screen_pieces_have_their_sizes() -> void:
	for file_name: String in SCREEN_PIECES:
		var image: Image = _load_image(LACQUER_DIR + file_name)
		if image == null:
			continue
		assert_eq(image.get_size(), SCREEN_PIECES[file_name], "%s: size with its shadow baked in" % file_name)

func test_screen_pieces_sit_on_the_2x_grid() -> void:
	for file_name: String in SCREEN_PIECES:
		var image: Image = _load_image(LACQUER_DIR + file_name)
		if image == null:
			continue
		if image.get_width() % 2 != 0 or image.get_height() % 2 != 0:
			fail_test("%s is %s: not a whole number of 2x2 blocks" % [file_name, image.get_size()])
			continue
		assert_eq(_count_ragged_blocks(image), 0, "%s: 2x2 blocks that are not one colour" % file_name)

#-----------------------------------------------------------------------------
# VEIL ATLAS
#-----------------------------------------------------------------------------

## The veil atlas keeps the forest atlas' layout, so a HexForestAtlas.pick()
## cell holds a tile in both, and the unused cell stays empty in both.
func test_veil_atlas_matches_the_forest_atlas() -> void:
	var forest: Image = _load_image(FOREST_ATLAS_PATH)
	var veil: Image = _load_image(VEIL_ATLAS_PATH)
	if forest == null or veil == null:
		return
	assert_eq(veil.get_size(), forest.get_size(), "the veil atlas is the forest atlas' size")
	@warning_ignore("integer_division")
	var rows: int = forest.get_height() / FOREST_CELL.y
	@warning_ignore("integer_division")
	var columns: int = forest.get_width() / FOREST_CELL.x
	for row: int in rows:
		for column: int in columns:
			var cell := Rect2i(column * FOREST_CELL.x, row * FOREST_CELL.y, FOREST_CELL.x, FOREST_CELL.y)
			assert_eq(veil.get_region(cell).get_used_rect().has_area(), forest.get_region(cell).get_used_rect().has_area(),
				"cell (%d, %d) is filled in the veil atlas exactly when it is in the forest atlas" % [column, row])

func test_veil_atlas_uses_only_veil_colours() -> void:
	var image: Image = _load_image(VEIL_ATLAS_PATH)
	if image == null:
		return
	var palette: Dictionary = {}
	for colour: Color in VEIL_COLOURS:
		palette[colour.to_rgba32()] = true
	var stray: Dictionary = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if is_zero_approx(pixel.a):
				continue
			if not palette.has(pixel.to_rgba32()):
				stray[pixel.to_html()] = int(stray.get(pixel.to_html(), 0)) + 1
	assert_eq(stray.size(), 0, "every visible pixel is an opaque veil colour, stray colours and how many: %s" % [stray])

#-----------------------------------------------------------------------------
# SPENT GLYPHS
#-----------------------------------------------------------------------------

func test_spent_glyphs_exist() -> void:
	for kind: String in SPENT_GLYPH_KINDS:
		var path: String = GLYPH_DIR + "adv_glyph_%s_spent_light_ai.png" % kind
		var image: Image = _load_image(path)
		if image == null:
			continue
		# The trap glyph is 32x32 native art; every other glyph's first frame is 64x64.
		var expected: Vector2i = Vector2i(32, 32) if kind == "trap" else Vector2i(64, 64)
		assert_eq(image.get_size(), expected, "%s: the size of its glyph's frame" % kind)
		assert_true(image.get_used_rect().has_area(), "%s: not blank" % kind)
