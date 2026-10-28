class_name AdventureChest
extends Control

## The adventure's chest at the view's top right, where the zone view keeps its
## zone chest (lacquer kit §5.5): the lacquer frame, a title in the zone
## name's Yatra One, the run clock, and under them the page for what the
## player is doing (the expedition on the map; the opponent in a fight).
## The pages are AdventureChestPage nodes under %PageSlot, 408 wide from the
## chest-local point (16, 82), and only the visible one counts. The chest
## hugs it: max(176, 82 + the page's content height + 24) tall, rounded to an
## even number as the mock's chest is. It lays itself out again when the
## visible page emits content_resized, when the page that shows changes, when the
## title changes, and when relayout() is called.
## The frame is the zone chest's: a 128 px top, a tiled middle and a 48 px
## bottom. Each slice carries its part of the column's 4 px shadow, so the
## slices are 444 wide and only the middle and the bottom follow the height.
## No text is cut off: the title wraps in its 312 px, so a long name never widens
## the chest or runs under the clock, and the page under it stands lower by each
## line the title adds (44 px, its line pitch), which the chest hugs with it.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The frame's slices: top and bottom heights; the middle tiles between.
const CHEST_TOP_HEIGHT: float = 128.0
const CHEST_BOTTOM_HEIGHT: float = 48.0
const MIN_CHEST_HEIGHT: float = 176.0
## Where the page slot starts under the header, and the room under the page.
const PAGE_TOP: float = 82.0
const GAP_UNDER_PAGE: float = 24.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _chest_mid: Control = %ChestMid
@onready var _chest_bottom: Control = %ChestBottom
@onready var _title_label: Label = %TitleLabel
@onready var _run_clock: RunClock = %RunClock
@onready var _page_slot: Control = %PageSlot
@onready var _expedition_page: ExpeditionPage = %ExpeditionPage

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_page_slot.child_entered_tree.connect(_on_page_slot_child_entered)
	for child: Node in _page_slot.get_children():
		_watch_page(child)
	relayout()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows title in the header: the adventure's name on the map, the opponent's
## in a fight. A long one wraps, and the page and the chest follow.
func set_title(text: String) -> void:
	_title_label.text = text
	relayout()

## Returns the run clock in the header, for the run's Timer to be bound to.
func get_run_clock() -> RunClock:
	return _run_clock

## Returns the expedition page, the page for the map: the Here tray, the
## encounter's choices and the Run ledger. The view feeds it the tile the player
## stands on and the run's figures, and listens to its choice_selected.
func get_expedition_page() -> ExpeditionPage:
	return _expedition_page

## Sizes the chest to the visible page (82 + the lines the title adds + its
## content height + 24, at least 176, rounded to an even number), stands the page
## slot where the title leaves it and places the middle and the bottom slice to
## match. With no page showing, the chest is its 176 px minimum.
func relayout() -> void:
	if not is_node_ready():
		return
	var content_height: float = 0.0
	var page: AdventureChestPage = _get_visible_page()
	if page != null:
		content_height = page.get_content_height()
	var page_top: float = PAGE_TOP + _title_extra_height()
	var chest_height: float = maxf(MIN_CHEST_HEIGHT, _round_to_even(page_top + content_height + GAP_UNDER_PAGE))
	_page_slot.position.y = page_top
	_page_slot.size.y = content_height
	size.y = chest_height
	_chest_mid.size.y = chest_height - CHEST_TOP_HEIGHT - CHEST_BOTTOM_HEIGHT
	_chest_bottom.position.y = chest_height - CHEST_BOTTOM_HEIGHT

#-----------------------------------------------------------------------------
# PAGES
#-----------------------------------------------------------------------------

## Returns the first page in the slot that is shown, or null. A page counts
## by its own visible flag, so hiding the whole chest does not shrink it.
func _get_visible_page() -> AdventureChestPage:
	for child: Node in _page_slot.get_children():
		var page := child as AdventureChestPage
		if page != null and page.visible:
			return page
	return null

## Lays the chest out again whenever the page says its content changed or the
## page is shown or hidden. Connects once however often it is asked.
func _watch_page(node: Node) -> void:
	var page := node as AdventureChestPage
	if page == null:
		return
	if not page.content_resized.is_connected(relayout):
		page.content_resized.connect(relayout)
	if not page.visibility_changed.is_connected(relayout):
		page.visibility_changed.connect(relayout)

## How much taller the title is than its one line (the scene's 45 px): each line
## after the first is 44 px, an even number, so the page's top stays even.
func _title_extra_height() -> float:
	return maxf(_title_label.get_combined_minimum_size().y - _title_label.custom_minimum_size.y, 0.0)

## The nearest even number, an odd one rounding up (the mock's even()).
func _round_to_even(value: float) -> float:
	return roundf(value / 2.0) * 2.0

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## A page that joins the slot is watched, and hugged once it is ready: its
## content height may need nodes that are not ready as it enters the tree.
func _on_page_slot_child_entered(node: Node) -> void:
	_watch_page(node)
	relayout.call_deferred()
