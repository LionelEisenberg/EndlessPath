class_name ActivityList
extends Control

## The zone chest's scrolling list of activity cards (lacquer kit §5.5, §0).
## Cards are grouped Talk, Cultivate, Gather, Venture, Visit
## (ZoneActionGroups), each group under a tan label with a carved groove.
## The flow, from content y 0: a group label row (18) and a 6 px gap, cards
## 8 px apart, groups 14 apart, 4 px under the last card. An empty list
## reads "Nothing to do here yet.".
## The list scrolls under its own brass rail (LacquerRail) with the native
## scrollbar hidden, and a hard shelf lip shows at an edge the list is
## scrolled away from. The zone panel sizes the list: it reads the content
## height and the fold heights (8 px under each whole drawer) to pick a
## height that never cuts a drawer.

## Emitted when the content height changes (a rebuild, or a card switching
## between the short and the tall drawer).
signal layout_changed

## Emitted when the player clicks the card of the idle action that runs.
signal card_pressed_while_running

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const CARD_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/zone_action_button.tscn")
const GROUP_SCENE: PackedScene = preload("res://scenes/zones/zone_panel/activity_list/activity_group_label.tscn")

## The flow (kit §5.5): a group's label row and the gap under it, the gap
## between cards, between groups, and under the last card.
const GROUP_HEADER_HEIGHT: float = 24.0
const CARD_GAP: float = 8.0
const GROUP_GAP: float = 14.0
const BOTTOM_PADDING: float = 4.0
## An empty list holds its one line: 8 above, 18 for the line, 4 under.
const EMPTY_CONTENT_HEIGHT: float = 30.0
## A fold sits this far under a whole drawer.
const FOLD_GAP: float = 8.0
## scroll_to_action leaves this much room around the card.
const SCROLL_MARGIN: float = 24.0
## The list counts as scrolled away from an edge beyond this many px.
const EDGE_SLACK: float = 2.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _scroll: ScrollContainer = %Scroll
@onready var _content: VBoxContainer = %Content
@onready var _empty_margin: Control = %EmptyMargin
@onready var _lip_top: Control = %LipTop
@onready var _lip_bottom: Control = %LipBottom
@onready var _rail: LacquerRail = %Rail

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

## The cards, by group, top to bottom.
var _groups: Array[Array] = []
var _cards_by_id: Dictionary = {}

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_rail.bind(_scroll)
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	bar.value_changed.connect(_on_scroll_value_changed)
	bar.changed.connect(_refresh_lips)
	_scroll.resized.connect(_refresh_lips)
	_refresh_lips()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Replaces the cards with one per action, grouped and ordered by
## ZoneActionGroups. With keep_scroll false the list goes back to the top.
func build(actions: Array[ZoneActionData], keep_scroll: bool = false) -> void:
	var scroll: int = _scroll.scroll_vertical if keep_scroll else 0
	_clear()
	var group_by_id: Dictionary = {}
	for action: ZoneActionData in ZoneActionGroups.sort_actions(actions):
		var group: int = ZoneActionGroups.group_of(action.action_type)
		if not group_by_id.has(group):
			group_by_id[group] = _add_group(ZoneActionGroups.label(group))
		_add_card(action, group_by_id[group] as VBoxContainer)
	_empty_margin.visible = _groups.is_empty()
	_scroll.scroll_vertical = 0
	if scroll > 0:
		# The scroll range follows the new content only once the containers
		# have sorted, which they do before deferred calls run.
		_restore_scroll.call_deferred(scroll)
	layout_changed.emit()

## Returns the card of the action, or null when the list has none.
func get_card(action_id: String) -> ZoneActionButton:
	var card: ZoneActionButton = _cards_by_id.get(action_id, null) as ZoneActionButton
	return card if is_instance_valid(card) else null

## Returns the height of the list's content, its padding included.
func get_content_height() -> float:
	return _compute_flow().content

## Returns the list heights that end 8 px under a whole drawer, top to
## bottom. A list of one of these heights never cuts a drawer.
func get_fold_heights() -> Array[float]:
	return _compute_flow().folds

## Scrolls only as far as needed to show the whole card with 24 px around it
## (not at all when it already shows), then flashes it.
func scroll_to_action(action_id: String) -> void:
	var card: ZoneActionButton = get_card(action_id)
	if card == null:
		return
	var flow: Dictionary = _compute_flow()
	var top: float = (flow.tops as Dictionary)[action_id]
	var view: float = _scroll.size.y
	var current: float = float(_scroll.scroll_vertical)
	var target: float = current
	var above: float = top - SCROLL_MARGIN
	var below: float = top + _card_height(card) + SCROLL_MARGIN - view
	if above < current:
		target = above
	elif below > current:
		target = below
	target = clampf(target, 0.0, maxf(0.0, (flow.content as float) - view))
	if absf(target - current) >= 1.0:
		_rail.step_to(target)
	card.flash()

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _clear() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_groups.clear()
	_cards_by_id.clear()

## Adds a labelled group and returns its card column.
func _add_group(label_text: String) -> VBoxContainer:
	var group: Control = GROUP_SCENE.instantiate() as Control
	_content.add_child(group)
	(group.get_node("%GroupLabel") as Label).text = label_text
	_groups.append([])
	return group.get_node("%Cards") as VBoxContainer

func _add_card(action: ZoneActionData, column: VBoxContainer) -> void:
	var card: ZoneActionButton = CARD_SCENE.instantiate() as ZoneActionButton
	card.setup_action(action)
	column.add_child(card)
	card.minimum_size_changed.connect(_on_card_minimum_size_changed)
	card.card_pressed_while_running.connect(_on_card_pressed_while_running)
	_groups[-1].append(card)
	_cards_by_id[action.action_id] = card

func _restore_scroll(scroll: int) -> void:
	_scroll.scroll_vertical = scroll

func _card_height(card: Control) -> float:
	return card.get_combined_minimum_size().y

## Walks the flow the containers lay out (kit §5.5) and returns the content
## height, the fold heights, and each card's top, keyed by action id.
func _compute_flow() -> Dictionary:
	var folds: Array[float] = []
	var tops: Dictionary = {}
	if _groups.is_empty():
		return {"content": EMPTY_CONTENT_HEIGHT, "folds": folds, "tops": tops}
	var y: float = 0.0
	for group_index: int in _groups.size():
		if group_index > 0:
			y += GROUP_GAP
		y += GROUP_HEADER_HEIGHT
		var cards: Array = _groups[group_index]
		for card_index: int in cards.size():
			var card: ZoneActionButton = cards[card_index] as ZoneActionButton
			if card_index > 0:
				y += CARD_GAP
			tops[card.action_data.action_id] = y
			y += _card_height(card)
			folds.append(y + FOLD_GAP)
	return {"content": y + BOTTOM_PADDING, "folds": folds, "tops": tops}

## The top lip shows while the list is scrolled down from its top, the
## bottom lip while there is more below.
func _refresh_lips() -> void:
	var view: float = _scroll.size.y
	var content: float = _scroll.get_v_scroll_bar().max_value
	var scroll: float = float(_scroll.scroll_vertical)
	var overflows: bool = content > view
	_lip_top.visible = overflows and scroll > EDGE_SLACK
	_lip_bottom.visible = overflows and scroll + view < content - EDGE_SLACK

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_scroll_value_changed(_value: float) -> void:
	_refresh_lips()

func _on_card_minimum_size_changed() -> void:
	layout_changed.emit()

func _on_card_pressed_while_running() -> void:
	card_pressed_while_running.emit()
