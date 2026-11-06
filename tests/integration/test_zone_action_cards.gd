extends GutTest

## Integration tests for the lacquer activity cards (ZoneActionButton and its
## presenters): the running tag, clicks, the NEW seal and when it clears, what
## each presenter's detail line and right column show, the adventure's Madra
## states and how gear moves them, and long text: no card cuts its text, a long
## title, detail, figure or list of finds wraps and the card grows by its lines.
## Cards are built with setup_action on a fresh save, as the zone panel builds
## them.

const CARD_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/zone_action_button.tscn")

const CYCLING_ID: String = "wilderness_cycling_action"
const AURA_WELL_ID: String = "aura_well_training"
const FORAGING_ID: String = "sprint_forest_foraging_action"
const ADVENTURE_ID: String = "shallow_woods_adventure_action"
const MERCHANT_ID: String = "spirit_valley_merchant"
const DIALOGUE_ID: String = "celestial_intervener_dialogue_1"
## "Return to the [INTERVENER]": not yet available on a fresh save, so unseen.
const RETURN_ID: String = "celestial_intervener_dialogue_2"

const FORAGING_EVENT: String = "q_fill_core_completed"
const AURA_WELL_EVENT: String = "aura_well_discovered"

## A card is 72 px for one title line and one detail line; each detail line after
## the first adds 18, each title line after the first 20.
const MIN_HEIGHT: float = 72.0
const DETAIL_LINE: float = 18.0
const TITLE_LINE: float = 20.0
## The detail row is 316 px; the right column takes at most half of it, with a
## 12 px gap before it.
const DETAIL_WIDTH: float = 316.0
const RIGHT_MAX_WIDTH: float = 158.0
const RIGHT_GAP: float = 12.0

## Player-log lines since the test started.
var _logged: Array[String] = []

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_logged.clear()
	LogManager.message_logged.connect(_on_message_logged)

func after_each() -> void:
	LogManager.message_logged.disconnect(_on_message_logged)
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

func _on_message_logged(bbcode_message: String) -> void:
	_logged.append(bbcode_message)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _card_for(action: ZoneActionData) -> ZoneActionButton:
	var card: ZoneActionButton = CARD_SCENE.instantiate() as ZoneActionButton
	card.setup_action(action)
	add_child_autofree(card)
	return card

func _card(action_id: String) -> ZoneActionButton:
	return _card_for(ZoneManager.get_action_by_id(action_id))

## Every visible Label and RichTextLabel text in the card.
func _texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for child: Node in node.get_children():
		var control := child as Control
		if control != null and not control.is_visible_in_tree():
			continue
		if child is Label:
			texts.append((child as Label).text)
		elif child is RichTextLabel:
			texts.append((child as RichTextLabel).get_parsed_text())
		texts.append_array(_texts(child))
	return texts

func _has_text_containing(card: Control, fragment: String) -> bool:
	for text: String in _texts(card):
		if text.contains(fragment):
			return true
	return false

func _tag_text(card: ZoneActionButton) -> String:
	return (card.get_node("%TagLabel") as Label).text

func _click(card: ZoneActionButton) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	card.gui_input.emit(press)

func _current_id() -> String:
	var current: ZoneActionData = ActionManager.get_current_action()
	return current.action_id if current else ""

## Unlocks the Aura Well, which starts it (the first idle unlock auto-starts).
func _run_aura_well() -> void:
	EventManager.trigger_event(AURA_WELL_EVENT)
	assert_eq(_current_id(), AURA_WELL_ID, "precondition: the Aura Well runs")

## Equips a fixture ring that adds this much Mind at Mind Lv 1 (a percent of
## mind / 10 of the trained Mind): 10 Madra of capacity per point.
func _equip_mind_ring(mind: float) -> void:
	var ring := EquipmentDefinitionData.new()
	ring.item_id = "test_zone_action_cards_ring"
	ring.item_name = "Fixture Ring"
	ring.slot_type = EquipmentDefinitionData.EquipmentSlot.ACCESSORY
	ring.stat_percent_bonuses[&"mind"] = mind / 10.0
	var instance := ItemInstanceData.new()
	instance.item_definition = ring
	InventoryManager.equip_item(instance, EquipmentDefinitionData.EquipmentSlot.ACCESSORY, -1, 0)

## The height of a card with this many detail lines under its title's lines (an
## unseen card's title can wrap beside its NEW seal).
func _height_for(card: ZoneActionButton, detail_lines: int) -> float:
	var title_lines: int = (card.get_node("%Title") as Label).get_line_count()
	return MIN_HEIGHT + DETAIL_LINE * (detail_lines - 1) + TITLE_LINE * (title_lines - 1)

## A story card's detail line: the default presenter's label.
func _detail_label(card: ZoneActionButton) -> Label:
	return card.get_detail_slot().find_child("DetailLabel", true, false) as Label

## A fixture material with a mini icon, so its yield shows an icon.
func _material(item_id: String, item_name: String) -> MaterialDefinitionData:
	var item := MaterialDefinitionData.new()
	item.item_id = item_id
	item.item_name = item_name
	item.icon = PlaceholderTexture2D.new()
	item.mini_icon = PlaceholderTexture2D.new()
	return item

func _loot_table(items: Array[MaterialDefinitionData]) -> LootTable:
	var entries: Array[LootTableEntry] = []
	for item: MaterialDefinitionData in items:
		var entry := LootTableEntry.new()
		entry.item = item
		entry.min_quantity = 1
		entry.max_quantity = 2
		entries.append(entry)
	var table := LootTable.new()
	table.entries = entries
	return table

func _story_fixture(action_name: String, description: String) -> ZoneActionData:
	var action := ZoneActionData.new()
	action.action_id = "test_zone_action_cards_story_fixture"
	action.action_name = action_name
	action.action_type = ZoneActionData.ActionType.NPC_DIALOGUE
	action.description = description
	return action

#-----------------------------------------------------------------------------
# THE RUNNING TAG
#-----------------------------------------------------------------------------

func test_running_card_is_tagged() -> void:
	var card: ZoneActionButton = _card(AURA_WELL_ID)
	_run_aura_well()
	assert_eq(_tag_text(card), "RUNNING")
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	assert_eq(_tag_text(card), "IDLE")

func test_card_built_while_running_reads_running() -> void:
	_run_aura_well()
	var card: ZoneActionButton = _card(AURA_WELL_ID)
	assert_eq(_tag_text(card), "RUNNING")

func test_running_session_action_is_not_tagged_running() -> void:
	var card: ZoneActionButton = _card(CYCLING_ID)
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	assert_eq(_tag_text(card), "ACTIVE", "only idle actions show RUNNING")

#-----------------------------------------------------------------------------
# CLICKS
#-----------------------------------------------------------------------------

func test_click_selects_the_action() -> void:
	_run_aura_well()
	EventManager.trigger_event(FORAGING_EVENT)
	var card: ZoneActionButton = _card(FORAGING_ID)
	_click(card)
	assert_eq(_current_id(), FORAGING_ID)

func test_click_on_running_card_signals_and_keeps_it() -> void:
	_run_aura_well()
	var card: ZoneActionButton = _card(AURA_WELL_ID)
	watch_signals(card)
	_click(card)
	assert_signal_emitted(card, "card_pressed_while_running")
	assert_eq(_current_id(), AURA_WELL_ID)

func test_unaffordable_click_does_not_select() -> void:
	_run_aura_well()
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	_logged.clear()
	_click(card)
	assert_eq(_current_id(), AURA_WELL_ID, "the idle action runs on")
	assert_eq(_logged.size(), 1, "the reject writes one log line")
	if _logged.size() == 1:
		assert_string_contains(_logged[0], "Not enough Madra")

#-----------------------------------------------------------------------------
# NEW SEAL
#-----------------------------------------------------------------------------

func test_new_seal_shows_for_unseen_action() -> void:
	assert_true(_card(MERCHANT_ID).is_new_shown(), "the merchant is unseen on a fresh save")
	assert_false(_card(DIALOGUE_ID).is_new_shown(), "the first init marks available actions seen")

## The seal stays while the pointer is on the card, so a card whose title wrapped
## beside it never shrinks under the pointer; the pointer leaving clears it.
func test_new_seal_clears_when_the_pointer_leaves() -> void:
	var card: ZoneActionButton = _card(MERCHANT_ID)
	card.mouse_entered.emit()
	assert_true(card.is_new_shown(), "the seal stays while the pointer is on the card")
	assert_false(ZoneManager.is_action_seen(MERCHANT_ID), "and the action is not seen yet")
	card.mouse_exited.emit()
	assert_false(card.is_new_shown(), "the pointer leaving clears it")
	assert_true(ZoneManager.is_action_seen(MERCHANT_ID))

func test_new_seal_clears_on_a_click() -> void:
	_run_aura_well()
	var card: ZoneActionButton = _card(MERCHANT_ID)
	card.mouse_entered.emit()
	_click(card)
	assert_false(card.is_new_shown(), "a click clears it at once, under the pointer")

func test_new_seal_clears_when_selected() -> void:
	var card: ZoneActionButton = _card(MERCHANT_ID)
	assert_true(card.is_new_shown(), "precondition: the merchant is unseen")
	ActionManager.select_action(ZoneManager.get_action_by_id(MERCHANT_ID))
	assert_false(card.is_new_shown())

#-----------------------------------------------------------------------------
# DETAIL LINES
#-----------------------------------------------------------------------------

## The Aura Well refills Madra only: its card names the trickle and no stat.
func test_training_detail() -> void:
	var card: ZoneActionButton = _card(AURA_WELL_ID)
	assert_has(_texts(card.get_detail_slot()), "+1.5 Madra / s", "the Madra rate on the left")
	assert_eq(card.get_detail_right_text(), "", "nothing in the right column below the max")

## At the max the trickle adds nothing, and the card says so; a spend clears it.
func test_training_card_says_madra_full_at_the_max() -> void:
	var card: ZoneActionButton = _card(AURA_WELL_ID)
	ResourceManager.add_madra(ResourceManager.get_max_madra(), true)
	assert_eq(card.get_detail_right_text(), "Madra full")
	assert_has(_texts(card.get_detail_slot()), "+1.5 Madra / s", "the rate stays on the left")
	ResourceManager.spend_madra(1.0)
	assert_eq(card.get_detail_right_text(), "", "below the max again")

## A training action whose levels grant a stat names it in the right column.
func test_training_detail_names_a_level_award() -> void:
	var action := ZoneManager.get_action_by_id(AURA_WELL_ID).duplicate() as TrainingActionData
	var award := AwardAttributeEffectData.new()
	award.attribute_type = CharacterAttributesData.AttributeType.SPIRIT
	action.effects_on_level = [award] as Array[EffectData]
	var card: ZoneActionButton = _card_for(action)
	assert_eq(card.get_detail_right_text(), "+1 Spirit / level")

func test_foraging_detail_names_what_it_finds() -> void:
	var card: ZoneActionButton = _card(FORAGING_ID)
	var texts: Array[String] = _texts(card.get_detail_slot())
	assert_has(texts, "Dewdrop Tear")
	assert_has(texts, "Spirit Fern")
	assert_eq(card.get_detail_right_text(), "", "no right column")

func test_foraging_icon_comes_from_the_item_data() -> void:
	# Any material can carry a mini icon: none is looked up by its id.
	var item := MaterialDefinitionData.new()
	item.item_id = "test_zone_action_cards_material"
	item.icon = PlaceholderTexture2D.new()
	item.mini_icon = PlaceholderTexture2D.new()
	var entry := LootTableEntry.new()
	entry.item = item
	entry.min_quantity = 1
	entry.max_quantity = 2
	var table := LootTable.new()
	table.entries = [entry] as Array[LootTableEntry]
	var action := ZoneManager.get_action_by_id(FORAGING_ID).duplicate() as ForageActionData
	action.loot_table = table
	var card: ZoneActionButton = _card_for(action)
	var icon: TextureRect = card.get_detail_slot().find_child("Icon", true, false) as TextureRect
	assert_eq(icon.texture, item.mini_icon)

func test_foraging_cost_shows_in_the_right_column() -> void:
	var action := ZoneManager.get_action_by_id(FORAGING_ID).duplicate() as ForageActionData
	action.madra_cost_per_second = 2.0
	var card: ZoneActionButton = _card_for(action)
	assert_eq(card.get_detail_right_text(), "costs 2 Madra / s")
	assert_has(_texts(card.get_detail_slot()), "Dewdrop Tear", "the finds stay on the left")

func test_merchant_detail() -> void:
	var card: ZoneActionButton = _card(MERCHANT_ID)
	assert_eq(_texts(card.get_detail_slot()), ["7 wares"] as Array[String])

func test_story_detail_is_the_description() -> void:
	var card: ZoneActionButton = _card_for(_story_fixture("The Intervener", "Your next story step"))
	assert_true(_has_text_containing(card, "Your next story step"))

#-----------------------------------------------------------------------------
# ADVENTURE
#-----------------------------------------------------------------------------

func test_adventure_below_threshold_shows_the_madra_figure() -> void:
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	assert_true(_has_text_containing(card, "25 / 50"), "Madra / threshold beside the rod")
	assert_false(_has_text_containing(card, "~"), "no countdown without a Madra action")

func test_adventure_hint_only_while_a_madra_action_runs() -> void:
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	_run_aura_well()
	assert_true(_has_text_containing(card, "~17 s"), "ceil((50 - 25) / 1.5) = 17")
	EventManager.trigger_event(FORAGING_EVENT)
	ActionManager.select_action(ZoneManager.get_action_by_id(FORAGING_ID))
	assert_eq(_current_id(), FORAGING_ID, "precondition: foraging runs, which makes no Madra")
	assert_false(_has_text_containing(card, "~"), "the hint hides")

func test_adventure_ready_copy_and_enter() -> void:
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	ResourceManager.set_madra(60.0)
	assert_has(_texts(card.get_detail_slot()), "5 min run", "the run's length on the left")
	assert_eq(card.get_detail_right_text(), "carries 100 Madra", "the Madra it carries in the right column")
	assert_eq(_tag_text(card), "ENTER")
	assert_false(_has_text_containing(card, "/ 50"), "the Madra row hides at the threshold")

func test_adventure_drops_back_below_threshold() -> void:
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	ResourceManager.set_madra(60.0)
	ResourceManager.set_madra(10.0)
	assert_eq(_tag_text(card), "ACTIVE")
	assert_true(_has_text_containing(card, "10 / 50"))
	assert_false(_has_text_containing(card, "min run"), "the ready line hides")
	assert_eq(card.get_detail_right_text(), "", "and so does its right column")

#-----------------------------------------------------------------------------
# LONG TEXT: NO CARD CUTS ITS TEXT, IT GROWS
#-----------------------------------------------------------------------------

## The card's height follows its lines: 72 for one title line and one detail
## line, 18 more for each detail line, 20 more for each title line.
func test_a_card_grows_by_its_lines() -> void:
	var cases: Array[Dictionary] = [
		{"name": "one line each", "title": "The Intervener", "description": "Your next story step", "title_lines": 1, "detail_lines": 1},
		{"name": "two detail lines", "title": "The Intervener", "description": "word ".repeat(10).strip_edges(), "title_lines": 1, "detail_lines": 2},
		{"name": "three detail lines", "title": "The Intervener", "description": "word ".repeat(18).strip_edges(), "title_lines": 1, "detail_lines": 3},
		{"name": "two title lines", "title": "The Intervener's Second Lesson by the River", "description": "Your next story step", "title_lines": 2, "detail_lines": 1},
	]
	for case: Dictionary in cases:
		# Seen, so no NEW seal narrows the title.
		var action: ZoneActionData = _story_fixture(case.title, case.description)
		ZoneManager.mark_action_seen(action.action_id)
		var card: ZoneActionButton = _card_for(action)
		var title := card.get_node("%Title") as Label
		var detail := _detail_label(card)
		assert_eq(title.get_line_count(), case.title_lines, "%s: the title's lines" % case.name)
		assert_eq(detail.get_line_count(), case.detail_lines, "%s: the detail's lines" % case.name)
		assert_eq(detail.get_visible_line_count(), detail.get_line_count(), "%s: every detail line shows" % case.name)
		var height: float = MIN_HEIGHT + DETAIL_LINE * (case.detail_lines - 1) + TITLE_LINE * (case.title_lines - 1)
		assert_eq(card.custom_minimum_size.y, height, "%s: the card's height" % case.name)
		assert_eq(card.size.y, height, "%s: and its size" % case.name)

## The first card of a new game: its description takes three lines, all shown.
func test_the_first_talk_shows_its_whole_description() -> void:
	var card: ZoneActionButton = _card(DIALOGUE_ID)
	var detail := _detail_label(card)
	assert_eq(detail.text, ZoneManager.get_action_by_id(DIALOGUE_ID).description, "the whole description")
	assert_eq(detail.get_line_count(), 3)
	assert_eq(detail.get_visible_line_count(), 3, "every line shows")
	assert_eq(card.size.y, MIN_HEIGHT + 2.0 * DETAIL_LINE)

## "Return to the [INTERVENER]" fits a line beside the tag but not beside the
## seal: it wraps there and takes its room back once the seal clears.
func test_a_title_wraps_beside_its_seal_and_takes_its_room_back() -> void:
	var card: ZoneActionButton = _card(RETURN_ID)
	var title := card.get_node("%Title") as Label
	assert_true(card.is_new_shown(), "precondition: the return is unseen")
	assert_eq(title.text, "Return to the [INTERVENER]", "the whole title")
	assert_eq(title.get_line_count(), 2, "it wraps beside the seal")
	var tall: float = MIN_HEIGHT + TITLE_LINE + DETAIL_LINE
	assert_eq(card.size.y, tall, "two title lines and two detail lines")
	card.mouse_entered.emit()
	assert_eq(card.size.y, tall, "the card keeps its height under the pointer")
	card.mouse_exited.emit()
	assert_eq(title.get_line_count(), 1, "the title takes the seal's room back")
	assert_eq(card.size.y, MIN_HEIGHT + DETAIL_LINE, "and the card is a line shorter")

## An idle card's figure past half the line wraps whole at half the line, and
## the left part keeps the room it leaves (Review Focus 3).
func test_an_idle_right_column_past_half_wraps_whole() -> void:
	var card: ZoneActionButton = _card(AURA_WELL_ID)
	var figure: String = "+1 Spirit / level until Spirit Lv 10"
	card.set_detail_right(figure)
	var right := card.get_node("%DetailRight") as RichTextLabel
	assert_eq(card.get_detail_right_text(), figure, "the whole figure")
	assert_eq(right.get_line_count(), 2, "on two lines")
	assert_eq(card.get_detail_room(), DETAIL_WIDTH - RIGHT_MAX_WIDTH - RIGHT_GAP, "the left part keeps the rest")
	assert_has(_texts(card.get_detail_slot()), "+1.5 Madra / s", "and its whole text")
	assert_eq(card.size.y, MIN_HEIGHT + DETAIL_LINE, "the card grows with the figure")

## With a Madra cost in the right column the two finds no longer fit one line:
## the second moves to the next line whole.
func test_finds_flow_onto_a_second_line() -> void:
	var action := ZoneManager.get_action_by_id(FORAGING_ID).duplicate() as ForageActionData
	action.madra_cost_per_second = 2.0
	var card: ZoneActionButton = _card_for(action)
	var texts: Array[String] = _texts(card.get_detail_slot())
	assert_has(texts, "Dewdrop Tear")
	assert_has(texts, "Spirit Fern")
	var yields: Array[Node] = card.get_detail_slot().find_children("YieldText", "RichTextLabel", true, false)
	assert_eq(yields.size(), 2, "precondition: one yield per find")
	if yields.size() == 2:
		var first_line: Node = yields[0].get_parent().get_parent()
		var second_line: Node = yields[1].get_parent().get_parent()
		assert_ne(first_line, second_line, "the second find is on a line of its own")
		assert_eq(first_line.get_parent(), second_line.get_parent(), "one line under the other")
	assert_eq(card.size.y, _height_for(card, 2), "the card grows by the second line")

## A find whose name is wider than the whole line wraps inside its yield instead
## of running past the card (Review Focus 4).
func test_a_find_too_long_for_the_line_wraps_inside_it() -> void:
	var long_name: String = "word ".repeat(40).strip_edges()
	var action := ZoneManager.get_action_by_id(FORAGING_ID).duplicate() as ForageActionData
	action.loot_table = _loot_table([_material("test_zone_action_cards_long_find", long_name)])
	var card: ZoneActionButton = _card_for(action)
	var name_text := card.get_detail_slot().find_child("YieldText", true, false) as RichTextLabel
	assert_eq(name_text.get_parsed_text(), long_name, "the whole name")
	assert_gt(name_text.get_line_count(), 1, "on several lines")
	# Positions come from the containers' sort, a frame later; heights do not.
	await wait_process_frames(1)
	var slot_right: float = card.get_detail_slot().get_global_rect().end.x
	assert_lte(name_text.get_global_rect().end.x, slot_right, "inside the detail line")
	assert_eq(card.size.y, _height_for(card, name_text.get_line_count()), "the card grows by the name's lines")

## A time hint too wide to sit beside the Madra figure takes a line of its own
## instead of covering the rod (Review Focus 5).
func test_the_madra_hint_takes_its_own_line_when_it_does_not_fit() -> void:
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	_run_aura_well()
	assert_eq(card.size.y, MIN_HEIGHT, "precondition: the figure and its hint share a line")
	_equip_mind_ring(5000.0)
	var figure := card.get_detail_slot().find_child("MadraFigure", true, false) as Label
	var hint := card.get_detail_slot().find_child("HintLabel", true, false) as Label
	assert_true(hint.visible, "precondition: a Madra action runs")
	assert_eq(hint.position.y - figure.position.y, DETAIL_LINE, "the hint takes the next line")
	assert_eq(card.size.y, MIN_HEIGHT + DETAIL_LINE, "and the card grows")

#-----------------------------------------------------------------------------
# ADVENTURE AND EQUIPMENT
#-----------------------------------------------------------------------------

func test_adventure_follows_equipment_capacity() -> void:
	# Capacity is max Madra (Mind x 10) and the threshold half of it, so
	# gear that adds Mind moves both without any Madra change.
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	ResourceManager.set_madra(60.0)
	assert_eq(_tag_text(card), "ENTER", "precondition: 60 of 50 Madra is ready")
	_equip_mind_ring(5.0)
	assert_eq(_tag_text(card), "ACTIVE", "the threshold is now 75")
	assert_true(_has_text_containing(card, "60 / 75"))
	ResourceManager.set_madra(80.0)
	assert_true(_has_text_containing(card, "carries 150 Madra"))
	InventoryManager.unequip_item(EquipmentDefinitionData.EquipmentSlot.ACCESSORY, 0)
	assert_true(_has_text_containing(card, "carries 100 Madra"), "taking the ring off shrinks it again")
