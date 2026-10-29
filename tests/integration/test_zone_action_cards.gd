extends GutTest

## Integration tests for the lacquer activity cards (ZoneActionButton and its
## presenters): the running tag, clicks, the NEW seal, what each presenter's
## detail line and right column show, the adventure's Madra states and how gear
## moves them, the tall drawer a long detail wraps in, and ellipsize_words,
## which cuts an idle card's detail line at a word. Cards are built with
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

const TALL_HEIGHT: float = 96.0
## Kit §5.5: a detail line is at most 316 px, then ends in an ellipsis.
const DETAIL_WIDTH: float = 316.0
const ELLIPSIS: String = "…"
const EULJIRO_PATH: String = "res://assets/fonts/BMEULJIROTTF.ttf"

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

## Equips a fixture ring that adds this much Foundation: 10 Madra of capacity
## per point.
func _equip_foundation_ring(foundation: float) -> void:
	var ring := EquipmentDefinitionData.new()
	ring.item_id = "test_zone_action_cards_ring"
	ring.item_name = "Fixture Ring"
	ring.slot_type = EquipmentDefinitionData.EquipmentSlot.ACCESSORY
	ring.attribute_bonuses = {CharacterAttributesData.AttributeType.FOUNDATION: foundation}
	var instance := ItemInstanceData.new()
	instance.item_definition = ring
	InventoryManager.equip_item(instance, EquipmentDefinitionData.EquipmentSlot.ACCESSORY, -1, 0)

## A story card whose description wraps in the tall drawer.
func _long_story_card() -> ZoneActionButton:
	return _card_for(_story_fixture("The Intervener", "word ".repeat(40).strip_edges()))

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
	var card: ZoneActionButton = _card(AURA_WELL_ID)
	assert_has(_texts(card.get_detail_slot()), "+1.5 Madra / s", "the Madra rate on the left")
	assert_eq(card.get_detail_right_text(), "+1 Spirit / level", "the level's attribute in the right column")

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
# LONG TEXT (Review Focus 4)
#-----------------------------------------------------------------------------

func test_long_detail_wraps_in_tall_drawer() -> void:
	var card: ZoneActionButton = _long_story_card()
	assert_eq(card.size.y, TALL_HEIGHT)
	assert_eq(card.custom_minimum_size.y, TALL_HEIGHT)

func test_ellipsize_words_keeps_text_that_fits() -> void:
	var font: Font = load(EULJIRO_PATH)
	assert_eq(ZoneActionButton.ellipsize_words("Madra and Core Density XP", font, 15, DETAIL_WIDTH), "Madra and Core Density XP")

func test_ellipsize_words_cuts_at_a_word() -> void:
	var font: Font = load(EULJIRO_PATH)
	var text: String = "2–6 · every 12.25 s · 12.5 Madra / s"
	var cut: String = ZoneActionButton.ellipsize_words(text, font, 15, 200.0)
	assert_true(cut.ends_with(ELLIPSIS), "ends in an ellipsis")
	assert_lte(font.get_string_size(cut, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, 200.0, "fits")
	var head: String = cut.trim_suffix(ELLIPSIS)
	assert_true(text.begins_with(head), "keeps the start of the line")
	assert_true(text.substr(head.length()).begins_with(" "), "cut between words")
	assert_false(head.ends_with("·") or head.ends_with("/") or head.ends_with(" "), "no dangling separator")

func test_ellipsize_words_cuts_a_long_word() -> void:
	var font: Font = load(EULJIRO_PATH)
	var cut: String = ZoneActionButton.ellipsize_words("Supercalifragilistic", font, 15, 60.0)
	assert_true(cut.ends_with(ELLIPSIS))
	assert_lte(font.get_string_size(cut, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, 60.0)

#-----------------------------------------------------------------------------
# ADVENTURE AND EQUIPMENT
#-----------------------------------------------------------------------------

func test_adventure_follows_equipment_capacity() -> void:
	# Capacity is max Madra (Foundation x 10) and the threshold half of it, so
	# gear that adds Foundation moves both without any Madra change.
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	ResourceManager.set_madra(60.0)
	assert_eq(_tag_text(card), "ENTER", "precondition: 60 of 50 Madra is ready")
	_equip_foundation_ring(5.0)
	assert_eq(_tag_text(card), "ACTIVE", "the threshold is now 75")
	assert_true(_has_text_containing(card, "60 / 75"))
	ResourceManager.set_madra(80.0)
	assert_true(_has_text_containing(card, "carries 150 Madra"))
	InventoryManager.unequip_item(EquipmentDefinitionData.EquipmentSlot.ACCESSORY, 0)
	assert_true(_has_text_containing(card, "carries 100 Madra"), "taking the ring off shrinks it again")
