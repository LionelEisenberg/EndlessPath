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

#-----------------------------------------------------------------------------
# BOOK THEME VARIANTS
#-----------------------------------------------------------------------------

const BOOK_THEME: Theme = preload("res://assets/themes/book_theme.tres")
const YATRA: String = "res://assets/fonts/YatraOne-Regular.ttf"
const EULJIRO: String = "res://assets/fonts/BMEULJIROTTF.ttf"
const STYLEBOX_DIR: String = "res://assets/styleboxes/book/"

## [variant, font file, size, colour hex, line pitch] (plan Task 2 table).
var _variants: Array[Array] = [
	[&"LabelBookPageTitle", YATRA, 38, "33261a", 44], [&"LabelBookItemName", YATRA, 30, "33261a", 34],
	[&"LabelBookQuestName", YATRA, 26, "33261a", 30], [&"LabelBookDropCap", YATRA, 46, "a83c30", 52],
	[&"LabelBookInk", EULJIRO, 18, "3b2a20", 26], [&"LabelBookInkDark", EULJIRO, 18, "33261a", 26],
	[&"LabelBookDetail", EULJIRO, 15, "765a43", 20], [&"LabelBookDetailDark", EULJIRO, 15, "33261a", 20],
	[&"LabelBookFlavor", EULJIRO, 16, "765a43", 22], [&"LabelBookStep", EULJIRO, 16, "3b2a20", 22],
	[&"LabelBookCount", EULJIRO, 20, "33261a", 24], [&"LabelBookCaps", EULJIRO, 13, "765a43", 18],
	[&"LabelBookTag", EULJIRO, 13, "33261a", 18], [&"LabelBookSeal", EULJIRO, 13, "f0e8d8", 18],
	[&"LabelBookFilter", EULJIRO, 13, "765a43", 18], [&"LabelBookFilterOn", EULJIRO, 13, "33261a", 18],
]

func test_pressed_label_variants() -> void:
	for row: Array in _variants:
		var font: Font = BOOK_THEME.get_font(&"font", row[0])
		var base: Font = (font as FontVariation).base_font if font is FontVariation else font
		assert_eq(base.resource_path, row[1], str(row[0]))
		assert_eq(BOOK_THEME.get_font_size(&"font_size", row[0]), row[2], str(row[0]))
		assert_eq(BOOK_THEME.get_color(&"font_color", row[0]).to_html(false), row[3], str(row[0]))
		var pitch: int = roundi(font.get_height(row[2])) + BOOK_THEME.get_constant(&"line_spacing", row[0])
		assert_eq(pitch, row[4], "%s line pitch" % row[0])

func test_capital_variants_space_their_letters() -> void:
	for variant: StringName in [&"LabelBookCaps", &"LabelBookSeal", &"LabelBookFilter", &"LabelBookFilterOn"]:
		var font: FontVariation = BOOK_THEME.get_font(&"font", variant) as FontVariation
		assert_not_null(font, str(variant))
		assert_eq(font.spacing_glyph, 1, str(variant))

func test_variants_the_other_books_use_are_unchanged() -> void:
	assert_eq(BOOK_THEME.get_font_size(&"font_size", &"LabelBookBody"), 20)
	assert_eq(BOOK_THEME.get_font_size(&"font_size", &"LabelBookTitle"), 28)
	assert_eq(BOOK_THEME.get_font_size(&"font_size", &"LabelBookMuted"), 16)
	assert_eq(BOOK_THEME.get_color(&"font_color", &"LabelBookMuted").to_html(false), "7d5f47")

func test_pressed_styleboxes() -> void:
	var panel: StyleBoxTexture = load(STYLEBOX_DIR + "pressed_panel.tres")
	assert_eq(panel.texture_margin_left, 8.0)
	assert_eq(panel.content_margin_top, 16.0)
	var marks: StyleBoxTexture = load(STYLEBOX_DIR + "printer_marks.tres")
	assert_false(marks.draw_center)
	assert_eq(marks.texture_margin_left, 10.0)
	assert_eq(BOOK_THEME.get_stylebox(&"panel", &"PanelPressed"), panel)
	assert_eq(BOOK_THEME.get_stylebox(&"panel", &"PanelPrinterMarks"), marks)
	assert_eq(BOOK_THEME.get_stylebox(&"normal", &"LabelBookTag").resource_path, STYLEBOX_DIR + "paper_tag.tres")
	assert_eq(BOOK_THEME.get_stylebox(&"normal", &"LabelBookFilterOn").resource_path, STYLEBOX_DIR + "pressed_lozenge.tres")
	assert_true(BOOK_THEME.get_stylebox(&"normal", &"LabelBookFilter") is StyleBoxEmpty)
	assert_eq(BOOK_THEME.get_constant(&"separation", &"HSeparatorPressed"), 4)

func test_text_reads_on_paper_and_panels() -> void:
	var paper := Color("#F7E6CA")
	var panel := Color("#EFDCBB")
	assert_gte(_contrast(Color("#765A43"), paper), 4.56, "muted on paper")
	assert_gte(_contrast(Color("#765A43"), panel), 4.56, "muted on a panel")
	assert_gte(_contrast(Color("#3B2A20"), panel), 4.56, "ink on a panel")
	assert_gte(_contrast(Color("#1C2F60"), panel), 4.56, "Madra ink on a panel")
	assert_gte(_contrast(Color("#F0E8D8"), Color("#A83C30")), 4.56, "seal text")

## WCAG 2 contrast ratio between two opaque colours.
func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)

#-----------------------------------------------------------------------------
# BOOK THEME VARIANTS: CHECKS BEYOND THE PLAN'S TESTS
#-----------------------------------------------------------------------------

## A variation only applies to controls of its base type, so a wrong one would
## break every scene that sets the variant.
func test_variants_have_their_base_types() -> void:
	for row: Array in _variants:
		assert_eq(BOOK_THEME.get_type_variation_base(row[0]), &"Label", str(row[0]))
	assert_eq(BOOK_THEME.get_type_variation_base(&"RichTextBookDetail"), &"RichTextLabel")
	assert_eq(BOOK_THEME.get_type_variation_base(&"RichTextBookValue"), &"RichTextLabel")
	assert_eq(BOOK_THEME.get_type_variation_base(&"PanelPressed"), &"PanelContainer")
	assert_eq(BOOK_THEME.get_type_variation_base(&"PanelBookBare"), &"PanelContainer")
	assert_eq(BOOK_THEME.get_type_variation_base(&"PanelPrinterMarks"), &"Panel")
	assert_eq(BOOK_THEME.get_type_variation_base(&"HSeparatorPressed"), &"HSeparator")

## The detail RichTextLabel variant: Euljiro 15, muted ink, a 20 px line pitch.
func test_rich_text_detail_variant() -> void:
	var font: Font = BOOK_THEME.get_font(&"normal_font", &"RichTextBookDetail")
	assert_eq(font.resource_path, EULJIRO)
	assert_eq(BOOK_THEME.get_font_size(&"normal_font_size", &"RichTextBookDetail"), 15)
	assert_eq(BOOK_THEME.get_color(&"default_color", &"RichTextBookDetail").to_html(false), "765a43")
	var pitch: int = roundi(font.get_height(15)) + BOOK_THEME.get_constant(&"line_separation", &"RichTextBookDetail")
	assert_eq(pitch, 20, "line pitch")

## The value RichTextLabel variant, for a table row's value: Euljiro 18 in
## dark ink, as the spec prints a row's value, with a 26 px line pitch.
func test_rich_text_value_variant() -> void:
	var font: Font = BOOK_THEME.get_font(&"normal_font", &"RichTextBookValue")
	assert_eq(font.resource_path, EULJIRO)
	assert_eq(BOOK_THEME.get_font_size(&"normal_font_size", &"RichTextBookValue"), 18)
	assert_eq(BOOK_THEME.get_color(&"default_color", &"RichTextBookValue").to_html(false), "33261a")
	var pitch: int = roundi(font.get_height(18)) + BOOK_THEME.get_constant(&"line_separation", &"RichTextBookValue")
	assert_eq(pitch, 26, "line pitch")

## pixel_theme's base Label draws a 1 px ink shadow: a variant that does not set
## its own transparent one would print it onto the paper.
func test_pressed_label_variants_draw_no_shadow() -> void:
	for row: Array in _variants:
		assert_true(BOOK_THEME.has_color(&"font_shadow_color", row[0]), "%s overrides the base shadow" % row[0])
		assert_eq(BOOK_THEME.get_color(&"font_shadow_color", row[0]).a, 0.0, "%s shadow" % row[0])

## An HSeparator draws its style at the style's minimum height, and a
## StyleBoxTexture has no height of its own beyond its margins. With top and
## bottom margins of 0 the rule is 0 px tall and never draws (measured in 4.7.2),
## so the margins must add up to the rule's 4 px, the separator's `separation`.
func test_pressed_rule_is_as_tall_as_its_separator() -> void:
	var rule: StyleBoxTexture = BOOK_THEME.get_stylebox(&"separator", &"HSeparatorPressed") as StyleBoxTexture
	assert_not_null(rule, "the separator style is a StyleBoxTexture")
	var separation: float = BOOK_THEME.get_constant(&"separation", &"HSeparatorPressed")
	assert_eq(rule.get_minimum_size().y, separation, "the rule's height")
	assert_eq(rule.get_minimum_size().y, float(rule.texture.get_height()), "the whole 4 px of art is drawn")

## A Label in the book theme, in the tree.
func _make_label(variant: StringName, text: String) -> Label:
	var label := Label.new()
	label.theme = BOOK_THEME
	label.theme_type_variation = variant
	label.text = text
	add_child_autofree(label)
	return label

## A one-line Label is as tall as its font (16 px at 13 px), not its 18 px line
## pitch, so the style's margins must make up the rest: the paper tag's art is
## 20 px tall.
func test_a_one_line_tag_is_as_tall_as_its_art() -> void:
	var tag: Label = _make_label(&"LabelBookTag", "7")
	await wait_process_frames(2)
	assert_eq(tag.get_combined_minimum_size().y, 20.0, "tag height")

## The same for a filter word and the 26 px lozenge behind the one in use. The
## two styles are the same size, so selecting a word moves nothing.
func test_a_one_line_filter_word_is_as_tall_as_its_lozenge() -> void:
	var word: Label = _make_label(&"LabelBookFilter", "ALL")
	var word_in_use: Label = _make_label(&"LabelBookFilterOn", "ALL")
	await wait_process_frames(2)
	assert_eq(word.get_combined_minimum_size().y, 26.0, "filter word height")
	assert_eq(word_in_use.get_combined_minimum_size().y, 26.0, "filter word in use height")
	assert_eq(word.get_combined_minimum_size(), word_in_use.get_combined_minimum_size(), "same footprint")
