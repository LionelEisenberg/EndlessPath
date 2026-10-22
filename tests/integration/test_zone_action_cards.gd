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
## Kit §5.5: a detail line is at most 316 px, then ends in an ellipsis.
const DETAIL_WIDTH: float = 316.0
const ELLIPSIS: String = "…"
const EULJIRO_PATH: String = "res://assets/fonts/BMEULJIROTTF.ttf"

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

## The rich text labels of the card's detail line (training and foraging),
## left to right.
func _detail_rich_texts(card: ZoneActionButton) -> Array[RichTextLabel]:
	var found: Array[RichTextLabel] = []
	for node: Node in card.get_detail_slot().find_children("*", "RichTextLabel", true, false):
		var rich := node as RichTextLabel
		if rich.is_visible_in_tree():
			found.append(rich)
	return found

## Spring Forest Foraging with a long tail: "every 12.25 s · 12.5 Madra / s".
func _long_forage_fixture() -> ForageActionData:
	var action := ZoneManager.get_action_by_id(FORAGING_ID).duplicate() as ForageActionData
	action.foraging_interval_in_sec = 12.25
	action.madra_cost_per_second = 12.5
	return action

## A training action whose detail runs far past 316 px:
## "+15000000 Madra / s · each level +123456789 Spirit".
func _long_training_fixture() -> TrainingActionData:
	var action := ZoneManager.get_action_by_id(AURA_WELL_ID).duplicate() as TrainingActionData
	var madra := AwardResourceEffectData.new()
	madra.resource_type = ResourceManager.ResourceType.MADRA
	madra.amount = 1.5
	action.effects_per_tick = [madra] as Array[EffectData]
	action.tick_interval_seconds = 0.0000001
	var spirit := AwardAttributeEffectData.new()
	spirit.attribute_type = CharacterAttributesData.AttributeType.SPIRIT
	spirit.amount = 123456789.0
	action.effects_on_level = [spirit] as Array[EffectData]
	return action

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

func test_foraging_icons_are_the_items_mini_icons() -> void:
	var card: ZoneActionButton = _card(FORAGING_ID)
	var icons: Array[Texture2D] = []
	for node: Node in card.get_detail_slot().find_children("Icon", "TextureRect", true, false):
		icons.append((node as TextureRect).texture)
	var forage := ZoneManager.get_action_by_id(FORAGING_ID) as ForageActionData
	var expected: Array[Texture2D] = []
	for entry: LootTableEntry in forage.loot_table.entries:
		expected.append(entry.item.mini_icon)
	assert_eq(icons, expected, "each yield shows its item's mini icon")

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

func test_card_keeps_its_width_in_a_wider_column() -> void:
	# A container wider than the drawer must not stretch the card's hover and
	# click area past it.
	var column := VBoxContainer.new()
	column.size = Vector2(500.0, 400.0)
	add_child_autofree(column)
	var card: ZoneActionButton = CARD_SCENE.instantiate() as ZoneActionButton
	card.setup_action(ZoneManager.get_action_by_id(MERCHANT_ID))
	column.add_child(card)
	await wait_process_frames(2)
	assert_eq(card.size, Vector2(CARD_WIDTH, SHORT_HEIGHT))

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

func test_ellipsize_words_keeps_text_that_fits() -> void:
	var font: Font = load(EULJIRO_PATH)
	assert_eq(ZoneActionButton.ellipsize_words("every 5 s · free", font, 15, DETAIL_WIDTH), "every 5 s · free")

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

func test_long_forage_detail_ends_in_an_ellipsis() -> void:
	var card: ZoneActionButton = _card_for(_long_forage_fixture())
	await wait_process_frames(1)
	var texts: Array[RichTextLabel] = _detail_rich_texts(card)
	var last: String = texts[-1].get_parsed_text()
	assert_true(last.begins_with("2–6 · every 12.25 s"), "the line keeps its start")
	assert_true(last.ends_with(ELLIPSIS), "and ends in an ellipsis")
	assert_lte(card.get_detail_slot().get_combined_minimum_size().x, DETAIL_WIDTH, "inside 316 px")

func test_long_training_detail_ends_in_an_ellipsis() -> void:
	var card: ZoneActionButton = _card_for(_long_training_fixture())
	await wait_process_frames(1)
	var text: RichTextLabel = _detail_rich_texts(card)[0]
	assert_true(text.get_parsed_text().begins_with("+15000000 Madra / s"))
	assert_true(text.get_parsed_text().ends_with(ELLIPSIS))
	assert_lte(text.get_content_width(), int(DETAIL_WIDTH))
	assert_eq(card.size, Vector2(CARD_WIDTH, SHORT_HEIGHT), "an idle card stays short")

func test_long_ready_line_ends_in_an_ellipsis() -> void:
	var action := ZoneManager.get_action_by_id(ADVENTURE_ID).duplicate() as AdventureActionData
	action.time_limit_seconds = 12345679
	var card: ZoneActionButton = _card_for(action)
	ResourceManager.set_madra(60.0)
	await wait_process_frames(1)
	var ready_text: RichTextLabel = card.get_footer_slot().find_child("ReadyText", true, false) as RichTextLabel
	assert_true(ready_text.get_parsed_text().begins_with("Ready · carries up to 100 Madra"))
	assert_true(ready_text.get_parsed_text().ends_with(ELLIPSIS))
	assert_lte(ready_text.get_content_width(), int(DETAIL_WIDTH))

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
	assert_true(_has_text_containing(card, "Needs 75 Madra · you have 60"))
	ResourceManager.set_madra(80.0)
	assert_true(_has_text_containing(card, "carries up to 150 Madra"))
	InventoryManager.unequip_item(EquipmentDefinitionData.EquipmentSlot.ACCESSORY, 0)
	assert_true(_has_text_containing(card, "carries up to 100 Madra"), "taking the ring off shrinks it again")

#-----------------------------------------------------------------------------
# FLASH
#-----------------------------------------------------------------------------

func test_flash_shows_the_brass_frame() -> void:
	var card: ZoneActionButton = _card(AURA_WELL_ID)
	var frame: LacquerFrameOverlay = card.get_node("%FlashFrame") as LacquerFrameOverlay
	card.flash()
	assert_true(frame.visible)
	assert_true(frame.is_flashing())
