extends GutTest

## Integration tests for the adventure's chest (AdventureChest) and the run
## clock in its header (RunClock): the clock following the run's Timer and
## turning to the low-time seal, the title wrapping in its slot and pushing the
## page down (the developer's rule: no text is cut off), the chest hugging its
## visible page (never shorter than 176) and following that page's
## content_resized. A plain AdventureChestPage stands in for the pages the chest
## will hold. The clock's two pure rules (M:SS and the 30 s threshold) are in
## test_run_clock.gd.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const CHEST_SCENE: PackedScene = preload("res://scenes/adventure/adventure_chest/adventure_chest.tscn")

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

func test_clock_turns_to_the_seal_when_low() -> void:
	var timer: Timer = _held_timer(31.0)
	_clock().bind_timer(timer)
	await wait_process_frames(1)
	assert_false(_clock().is_low_shown(), "31 s: the carved recess")
	timer.start(30.0)
	await wait_process_frames(1)
	assert_true(_clock().is_low_shown(), "30 s: the seal")
	assert_eq(_time_text(), "0:30", "and the time still reads")
	timer.start(90.0)
	await wait_process_frames(1)
	assert_false(_clock().is_low_shown(), "a new run starts on the recess again")
	assert_eq(_time_text(), "1:30")

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

## A new run starts from a tween callback, which steps after the frame's
## _process, so a clock that painted only in _process would show the last run's
## end for the first frame of the next: after a timeout, "0:00" on the vermilion
## seal. Binding a timer paints the clock at once: nothing is awaited here.
func test_binding_a_timer_paints_the_clock_before_any_frame_passes() -> void:
	var timed_out: Timer = _held_timer(0.5)
	_clock().bind_timer(timed_out)
	await wait_process_frames(1)
	assert_eq(_time_text(), "0:00", "precondition: the last run ended on 0:00")
	assert_true(_clock().is_low_shown(), "precondition: on the seal")

	_clock().bind_timer(_held_timer(300.0))

	assert_eq(_time_text(), "5:00", "the fresh run's time shows before any frame passes")
	assert_false(_clock().is_low_shown(), "on the normal recess")

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
	assert_eq(_time_text(), "0:20", "bound again, the timer's time shows at once")
	timer.free()
	await wait_process_frames(2)
	assert_eq(_time_text(), "0:20", "a freed timer leaves the clock as it was")

#-----------------------------------------------------------------------------
# TITLE
#-----------------------------------------------------------------------------

func test_set_title() -> void:
	_chest.set_title("The Shallow Woods")
	assert_eq(_title().text, "The Shallow Woods")
	_chest.set_title("Amorphous Spirit")
	assert_eq(_title().text, "Amorphous Spirit", "a new title replaces it")

## A long adventure name wraps in its 312 px, never widening the chest or running
## under the clock, and the page under it moves down by the lines it adds (44 px
## each: the title's line pitch), so the chest grows by as much.
func test_a_long_title_wraps_and_pushes_the_page_down() -> void:
	var long_title: String = ("The Shallow Woods Beyond The Edge Of The Known World ").repeat(2).left(60)
	assert_eq(long_title.length(), 60, "precondition: 60 characters")
	_add_page(300.0)
	_chest.relayout()
	var plain_height: float = _chest.size.y

	_chest.set_title(long_title)
	await wait_process_frames(2)

	var label: Label = _title()
	var font: Font = label.get_theme_font(&"font")
	var natural_width: float = font.get_string_size(long_title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label.get_theme_font_size(&"font_size")).x
	assert_gt(natural_width, 312.0, "precondition: the text is wider than its slot")
	assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "wrapped, never trimmed")
	assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_gt(label.get_line_count(), 1, "the title takes more than one line")
	assert_lte(label.size.x, 312.0, "the label stays within its 312 px")
	assert_eq(_chest.size.x, 440.0, "and the chest stays 440 wide")
	assert_lte(label.get_global_rect().end.x, _clock().get_global_rect().position.x, "the title stops before the clock")
	var extra: float = 44.0 * (label.get_line_count() - 1)
	assert_eq((_node("PageSlot") as Control).position.y, 82.0 + extra, "the page stands lower by each line's 44 px")
	assert_eq(_chest.size.y, plain_height + extra, "and the chest is taller by as much")

#-----------------------------------------------------------------------------
# HEIGHT
#-----------------------------------------------------------------------------

func test_relayouts_on_content_resized() -> void:
	var page: AdventureChestPage = _add_page(300.0)
	page.content_resized.emit()
	assert_eq(_chest.size.y, 406.0, "the signal alone sizes the chest")
	page.size.y = 400.0
	assert_eq(_chest.size.y, 406.0, "nothing moves until the page says its content resized")
	page.content_resized.emit()
	assert_eq(_chest.size.y, 506.0)
	page.size.y = 20.0
	page.content_resized.emit()
	assert_eq(_chest.size.y, 176.0, "and back down to the minimum")

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
