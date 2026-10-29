extends GutTest

## Integration tests for the adventure chest's expedition page (ExpeditionPage)
## and the choice drawers in it (ChoiceDrawer), instanced alone on a fresh save
## (and in the chest, for the pointer and the chest growing with the page): the
## Here tray's three states (an unresolved encounter, a resolved one, open
## ground), the lore, the drawers and what each does when pressed, the walk hint
## following Stamina, the lock line, the Run ledger, the content height the chest
## reads, and long text wrapping and growing the tray, a drawer and the chest. The
## here line and the walk hint are statics, so they are asked directly as well as
## through the page. Encounters are the shipped Shallow Woods ones or built in code.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const PAGE_SCENE: PackedScene = preload("res://scenes/adventure/adventure_chest/expedition_page/expedition_page.tscn")
const DRAWER_SCENE: PackedScene = preload("res://scenes/adventure/adventure_chest/choice_drawer/choice_drawer.tscn")
const CHEST_SCENE: PackedScene = preload("res://scenes/adventure/adventure_chest/adventure_chest.tscn")
const AMORPHOUS_SPIRIT_ENCOUNTER: AdventureEncounter = preload("res://resources/adventure/encounters/shallow_woods/combat_encounters/regular/amorphous_spirit_encounter.tres")
const AURA_WELL: AdventureEncounter = preload("res://resources/adventure/encounters/shallow_woods/special_encounters/aura_well_encounter.tres")
const CRUDE_SCALE: ItemDefinitionData = preload("res://resources/items/consumables/crude_scale.tres")

const Type := AdventureEncounter.EncounterType

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

var _page: ExpeditionPage = null
var _original_save: SaveGameData = null
var _original_stamina: float = 0.0
## True once a test moved the real pointer, so after_each puts it back: the zone
## map reads it to hover a hex, and would otherwise find where it was left.
var _pointer_moved: bool = false

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_original_stamina = PlayerManager.vitals_manager.current_stamina
	_pointer_moved = false
	_page = PAGE_SCENE.instantiate() as ExpeditionPage
	add_child_autofree(_page)

func after_each() -> void:
	PlayerManager.vitals_manager.current_stamina = _original_stamina
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	if _pointer_moved:
		await _move_pointer_to_window_point(Vector2.ZERO)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _node(unique_name: String) -> Node:
	return _page.get_node("%" + unique_name)

func _control(unique_name: String) -> Control:
	return _node(unique_name) as Control

func _text(unique_name: String) -> String:
	return (_node(unique_name) as Label).text

func _shown(unique_name: String) -> bool:
	return _control(unique_name).visible

func _drawer(index: int) -> ChoiceDrawer:
	return _page.get_drawer(index)

func _drawer_node(index: int, unique_name: String) -> Node:
	return _drawer(index).get_node("%" + unique_name)

func _drawer_title(index: int) -> String:
	return (_drawer_node(index, "Title") as Label).text

func _drawer_detail(index: int) -> String:
	return (_drawer_node(index, "Detail") as Label).text

func _drawer_seal_shown(index: int) -> bool:
	return (_drawer_node(index, "LockedSeal") as Control).visible

## How many drawers show.
func _shown_drawers() -> int:
	var count: int = 0
	for index: int in ExpeditionPage.MAX_DRAWERS:
		if _drawer(index).visible:
			count += 1
	return count

## A left press on the drawer, as the GUI delivers it.
func _press(drawer: ChoiceDrawer, button: MouseButton = MOUSE_BUTTON_LEFT, pressed: bool = true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	drawer.gui_input.emit(event)

func _enemy(character_name: String, body: float = 10.0, technique_names: Array[String] = [], base_gold: int = 15) -> CombatantData:
	var enemy := CombatantData.new()
	enemy.character_name = character_name
	enemy.attributes = CharacterAttributesData.new()
	enemy.attributes.body = body
	enemy.base_gold_drop = base_gold
	for technique_name: String in technique_names:
		var ability := AbilityData.new()
		ability.ability_name = technique_name
		enemy.abilities.append(ability)
	return enemy

func _combat_choice(enemy: CombatantData, label: String = "Attack", tooltip: String = "", gold_multiplier: float = 1.0) -> CombatChoice:
	var choice := CombatChoice.new()
	var pool: Array[CombatantData] = [enemy]
	choice.enemy_pool = pool
	choice.label = label
	choice.tooltip = tooltip
	choice.gold_multiplier = gold_multiplier
	return choice

func _plain_choice(label: String, tooltip: String = "") -> EncounterChoice:
	var choice := EncounterChoice.new()
	choice.label = label
	choice.tooltip = tooltip
	return choice

func _dialogue_choice(label: String, tooltip: String = "") -> DialogueChoice:
	var choice := DialogueChoice.new()
	choice.label = label
	choice.tooltip = tooltip
	return choice

func _event_condition(event_id: String) -> UnlockConditionData:
	var condition := UnlockConditionData.new()
	condition.condition_id = "test_" + event_id
	condition.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
	condition.target_value = event_id
	return condition

## An encounter of the type with the choices (any Array of EncounterChoice).
func _encounter(type: AdventureEncounter.EncounterType, encounter_name: String, choice_list: Array, description: String = "Something stirs.", completed_text: String = "") -> AdventureEncounter:
	var encounter := AdventureEncounter.new()
	encounter.encounter_type = type
	encounter.encounter_name = encounter_name
	encounter.description = description
	encounter.text_description_completed = completed_text
	encounter.choices.assign(choice_list)
	return encounter

## An item whose icon is a texture of its own, so a socket's icon names it.
func _item(item_name: String) -> ItemDefinitionData:
	var item := ItemDefinitionData.new()
	item.item_name = item_name
	item.icon = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	return item

func _loot_icon(index: int) -> TextureRect:
	return _control("LootIcon%d" % (index + 1)) as TextureRect

## Moves the pointer, through the window as the player would, to a point in the
## viewport (headless, the window is not 1920x1080).
func _move_pointer_to(point: Vector2) -> void:
	_pointer_moved = true
	await _move_pointer_to_window_point(get_viewport().get_screen_transform() * point)

func _move_pointer_to_window_point(window_point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = window_point
	motion.global_position = window_point
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame

## A left click at a point in the viewport: the pointer moves there, then presses
## and releases.
func _click_at(point: Vector2) -> void:
	await _move_pointer_to(point)
	var window_point: Vector2 = get_viewport().get_screen_transform() * point
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = window_point
		event.global_position = window_point
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await get_tree().process_frame

## The chest with the page in it, on a CanvasLayer above GUT's own window, which
## would otherwise cover the screen and take the pointer.
func _hosted_chest() -> AdventureChest:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child_autofree(layer)
	var chest := CHEST_SCENE.instantiate() as AdventureChest
	layer.add_child(chest)
	return chest

#-----------------------------------------------------------------------------
# THE STATICS
#-----------------------------------------------------------------------------

func test_walk_hint_counts_whole_steps() -> void:
	assert_eq(ExpeditionPage.walk_hint(80.0), "Click a hex to walk · 5 Stamina a step · 16 steps left")
	assert_eq(ExpeditionPage.walk_hint(79.0), "Click a hex to walk · 5 Stamina a step · 15 steps left", "a part step is not a step")
	assert_eq(ExpeditionPage.walk_hint(4.9), "Click a hex to walk · 5 Stamina a step · 0 steps left")
	assert_eq(ExpeditionPage.walk_hint(0.0), "Click a hex to walk · 5 Stamina a step · 0 steps left")
	var cost: int = int(AdventureTilemap.MOVEMENT_STAMINA_COST)
	assert_eq(ExpeditionPage.walk_hint(cost * 7.0), "Click a hex to walk · %d Stamina a step · 7 steps left" % cost, "the cost is the tilemap's")

## A fight with no combat choice (or nobody in its pool) has no enemy to name.
func test_here_line_of_a_fight_with_no_enemy_is_its_kind() -> void:
	assert_eq(ExpeditionPage.here_line(_encounter(Type.COMBAT_REGULAR, "Quiet", [_plain_choice("Wait")])), "Fight")
	assert_eq(ExpeditionPage.here_line(_encounter(Type.COMBAT_ELITE, "Empty", [CombatChoice.new()])), "Elite")
	assert_eq(ExpeditionPage.here_line(null), "", "no encounter, no line")

func test_here_line_takes_the_first_combat_choice() -> void:
	var first: CombatChoice = _combat_choice(_enemy("First", 11.0))
	var second: CombatChoice = _combat_choice(_enemy("Second", 30.0))
	var encounter: AdventureEncounter = _encounter(Type.COMBAT_REGULAR, "Two ways", [_plain_choice("Talk"), first, second])
	assert_eq(ExpeditionPage.here_line(encounter), "Fight · First", "the first combat choice, not the first choice")

#-----------------------------------------------------------------------------
# THE HERE TRAY
#-----------------------------------------------------------------------------

func test_fight_tile_here_tray() -> void:
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)

	assert_eq(_text("NameLabel"), "Amorphous Spirit Attacks!")
	assert_true(_shown("Tag"), "a fight carries its tag")
	assert_eq(_text("TagLabel"), "FIGHT")
	assert_false(_shown("BossSeal"))
	assert_eq(_text("LineLabel"), "Fight · Amorphous Spirit", "the kind and the enemy, no Health")

func test_noop_tile() -> void:
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)
	assert_true(_shown("Tag"), "precondition: a fight showed a tag")

	_page.show_tile(NoOpEncounter.new(), "", null)

	assert_eq(_text("NameLabel"), "Open ground")
	assert_false(_shown("Glyph"), "no glyph")
	assert_false(_shown("Tag"), "no tag")
	assert_false(_shown("BossSeal"))
	assert_false(_shown("LoreLabel"))
	assert_false(_shown("HintRow"))
	assert_false(_shown("DividerRow"))
	assert_false(_shown("DrawerRows"))
	assert_eq(_shown_drawers(), 0)

## The map treats a NoOp tile as open ground whatever it holds, so the page does.
func test_a_noop_is_open_ground_even_with_choices() -> void:
	var noop := NoOpEncounter.new()
	noop.encounter_name = "Quiet Glade"
	noop.description = "Nothing here."
	noop.choices.assign([_plain_choice("Linger")])
	_page.show_tile(noop, "", null)

	assert_eq(_text("NameLabel"), "Open ground")
	assert_eq(_shown_drawers(), 0, "no drawer for a NoOp's choice")
	assert_false(_shown("LoreLabel"))

func test_an_encounter_without_choices_is_open_ground() -> void:
	var choice_less: AdventureEncounter = _encounter(Type.TREASURE, "Hollow", [])
	_page.show_tile(choice_less, "", null)

	assert_eq(_text("NameLabel"), "Open ground", "the map treats it as open ground")
	assert_false(_shown("Tag"))
	assert_false(_shown("Glyph"))
	assert_eq(_shown_drawers(), 0)

	_page.show_tile(choice_less, "Done", null)
	assert_eq(_text("NameLabel"), "Open ground", "a summary has nothing to say about it either")

#-----------------------------------------------------------------------------
# THE ENCOUNTER: LORE AND DRAWERS
#-----------------------------------------------------------------------------

func test_unresolved_tile_shows_the_lore_and_one_drawer_per_choice() -> void:
	_page.show_tile(AURA_WELL, "", null)

	assert_true(_shown("LoreLabel"))
	assert_eq(_text("LoreLabel"), "The air here is thick with aura, recover briefly from the chaos beyond.")
	assert_true(_shown("HintRow"), "the hint row stands under the lore")
	assert_false(_shown("WalkHint"), "the walk hint waits until the tile is resolved")
	assert_true(_shown("LockLine"), "and the lock line says the choices hold the player")
	assert_true(_shown("DividerRow"))
	assert_true(_shown("DrawerRows"))
	assert_eq(_shown_drawers(), 2, "the Aura Well has two choices")
	assert_true(_drawer(0).visible)
	assert_true(_drawer(1).visible)
	assert_false(_drawer(2).visible)
	assert_eq(_drawer_title(0), "Rest")
	assert_eq(_drawer_title(1), "Mark down the location")

func test_extra_choices_beyond_the_third_are_left_out() -> void:
	var choices: Array = [_plain_choice("A"), _plain_choice("B"), _plain_choice("C"), _plain_choice("D")]
	_page.show_tile(_encounter(Type.TREASURE, "Many", choices), "", null)
	assert_eq(_shown_drawers(), 3, "the scene holds three")
	assert_eq(_drawer_title(2), "C")

## A choice that failed to load (a missing sub-resource leaves a null in the
## array) takes no drawer, and the choices after it close up the gap.
func test_a_missing_choice_is_skipped() -> void:
	var encounter: AdventureEncounter = _encounter(Type.TREASURE, "Cache", [_plain_choice("A")])
	encounter.choices.append(null)
	encounter.choices.append(_plain_choice("C"))

	_page.show_tile(encounter, "", null)

	assert_eq(_shown_drawers(), 2, "the null gets no drawer")
	assert_eq(_drawer_title(0), "A")
	assert_eq(_drawer_title(1), "C", "the next choice takes the next drawer")
	watch_signals(_page)
	_press(_drawer(1))
	assert_eq(get_signal_parameters(_page, "choice_selected", 0), [encounter.choices[2]], "and it is the choice behind it")

func test_locked_choice() -> void:
	var locked: EncounterChoice = _combat_choice(_enemy("Guardian", 10.0, ["Slam"]), "Face the guardian", "Needs the key.")
	locked.requirements = {_event_condition("has_the_key"): true}
	assert_false(locked.evaluate_requirements(), "precondition: the key is not found")
	_page.show_tile(_encounter(Type.COMBAT_ELITE, "Gate", [locked, _plain_choice("Go round")]), "", null)
	watch_signals(_page)

	var drawer: ChoiceDrawer = _drawer(0)
	assert_false(drawer.is_available())
	assert_eq(_drawer_title(0), "Face the guardian", "its own label")
	assert_true(_drawer_seal_shown(0), "the LOCKED seal")
	assert_eq(_drawer_detail(0), "Needs the key.", "and it still says what it does")

	_press(drawer)
	drawer.pressed.emit()
	assert_signal_not_emitted(_page, "choice_selected", "a locked drawer takes no press")
	assert_true(_drawer(1).is_available(), "the other drawer is not locked by it")

func test_a_locked_choice_opens_once_its_requirement_is_met() -> void:
	var gated: EncounterChoice = _plain_choice("Enter")
	gated.requirements = {_event_condition("gate_opened"): true}
	var encounter: AdventureEncounter = _encounter(Type.TREASURE, "Gate", [gated])
	_page.show_tile(encounter, "", null)
	assert_false(_drawer(0).is_available(), "precondition")

	EventManager.trigger_event("gate_opened")
	_page.show_tile(encounter, "", null)

	assert_true(_drawer(0).is_available(), "shown again, it is read afresh")
	assert_false(_drawer_seal_shown(0))

func test_completed_choice_shows_its_completed_label() -> void:
	EventManager.trigger_event("aura_well_discovered")
	var mark: EncounterChoice = AURA_WELL.choices[1]
	assert_true(mark.is_completed(), "precondition: the well is marked")
	assert_false(mark.evaluate_requirements(), "precondition: and the choice's own requirement now fails")

	_page.show_tile(AURA_WELL, "", null)

	assert_eq(_drawer_title(1), "✓ Location noted", "its completed label")
	assert_false(_drawer(1).is_available())
	assert_false(_drawer_seal_shown(1), "done outranks locked: no LOCKED seal")
	assert_true(_drawer(0).is_available(), "the Rest drawer is still open")
	assert_eq(_drawer_title(0), "Rest")

	watch_signals(_page)
	_press(_drawer(1))
	_drawer(1).pressed.emit()
	assert_signal_not_emitted(_page, "choice_selected", "a completed drawer takes no press")

func test_completed_label_falls_back_to_the_label() -> void:
	var done: EncounterChoice = _plain_choice("Light the beacon")
	done.completion_condition = _event_condition("beacon_lit")
	var encounter: AdventureEncounter = _encounter(Type.TREASURE, "Beacon", [done])
	EventManager.trigger_event("beacon_lit")

	_page.show_tile(encounter, "", null)

	assert_eq(_drawer_title(0), "Light the beacon", "with no completed label, the label")
	assert_false(_drawer(0).is_available())

func test_pressing_an_available_drawer_emits_choice_selected() -> void:
	_page.show_tile(AURA_WELL, "", null)
	watch_signals(_page)

	_press(_drawer(0))
	assert_signal_emit_count(_page, "choice_selected", 1)
	assert_signal_emitted_with_parameters(_page, "choice_selected", [AURA_WELL.choices[0]])

	_drawer(1).pressed.emit()
	assert_signal_emit_count(_page, "choice_selected", 2)
	assert_eq(get_signal_parameters(_page, "choice_selected", 1), [AURA_WELL.choices[1]], "the second drawer is the second choice")

func test_a_press_sends_the_choice_of_the_tile_now_shown() -> void:
	_page.show_tile(AURA_WELL, "", null)
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)
	watch_signals(_page)

	_press(_drawer(0))

	assert_signal_emit_count(_page, "choice_selected", 1)
	assert_eq(get_signal_parameters(_page, "choice_selected", 0), [AMORPHOUS_SPIRIT_ENCOUNTER.choices[0]])

func test_a_drawer_put_away_picks_nothing() -> void:
	_page.show_tile(AURA_WELL, "", null)
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)
	assert_false(_drawer(1).visible, "precondition: the second drawer is put away")
	watch_signals(_page)

	_drawer(1).pressed.emit()
	_page.show_resolved("Done")
	_drawer(0).pressed.emit()

	assert_signal_not_emitted(_page, "choice_selected", "a drawer that is not shown has no choice behind it")

func test_only_a_left_press_counts() -> void:
	_page.show_tile(AURA_WELL, "", null)
	watch_signals(_page)
	_press(_drawer(0), MOUSE_BUTTON_RIGHT)
	_press(_drawer(0), MOUSE_BUTTON_LEFT, false)
	assert_signal_not_emitted(_page, "choice_selected", "neither a right press nor a release")

#-----------------------------------------------------------------------------
# A CHOICE DRAWER ALONE
#-----------------------------------------------------------------------------

func test_a_drawer_set_up_before_it_enters_the_tree() -> void:
	var drawer := DRAWER_SCENE.instantiate() as ChoiceDrawer
	var choice: EncounterChoice = _plain_choice("Search the roots", "Look for what was buried.")
	drawer.setup(choice, EncounterCoin.glyph_for(Type.TREASURE, false), EncounterCoin.glyph_frame_size_for(Type.TREASURE), "Look for what was buried.")
	assert_false(drawer.is_available(), "nothing is known until the drawer is ready")

	add_child_autofree(drawer)

	assert_true(drawer.is_available(), "set up once it is ready")
	assert_eq((drawer.get_node("%Title") as Label).text, "Search the roots")
	assert_eq((drawer.get_node("%Detail") as Label).text, "Look for what was buried.")
	assert_true((drawer.get_node("%Glyph") as Control).visible)

func test_a_drawer_set_up_again_replaces_everything() -> void:
	var drawer := DRAWER_SCENE.instantiate() as ChoiceDrawer
	add_child_autofree(drawer)
	var locked: EncounterChoice = _combat_choice(_enemy("Guardian"), "Face the guardian")
	locked.requirements = {_event_condition("never_found"): true}
	drawer.setup(locked, EncounterCoin.glyph_for(Type.COMBAT_ELITE, false), Vector2i(64, 64), "Needs the key.")
	assert_false(drawer.is_available(), "precondition: locked")
	assert_true((drawer.get_node("%LockedSeal") as Control).visible, "precondition")

	drawer.setup(_dialogue_choice("Ask the way"), null, Vector2i.ZERO, "")

	assert_true(drawer.is_available())
	assert_eq((drawer.get_node("%Title") as Label).text, "Ask the way")
	assert_eq((drawer.get_node("%Detail") as Label).text, "")
	assert_false((drawer.get_node("%LockedSeal") as Control).visible, "the seal goes with the lock")
	assert_eq((drawer.get_node("%TagLabel") as Label).text, "TALK")
	assert_true((drawer.get_node("%Tag") as Control).visible)
	assert_false((drawer.get_node("%Glyph") as Control).visible, "no glyph handed, none drawn")

func test_a_drawer_with_no_choice_is_not_available() -> void:
	var drawer := DRAWER_SCENE.instantiate() as ChoiceDrawer
	add_child_autofree(drawer)
	watch_signals(drawer)
	assert_false(drawer.is_available())
	_press(drawer)
	assert_signal_not_emitted(drawer, "pressed")
	drawer.setup(null, null, Vector2i.ZERO, "")
	assert_false(drawer.is_available())
	assert_eq((drawer.get_node("%Title") as Label).text, "")

#-----------------------------------------------------------------------------
# RESOLVED TILES
#-----------------------------------------------------------------------------

func test_resolved_tile_shows_summary_and_no_drawers() -> void:
	PlayerManager.vitals_manager.current_stamina = 80.0
	_page.show_tile(AURA_WELL, "", null)
	assert_eq(_shown_drawers(), 2, "precondition: the choices stood there")

	_page.show_resolved("+10 Health")

	assert_eq(_text("NameLabel"), "Aura Well", "the tile keeps its name")
	assert_true(_shown("Tag"))
	assert_eq(_text("TagLabel"), "CLEARED")
	assert_false(_shown("BossSeal"))
	assert_eq(_text("LineLabel"), "+10 Health", "the line is the summary")
	assert_eq(_text("LoreLabel"), "Diminished as the aura is, nothing to do now but move on.", "the completed text")
	assert_true(_shown("HintRow"), "the walk hint shows")
	assert_eq(_text("WalkHint"), "Click a hex to walk · 5 Stamina a step · 16 steps left")
	assert_false(_shown("DividerRow"))
	assert_false(_shown("DrawerRows"))
	assert_eq(_shown_drawers(), 0, "the drawers are put away")
	assert_true(_shown("Glyph"), "and the glyph stays")

func test_revisit_resolved_tile_shows_summary_and_no_drawers() -> void:
	PlayerManager.vitals_manager.current_stamina = 35.0
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)
	assert_eq(_shown_drawers(), 1, "precondition: the last tile had a drawer")

	_page.show_tile(AURA_WELL, "Rested · +80 Health · +24 Madra", null)

	assert_eq(_text("NameLabel"), "Aura Well")
	assert_eq(_text("TagLabel"), "CLEARED")
	assert_true(_shown("Tag"))
	assert_eq(_text("LineLabel"), "Rested · +80 Health · +24 Madra")
	assert_eq(_text("LoreLabel"), "Diminished as the aura is, nothing to do now but move on.")
	assert_true(_shown("HintRow"))
	assert_eq(_text("WalkHint"), "Click a hex to walk · 5 Stamina a step · 7 steps left")
	assert_eq(_shown_drawers(), 0, "no drawers on a tile that is done")
	assert_false(_shown("DividerRow"))

func test_a_new_tile_after_a_resolved_one_starts_over() -> void:
	_page.show_tile(AURA_WELL, "Done", null)
	assert_true(_shown("HintRow"), "precondition")

	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)

	assert_false(_shown("WalkHint"), "the walk hint goes with the resolved tile")
	assert_true(_shown("LockLine"), "the next encounter holds the player")
	assert_eq(_text("TagLabel"), "FIGHT")
	assert_eq(_text("LoreLabel"), AMORPHOUS_SPIRIT_ENCOUNTER.description)
	assert_true(_shown("DividerRow"))
	assert_eq(_shown_drawers(), 1)

func test_show_resolved_with_no_tile_to_resolve_changes_nothing() -> void:
	watch_signals(_page)
	_page.show_resolved("Done")
	assert_eq(_text("NameLabel"), "Open ground", "nothing stood here to resolve")
	assert_false(_shown("Tag"))
	assert_false(_shown("HintRow"))

	_page.show_tile(NoOpEncounter.new(), "", null)
	_page.show_resolved("Done")
	assert_eq(_text("NameLabel"), "Open ground")
	assert_false(_shown("HintRow"))
	assert_signal_emit_count(_page, "content_resized", 1, "only the show_tile spoke")

func test_the_walk_hint_follows_the_vitals_through_a_real_change() -> void:
	PlayerManager.vitals_manager.current_stamina = 40.0
	_page.show_tile(AURA_WELL, "Done", null)
	assert_eq(_text("WalkHint"), "Click a hex to walk · 5 Stamina a step · 8 steps left", "precondition")

	PlayerManager.vitals_manager.apply_vitals_change(0.0, -5.0, 0.0)

	assert_eq(_text("WalkHint"), "Click a hex to walk · 5 Stamina a step · 7 steps left", "a step walked, as the tilemap spends it")

func test_the_hint_reads_stamina_as_it_is_when_a_tile_resolves() -> void:
	PlayerManager.vitals_manager.current_stamina = 80.0
	_page.show_tile(AURA_WELL, "", null)
	PlayerManager.vitals_manager.current_stamina = 20.0

	_page.show_resolved("Done")

	assert_eq(_text("WalkHint"), "Click a hex to walk · 5 Stamina a step · 4 steps left")

#-----------------------------------------------------------------------------
# THE RUN LEDGER
#-----------------------------------------------------------------------------

func test_run_ledger_values() -> void:
	var loot: Array[ItemDefinitionData] = [CRUDE_SCALE]

	_page.set_run_stats(1, 13, 20, 3, 23, loot)

	assert_eq(_text("FightsValue"), "1 / 13")
	assert_eq(_text("GoldValue"), "20")
	assert_eq(_text("ExploredValue"), "3 / 23")
	assert_true(_loot_icon(0).visible, "the first socket holds the item")
	assert_eq(_loot_icon(0).texture, CRUDE_SCALE.icon, "showing its icon")
	for index: int in range(1, ExpeditionPage.MAX_LOOT):
		assert_false(_loot_icon(index).visible, "socket %d is empty" % (index + 1))

func test_ledger_keeps_the_latest_six() -> void:
	var loot: Array[ItemDefinitionData] = []
	for index: int in 8:
		loot.append(_item("Item %d" % (index + 1)))

	_page.set_run_stats(0, 1, 0, 1, 2, loot)

	for index: int in ExpeditionPage.MAX_LOOT:
		assert_true(_loot_icon(index).visible, "socket %d is filled" % (index + 1))
		assert_eq(_loot_icon(index).texture, loot[index + 2].icon, "socket %d holds item %d: the latest six, oldest first" % [index + 1, index + 3])

func test_a_new_run_clears_the_ledger() -> void:
	var loot: Array[ItemDefinitionData] = [CRUDE_SCALE, _item("Other")]
	_page.set_run_stats(2, 13, 40, 5, 23, loot)

	_page.set_run_stats(0, 13, 0, 1, 23, [] as Array[ItemDefinitionData])

	assert_eq(_text("FightsValue"), "0 / 13")
	assert_eq(_text("GoldValue"), "0")
	assert_eq(_text("ExploredValue"), "1 / 23")
	for index: int in ExpeditionPage.MAX_LOOT:
		assert_false(_loot_icon(index).visible, "socket %d is empty again" % (index + 1))

func test_the_ledger_does_not_touch_the_tile() -> void:
	_page.show_tile(AURA_WELL, "", null)
	watch_signals(_page)
	var height: float = _page.get_content_height()
	_page.set_run_stats(3, 13, 50, 9, 23, [CRUDE_SCALE] as Array[ItemDefinitionData])
	assert_eq(_text("NameLabel"), "Aura Well")
	assert_eq(_shown_drawers(), 2)
	assert_eq(_page.get_content_height(), height, "the ledger is a fixed 128 px")
	assert_signal_not_emitted(_page, "content_resized")

#-----------------------------------------------------------------------------
# THE POINTER
#-----------------------------------------------------------------------------

func test_only_the_drawers_take_the_pointer() -> void:
	_page.show_tile(AURA_WELL, "", null)
	var pending: Array[Node] = [_page]
	var checked: int = 0
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var control := node as Control
		if control is ChoiceDrawer:
			assert_eq(control.mouse_filter, Control.MOUSE_FILTER_STOP, "a drawer takes the press")
			for piece: Node in control.find_children("*", "Control", true, false):
				assert_eq((piece as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s inside a drawer lets it through to the drawer" % piece.name)
			continue
		pending.append_array(node.get_children())
		if control != null:
			assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s lets the pointer through" % control.name)
			checked += 1
	assert_gt(checked, 40, "precondition: the walk met the page's pieces")

func test_a_real_click_on_a_drawer_picks_its_choice() -> void:
	var chest: AdventureChest = _hosted_chest()
	var page: ExpeditionPage = chest.get_expedition_page()
	page.show_tile(AURA_WELL, "", null)
	await wait_process_frames(2)
	watch_signals(page)

	await _click_at(page.get_drawer(1).get_global_rect().get_center())

	assert_signal_emit_count(page, "choice_selected", 1)
	assert_eq(get_signal_parameters(page, "choice_selected", 0), [AURA_WELL.choices[1]], "the drawer under the pointer")

func test_a_real_click_beside_the_drawers_picks_nothing() -> void:
	var chest: AdventureChest = _hosted_chest()
	var page: ExpeditionPage = chest.get_expedition_page()
	page.show_tile(AURA_WELL, "", null)
	await wait_process_frames(2)
	watch_signals(page)

	var lore_point: Vector2 = (page.get_node("%LoreLabel") as Control).get_global_rect().get_center()
	await _click_at(lore_point)
	await _click_at(page.get_drawer(1).get_global_rect().end + Vector2(30.0, 30.0))

	assert_signal_not_emitted(page, "choice_selected")

#-----------------------------------------------------------------------------
# HEIGHT
#-----------------------------------------------------------------------------

func test_content_height_follows_the_tile() -> void:
	var short_lore: String = "Short lore."
	var one: AdventureEncounter = _encounter(Type.TREASURE, "One", [_plain_choice("A")], short_lore)
	var two: AdventureEncounter = _encounter(Type.TREASURE, "Two", [_plain_choice("A"), _plain_choice("B")], short_lore)
	watch_signals(_page)

	_page.show_tile(NoOpEncounter.new(), "", null)
	var open_height: float = _page.get_content_height()
	assert_signal_emit_count(_page, "content_resized", 1, "a new tile says its content changed")

	_page.show_tile(one, "", null)
	var one_height: float = _page.get_content_height()
	assert_signal_emit_count(_page, "content_resized", 2)

	_page.show_tile(two, "", null)
	var two_height: float = _page.get_content_height()
	assert_signal_emit_count(_page, "content_resized", 3)

	assert_ne(two_height, open_height, "two drawers and none differ")
	assert_gt(two_height, one_height)
	assert_gt(one_height, open_height)

	_page.show_resolved("Done")
	assert_signal_emit_count(_page, "content_resized", 4, "resolving changes the content too")

func test_content_height_is_right_without_waiting_a_frame() -> void:
	var encounter: AdventureEncounter = _encounter(Type.TREASURE, "Cache", [_plain_choice("A"), _plain_choice("B")], "A longer lore that runs on and on, past one line of the page's width, and then a little further still.")
	_page.show_tile(encounter, "", null)
	var at_once: float = _page.get_content_height()
	await wait_process_frames(3)
	assert_eq(_page.get_content_height(), at_once, "the answer the chest gets in the signal is the settled one")
	var flow := _node("Flow") as Control
	assert_eq(_page.get_content_height(), flow.position.y + flow.size.y, "the flow's own bottom")

#-----------------------------------------------------------------------------
# NO TEXT IS CUT OFF (the developer's rule: "increase the size, go to the next line")
#-----------------------------------------------------------------------------

## Long enough for three lines in the tray's name and in a drawer's title (250 px each).
const LONG_NAME: String = "The Starving Dreadbeast of the Misty Bamboo Hollow Attacks From The Dark"
const NO_TRIMMING: TextServer.OverrunBehavior = TextServer.OVERRUN_NO_TRIMMING

## The Here tray's height, which the name and the line stretch.
func _tray_height() -> float:
	return _control("HereTray").size.y

func _lines(unique_name: String) -> int:
	return (_node(unique_name) as Label).get_line_count()

## A fight whose drawer is a plain unresolved one: a long name, its choice's own label.
func _long_name_fight() -> AdventureEncounter:
	return _encounter(Type.COMBAT_REGULAR, LONG_NAME, [_combat_choice(_enemy("Starving Dreadbeast"), "Attack the Dreadbeast")])

## An encounter with one choice of the given label and tooltip.
func _one_drawer(label: String, tooltip: String) -> AdventureEncounter:
	return _encounter(Type.TREASURE, "Cache", [_plain_choice(label, tooltip)], "Short lore.")

func test_a_long_name_wraps_and_grows_the_tray() -> void:
	_page.show_tile(_long_name_fight(), "", null)
	var name_label := _node("NameLabel") as Label

	assert_gt(_lines("NameLabel"), 2, "precondition: the name needs three lines in its 250 px")
	assert_eq(name_label.text_overrun_behavior, NO_TRIMMING, "wrapped, never trimmed")
	assert_eq(name_label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(_lines("LineLabel"), 1, "precondition: the line is short")
	assert_eq(_tray_height(), 88.0 + 22.0 * (_lines("NameLabel") - 1), "every line after the first adds the name's 22 px")

## "Starving Dreadbeast Attacks!" is the name the developer saw cut off in a 236 px
## name. The name has the drawers' 250 px now and takes it whole, 246 px on one
## line; "Ravenous Dreadbeast Attacks!" is 254 px, wraps onto a second line, and the
## tray grows by it.
func test_the_dreadbeast_names_in_the_trays_wider_room() -> void:
	var starving: AdventureEncounter = load("res://resources/adventure/encounters/shallow_woods/combat_encounters/regular/starving_dreadbeast_encounter.tres")
	assert_eq(starving.encounter_name, "Starving Dreadbeast Attacks!", "precondition: the name the developer saw cut off")
	_page.show_tile(starving, "", null)
	assert_eq(_lines("NameLabel"), 1, "now whole on one line")
	assert_eq(_tray_height(), 88.0)
	var ravenous: AdventureEncounter = load("res://resources/adventure/encounters/shallow_woods/combat_encounters/elite/ravenous_dreadbeast_encounter.tres")
	assert_eq(ravenous.encounter_name, "Ravenous Dreadbeast Attacks!", "precondition: the longer of the two")
	_page.show_tile(ravenous, "", null)
	assert_eq(_lines("NameLabel"), 2, "wrapped onto a second line")
	assert_eq(_tray_height(), 110.0, "the tray one line taller: 88 + 22")

func test_the_chest_grows_with_a_grown_tray() -> void:
	var chest := CHEST_SCENE.instantiate() as AdventureChest
	add_child_autofree(chest)
	var page: ExpeditionPage = chest.get_expedition_page()
	page.show_tile(AURA_WELL, "", null)
	var chest_before: float = chest.size.y
	page.show_tile(_encounter(Type.REST_SITE, LONG_NAME, AURA_WELL.choices, AURA_WELL.description), "", null)
	assert_gt(chest.size.y, chest_before, "the chest hugs the taller page")

func test_a_long_drawer_title_wraps_and_grows_the_drawer() -> void:
	_page.show_tile(_one_drawer(LONG_NAME, "Short."), "", null)
	var drawer: ChoiceDrawer = _drawer(0)
	var title := _drawer_node(0, "Title") as Label

	assert_gt(title.get_line_count(), 2, "precondition: the label needs three lines in its 250 px")
	assert_eq(title.text_overrun_behavior, NO_TRIMMING)
	assert_eq(title.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(drawer.size.y, 72.0 + 20.0 * (title.get_line_count() - 1), "every line after the first adds the title's 20 px")

#-----------------------------------------------------------------------------
# THE LOCK
#-----------------------------------------------------------------------------

## It shows while the encounter holds the player (an unresolved one) and nowhere
## else: not on open ground, not on a tile that is done.
func test_the_lock_line_shows_on_an_unresolved_encounter_only() -> void:
	var lock := _node("LockLine") as Label
	var hint := _node("WalkHint") as Label
	assert_false(lock.is_visible_in_tree(), "a new page stands on open ground")
	assert_false(hint.is_visible_in_tree())

	_page.show_tile(AURA_WELL, "", null)
	assert_true(lock.is_visible_in_tree(), "an unresolved encounter holds the player")
	assert_false(hint.is_visible_in_tree(), "the walk hint waits")

	_page.show_resolved("Rested")
	assert_false(lock.is_visible_in_tree(), "resolved, it lets go")
	assert_true(hint.is_visible_in_tree(), "and the walk hint shows as it always did")

	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)
	assert_true(lock.is_visible_in_tree(), "the next encounter holds the player again")

	_page.show_tile(AURA_WELL, "Rested", null)
	assert_false(lock.is_visible_in_tree(), "a resolved tile revisited: no lock")
	assert_true(hint.is_visible_in_tree())

	_page.show_tile(NoOpEncounter.new(), "", null)
	assert_false(lock.is_visible_in_tree(), "open ground: no lock")
	assert_false(hint.is_visible_in_tree(), "and no walk hint, as before")

	_page.show_tile(null, "", null)
	assert_false(lock.is_visible_in_tree())
