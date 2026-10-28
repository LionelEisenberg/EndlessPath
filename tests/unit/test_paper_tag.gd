extends GutTest

## PaperTag keeps a paper tag's width even: its text and padding, rounded up.
## A tag anchored to a slot's right edge then starts on an even x, and its art
## stays on the 2 px grid, as the mockup draws it.

const BOOK_THEME: Theme = preload("res://assets/themes/book_theme.tres")
const PaperTagScene: PackedScene = preload("res://scenes/inventory/pressed/paper_tag/paper_tag.tscn")

## A PaperTag in the book theme, in the tree.
func _tag() -> PaperTag:
	var page: Control = Control.new()
	page.theme = BOOK_THEME
	add_child_autofree(page)
	var tag: PaperTag = PaperTagScene.instantiate() as PaperTag
	page.add_child(tag)
	return tag

func test_an_odd_width_rounds_up_to_an_even_tag() -> void:
	var tag: PaperTag = _tag()
	tag.set_count(7)
	var natural: float = tag.get_minimum_size().x
	assert_eq(tag.text, "×7")
	assert_eq(fmod(natural, 2.0), 1.0, "×7 is an odd width: 13 px of text and 10 of paper")
	assert_eq(tag.get_combined_minimum_size().x, natural + 1.0, "rounded up to the next even width")

func test_an_even_width_stays_as_it_is() -> void:
	var tag: PaperTag = _tag()
	tag.set_count(12)
	var natural: float = tag.get_minimum_size().x
	assert_eq(fmod(natural, 2.0), 0.0, "×12 is an even width: 20 px of text and 10 of paper")
	assert_eq(tag.get_combined_minimum_size().x, natural)

func test_a_new_count_refits_the_tag() -> void:
	var tag: PaperTag = _tag()
	tag.set_count(1234567)
	tag.set_count(7)
	assert_eq(tag.get_combined_minimum_size().x, tag.get_minimum_size().x + 1.0, "a shorter count shrinks the tag back to its own even width")

func test_a_tag_is_as_tall_as_its_art() -> void:
	var tag: PaperTag = _tag()
	tag.set_count(7)
	assert_eq(tag.get_combined_minimum_size().y, 20.0)
	assert_eq(tag.theme_type_variation, &"LabelBookTag")
