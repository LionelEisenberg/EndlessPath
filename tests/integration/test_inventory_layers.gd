extends GutTest

## The inventory book draws its art at 2x and its pages at 1x (spec: Calls).
## Also pins the page title with its ornament, the open_page() calls the book
## makes on its tabs, and the PageBounds helper the tab tests use.

const InventoryViewScene: PackedScene = preload("res://scenes/inventory/inventory_view/inventory_view.tscn")
const PageTitleScene: PackedScene = preload("res://scenes/inventory/pressed/page_title/page_title.tscn")
const BOOK_THEME_PATH: String = "res://assets/themes/book_theme.tres"
const ANIMATION_TIMEOUT: float = 2.0

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

## Stands in for a tab: counts open_page() calls and notes whether it was
## already showing when it was called.
class OpenPageSpy:
	extends Control

	var opened: int = 0
	var showing_when_opened: bool = false

	## Counts the call and notes whether the tab was showing.
	func open_page() -> void:
		opened += 1
		showing_when_opened = visible

func _view() -> MenuBookView:
	var view: MenuBookView = InventoryViewScene.instantiate() as MenuBookView
	add_child_autofree(view)
	return view

## Swaps the view's tab at `index` for a spy that counts open_page() calls.
func _spy_for_tab(view: MenuBookView, index: int) -> OpenPageSpy:
	var spy: OpenPageSpy = OpenPageSpy.new()
	add_child_autofree(spy)
	view.tabs[index] = spy
	return spy

## A PageTitle inside a parent that carries the book's theme, as the book does.
func _page_title() -> PageTitle:
	var parent: Control = Control.new()
	parent.theme = load(BOOK_THEME_PATH) as Theme
	add_child_autofree(parent)
	var title: PageTitle = PageTitleScene.instantiate() as PageTitle
	parent.add_child(title)
	return title

## The first row of the texture whose leftmost pixel is inked: where the
## ornament's line sits, far from the diamond.
func _line_row(texture: Texture2D) -> int:
	var image: Image = texture.get_image()
	for y: int in image.get_height():
		if image.get_pixel(0, y).a > 0.0:
			return y
	return -1

## A Label of the given name and global rect, under `parent`.
func _label(parent: Node, label_name: String, rect: Rect2) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.text = "x"
	parent.add_child(label)
	label.global_position = rect.position
	label.size = rect.size
	return label

#-----------------------------------------------------------------------------
# LAYERS
#-----------------------------------------------------------------------------

func test_book_art_is_doubled_and_pages_are_not() -> void:
	var view: MenuBookView = _view()
	assert_eq((view.get_node("BookLayer") as Control).scale, Vector2(2, 2))
	assert_eq((view.get_node("PageLayer") as Control).scale, Vector2.ONE)

func test_the_four_tabs_live_on_the_page_layer() -> void:
	var view: MenuBookView = _view()
	for tab_name: String in ["EquipmentTab", "ConsumablesTab", "MaterialsTab", "QuestItemsTab"]:
		assert_eq(view.find_child(tab_name, true, false).get_parent().name, &"PageLayer", tab_name)

func test_pages_show_only_while_the_book_lies_open() -> void:
	var view: MenuBookView = _view()
	assert_false((view.get_node("PageLayer") as Control).visible)
	view._on_book_opened()
	assert_true((view.get_node("PageLayer") as Control).visible)

func test_the_view_fills_the_screen_in_the_book_theme_and_lets_clicks_through() -> void:
	var view: MenuBookView = _view()
	assert_eq(view.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(view.scale, Vector2.ONE, "the view has no scale of its own")
	assert_eq(view.theme.resource_path, BOOK_THEME_PATH)
	assert_eq([view.anchor_left, view.anchor_top, view.anchor_right, view.anchor_bottom], [0.0, 0.0, 1.0, 1.0])
	for layer_name: String in ["BookLayer", "PageLayer"]:
		assert_eq((view.get_node(layer_name) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, layer_name)

func test_each_tab_starts_at_the_books_corner_and_ignores_the_mouse() -> void:
	var view: MenuBookView = _view()
	view._on_book_opened()
	await wait_process_frames(2)
	# The book's top-left, screen (260, 90): what every tab's local px count from.
	for tab_name: String in ["EquipmentTab", "ConsumablesTab", "MaterialsTab", "QuestItemsTab"]:
		var tab: Control = view.find_child(tab_name, true, false) as Control
		assert_eq(tab.global_position, Vector2(260, 90), tab_name)
		assert_eq(tab.mouse_filter, Control.MOUSE_FILTER_IGNORE, tab_name)

#-----------------------------------------------------------------------------
# OPEN PAGE
#-----------------------------------------------------------------------------

func test_opening_the_book_opens_the_page_of_the_shown_tab() -> void:
	var view: MenuBookView = _view()
	var spy: OpenPageSpy = _spy_for_tab(view, 0)
	view.animate_open()
	assert_eq(spy.opened, 1)

func test_a_page_turn_opens_the_page_it_lands_on_before_showing_it() -> void:
	var view: MenuBookView = _view()
	var spy: OpenPageSpy = _spy_for_tab(view, 2)
	(view.get_node("%TabSwitcher") as Control).tab_changed.emit(2)
	assert_eq(spy.opened, 0, "not until the page has landed")
	await wait_for_signal(view.book_frame.page_turned, ANIMATION_TIMEOUT)
	assert_eq(spy.opened, 1)
	assert_false(spy.showing_when_opened, "its page is ready before the tab shows")
	assert_true(spy.visible)

func test_every_tab_has_an_open_page() -> void:
	var view: MenuBookView = _view()
	for tab: Control in view.tabs:
		assert_true(tab.has_method("open_page"), tab.name)

#-----------------------------------------------------------------------------
# PAGE TITLE
#-----------------------------------------------------------------------------

func test_page_title_shows_its_title() -> void:
	var title: PageTitle = PageTitleScene.instantiate() as PageTitle
	add_child_autofree(title)
	title.title = "Gear"
	assert_eq((title.get_node("%TitleLabel") as Label).text, "Gear")
	assert_eq((title.get_node("%Ornament") as TextureRect).texture.resource_path, "res://assets/sprites/ui/book/pressed/title_ornament_ai.png")

func test_page_title_set_before_it_is_ready_shows_too() -> void:
	var title: PageTitle = PageTitleScene.instantiate() as PageTitle
	title.title = "Hotbar"
	add_child_autofree(title)
	assert_eq((title.get_node("%TitleLabel") as Label).text, "Hotbar")

func test_the_ornament_line_sits_16_px_under_the_title_baseline() -> void:
	var title: PageTitle = _page_title()
	title.title = "Gear"
	await wait_process_frames(2)
	var label: Label = title.get_node("%TitleLabel") as Label
	var font: Font = label.get_theme_font(&"font")
	assert_eq(label.get_theme_font_size(&"font_size"), 38, "the book theme reaches the title")
	var baseline: float = label.global_position.y + font.get_ascent(label.get_theme_font_size(&"font_size"))
	var ornament: TextureRect = title.get_node("%Ornament") as TextureRect
	var line_top: float = ornament.global_position.y + _line_row(ornament.texture)
	assert_eq(line_top - baseline, 16.0)

func test_the_ornament_is_centred_under_the_title() -> void:
	var title: PageTitle = _page_title()
	title.title = "Gear"
	title.custom_minimum_size.x = 452.0
	await wait_process_frames(2)
	var label: Label = title.get_node("%TitleLabel") as Label
	var ornament: TextureRect = title.get_node("%Ornament") as TextureRect
	assert_eq(label.size.x, 452.0, "the title's width fills")
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(ornament.size, Vector2(272, 14), "the ornament is drawn at its own size")
	assert_eq(ornament.global_position.x, title.global_position.x + 90.0, "centred: (452 - 272) / 2")

func test_a_long_title_wraps_inside_the_width_it_is_given() -> void:
	var title: PageTitle = _page_title()
	title.title = "Pill of the Thousand Quiet Mornings Beneath the Valley"
	title.custom_minimum_size.x = 468.0
	await wait_process_frames(2)
	var label: Label = title.get_node("%TitleLabel") as Label
	assert_gt(label.get_line_count(), 1, "it wraps")
	assert_eq(title.size.x, 468.0, "and never widens its page")
	assert_lte(label.size.x, 468.0)

#-----------------------------------------------------------------------------
# PAGE BOUNDS
#-----------------------------------------------------------------------------

func test_the_page_rects_are_the_books_two_pages() -> void:
	assert_eq(PageBounds.LEFT_PAGE, Rect2(424, 202, 508, 688))
	assert_eq(PageBounds.RIGHT_PAGE, Rect2(988, 202, 508, 688))

func test_scaled_text_names_visible_text_drawn_at_another_scale() -> void:
	var root: Control = Control.new()
	add_child_autofree(root)
	var doubled: Control = Control.new()
	doubled.scale = Vector2(2, 2)
	root.add_child(doubled)
	_label(root, "Plain", Rect2(450, 300, 100, 30))
	_label(doubled, "Doubled", Rect2(450, 340, 100, 30))
	var rich: RichTextLabel = RichTextLabel.new()
	rich.name = "DoubledRich"
	doubled.add_child(rich)
	var hidden: Label = _label(doubled, "DoubledHidden", Rect2(450, 380, 100, 30))
	hidden.visible = false
	assert_eq(PageBounds.scaled_text(root), ["Doubled", "DoubledRich"] as Array[String])

func test_scaled_text_is_empty_when_everything_is_drawn_at_one_to_one() -> void:
	var root: Control = Control.new()
	add_child_autofree(root)
	_label(root, "Plain", Rect2(450, 300, 100, 30))
	assert_eq(PageBounds.scaled_text(root), [] as Array[String])

func test_escaping_text_names_visible_text_outside_both_pages() -> void:
	var root: Control = Control.new()
	add_child_autofree(root)
	_label(root, "InLeft", Rect2(452, 244, 452, 30))
	_label(root, "InRight", Rect2(1008, 244, 468, 30))
	_label(root, "FillsLeftPage", PageBounds.LEFT_PAGE)
	_label(root, "AcrossTheGutter", Rect2(900, 300, 100, 30))
	_label(root, "BelowThePage", Rect2(452, 870, 100, 30))
	_label(root, "BeyondTheBook", Rect2(1480, 300, 100, 30))
	var hidden: Label = _label(root, "HiddenOutside", Rect2(0, 0, 100, 30))
	hidden.visible = false
	assert_eq(PageBounds.escaping_text(root), ["AcrossTheGutter", "BelowThePage", "BeyondTheBook"] as Array[String])

func test_escaping_text_counts_the_scale_text_is_drawn_at() -> void:
	var root: Control = Control.new()
	add_child_autofree(root)
	var doubled: Control = Control.new()
	doubled.scale = Vector2(2, 2)
	root.add_child(doubled)
	# 100 wide at 2x is 200 on screen: from x 800 it runs past the left page's edge at 932.
	_label(doubled, "DoubledPastTheEdge", Rect2(800, 300, 100, 30))
	assert_eq(PageBounds.escaping_text(root), ["DoubledPastTheEdge"] as Array[String])
