extends GutTest

## The pressed page pieces (spec: Pieces) and the book theme's pressed variants.

const PRESSED_DIR: String = "res://assets/sprites/ui/book/pressed/"
const SIZES: Dictionary[String, Vector2i] = {
	"pressed_slot_deep_ai.png": Vector2i(72, 72), "pressed_slot_shallow_ai.png": Vector2i(72, 72),
	"pressed_page_deep_ai.png": Vector2i(28, 28), "pressed_page_shallow_ai.png": Vector2i(28, 28),
	"pressed_panel_ai.png": Vector2i(32, 32), "pressed_lozenge_ai.png": Vector2i(24, 26),
	"pressed_rule_ai.png": Vector2i(8, 4), "pressed_groove_ai.png": Vector2i(10, 24),
	"pressed_thumb_ai.png": Vector2i(4, 8), "title_ornament_ai.png": Vector2i(272, 14),
	"printer_marks_ai.png": Vector2i(32, 32), "paper_tag_ai.png": Vector2i(12, 20),
	"seal_ai.png": Vector2i(66, 26), "tick_box_ai.png": Vector2i(22, 22),
	"tick_box_ticked_ai.png": Vector2i(22, 22), "printed_cross_ai.png": Vector2i(28, 28),
	"gear_plate_ai.png": Vector2i(468, 268),
}
const ICONS: Array[String] = [
	"res://assets/sprites/items/materials/spirit_fern_ai.png",
	"res://assets/sprites/items/materials/dewdrop_tear_ai.png",
	"res://assets/sprites/items/quest_items/refugee_camp_map_ai.png",
]

func _image(file: String) -> Image:
	return (load(PRESSED_DIR + file) as Texture2D).get_image()

func test_pressed_textures_have_their_sizes() -> void:
	for file: String in SIZES:
		var texture: Texture2D = load(PRESSED_DIR + file) as Texture2D
		assert_not_null(texture, file)
		assert_eq(Vector2i(texture.get_size()), SIZES[file], file)

func test_slot_walls_and_floors_use_the_pressed_palette() -> void:
	var deep: Image = _image("pressed_slot_deep_ai.png")
	assert_eq(deep.get_pixel(0, 36).to_html(false), "b9996f", "left wall, first shadow step")
	assert_eq(deep.get_pixel(2, 36).to_html(false), "d3b98f", "left wall, second step")
	assert_eq(deep.get_pixel(71, 36).to_html(false), "fbf1de", "right wall catches the light")
	assert_eq(deep.get_pixel(36, 36).to_html(false), "e7cfa6", "owned floor")
	assert_eq(deep.get_pixel(0, 0).a, 0.0, "corners are cut")
	var shallow: Image = _image("pressed_slot_shallow_ai.png")
	assert_eq(shallow.get_pixel(36, 36).to_html(false), "efdcbb", "empty floor")
	assert_eq(shallow.get_pixel(2, 36).to_html(false), "efdcbb", "one shadow step only")

func test_marks_leave_their_middle_clear() -> void:
	var marks: Image = _image("printer_marks_ai.png")
	assert_eq(marks.get_pixel(16, 16).a, 0.0)
	assert_eq(marks.get_pixel(0, 0).to_html(false), "a83c30")

func test_seal_and_tag_colours() -> void:
	assert_eq(_image("seal_ai.png").get_pixel(32, 12).to_html(false), "a83c30")
	assert_eq(_image("paper_tag_ai.png").get_pixel(6, 10).to_html(false), "f7e6ca")

func test_placeholder_item_icons_are_64_px() -> void:
	for path: String in ICONS:
		assert_eq(Vector2i((load(path) as Texture2D).get_size()), Vector2i(64, 64), path)
