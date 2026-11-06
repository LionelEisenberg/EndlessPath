extends GutTest

## Unit tests for PaperTag: the paper hugs whatever it prints and keeps an
## even width, so its art stays on the 2 px grid. The Character book's tiles
## and stat page print totals on it; the Inventory's slots print counts.

const PaperTagScene := preload("res://scenes/inventory/pressed/paper_tag/paper_tag.tscn")

func test_a_figure_keeps_the_tag_even() -> void:
	var tag: PaperTag = PaperTagScene.instantiate() as PaperTag
	add_child_autofree(tag)
	for figure: String in ["7", "12", "108", "1250"]:
		tag.set_figure(figure)
		assert_eq(tag.text, figure, "the tag prints the figure as it is")
		assert_eq(int(tag.custom_minimum_size.x) % 2, 0, "\"%s\" leaves the tag an even width" % figure)
		assert_gte(tag.custom_minimum_size.x, tag.get_minimum_size().x, "\"%s\" fits on the tag" % figure)
