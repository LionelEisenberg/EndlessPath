extends GutTest

## Integration tests for the lacquer activity cards (ZoneActionButton and its
## presenters): mode tags, the running drawer, the NEW seal, each presenter's
## detail line, the adventure's Madra states, the tall drawer for long details,
## and long text never widening a card (Review Focus 4). Cards are built with
## setup_action on a fresh save, as the zone panel builds them.

const CARD_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/zone_action_button.tscn")

const CYCLING_ID: String = "wilderness_cycling_action"
const AURA_WELL_ID: String = "aura_well_training"
const FORAGING_ID: String = "sprint_forest_foraging_action"
const ADVENTURE_ID: String = "shallow_woods_adventure_action"
const MERCHANT_ID: String = "spirit_valley_merchant"
const DIALOGUE_ID: String = "celestial_intervener_dialogue_1"

const FORAGING_EVENT: String = "q_fill_core_completed"
const AURA_WELL_EVENT: String = "aura_well_discovered"

const CARD_WIDTH: float = 392.0
const SHORT_HEIGHT: float = 72.0
const TALL_HEIGHT: float = 96.0

const FIXTURE_TECHNIQUE_ID: String = "test_zone_action_cards_technique"

## CyclingManager's technique index while a test adds its fixture technique.
## Other tests may leave the index empty, so these tests never rely on it.
var _saved_technique_index: Dictionary = {}
var _technique_index_swapped: bool = false

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
	if _technique_index_swapped:
		CyclingManager._techniques_by_id = _saved_technique_index
		_technique_index_swapped = false

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

func _drawer(card: ZoneActionButton) -> Control:
	return card.get_node("%Drawer") as Control

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

## Equips a fixture cycling technique with this name (the index is restored
## after the test).
func _equip_technique_named(technique_name: String) -> void:
	var technique := CyclingTechniqueData.new()
	technique.id = FIXTURE_TECHNIQUE_ID
	technique.technique_name = technique_name
	_saved_technique_index = CyclingManager._techniques_by_id
	_technique_index_swapped = true
	var index: Dictionary = _saved_technique_index.duplicate()
	index[FIXTURE_TECHNIQUE_ID] = technique
	CyclingManager._techniques_by_id = index
	PersistenceManager.save_game_data.equipped_cycling_technique_id = FIXTURE_TECHNIQUE_ID

func _story_fixture(action_name: String, description: String) -> ZoneActionData:
	var action := ZoneActionData.new()
	action.action_id = "test_zone_action_cards_story_fixture"
	action.action_name = action_name
	action.action_type = ZoneActionData.ActionType.NPC_DIALOGUE
	action.description = description
	return action

#-----------------------------------------------------------------------------
# MODE TAGS AND THE RUNNING DRAWER
#-----------------------------------------------------------------------------

func test_mode_tags_per_type() -> void:
	assert_eq(_tag_text(_card(CYCLING_ID)), "ACTIVE")
	assert_eq(_tag_text(_card(AURA_WELL_ID)), "IDLE")
	assert_eq(_tag_text(_card(FORAGING_ID)), "IDLE")
	assert_eq(_tag_text(_card(ADVENTURE_ID)), "ACTIVE", "below the threshold the adventure is ACTIVE")
	assert_eq(_tag_text(_card(MERCHANT_ID)), "SHOP")
	assert_eq(_tag_text(_card(DIALOGUE_ID)), "STORY")

func test_cards_are_fixed_width() -> void:
	var card: ZoneActionButton = _card(AURA_WELL_ID)
	assert_eq(card.size, Vector2(CARD_WIDTH, SHORT_HEIGHT))
	assert_eq(card.custom_minimum_size, Vector2(CARD_WIDTH, SHORT_HEIGHT))

func test_running_card_is_pulled_out_and_tagged() -> void:
	var card: ZoneActionButton = _card(AURA_WELL_ID)
	assert_eq(_drawer(card).position, Vector2.ZERO, "a resting drawer sits in place")
	_run_aura_well()
	assert_eq(_tag_text(card), "RUNNING")
	assert_eq(_drawer(card).position, Vector2(-2, -2), "the running drawer is pulled out")
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	assert_eq(_drawer(card).position, Vector2.ZERO)
	assert_eq(_tag_text(card), "IDLE")

func test_card_built_while_running_starts_pulled_out() -> void:
	_run_aura_well()
	var card: ZoneActionButton = _card(AURA_WELL_ID)
	assert_eq(_tag_text(card), "RUNNING")
	assert_eq(_drawer(card).position, Vector2(-2, -2))

func test_running_session_action_is_not_pulled_out() -> void:
	var card: ZoneActionButton = _card(CYCLING_ID)
	ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))
	assert_eq(_tag_text(card), "ACTIVE", "only idle actions show RUNNING")
	assert_eq(_drawer(card).position, Vector2.ZERO)

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

func test_new_seal_clears_on_hover() -> void:
	var card: ZoneActionButton = _card(MERCHANT_ID)
	card.mouse_entered.emit()
	assert_false(card.is_new_shown())
	assert_true(ZoneManager.is_action_seen(MERCHANT_ID))

func test_new_seal_clears_when_selected() -> void:
	var card: ZoneActionButton = _card(MERCHANT_ID)
	assert_true(card.is_new_shown(), "precondition: the merchant is unseen")
	ActionManager.select_action(ZoneManager.get_action_by_id(MERCHANT_ID))
	assert_false(card.is_new_shown())

#-----------------------------------------------------------------------------
# DETAIL LINES
#-----------------------------------------------------------------------------

func test_training_detail() -> void:
	assert_true(_has_text_containing(_card(AURA_WELL_ID), "+1.5 Madra / s · each level +1 Spirit"))

func test_foraging_detail_has_ranges_interval_and_cost() -> void:
	var card: ZoneActionButton = _card(FORAGING_ID)
	assert_true(_has_text_containing(card, "1–5"), "Dewdrop Tear range")
	assert_true(_has_text_containing(card, "2–6"), "Spirit Fern range")
	assert_true(_has_text_containing(card, "every 5 s · free"))

func test_foraging_cost_replaces_free() -> void:
	var action := ZoneManager.get_action_by_id(FORAGING_ID).duplicate() as ForageActionData
	action.madra_cost_per_second = 2.0
	var card: ZoneActionButton = _card_for(action)
	assert_true(_has_text_containing(card, "every 5 s · 2 Madra / s"))
	assert_false(_has_text_containing(card, "free"))

func test_cycling_detail_names_the_technique() -> void:
	_equip_technique_named("Calm")
	assert_true(_has_text_containing(_card(CYCLING_ID), "Calm · Madra and Core Density XP"))

func test_merchant_detail() -> void:
	ResourceManager.set_gold(120.0)
	var expected: String = "7 wares · you have 120 gold"
	assert_true(_has_text_containing(_card(MERCHANT_ID), expected))

func test_merchant_detail_follows_gold() -> void:
	var card: ZoneActionButton = _card(MERCHANT_ID)
	ResourceManager.set_gold(42.0)
	assert_true(_has_text_containing(card, "you have 42 gold"))

func test_story_detail_is_the_description() -> void:
	var card: ZoneActionButton = _card_for(_story_fixture("The Intervener", "Your next story step"))
	assert_true(_has_text_containing(card, "Your next story step"))
	assert_eq(_tag_text(card), "STORY")

#-----------------------------------------------------------------------------
# ADVENTURE
#-----------------------------------------------------------------------------

func test_adventure_below_threshold_copy() -> void:
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	assert_true(_has_text_containing(card, "Needs 50 Madra · you have 25"))
	assert_true(_has_text_containing(card, "train or cycle to fill"))
	assert_eq(card.size.y, TALL_HEIGHT, "the adventure uses the tall drawer")

func test_adventure_hint_with_aura_well() -> void:
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	_run_aura_well()
	assert_true(_has_text_containing(card, "ready in ~17 s"), "ceil((50 - 25) / 1.5) = 17")
	assert_false(_has_text_containing(card, "train or cycle to fill"))

func test_adventure_rod_follows_madra() -> void:
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	var rod: LacquerRod = card.get_footer_slot().find_child("MadraRod", true, false) as LacquerRod
	assert_not_null(rod, "the Madra rod sits in the footer")
	if rod:
		assert_eq(rod.get_step(), 37, "25 / 50 of 74 steps")
		ResourceManager.set_madra(40.0)
		assert_eq(rod.get_step(), roundi(40.0 / 50.0 * 74.0))

func test_adventure_ready_copy_and_enter() -> void:
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	ResourceManager.set_madra(60.0)
	assert_true(_has_text_containing(card, "Ready · carries up to 100 Madra · 5 min run"))
	assert_eq(_tag_text(card), "ENTER")
	assert_false(_has_text_containing(card, "Needs"), "the Madra line hides at the threshold")
	assert_eq(card.size.y, TALL_HEIGHT)

func test_adventure_drops_back_below_threshold() -> void:
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	ResourceManager.set_madra(60.0)
	ResourceManager.set_madra(10.0)
	assert_eq(_tag_text(card), "ACTIVE")
	assert_true(_has_text_containing(card, "Needs 50 Madra · you have 10"))

#-----------------------------------------------------------------------------
# LONG TEXT (Review Focus 4)
#-----------------------------------------------------------------------------

func test_long_action_name_ellipsizes() -> void:
	var long_name: String = "The Exceedingly Long and Winding Name of a Story Step ".repeat(4)
	var card: ZoneActionButton = _card_for(_story_fixture(long_name, "Short"))
	var title: Label = card.get_node("%Title") as Label
	assert_eq(card.size.x, CARD_WIDTH, "the card stays 392 wide")
	assert_lte(title.size.x, 232.0, "the title stops before the tag")
	assert_eq(title.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)

func test_long_detail_wraps_in_tall_drawer() -> void:
	_equip_technique_named("word ".repeat(40).strip_edges())
	var card: ZoneActionButton = _card(CYCLING_ID)
	assert_eq(card.size.y, TALL_HEIGHT)
	assert_eq(card.custom_minimum_size.y, TALL_HEIGHT)
	assert_eq(card.size.x, CARD_WIDTH)

func test_fresh_save_cycling_card_wraps() -> void:
	# Kit §0: "Foundational Technique · Madra and Core Density XP" is wider than 316 px.
	_equip_technique_named("Foundational Technique")
	assert_eq(_card(CYCLING_ID).size.y, TALL_HEIGHT)

func test_short_detail_keeps_the_short_drawer() -> void:
	_equip_technique_named("Calm")
	assert_eq(_card(CYCLING_ID).size.y, SHORT_HEIGHT)

func test_cycling_card_follows_the_equipped_technique() -> void:
	_equip_technique_named("Calm")
	var card: ZoneActionButton = _card(CYCLING_ID)
	var technique: CyclingTechniqueData = CyclingManager.get_equipped_technique()
	technique.technique_name = "Foundational Technique"
	CyclingManager.equipped_technique_changed.emit(technique)
	assert_true(_has_text_containing(card, "Foundational Technique · Madra and Core"))
	assert_eq(card.size.y, TALL_HEIGHT, "the longer line wraps in the tall drawer")

func test_long_idle_detail_does_not_grow_the_card() -> void:
	var action := ZoneManager.get_action_by_id(FORAGING_ID).duplicate() as ForageActionData
	action.madra_cost_per_second = 123456789.0
	action.foraging_interval_in_sec = 987654321.0
	var card: ZoneActionButton = _card_for(action)
	assert_eq(card.size, Vector2(CARD_WIDTH, SHORT_HEIGHT), "an idle card never wraps or widens")

#-----------------------------------------------------------------------------
# FLASH
#-----------------------------------------------------------------------------

func test_flash_shows_the_brass_frame() -> void:
	var card: ZoneActionButton = _card(AURA_WELL_ID)
	var frame: LacquerFrameOverlay = card.get_node("%FlashFrame") as LacquerFrameOverlay
	card.flash()
	assert_true(frame.visible)
	assert_true(frame.is_flashing())
