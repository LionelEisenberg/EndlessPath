extends GutTest

## Integration tests for the lacquer activity cards (ZoneActionButton and its
## presenters): the running tag, clicks, the NEW seal and when it clears, what
## each presenter's detail line and right column show, the adventure's pool
## and how gear moves its max, and long text: no card cuts its text, a long
## title, detail, figure or list of finds wraps and the card grows by its lines.
## Cards are built with setup_action on a fresh save, as the zone panel builds
## them.

const CARD_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/zone_action_button.tscn")

const CYCLING_ID: String = "wilderness_cycling_action"
const AURA_WELL_ID: String = "aura_well_training"
const FORAGING_ID: String = "sprint_forest_foraging_action"
const ADVENTURE_ID: String = "shallow_woods_adventure_action"
const MERCHANT_ID: String = "spirit_valley_merchant"
const BODY_REFINING_ID: String = "riverbank_training_action"
const HEALTH_MINI: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_health_ai.png")
const DIALOGUE_ID: String = "celestial_intervener_dialogue_1"
## "Return to the [INTERVENER]": not yet available on a fresh save, so unseen.
const RETURN_ID: String = "celestial_intervener_dialogue_2"

const FORAGING_EVENT: String = "q_fill_core_completed"
const SMOOTH_ID: String = "smooth_flow"
const TORRENTIAL_ID: String = "torrential_flow"
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

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()

func after_each() -> void:
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

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
# THE CYCLING CARD
#-----------------------------------------------------------------------------

## The cycling card's reward row as it reads, in order: the Madra's word, then
## each shown stat's.
func _reward_words(card: ZoneActionButton) -> Array[String]:
	var row: Node = card.get_detail_slot().find_child("RewardRow", true, false)
	var words: Array[String] = [(row.find_child("MadraLabel", true, false) as Label).text]
	for stat_name: String in ["Spirit", "Mind", "Control"]:
		if (row.find_child(stat_name + "Entry", true, false) as Control).visible:
			words.append((row.find_child(stat_name + "Name", true, false) as Label).text)
	return words

## The cycling card names what cycling trains with the techniques the player
## knows: Madra and Spirit, then each known technique's other stat, each stat
## with its icon.
func test_the_cycling_card_lists_what_the_known_techniques_train() -> void:
	var cases: Array[Dictionary] = [
		{"name": "a new save", "unlock": [], "words": ["Madra and", "Spirit XP"]},
		{"name": "with Smooth Flow", "unlock": [SMOOTH_ID], "words": ["Madra,", "Spirit and", "Control XP"]},
		{"name": "with all three", "unlock": [SMOOTH_ID, TORRENTIAL_ID], "words": ["Madra,", "Spirit,", "Mind and", "Control XP"]},
	]
	for case: Dictionary in cases:
		PersistenceManager.save_game_data = SaveGameData.new()
		PersistenceManager.save_data_reset.emit()
		for technique_id: String in case.unlock:
			CyclingManager.unlock_technique(technique_id)
		var card: ZoneActionButton = _card(CYCLING_ID)
		assert_eq(_reward_words(card), Array(case.words, TYPE_STRING, "", null), case.name)
		var row: Node = card.get_detail_slot().find_child("RewardRow", true, false)
		for stat: CharacterAttributesData.AttributeType in StatDisplay.SPIRITUAL:
			var stat_name: String = StatDisplay.name_of(stat)
			var icon: TextureRect = row.find_child(stat_name + "Icon", true, false) as TextureRect
			if icon.is_visible_in_tree():
				assert_eq(icon.texture, StatDisplay.icon_of(stat), "%s: %s's icon" % [case.name, stat_name])

func test_the_cycling_card_follows_a_technique_unlock() -> void:
	var card: ZoneActionButton = _card(CYCLING_ID)
	assert_eq(_reward_words(card), ["Madra and", "Spirit XP"] as Array[String], "precondition: a new save")
	CyclingManager.unlock_technique(TORRENTIAL_ID)
	assert_eq(_reward_words(card), ["Madra,", "Spirit and", "Mind XP"] as Array[String], "the unlock adds Mind")

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
	assert_eq(_tag_text(card), "ACTIVE", "a cycling card, out of sight under the techniques, shows no RUNNING")

## Body refining's board leaves the chest in view, so its card is pulled out and
## tagged RUNNING while it runs, as a running idle card is.
func test_a_running_body_refining_card_is_tagged() -> void:
	var card: ZoneActionButton = _card(BODY_REFINING_ID)
	ActionManager.select_action(ZoneManager.get_action_by_id(BODY_REFINING_ID))
	assert_eq(_tag_text(card), "RUNNING")
	assert_eq((card.get_node("%Drawer") as Control).position, ZoneActionButton.RUNNING_OFFSET, "pulled out")
	ActionManager.stop_action()
	assert_eq(_tag_text(card), "ACTIVE", "back at rest once it stops")
	assert_eq((card.get_node("%Drawer") as Control).position, Vector2.ZERO)

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

## A fresh save's 25 Madra starts a run: no Madra figure refuses the click.
func test_a_click_on_the_adventure_starts_it_on_any_pool() -> void:
	_run_aura_well()
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	_click(card)
	assert_eq(_current_id(), ADVENTURE_ID, "the adventure takes over")

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

## Body refining's card names what every drill gives, each with its icon, as the
## forage card lists its finds: the Health heart with Health, and Strength's mini
## with Strength XP. Never the drill, which is the board's to name.
func test_body_refining_detail_shows_health_and_strength_xp() -> void:
	var card: ZoneActionButton = _card(BODY_REFINING_ID)
	assert_eq(_texts(card.get_detail_slot()), ["Health", "Strength XP"] as Array[String])
	var icons: Array[Texture2D] = []
	for rect: Node in card.get_detail_slot().find_children("Icon", "TextureRect", true, false):
		icons.append((rect as TextureRect).texture)
	assert_eq(icons, [HEALTH_MINI, StatDisplay.mini_icon_of(CharacterAttributesData.AttributeType.STRENGTH)] as Array[Texture2D], "the Health heart, then Strength's mini")
	assert_eq(card.size.y, _height_for(card, 1), "one detail line")

func test_story_detail_is_the_description() -> void:
	var card: ZoneActionButton = _card_for(_story_fixture("The Intervener", "Your next story step"))
	assert_true(_has_text_containing(card, "Your next story step"))

#-----------------------------------------------------------------------------
# ADVENTURE
#-----------------------------------------------------------------------------

## A run starts on any pool, so the card is always ready and shows the pool.
func test_adventure_shows_the_pool_and_enter() -> void:
	var cases: Array[Dictionary] = [
		{"name": "an empty pool", "madra": 0.0, "right": "0 / 100 Madra"},
		{"name": "a new character's 25", "madra": 25.0, "right": "25 / 100 Madra"},
		{"name": "a full pool", "madra": 100.0, "right": "100 / 100 Madra"},
	]
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	for case: Dictionary in cases:
		ResourceManager.set_madra(case.madra)
		assert_has(_texts(card.get_detail_slot()), "5 min run", "%s: the run's length on the left" % case.name)
		assert_eq(card.get_detail_right_text(), case.right, "%s: the pool in the right column" % case.name)
		assert_eq(_tag_text(card), "ENTER", "%s: always ready" % case.name)

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

#-----------------------------------------------------------------------------
# ADVENTURE AND EQUIPMENT
#-----------------------------------------------------------------------------

func test_adventure_follows_the_max_madra() -> void:
	# Gear that adds Mind moves the pool's max without any Madra change.
	var card: ZoneActionButton = _card(ADVENTURE_ID)
	ResourceManager.set_madra(60.0)
	_equip_mind_ring(5.0)
	assert_eq(card.get_detail_right_text(), "60 / 150 Madra", "the ring raises the max to 150")
	ResourceManager.set_madra(140.0)
	assert_eq(card.get_detail_right_text(), "140 / 150 Madra")
	InventoryManager.unequip_item(EquipmentDefinitionData.EquipmentSlot.ACCESSORY, 0)
	assert_eq(card.get_detail_right_text(), "100 / 100 Madra", "taking the ring off brings the pool down to the new max")
