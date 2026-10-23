extends GutTest

## Integration tests for the adventure's chest (AdventureChest) and the run
## clock in its header (RunClock): the clock following the run's Timer and
## turning to the low-time seal, the title ellipsizing in its slot (Review
## Focus 3), the chest hugging its visible page (never shorter than 176) and
## following that page's content_resized, and where each piece sits. A plain
## AdventureChestPage stands in for the pages the chest will hold. The clock's
## two pure rules (M:SS and the 30 s threshold) are in test_run_clock.gd.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const CHEST_SCENE: PackedScene = preload("res://scenes/adventure/adventure_chest/adventure_chest.tscn")
const LACQUER_THEME_PATH: String = "res://assets/themes/lacquer/lacquer_theme.tres"
const RECESS_PATH: String = "res://assets/ui/lacquer/lacquer_timer_ai.png"
const LOW_RECESS_PATH: String = "res://assets/ui/lacquer/lacquer_timer_low_ai.png"
const HOURGLASS_PATH: String = "res://assets/ui/lacquer/lacquer_mini_hourglass_ai.png"
const CHEST_TOP_PATH: String = "res://assets/ui/lacquer/lacquer_chest_top_ai.png"
const CHEST_MID_PATH: String = "res://assets/ui/lacquer/lacquer_chest_mid_ai.png"
const CHEST_BOTTOM_PATH: String = "res://assets/ui/lacquer/lacquer_chest_bot_ai.png"
## Where the chest stands on screen, where the zone view keeps its chest.
const CHEST_HOME: Vector2 = Vector2(1456.0, 24.0)
## The frame's slices are 444 wide: the chest's 440 and the column's 4 px
## shadow, which each slice carries its part of.
const SLICE_WIDTH: float = 444.0

var _chest: AdventureChest = null

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	_chest = CHEST_SCENE.instantiate() as AdventureChest
	add_child_autofree(_chest)
	# The chest's scene holds the expedition page, which counts as the visible
	# page. These tests stand plain pages in for the pages, so it is put away.
	_chest.get_expedition_page().hide()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _node(unique_name: String) -> Node:
	return _chest.get_node("%" + unique_name)

func _clock() -> RunClock:
	return _chest.get_run_clock()

func _clock_node(unique_name: String) -> Node:
	return _clock().get_node("%" + unique_name)

func _time_text() -> String:
	return (_clock_node("TimeLabel") as Label).text

func _recess_path() -> String:
	return (_clock_node("Recess") as TextureRect).texture.resource_path

func _title() -> Label:
	return _node("TitleLabel") as Label

## A page of the given height in the chest's page slot, 408 wide. It is
## visible unless shown is false. Its content height is its own height, as a
## plain page's is.
func _add_page(height: float, shown: bool = true) -> AdventureChestPage:
	var page := AdventureChestPage.new()
	page.size = Vector2(408.0, height)
	page.visible = shown
	_node("PageSlot").add_child(page)
	return page

## A timer in the tree with seconds left, paused so that its time left holds
## still: the clock then reads exactly what the timer was started with.
## start() on a paused timer sets the time left and keeps it paused.
func _held_timer(seconds: float) -> Timer:
	var timer := Timer.new()
	add_child_autofree(timer)
	timer.start(seconds)
	timer.paused = true
	return timer

#-----------------------------------------------------------------------------
# RUN CLOCK
#-----------------------------------------------------------------------------

func test_clock_follows_its_timer() -> void:
	assert_eq(_time_text(), "0:00", "precondition: nothing is bound, so it reads the scene's 0:00")
	_clock().bind_timer(_held_timer(90.0))
	await wait_process_frames(1)
	assert_eq(_time_text(), "1:30")

## Not paused: the clock counts down with the timer. 62 s reads 1:01 from the
## start until a second has passed and 1:00 for the second after that, so
## reads at 0.5 s and at 1.5 s each have 0.5 s of slack either way.
func test_clock_counts_down_with_a_running_timer() -> void:
	var timer := Timer.new()
	add_child_autofree(timer)
	timer.start(62.0)
	_clock().bind_timer(timer)
	await wait_seconds(0.5)
	assert_eq(_time_text(), "1:01", "61.5 s left")
	await wait_seconds(1.0)
	assert_eq(_time_text(), "1:00", "60.5 s left")

func test_clock_turns_to_the_seal_when_low() -> void:
	var timer: Timer = _held_timer(31.0)
	_clock().bind_timer(timer)
	await wait_process_frames(1)
	assert_false(_clock().is_low_shown(), "31 s: the carved recess")
	assert_eq(_recess_path(), RECESS_PATH)
	timer.start(30.0)
	await wait_process_frames(1)
	assert_true(_clock().is_low_shown(), "30 s: the seal")
	assert_eq(_recess_path(), LOW_RECESS_PATH)
	assert_eq(_time_text(), "0:30", "and the time still reads")
	timer.start(90.0)
	await wait_process_frames(1)
	assert_false(_clock().is_low_shown(), "a new run starts on the recess again")
	assert_eq(_recess_path(), RECESS_PATH)
	assert_eq(_time_text(), "1:30")

## The seal changes the recess and nothing else: the time keeps the label's
## own cream, which reads on the vermilion.
func test_the_seal_changes_only_the_recess() -> void:
	var timer: Timer = _held_timer(90.0)
	_clock().bind_timer(timer)
	await wait_process_frames(1)
	var label: Label = _clock_node("TimeLabel") as Label
	var hourglass: TextureRect = _clock().get_node("Hourglass") as TextureRect
	var cream: Color = label.get_theme_color(&"font_color")
	assert_eq(cream.to_html(false), "f0e8d8", "precondition: the label's own colour is the kit's cream")
	var label_rect: Rect2 = label.get_rect()
	var hourglass_rect: Rect2 = hourglass.get_rect()
	timer.start(12.0)
	await wait_process_frames(1)
	assert_true(_clock().is_low_shown(), "precondition: the seal shows")
	assert_eq(label.get_theme_color(&"font_color"), cream, "the time keeps its colour")
	assert_false(label.has_theme_color_override(&"font_color"), "no override: the variant's cream")
	assert_eq(label.get_rect(), label_rect, "the label has not moved")
	assert_eq(hourglass.get_rect(), hourglass_rect, "nor has the hourglass")
	assert_eq(label.modulate, Color.WHITE, "nothing is tinted")
	assert_eq(_clock().modulate, Color.WHITE)

## A run that ends with time left leaves the clock showing it (the end card
## opens over it): a stopped timer reads 0, and that must not turn the seal on.
func test_clock_keeps_its_last_time_when_the_timer_stops() -> void:
	var timer: Timer = _held_timer(45.0)
	_clock().bind_timer(timer)
	await wait_process_frames(1)
	assert_eq(_time_text(), "0:45", "precondition")
	timer.stop()
	await wait_process_frames(2)
	assert_eq(_time_text(), "0:45", "the stopped timer leaves the clock as it was")
	assert_false(_clock().is_low_shown(), "and no seal")
	timer.start(20.0)
	await wait_process_frames(1)
	assert_eq(_time_text(), "0:20", "the next run's timer runs it again")
	assert_true(_clock().is_low_shown())

func test_clock_follows_the_timer_it_was_bound_to_last() -> void:
	var first: Timer = _held_timer(90.0)
	var second: Timer = _held_timer(45.0)
	_clock().bind_timer(first)
	await wait_process_frames(1)
	assert_eq(_time_text(), "1:30")
	_clock().bind_timer(second)
	await wait_process_frames(1)
	assert_eq(_time_text(), "0:45", "the second timer's time")
	first.start(20.0)
	await wait_process_frames(1)
	assert_eq(_time_text(), "0:45", "the first no longer moves the clock")
	assert_false(_clock().is_low_shown())

## A clock with no timer, with its timer unbound (null) or with its timer freed
## sits still and raises no error (an engine error fails the test).
func test_clock_without_a_live_timer_sits_still() -> void:
	await wait_process_frames(2)
	assert_eq(_time_text(), "0:00", "no timer bound")
	assert_false(_clock().is_low_shown())
	var timer: Timer = _held_timer(45.0)
	_clock().bind_timer(timer)
	await wait_process_frames(1)
	_clock().bind_timer(null)
	timer.start(20.0)
	await wait_process_frames(2)
	assert_eq(_time_text(), "0:45", "unbound: the timer no longer reaches it")
	_clock().bind_timer(timer)
	timer.free()
	await wait_process_frames(2)
	assert_eq(_time_text(), "0:45", "a freed timer leaves the clock as it was")

#-----------------------------------------------------------------------------
# TITLE
#-----------------------------------------------------------------------------

func test_set_title() -> void:
	_chest.set_title("The Shallow Woods")
	assert_eq(_title().text, "The Shallow Woods")
	_chest.set_title("Amorphous Spirit")
	assert_eq(_title().text, "Amorphous Spirit", "a new title replaces it")

## Review Focus 3: a long adventure name ellipsizes in its 312 px, never
## widening the chest or running under the clock.
func test_title_ellipsizes() -> void:
	var long_title: String = ("The Shallow Woods Beyond The Edge Of The Known World ").repeat(2).left(60)
	assert_eq(long_title.length(), 60, "precondition: 60 characters")
	_chest.set_title(long_title)
	await wait_process_frames(2)
	var label: Label = _title()
	var font: Font = label.get_theme_font(&"font")
	var natural_width: float = font.get_string_size(long_title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label.get_theme_font_size(&"font_size")).x
	assert_gt(natural_width, 312.0, "precondition: the text is wider than its slot")
	assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
	assert_lte(label.size.x, 312.0, "the label stays within its 312 px")
	assert_eq(_chest.size.x, 440.0, "and the chest stays 440 wide")
	assert_lte(label.get_global_rect().end.x, _clock().get_global_rect().position.x, "the title stops before the clock")

#-----------------------------------------------------------------------------
# HEIGHT
#-----------------------------------------------------------------------------

func test_hugs_its_page() -> void:
	_add_page(300.0)
	_chest.relayout()
	assert_eq(_chest.size.y, 406.0, "82 above the page, its 300, and 24 under it")
	assert_eq((_node("ChestMid") as Control).size.y, 230.0, "406 less the 128 top and the 48 bottom")
	assert_eq((_node("ChestBottom") as Control).position.y, 358.0, "the bottom slice is the last 48")
	assert_eq(_chest.size.x, 440.0)
	assert_eq((_node("PageSlot") as Control).size.y, 300.0, "the slot is the page's area")

func test_never_shorter_than_176() -> void:
	assert_eq(_chest.size.y, 176.0, "a chest with no page is the minimum")
	assert_eq((_node("ChestMid") as Control).size.y, 0.0, "the minimum is the top and the bottom")
	assert_eq((_node("ChestBottom") as Control).position.y, 128.0)
	_add_page(20.0)
	_chest.relayout()
	assert_eq(_chest.size.y, 176.0, "82 + 20 + 24 is only 126")
	assert_eq((_node("ChestMid") as Control).size.y, 0.0)
	assert_eq((_node("ChestBottom") as Control).position.y, 128.0)

func test_hug_starts_where_the_minimum_ends() -> void:
	var page: AdventureChestPage = _add_page(70.0)
	_chest.relayout()
	assert_eq(_chest.size.y, 176.0, "82 + 70 + 24 is exactly the minimum")
	page.size.y = 72.0
	_chest.relayout()
	assert_eq(_chest.size.y, 178.0, "two more px of page, two more of chest")
	assert_eq((_node("ChestMid") as Control).size.y, 2.0)
	assert_eq((_node("ChestBottom") as Control).position.y, 130.0)

func test_relayouts_on_content_resized() -> void:
	var page: AdventureChestPage = _add_page(300.0)
	page.content_resized.emit()
	assert_eq(_chest.size.y, 406.0, "the signal alone sizes the chest")
	page.size.y = 400.0
	assert_eq(_chest.size.y, 406.0, "nothing moves until the page says its content resized")
	page.content_resized.emit()
	assert_eq(_chest.size.y, 506.0)
	assert_eq((_node("ChestMid") as Control).size.y, 330.0)
	assert_eq((_node("ChestBottom") as Control).position.y, 458.0)
	page.size.y = 20.0
	page.content_resized.emit()
	assert_eq(_chest.size.y, 176.0, "and back down to the minimum")
	assert_eq((_node("ChestMid") as Control).size.y, 0.0)

## A page's own get_content_height() decides, not its size: a page overrides
## it for content that flows.
func test_the_chest_asks_the_page_for_its_content_height() -> void:
	var page := TallContentPage.new()
	page.size = Vector2(408.0, 10.0)
	page.content_height = 500.0
	_node("PageSlot").add_child(page)
	page.content_resized.emit()
	assert_eq(_chest.size.y, 606.0, "82 + 500 + 24, whatever the page's size")
	page.content_height = 250.0
	page.content_resized.emit()
	assert_eq(_chest.size.y, 356.0)

## The slices come in even numbers, as the mock's chest does: an odd page is
## rounded to the nearest even height (an exact odd one up).
func test_height_is_even() -> void:
	var page: AdventureChestPage = _add_page(301.0)
	_chest.relayout()
	assert_eq(_chest.size.y, 408.0, "407 rounds up")
	assert_eq((_node("ChestMid") as Control).size.y, 232.0)
	assert_eq((_node("ChestBottom") as Control).position.y, 360.0)
	page.size.y = 300.4
	_chest.relayout()
	assert_eq(_chest.size.y, 406.0, "406.4 rounds to 406")

#-----------------------------------------------------------------------------
# PAGES
#-----------------------------------------------------------------------------

## Only the visible page counts, and the chest follows which one shows.
func test_hugs_the_visible_page_only() -> void:
	var tall: AdventureChestPage = _add_page(300.0)
	var short: AdventureChestPage = _add_page(100.0, false)
	_chest.relayout()
	assert_eq(_chest.size.y, 406.0, "the hidden page does not count")
	short.content_resized.emit()
	assert_eq(_chest.size.y, 406.0, "and does not move the chest")
	tall.hide()
	short.show()
	assert_eq(_chest.size.y, 206.0, "the chest follows the page that shows")
	short.hide()
	assert_eq(_chest.size.y, 176.0, "no page showing: the minimum")
	tall.show()
	assert_eq(_chest.size.y, 406.0)

## A page that joins the slot later is hugged without a call, once it is ready.
func test_a_page_added_later_is_hugged() -> void:
	_add_page(300.0)
	await wait_process_frames(1)
	assert_eq(_chest.size.y, 406.0)

## A page's content height may need what the page builds in _ready, so the
## chest does not ask a page that joins the slot until the page is ready.
func test_a_joining_page_is_not_asked_for_its_height_before_it_is_ready() -> void:
	var page := ReadyAwarePage.new()
	page.size = Vector2(408.0, 300.0)
	_node("PageSlot").add_child(page)
	await wait_process_frames(1)
	assert_false(page.asked_before_ready, "the chest waited for the page")
	assert_eq(_chest.size.y, 406.0, "and then hugged it")

## A page that is already in the slot when the chest becomes ready, as a page
## placed in the chest's scene is: hugged at once, and followed from then on.
func test_a_page_already_in_the_slot_is_hugged_and_followed() -> void:
	var chest := CHEST_SCENE.instantiate() as AdventureChest
	chest.get_node("%ExpeditionPage").hide()
	var page := AdventureChestPage.new()
	page.size = Vector2(408.0, 300.0)
	chest.get_node("%PageSlot").add_child(page)
	add_child_autofree(chest)
	assert_eq(chest.size.y, 406.0, "hugged as soon as the chest is ready")
	page.size.y = 400.0
	page.content_resized.emit()
	assert_eq(chest.size.y, 506.0, "followed when its content resizes")
	page.hide()
	assert_eq(chest.size.y, 176.0, "and when it is hidden")

#-----------------------------------------------------------------------------
# LAYOUT
#-----------------------------------------------------------------------------

func test_chest_stands_at_the_top_right_and_stops_clicks() -> void:
	assert_eq(_chest.position, CHEST_HOME)
	assert_eq(_chest.size.x, 440.0)
	assert_eq(_chest.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(_chest.theme, load(LACQUER_THEME_PATH))

func test_constants() -> void:
	assert_eq(AdventureChest.CHEST_TOP_HEIGHT, 128.0)
	assert_eq(AdventureChest.CHEST_BOTTOM_HEIGHT, 48.0)
	assert_eq(AdventureChest.MIN_CHEST_HEIGHT, 176.0)
	assert_eq(AdventureChest.PAGE_TOP, 82.0)
	assert_eq(AdventureChest.GAP_UNDER_PAGE, 24.0)

## The header's pieces sit where the kit puts them (chest-local: the mock's
## screen coordinates minus (1456, 24)). The title is the exception, 1 px above
## the mock's (16, 18), as the zone chest's name is (15 for the kit's 16): the
## mock's 44 px line box seats the 45 px tall Yatra glyphs half a px higher than
## a Label's top edge does, and its renderer rounds that to 1 px. At 17 the
## title's pixel rows fall on the mock's.
func test_header_sits_where_the_kit_puts_it() -> void:
	var label: Label = _title()
	assert_eq(label.position, Vector2(16.0, 17.0))
	assert_eq(label.size.x, 312.0)
	assert_eq(label.theme_type_variation, &"LabelLacquerZoneName")
	var clock: RunClock = _clock()
	assert_eq(Rect2(clock.position, clock.size), Rect2(336.0, 22.0, 88.0, 36.0))
	var page_slot: Control = _node("PageSlot") as Control
	assert_eq(page_slot.position, Vector2(16.0, 82.0))
	assert_eq(page_slot.size.x, 408.0)

func test_clock_pieces_sit_where_the_kit_puts_them() -> void:
	var recess: TextureRect = _clock_node("Recess") as TextureRect
	assert_eq(Rect2(recess.position, recess.size), Rect2(0.0, 0.0, 88.0, 36.0))
	assert_eq(recess.texture.resource_path, RECESS_PATH, "the carved recess to begin with")
	var hourglass: TextureRect = _clock().get_node("Hourglass") as TextureRect
	assert_eq(Rect2(hourglass.position, hourglass.size), Rect2(12.0, 10.0, 16.0, 16.0))
	assert_eq(hourglass.texture.resource_path, HOURGLASS_PATH)
	var label: Label = _clock_node("TimeLabel") as Label
	assert_eq(Rect2(label.position, label.size), Rect2(32.0, 7.0, 46.0, 22.0))
	assert_eq(label.theme_type_variation, &"LabelLacquerNowName")
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(label.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)

## The frame is the zone chest's: a 128 top, a middle that tiles, a 48 bottom
## (52 with the column's shadow), each 444 wide.
func test_frame_slices_are_the_zone_chests() -> void:
	_add_page(300.0)
	_chest.relayout()
	var top: TextureRect = _node("ChestTop") as TextureRect
	var mid: TextureRect = _node("ChestMid") as TextureRect
	var bottom: TextureRect = _node("ChestBottom") as TextureRect
	assert_eq(top.texture.resource_path, CHEST_TOP_PATH)
	assert_eq(Rect2(top.position, top.size), Rect2(0.0, 0.0, SLICE_WIDTH, 128.0))
	assert_eq(mid.texture.resource_path, CHEST_MID_PATH)
	assert_eq(Rect2(mid.position, mid.size), Rect2(0.0, 128.0, SLICE_WIDTH, 230.0))
	assert_eq(mid.stretch_mode, TextureRect.STRETCH_TILE, "the middle tiles")
	assert_eq(mid.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "and takes any height")
	assert_eq(bottom.texture.resource_path, CHEST_BOTTOM_PATH)
	assert_eq(Rect2(bottom.position, bottom.size), Rect2(0.0, 358.0, SLICE_WIDTH, 52.0))
	assert_eq((_chest.get_node("ChestFrame") as Control).size, _chest.size, "the frame's wrapper follows the chest")

## Every slice lets the pointer through to the chest, which stops it: a press
## on the frame never reaches the map behind.
func test_the_frame_lets_the_pointer_through_to_the_chest() -> void:
	for slice_name: String in ["ChestTop", "ChestMid", "ChestBottom"]:
		assert_eq((_node(slice_name) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the pointer" % slice_name)
	assert_eq((_chest.get_node("ChestFrame") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((_node("PageSlot") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "the slot is only a place for the pages")

#-----------------------------------------------------------------------------
# TEST DOUBLES
#-----------------------------------------------------------------------------

## A page whose content is taller or shorter than itself, as a page of flowing
## content is.
class TallContentPage extends AdventureChestPage:
	var content_height: float = 0.0

	## Returns the height the test set, whatever the page's own size is.
	func get_content_height() -> float:
		return content_height

## A page that notes whether it was asked for its height before it was ready.
class ReadyAwarePage extends AdventureChestPage:
	var asked_before_ready: bool = false

	## Returns the page's own height, noting an ask that came too early.
	func get_content_height() -> float:
		if not is_node_ready():
			asked_before_ready = true
		return size.y
