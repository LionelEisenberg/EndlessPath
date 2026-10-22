extends GutTest

## Unit tests for BookStyleData: the colours a menu book swaps into the shared
## book art, and the order BookFrame pairs them with its source colours.

const STYLE_DIR: String = "res://resources/ui/book_styles/"

#-----------------------------------------------------------------------------
# DEFAULTS
#-----------------------------------------------------------------------------

func test_default_book_colors_are_the_master_art() -> void:
	var style := BookStyleData.new()
	assert_eq(style.get_book_colors(), PackedColorArray(BookFrame.BOOK_SOURCE_COLORS),
		"a fresh style must leave the master book art unchanged")

func test_default_bookmark_colors_are_the_master_art() -> void:
	var style := BookStyleData.new()
	assert_eq(style.get_bookmark_colors(), PackedColorArray(BookFrame.BOOKMARK_SOURCE_COLORS),
		"a fresh style must leave the master bookmark unchanged")

#-----------------------------------------------------------------------------
# ORDER
#-----------------------------------------------------------------------------

func test_book_colors_follow_the_source_order() -> void:
	var style := BookStyleData.new()
	style.cover_light = Color.RED
	style.cover_mid = Color.GREEN
	style.cover_dark = Color.BLUE
	style.page_border = Color.YELLOW
	assert_eq(style.get_book_colors(), PackedColorArray([Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]))

func test_bookmark_colors_follow_the_source_order() -> void:
	var style := BookStyleData.new()
	style.bookmark_dark = Color.RED
	style.bookmark_mid = Color.GREEN
	style.bookmark_light = Color.BLUE
	assert_eq(style.get_bookmark_colors(), PackedColorArray([Color.RED, Color.GREEN, Color.BLUE]))

#-----------------------------------------------------------------------------
# THE FOUR BOOKS
#-----------------------------------------------------------------------------

func test_each_menu_has_a_style() -> void:
	for book: String in ["inventory", "abilities", "character", "path"]:
		var style: BookStyleData = load(STYLE_DIR + book + "_book_style.tres") as BookStyleData
		assert_not_null(style, "%s_book_style.tres loads as BookStyleData" % book)

func test_every_book_recolours_its_page_border() -> void:
	# The border colour is what tells the books apart at a glance; the cover
	# edge is too thin to do it alone.
	var master_border: Color = BookFrame.BOOK_SOURCE_COLORS[3]
	for book: String in ["inventory", "abilities", "character", "path"]:
		var style: BookStyleData = load(STYLE_DIR + book + "_book_style.tres") as BookStyleData
		assert_ne(style.page_border, master_border, "%s keeps the master border colour" % book)

func test_page_borders_differ_between_books() -> void:
	var borders: Array[Color] = []
	for book: String in ["inventory", "abilities", "character", "path"]:
		var style: BookStyleData = load(STYLE_DIR + book + "_book_style.tres") as BookStyleData
		assert_does_not_have(borders, style.page_border, "%s shares a border colour with another book" % book)
		borders.append(style.page_border)
