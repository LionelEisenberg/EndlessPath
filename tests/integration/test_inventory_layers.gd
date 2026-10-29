extends GutTest

## The inventory book's layers: the pages show only while the book lies open,
## and the view, its layers and its tabs let clicks through. Also pins the page
## title, the open_page() calls the book makes on its tabs, and the PageBounds
## helper the tab tests use.

const InventoryViewScene: PackedScene = preload("res://scenes/inventory/inventory_view/inventory_view.tscn")
const PageTitleScene: PackedScene = preload("res://scenes/inventory/pressed/page_title/page_title.tscn")
const BOOK_THEME_PATH: String = "res://assets/themes/book_theme.tres"
const ANIMATION_TIMEOUT: float = 2.0

#-----------------------------------------------------------------------------
# FIXTURES
#-----------------------------------------------------------------------------

func after_each() -> void:
	# The Equipment tab's PaginationBar.setup() frees the page buttons it
	# replaces a frame late: let that frame pass so GUT counts no orphans.
	await wait_process_frames(1)

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

func test_pages_show_only_while_the_book_lies_open() -> void:
	var view: MenuBookView = _view()
	assert_false((view.get_node("PageLayer") as Control).visible)
	view._on_book_opened()
	assert_true((view.get_node("PageLayer") as Control).visible)

func test_the_view_lets_clicks_through() -> void:
	var view: MenuBookView = _view()
	assert_eq(view.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for layer_name: String in ["BookLayer", "PageLayer"]:
		assert_eq((view.get_node(layer_name) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, layer_name)

func test_each_tab_ignores_the_mouse() -> void:
	var view: MenuBookView = _view()
	for tab_name: String in ["EquipmentTab", "ConsumablesTab", "MaterialsTab", "QuestItemsTab"]:
		var tab: Control = view.find_child(tab_name, true, false) as Control
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

func test_page_title_set_before_it_is_ready_shows_too() -> void:
	var title: PageTitle = PageTitleScene.instantiate() as PageTitle
	title.title = "Hotbar"
	add_child_autofree(title)
	assert_eq((title.get_node("%TitleLabel") as Label).text, "Hotbar")

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
