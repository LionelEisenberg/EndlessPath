extends GutTest

## Integration tests for the adventure chest's expedition page (ExpeditionPage)
## and the choice drawers in it (ChoiceDrawer), instanced alone on a fresh save
## (and in the chest, for the hug and the pointer): the Here tray's three states
## (an unresolved encounter, a resolved one, open ground), the lore, the drawers
## and what each says and does when pressed, the walk hint following Stamina, the
## Run ledger, the shake, and the page's height and width (Review Focus 3 and 5).
## The text rules are statics, so they are asked directly as well as through the
## page. Encounters are the shipped Shallow Woods ones or built in code.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const PAGE_SCENE: PackedScene = preload("res://scenes/adventure/adventure_chest/expedition_page/expedition_page.tscn")
const DRAWER_SCENE: PackedScene = preload("res://scenes/adventure/adventure_chest/choice_drawer/choice_drawer.tscn")
const CHEST_SCENE: PackedScene = preload("res://scenes/adventure/adventure_chest/adventure_chest.tscn")
const AMORPHOUS_SPIRIT_ENCOUNTER: AdventureEncounter = preload("res://resources/adventure/encounters/shallow_woods/combat_encounters/regular/amorphous_spirit_encounter.tres")
const COALESCING_SPIRIT_ENCOUNTER: AdventureEncounter = preload("res://resources/adventure/encounters/shallow_woods/combat_encounters/elite/coalescing_spirit_encounter.tres")
const BOSS_ENCOUNTER: AdventureEncounter = preload("res://resources/adventure/encounters/shallow_woods/combat_encounters/manifested_spirit_encounter.tres")
const AURA_WELL: AdventureEncounter = preload("res://resources/adventure/encounters/shallow_woods/special_encounters/aura_well_encounter.tres")
const SPIRIT_VALLEY_ADVENTURE: AdventureActionData = preload("res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres")
const CRUDE_SCALE: ItemDefinitionData = preload("res://resources/items/consumables/crude_scale.tres")

const Type := AdventureEncounter.EncounterType

const LACQUER_THEME_PATH: String = "res://assets/themes/lacquer/lacquer_theme.tres"
const TRAY_PATH: String = "res://assets/ui/lacquer/lacquer_now_tray_ai.png"
const PLATE_PATH: String = "res://assets/ui/lacquer/lacquer_now_plate_ai.png"
const SOCKET_PATH: String = "res://assets/ui/lacquer/lacquer_socket_glyph_ai.png"
const TAG_PATH: String = "res://assets/ui/lacquer/lacquer_tag_ai.png"
const SEAL_PATH: String = "res://assets/ui/lacquer/lacquer_seal_locked_ai.png"
const LOCK_PATH: String = "res://assets/ui/lacquer/lacquer_mini_lock_ai.png"
const DRAWER9_PATH: String = "res://assets/ui/lacquer/lacquer_drawer9_ai.png"
const SOCKET_DRAWER_PATH: String = "res://assets/ui/lacquer/lacquer_socket_drawer_ai.png"
const DIVIDER_PATH: String = "res://assets/ui/lacquer/lacquer_line_ai.png"
const GROOVE_PATH: String = "res://assets/ui/lacquer/lacquer_groove_ai.png"
const GROOVE_END_PATH: String = "res://assets/ui/lacquer/lacquer_groove_end_ai.png"
const LOOT_SOCKET_PATH: String = "res://assets/ui/lacquer/lacquer_socket_buff_ai.png"
const COMBAT_ICON_PATH: String = "res://assets/sprites/ui/stat_icons/combat_icon.png"
const GOLD_ICON_PATH: String = "res://assets/sprites/ui/resources/gold_icon.png"
const MAP_ICON_PATH: String = "res://assets/sprites/ui/stat_icons/map_icon.png"
const STORY_GLYPH_PATH: String = "res://assets/ui/lacquer/icons/ic_story_ai.png"
const REST_GLYPH_PATH: String = "res://assets/sprites/adventure/encounter_glyphs/rest-sheet.png"
const FRAME_HOVER_PATH: String = "res://assets/styleboxes/lacquer/frame_hover.tres"

const WALK_LINE: String = "Click a hex to walk · 5 Stamina a step"
const TAN_HEX: String = "a89070"
const CREAM_HEX: String = "f0e8d8"

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

func _drawer_tag_shown(index: int) -> bool:
	return (_drawer_node(index, "Tag") as Control).visible

func _drawer_tag_text(index: int) -> String:
	return (_drawer_node(index, "TagLabel") as Label).text

func _drawer_seal_shown(index: int) -> bool:
	return (_drawer_node(index, "LockedSeal") as Control).visible

func _font_color_hex(label: Label) -> String:
	return label.get_theme_color(&"font_color").to_html(false)

func _drawer_title_color(index: int) -> String:
	return _font_color_hex(_drawer_node(index, "Title") as Label)

func _name_color() -> String:
	return _font_color_hex(_node("NameLabel") as Label)

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

func _rect_of(node: Control) -> Rect2:
	return Rect2(node.position, node.size)

## The natural width of text in a label's font.
func _text_width(label: Label, text: String) -> float:
	var font: Font = label.get_theme_font(&"font")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label.get_theme_font_size(&"font_size")).x

## The largest right edge among the Controls of `root` that show, in global px.
func _widest_right_edge(root: Control) -> float:
	var widest: float = 0.0
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		var control := node as Control
		if control != null and control != root and control.is_visible_in_tree():
			widest = maxf(widest, control.get_global_rect().end.x)
	return widest

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

func test_kind_words() -> void:
	assert_eq(ExpeditionPage.kind_word(Type.COMBAT_REGULAR), "Fight")
	assert_eq(ExpeditionPage.kind_word(Type.COMBAT_AMBUSH), "Ambush")
	assert_eq(ExpeditionPage.kind_word(Type.COMBAT_ELITE), "Elite")
	assert_eq(ExpeditionPage.kind_word(Type.COMBAT_BOSS), "Boss")
	assert_eq(ExpeditionPage.kind_word(Type.REST_SITE), "Rest")
	assert_eq(ExpeditionPage.kind_word(Type.TRAP), "Trap")
	assert_eq(ExpeditionPage.kind_word(Type.TREASURE), "Treasure")
	assert_eq(ExpeditionPage.kind_word(Type.NONE), "", "nothing to say of no encounter")

func test_kind_tags() -> void:
	assert_eq(ExpeditionPage.kind_tag(Type.COMBAT_REGULAR), "FIGHT")
	assert_eq(ExpeditionPage.kind_tag(Type.COMBAT_AMBUSH), "FIGHT", "an ambush is a fight")
	assert_eq(ExpeditionPage.kind_tag(Type.COMBAT_ELITE), "ELITE")
	assert_eq(ExpeditionPage.kind_tag(Type.COMBAT_BOSS), "BOSS")
	assert_eq(ExpeditionPage.kind_tag(Type.REST_SITE), "REST")
	assert_eq(ExpeditionPage.kind_tag(Type.TREASURE), "TREASURE")
	assert_eq(ExpeditionPage.kind_tag(Type.TRAP), "TRAP")
	assert_eq(ExpeditionPage.kind_tag(Type.NONE), "", "no tag for no encounter")

func test_walk_hint_counts_whole_steps() -> void:
	assert_eq(ExpeditionPage.walk_hint(80.0), "Click a hex to walk · 5 Stamina a step · 16 steps left")
	assert_eq(ExpeditionPage.walk_hint(79.0), "Click a hex to walk · 5 Stamina a step · 15 steps left", "a part step is not a step")
	assert_eq(ExpeditionPage.walk_hint(4.9), "Click a hex to walk · 5 Stamina a step · 0 steps left")
	assert_eq(ExpeditionPage.walk_hint(0.0), "Click a hex to walk · 5 Stamina a step · 0 steps left")
	var cost: int = int(AdventureTilemap.MOVEMENT_STAMINA_COST)
	assert_eq(ExpeditionPage.walk_hint(cost * 7.0), "Click a hex to walk · %d Stamina a step · 7 steps left" % cost, "the cost is the tilemap's")

func test_here_line_for_a_fight_names_the_enemy() -> void:
	var encounter: AdventureEncounter = _encounter(Type.COMBAT_REGULAR, "Wolves", [_combat_choice(_enemy("Grey Wolf", 12.0))])
	assert_eq(ExpeditionPage.here_line(encounter), "Fight · Grey Wolf")
	assert_eq(ExpeditionPage.here_line(AMORPHOUS_SPIRIT_ENCOUNTER), "Fight · Amorphous Spirit")

## The enemy's Health is not on the tray (it may come back as an unlockable). The
## rule that finds it stays: VitalsManager.max_health_for(), tested in
## test_fight_rules.gd.
func test_here_line_leaves_the_enemys_health_out() -> void:
	var enemy: CombatantData = _enemy("Big Beast", 10.15)
	var encounter: AdventureEncounter = _encounter(Type.COMBAT_ELITE, "Beast", [_combat_choice(enemy)])
	assert_eq(ExpeditionPage.here_line(encounter), "Elite · Big Beast")
	assert_false(ExpeditionPage.here_line(encounter).contains("Health"), "no Health figure")

func test_here_line_uses_the_kind_of_the_encounter() -> void:
	var enemy: CombatantData = _enemy("Grey Wolf")
	assert_eq(ExpeditionPage.here_line(_encounter(Type.COMBAT_AMBUSH, "Ambush!", [_combat_choice(enemy)])), "Ambush · Grey Wolf")
	assert_eq(ExpeditionPage.here_line(_encounter(Type.COMBAT_ELITE, "Alpha", [_combat_choice(enemy)])), "Elite · Grey Wolf")
	assert_eq(ExpeditionPage.here_line(_encounter(Type.COMBAT_BOSS, "Boss", [_combat_choice(enemy)])), "Boss · Grey Wolf")

func test_here_line_for_the_rest_is_its_kind() -> void:
	assert_eq(ExpeditionPage.here_line(AURA_WELL), "Rest")
	assert_eq(ExpeditionPage.here_line(_encounter(Type.TRAP, "Pit", [_plain_choice("Jump")])), "Trap")
	assert_eq(ExpeditionPage.here_line(_encounter(Type.TREASURE, "Chest", [_plain_choice("Open")])), "Treasure")

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

func test_choice_detail_prefers_the_tooltip() -> void:
	var choice: CombatChoice = _combat_choice(_enemy("Wolf", 10.0, ["Bite"]), "Fight", "Wolves hunt in packs.")
	assert_eq(ExpeditionPage.choice_detail(choice, null), "Wolves hunt in packs.", "the author's words win over the derived line")
	assert_eq(ExpeditionPage.choice_detail(AURA_WELL.choices[0], null), "Draw on the well's aura to restore yourself.")

## A fight says no more than any other choice: not the techniques its enemy uses
## and not the gold a win pays (AdventureCombat.gold_reward_for(), tested in
## test_fight_rules.gd, is no longer quoted here).
func test_choice_detail_of_a_fight_is_empty_without_a_tooltip() -> void:
	var choice: CombatChoice = _combat_choice(_enemy("Wolf", 10.0, ["Bite", "Howl"], 18))
	assert_eq(ExpeditionPage.choice_detail(choice), "", "no techniques, no gold")
	var action := AdventureActionData.new()
	action.gold_multiplier = 2.0
	assert_eq(ExpeditionPage.choice_detail(choice, action), "", "whatever the run's action pays")
	assert_eq(ExpeditionPage.choice_detail(_combat_choice(_enemy("Statue", 10.0, [], 7))), "", "an enemy with no techniques")
	assert_eq(ExpeditionPage.choice_detail(CombatChoice.new()), "", "nobody to fight")

func test_choice_detail_of_other_choices_is_empty_without_a_tooltip() -> void:
	assert_eq(ExpeditionPage.choice_detail(_plain_choice("Search"), null), "")
	assert_eq(ExpeditionPage.choice_detail(_dialogue_choice("Talk"), null), "")
	assert_eq(ExpeditionPage.choice_detail(_dialogue_choice("Talk", "Hear them out."), null), "Hear them out.")
	assert_eq(ExpeditionPage.choice_detail(null, null), "")

#-----------------------------------------------------------------------------
# THE HERE TRAY
#-----------------------------------------------------------------------------

func test_a_new_page_starts_on_open_ground() -> void:
	assert_eq(_text("NameLabel"), "Open ground")
	assert_eq(_name_color(), TAN_HEX)
	assert_eq(_text("LineLabel"), WALK_LINE)
	assert_false(_shown("Tag"))
	assert_false(_shown("BossSeal"))
	assert_false(_shown("Glyph"))
	assert_false(_shown("LoreLabel"))
	assert_false(_shown("HintRow"))
	assert_false(_shown("DividerRow"))
	assert_false(_shown("DrawerRows"))
	assert_eq(_shown_drawers(), 0)

func test_fight_tile_here_tray() -> void:
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)

	assert_eq(_text("NameLabel"), "Amorphous Spirit Attacks!")
	assert_eq(_name_color(), CREAM_HEX, "an encounter's name is cream")
	assert_true(_shown("Tag"), "a fight carries its tag")
	assert_eq(_text("TagLabel"), "FIGHT")
	assert_false(_shown("BossSeal"))
	assert_eq(_text("LineLabel"), "Fight · Amorphous Spirit", "the kind and the enemy, no Health")

func test_fight_tile_shows_the_encounters_glyph_on_frame_zero() -> void:
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)

	var glyph := _node("Glyph") as LacquerStripRect
	assert_true(glyph.visible)
	assert_eq(glyph.strip, EncounterCoin.glyph_for(Type.COMBAT_REGULAR, false), "the coin's glyph for a fight")
	assert_eq(glyph.strip.resource_path, COMBAT_ICON_PATH)
	assert_eq(glyph.frame_size, EncounterCoin.glyph_frame_size_for(Type.COMBAT_REGULAR))
	assert_eq(glyph.get_frame(), Vector2i.ZERO)
	assert_eq(glyph.size, Vector2(32.0, 32.0), "64 px art at 32")

func test_strip_glyphs_show_their_first_frame() -> void:
	_page.show_tile(AURA_WELL, "", null)
	var glyph := _node("Glyph") as LacquerStripRect
	assert_eq(glyph.strip.resource_path, REST_GLYPH_PATH, "the rest site's strip")
	assert_eq(glyph.frame_size, Vector2i(64, 64))
	assert_eq(glyph.get_frame(), Vector2i.ZERO, "frame 0 of 5")
	assert_eq(glyph.size, Vector2(32.0, 32.0))

	_page.show_tile(BOSS_ENCOUNTER, "", null)
	assert_eq(glyph.strip, EncounterCoin.glyph_for(Type.COMBAT_BOSS, false))
	assert_eq(glyph.get_frame(), Vector2i.ZERO, "frame 0 of the boss's 7")

func test_a_glyph_starts_on_its_first_frame_with_every_tile() -> void:
	_page.show_tile(AURA_WELL, "", null)
	var glyph := _node("Glyph") as LacquerStripRect
	var drawer_glyph := _drawer_node(0, "Glyph") as LacquerStripRect
	glyph.set_frame(3)
	drawer_glyph.set_frame(2)
	assert_eq(glyph.get_frame(), Vector2i(3, 0), "precondition: the strips are on a later frame")

	_page.show_tile(AURA_WELL, "", null)

	assert_eq(glyph.get_frame(), Vector2i.ZERO, "the tray's glyph")
	assert_eq(drawer_glyph.get_frame(), Vector2i.ZERO, "and the drawer's")

func test_trap_glyph_shows_at_its_file_size() -> void:
	_page.show_tile(_encounter(Type.TRAP, "Pit", [_plain_choice("Jump")]), "", null)
	var glyph := _node("Glyph") as LacquerStripRect
	assert_eq(glyph.strip, EncounterCoin.glyph_for(Type.TRAP, false))
	assert_eq(glyph.frame_size, Vector2i(32, 32), "the trap's art is 32 px native")
	assert_eq(glyph.size, Vector2(32.0, 32.0), "in the same 32 px: 1:1")

func test_an_encounter_with_no_glyph_shows_none() -> void:
	_page.show_tile(_encounter(Type.NONE, "Odd", [_plain_choice("Poke")]), "", null)
	assert_false(_shown("Glyph"), "nothing to draw for a type with no glyph")
	assert_false(_shown("Tag"), "and no tag")
	assert_eq(_text("NameLabel"), "Odd")

func test_ambush_and_elite_tiles() -> void:
	var enemy: CombatantData = _enemy("Grey Wolf", 12.0)
	_page.show_tile(_encounter(Type.COMBAT_AMBUSH, "Ambush!", [_combat_choice(enemy)]), "", null)
	assert_eq(_text("TagLabel"), "FIGHT", "an ambush is tagged as a fight")
	assert_eq(_text("LineLabel"), "Ambush · Grey Wolf")
	assert_eq((_node("Glyph") as LacquerStripRect).strip, EncounterCoin.glyph_for(Type.COMBAT_AMBUSH, false), "it shows combat")

	_page.show_tile(COALESCING_SPIRIT_ENCOUNTER, "", null)
	assert_eq(_text("TagLabel"), "ELITE")
	assert_true(_shown("Tag"))
	assert_eq(_text("LineLabel"), "Elite · Coalescing Spirit")

func test_boss_tag_is_a_seal() -> void:
	_page.show_tile(BOSS_ENCOUNTER, "", null)

	assert_true(_shown("BossSeal"), "the boss wears the vermilion seal")
	assert_eq(_text("BossSealLabel"), "BOSS")
	assert_false(_shown("Tag"), "not the carved tag")
	assert_eq(_text("LineLabel"), "Boss · Amorphous Spirit")
	assert_eq((_node("BossSeal") as TextureRect).texture.resource_path, SEAL_PATH)

	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)
	assert_false(_shown("BossSeal"), "the next tile takes the seal off")
	assert_true(_shown("Tag"))

## The seal is wider than the tag and starts 12 px sooner, so a long boss name
## stops short of it (6 px, as it does short of the tag) and wraps there instead of
## running under it. The text column starts at x 64, where the drawers' text does,
## so the room is the drawers' title room: 250 beside the tag, 238 beside the seal.
func test_the_name_leaves_room_for_the_boss_seal() -> void:
	var name_label := _node("NameLabel") as Label
	var column_x: float = _control("TextColumn").position.x
	assert_eq(column_x, 64.0, "precondition: the drawers' text column")
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)
	assert_eq(name_label.size.x, 250.0, "beside the tag, as wide as the drawer's title")
	assert_eq(name_label.custom_minimum_size.x, 250.0)
	assert_eq(column_x + name_label.size.x, _control("Tag").position.x - 6.0, "6 px short of the tag")

	_page.show_tile(BOSS_ENCOUNTER, "", null)
	assert_eq(name_label.size.x, 238.0, "beside the seal, 12 less")
	assert_eq(name_label.custom_minimum_size.x, 238.0)
	assert_eq(column_x + name_label.size.x, _control("BossSeal").position.x - 6.0, "6 px short of the seal")

	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)
	assert_eq(name_label.size.x, 250.0, "and the next tile gives the room back")
	_page.show_tile(NoOpEncounter.new(), "", null)
	assert_eq(name_label.size.x, 250.0)

func test_rest_tile_line_is_its_kind() -> void:
	_page.show_tile(AURA_WELL, "", null)

	assert_eq(_text("NameLabel"), "Aura Well")
	assert_eq(_text("TagLabel"), "REST")
	assert_true(_shown("Tag"))
	assert_eq(_text("LineLabel"), "Rest")

func test_treasure_and_trap_tiles() -> void:
	_page.show_tile(_encounter(Type.TREASURE, "Hidden Cache", [_plain_choice("Open it")]), "", null)
	assert_eq(_text("TagLabel"), "TREASURE")
	assert_eq(_text("LineLabel"), "Treasure")
	_page.show_tile(_encounter(Type.TRAP, "Spike Pit", [_plain_choice("Jump")]), "", null)
	assert_eq(_text("TagLabel"), "TRAP")
	assert_eq(_text("LineLabel"), "Trap")

func test_noop_tile() -> void:
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)
	assert_true(_shown("Tag"), "precondition: a fight showed a tag")

	_page.show_tile(NoOpEncounter.new(), "", null)

	assert_eq(_text("NameLabel"), "Open ground")
	assert_eq(_name_color(), TAN_HEX, "in tan")
	assert_eq(_text("LineLabel"), WALK_LINE)
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
	assert_eq(_text("LineLabel"), WALK_LINE)

func test_no_encounter_is_open_ground() -> void:
	_page.show_tile(AURA_WELL, "", null)
	_page.show_tile(null, "", null)
	assert_eq(_text("NameLabel"), "Open ground")
	assert_eq(_text("LineLabel"), WALK_LINE)
	assert_eq(_shown_drawers(), 0)

func test_the_here_plate_reads_here() -> void:
	assert_eq(_text("HereLabel"), "Here")
	_page.show_tile(AURA_WELL, "", null)
	assert_eq(_text("HereLabel"), "Here", "and says so on every tile")

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

func test_drawer_count_follows_the_choices() -> void:
	var choices: Array[EncounterChoice] = []
	for index: int in ExpeditionPage.MAX_DRAWERS:
		choices.append(_plain_choice("Choice %d" % (index + 1)))
		_page.show_tile(_encounter(Type.TREASURE, "Cache", choices), "", null)
		assert_eq(_shown_drawers(), index + 1, "%d choices, %d drawers" % [index + 1, index + 1])
		assert_eq(_drawer_title(index), "Choice %d" % (index + 1))

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

func test_a_new_tile_resets_the_drawers() -> void:
	_page.show_tile(AURA_WELL, "", null)
	assert_eq(_shown_drawers(), 2, "precondition")
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)
	assert_eq(_shown_drawers(), 1, "the spirit has one choice")
	assert_eq(_drawer_title(0), "Attack the Spirit")
	assert_false(_drawer(1).visible, "the second drawer is put away")

func test_get_drawer_stays_within_the_three() -> void:
	assert_not_null(_page.get_drawer(0))
	assert_not_null(_page.get_drawer(ExpeditionPage.MAX_DRAWERS - 1))
	assert_null(_page.get_drawer(ExpeditionPage.MAX_DRAWERS))
	assert_null(_page.get_drawer(-1))

func test_drawer_detail_uses_the_tooltip() -> void:
	_page.show_tile(AURA_WELL, "", null)

	assert_eq(_drawer_title(0), "Rest")
	assert_eq(_drawer_detail(0), "Draw on the well's aura to restore yourself.")
	assert_eq(_drawer_detail(1), "Commit the well's site to memory so you can find your way back.")

## A fight's drawer has a title and a tag and nothing under the title: no
## techniques, no gold (its choice has no tooltip).
func test_combat_drawer_has_no_detail_without_a_tooltip() -> void:
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)

	assert_eq(_drawer_title(0), "Attack the Spirit")
	assert_eq(_drawer_detail(0), "")
	assert_eq(_drawer_tag_text(0), "FIGHT")
	assert_true(_drawer_tag_shown(0))

func test_a_runs_action_changes_no_drawer() -> void:
	var enemy: CombatantData = _enemy("Wolf", 10.0, ["Bite"], 15)
	var action := AdventureActionData.new()
	action.gold_multiplier = 2.0
	_page.show_tile(_encounter(Type.COMBAT_REGULAR, "Wolf", [_combat_choice(enemy)]), "", action)
	assert_eq(_drawer_detail(0), "")
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", SPIRIT_VALLEY_ADVENTURE)
	assert_eq(_drawer_detail(0), "", "not the real action's either")

func test_drawer_glyph_is_the_encounters_or_the_story_for_a_talk() -> void:
	var encounter: AdventureEncounter = _encounter(Type.REST_SITE, "Camp", [_plain_choice("Rest"), _dialogue_choice("Talk to them")])
	_page.show_tile(encounter, "", null)

	var rest_glyph := _drawer_node(0, "Glyph") as LacquerStripRect
	assert_eq(rest_glyph.strip, EncounterCoin.glyph_for(Type.REST_SITE, false), "a plain choice shows the encounter's glyph")
	assert_eq(rest_glyph.frame_size, EncounterCoin.glyph_frame_size_for(Type.REST_SITE))
	assert_eq(rest_glyph.get_frame(), Vector2i.ZERO)
	assert_eq(rest_glyph.size, Vector2(32.0, 32.0))

	var talk_glyph := _drawer_node(1, "Glyph") as LacquerStripRect
	assert_eq(talk_glyph.strip.resource_path, STORY_GLYPH_PATH, "a talk shows the story glyph")
	assert_eq(talk_glyph.frame_size, Vector2i(16, 16))
	assert_eq(talk_glyph.size, Vector2(32.0, 32.0), "16 px art at 32")

func test_combat_drawer_shows_the_combat_glyph() -> void:
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)
	var glyph := _drawer_node(0, "Glyph") as LacquerStripRect
	assert_eq(glyph.strip.resource_path, COMBAT_ICON_PATH)
	assert_true(glyph.visible)

func test_tags_by_choice_kind() -> void:
	var encounter: AdventureEncounter = _encounter(Type.REST_SITE, "Camp", [
		_plain_choice("Rest"), _dialogue_choice("Talk to them"), _combat_choice(_enemy("Bandit"), "Fight them"),
	])
	_page.show_tile(encounter, "", null)

	assert_false(_drawer_tag_shown(0), "a plain choice has no tag")
	assert_true(_drawer_tag_shown(1))
	assert_eq(_drawer_tag_text(1), "TALK")
	assert_true(_drawer_tag_shown(2))
	assert_eq(_drawer_tag_text(2), "FIGHT")

func test_an_available_drawer_reads_in_cream() -> void:
	_page.show_tile(AURA_WELL, "", null)
	assert_true(_drawer(0).is_available())
	assert_eq(_drawer_title_color(0), CREAM_HEX)
	assert_false((_drawer_node(0, "Title") as Label).has_theme_color_override(&"font_color"), "the variant's own cream")
	assert_false(_drawer_seal_shown(0))

func test_locked_choice() -> void:
	var locked: EncounterChoice = _combat_choice(_enemy("Guardian", 10.0, ["Slam"]), "Face the guardian", "Needs the key.")
	locked.requirements = {_event_condition("has_the_key"): true}
	assert_false(locked.evaluate_requirements(), "precondition: the key is not found")
	_page.show_tile(_encounter(Type.COMBAT_ELITE, "Gate", [locked, _plain_choice("Go round")]), "", null)
	watch_signals(_page)

	var drawer: ChoiceDrawer = _drawer(0)
	assert_false(drawer.is_available())
	assert_eq(_drawer_title(0), "Face the guardian", "its own label")
	assert_eq(_drawer_title_color(0), TAN_HEX, "in tan")
	assert_true(_drawer_seal_shown(0), "the LOCKED seal")
	assert_eq((_drawer_node(0, "LockedLabel") as Label).text, "LOCKED")
	assert_false(_drawer_tag_shown(0), "the seal stands where the tag would")
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
	assert_eq(_drawer_title_color(0), CREAM_HEX)

func test_completed_choice_shows_its_completed_label() -> void:
	EventManager.trigger_event("aura_well_discovered")
	var mark: EncounterChoice = AURA_WELL.choices[1]
	assert_true(mark.is_completed(), "precondition: the well is marked")
	assert_false(mark.evaluate_requirements(), "precondition: and the choice's own requirement now fails")

	_page.show_tile(AURA_WELL, "", null)

	assert_eq(_drawer_title(1), "✓ Location noted", "its completed label")
	assert_eq(_drawer_title_color(1), TAN_HEX, "in tan")
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
	assert_eq(_drawer_title_color(0), TAN_HEX)
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

func test_only_an_available_drawer_shows_the_hover_frame() -> void:
	EventManager.trigger_event("aura_well_discovered")
	_page.show_tile(AURA_WELL, "", null)
	var open_frame := _drawer_node(0, "HoverFrame") as LacquerFrameOverlay
	var done_frame := _drawer_node(1, "HoverFrame") as LacquerFrameOverlay
	assert_false(open_frame.visible, "precondition: hidden to begin with")

	_drawer(0).mouse_entered.emit()
	_drawer(1).mouse_entered.emit()
	assert_true(open_frame.visible, "hover frames an available drawer")
	assert_false(done_frame.visible, "and not a completed one")

	_drawer(0).mouse_exited.emit()
	assert_false(open_frame.visible)

func test_hover_frame_is_the_kits_and_a_new_tile_clears_it() -> void:
	_page.show_tile(AURA_WELL, "", null)
	var frame := _drawer_node(0, "HoverFrame") as LacquerFrameOverlay
	assert_eq((frame.get_theme_stylebox(&"panel") as StyleBox).resource_path, FRAME_HOVER_PATH)
	_drawer(0).mouse_entered.emit()
	assert_true(frame.visible, "precondition")

	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)

	assert_false(frame.visible, "a drawer set up again starts without its frame")

func test_an_available_drawer_shows_the_hand_and_the_others_do_not() -> void:
	EventManager.trigger_event("aura_well_discovered")
	_page.show_tile(AURA_WELL, "", null)
	assert_eq(_drawer(0).mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND)
	assert_eq(_drawer(1).mouse_default_cursor_shape, Control.CURSOR_ARROW, "a completed drawer is not a button")

## The drawer's pieces, at the Here tray's 408: the tag and the seal where the
## tray's stand, the detail to x 396, the glyph and the text where the zone card's
## are. (Its other states and heights are tested with the growing, below.)
func test_drawer_pieces_sit_where_the_tray_and_the_zone_card_put_them() -> void:
	_page.show_tile(AURA_WELL, "", null)
	await wait_process_frames(2)
	var drawer: ChoiceDrawer = _drawer(0)
	assert_eq(drawer.size, Vector2(408.0, 72.0))
	assert_eq(drawer.custom_minimum_size, Vector2(408.0, 72.0))
	assert_eq(drawer.mouse_filter, Control.MOUSE_FILTER_STOP, "the drawer takes the press")
	assert_eq(drawer.theme, load(LACQUER_THEME_PATH))
	var face := _drawer_node(0, "Face") as NinePatchRect
	assert_eq(_rect_of(face), Rect2(0.0, 0.0, 410.0, 74.0), "the face and its 2 px shadow")
	assert_eq(face.texture.resource_path, DRAWER9_PATH)
	assert_eq([face.patch_margin_left, face.patch_margin_top, face.patch_margin_right, face.patch_margin_bottom], [4, 4, 6, 6], "a 9-slice with the shadow in its right and bottom margins")
	assert_true(face.draw_center)
	var socket := _drawer_node(0, "Socket") as TextureRect
	assert_eq(_rect_of(socket), Rect2(8.0, 12.0, 48.0, 48.0), "the carved socket at the card's (8, 12)")
	assert_eq(socket.texture.resource_path, SOCKET_DRAWER_PATH)
	assert_eq(_rect_of(_drawer_node(0, "Glyph") as Control), Rect2(16.0, 20.0, 32.0, 32.0))
	var column := _drawer_node(0, "TextColumn") as Control
	assert_eq(column.position, Vector2(64.0, 14.0), "the text at the card's (64, 14)")
	var title := _drawer_node(0, "Title") as Label
	assert_eq(title.global_position - drawer.global_position, Vector2(64.0, 14.0))
	assert_eq(title.size.x, 250.0, "stopping 6 px short of the tag at x 320")
	assert_eq(title.theme_type_variation, &"LabelLacquerName")
	assert_eq(title.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(title.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)
	var tag := _drawer_node(0, "Tag") as TextureRect
	assert_eq(_rect_of(tag), Rect2(320.0, 13.0, 76.0, 22.0), "where the tray's tag stands")
	assert_eq(tag.texture.resource_path, TAG_PATH)
	var tag_label := _drawer_node(0, "TagLabel") as Label
	assert_eq(tag_label.theme_type_variation, &"LabelLacquerTag")
	assert_eq(_rect_of(tag_label), Rect2(0.0, 0.0, 76.0, 22.0), "the tag's own rect, its word centred")
	assert_eq(tag_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	var seal := _drawer_node(0, "LockedSeal") as TextureRect
	assert_eq(_rect_of(seal), Rect2(308.0, 13.0, 88.0, 22.0), "where the tray's BOSS seal stands")
	assert_eq(seal.texture.resource_path, SEAL_PATH)
	var lock := _drawer_node(0, "LockedIcon") as TextureRect
	assert_eq(_rect_of(lock), Rect2(8.0, 3.0, 16.0, 16.0), "the kit's lock, at the seal's +8, +3")
	assert_eq(lock.texture.resource_path, LOCK_PATH)
	var seal_label := _drawer_node(0, "LockedLabel") as Label
	assert_eq(seal_label.theme_type_variation, &"LabelLacquerSeal")
	assert_eq(seal_label.position.x, 25.0, "the word starts at +26 with the variant's 1 px indent")
	assert_eq(seal_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
	var detail := _drawer_node(0, "Detail") as Label
	assert_eq(detail.global_position - drawer.global_position, Vector2(64.0, 38.0))
	assert_eq(detail.size.x, 332.0, "to x 396")
	assert_eq(detail.theme_type_variation, &"LabelLacquerDetail")
	assert_eq(detail.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(detail.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)

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
	assert_false((drawer.get_node("%Title") as Label).has_theme_color_override(&"font_color"), "cream again")

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

func test_a_drawer_presses_only_when_available() -> void:
	var drawer := DRAWER_SCENE.instantiate() as ChoiceDrawer
	add_child_autofree(drawer)
	watch_signals(drawer)
	drawer.setup(_plain_choice("Open"), null, Vector2i.ZERO, "")

	_press(drawer)
	assert_signal_emit_count(drawer, "pressed", 1)

	var done: EncounterChoice = _plain_choice("Already open")
	done.completion_condition = _event_condition("opened_before")
	EventManager.trigger_event("opened_before")
	drawer.setup(done, null, Vector2i.ZERO, "")
	_press(drawer)
	assert_signal_emit_count(drawer, "pressed", 1, "a completed drawer does not press")

#-----------------------------------------------------------------------------
# RESOLVED TILES
#-----------------------------------------------------------------------------

func test_resolved_tile_shows_summary_and_no_drawers() -> void:
	PlayerManager.vitals_manager.current_stamina = 80.0
	_page.show_tile(AURA_WELL, "", null)
	assert_eq(_shown_drawers(), 2, "precondition: the choices stood there")

	_page.show_resolved("+10 Health")

	assert_eq(_text("NameLabel"), "Aura Well", "the tile keeps its name")
	assert_eq(_name_color(), CREAM_HEX)
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

func test_resolving_a_fight_shows_what_it_paid() -> void:
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)
	_page.show_resolved("Won · 15 gold")
	assert_eq(_text("LineLabel"), "Won · 15 gold")
	assert_eq(_text("TagLabel"), "CLEARED")
	assert_eq(_text("LoreLabel"), "You defeated the Amorphous Spirit! Only a puddle of Goo remains...")

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
	assert_eq((_node("Glyph") as LacquerStripRect).strip.resource_path, REST_GLYPH_PATH)

func test_a_resolved_boss_is_cleared_not_sealed() -> void:
	_page.show_tile(BOSS_ENCOUNTER, "Won", null)
	assert_true(_shown("Tag"))
	assert_eq(_text("TagLabel"), "CLEARED")
	assert_false(_shown("BossSeal"), "the seal belongs to the fight ahead")
	assert_eq((_node("NameLabel") as Label).size.x, 250.0, "so the name has the tag's room")

func test_completed_text_falls_back() -> void:
	var plain: AdventureEncounter = _encounter(Type.TREASURE, "Cache", [_plain_choice("Open")], "A cache.", "")
	_page.show_tile(plain, "Done", null)
	assert_eq(_text("LoreLabel"), "Encounter completed.")

	var told: AdventureEncounter = _encounter(Type.TREASURE, "Cache", [_plain_choice("Open")], "A cache.", "The cache is bare.")
	_page.show_tile(told, "Done", null)
	assert_eq(_text("LoreLabel"), "The cache is bare.")

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

func test_the_walk_hint_follows_stamina() -> void:
	PlayerManager.vitals_manager.current_stamina = 80.0
	_page.show_tile(AURA_WELL, "Done", null)
	assert_eq(_text("WalkHint"), "Click a hex to walk · 5 Stamina a step · 16 steps left")

	PlayerManager.vitals_manager.current_stamina = 75.0
	assert_eq(_text("WalkHint"), "Click a hex to walk · 5 Stamina a step · 15 steps left", "one step spent")
	PlayerManager.vitals_manager.current_stamina = 4.0
	assert_eq(_text("WalkHint"), "Click a hex to walk · 5 Stamina a step · 0 steps left", "too tired for a step")
	PlayerManager.vitals_manager.current_stamina = 100.0
	assert_eq(_text("WalkHint"), "Click a hex to walk · 5 Stamina a step · 20 steps left", "and rested")

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

## Whether or not the page heard the Stamina change, a tile that shows resolved
## reads the Stamina as it is then. (A page out of the tree hears nothing.)
func test_a_tile_shown_resolved_reads_the_stamina_of_that_moment() -> void:
	PlayerManager.vitals_manager.current_stamina = 80.0
	remove_child(_page)
	PlayerManager.vitals_manager.current_stamina = 35.0
	add_child(_page)

	_page.show_tile(AURA_WELL, "Done", null)

	assert_eq(_text("WalkHint"), "Click a hex to walk · 5 Stamina a step · 7 steps left")

func test_a_page_out_of_the_tree_stops_following_stamina() -> void:
	PlayerManager.vitals_manager.current_stamina = 80.0
	_page.show_tile(AURA_WELL, "Done", null)
	remove_child(_page)

	PlayerManager.vitals_manager.current_stamina = 20.0

	assert_eq(_text("WalkHint"), "Click a hex to walk · 5 Stamina a step · 16 steps left", "it heard nothing once it left the tree")

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

func test_run_ledger_starts_at_zero() -> void:
	assert_eq(_text("FightsValue"), "0 / 0")
	assert_eq(_text("GoldValue"), "0")
	assert_eq(_text("ExploredValue"), "0 / 0")
	for index: int in ExpeditionPage.MAX_LOOT:
		assert_false(_loot_icon(index).visible)

func test_ledger_keeps_the_latest_six() -> void:
	var loot: Array[ItemDefinitionData] = []
	for index: int in 8:
		loot.append(_item("Item %d" % (index + 1)))

	_page.set_run_stats(0, 1, 0, 1, 2, loot)

	for index: int in ExpeditionPage.MAX_LOOT:
		assert_true(_loot_icon(index).visible, "socket %d is filled" % (index + 1))
		assert_eq(_loot_icon(index).texture, loot[index + 2].icon, "socket %d holds item %d: the latest six, oldest first" % [index + 1, index + 3])

func test_ledger_shows_up_to_six_in_the_order_given() -> void:
	var loot: Array[ItemDefinitionData] = [_item("A"), _item("B"), _item("C")]
	_page.set_run_stats(0, 0, 0, 0, 0, loot)
	for index: int in 3:
		assert_eq(_loot_icon(index).texture, loot[index].icon)
	for index: int in range(3, ExpeditionPage.MAX_LOOT):
		assert_false(_loot_icon(index).visible)

	var exactly_six: Array[ItemDefinitionData] = []
	for index: int in 6:
		exactly_six.append(_item("Six %d" % index))
	_page.set_run_stats(0, 0, 0, 0, 0, exactly_six)
	for index: int in 6:
		assert_eq(_loot_icon(index).texture, exactly_six[index].icon)

func test_a_new_run_clears_the_ledger() -> void:
	var loot: Array[ItemDefinitionData] = [CRUDE_SCALE, _item("Other")]
	_page.set_run_stats(2, 13, 40, 5, 23, loot)

	_page.set_run_stats(0, 13, 0, 1, 23, [] as Array[ItemDefinitionData])

	assert_eq(_text("FightsValue"), "0 / 13")
	assert_eq(_text("GoldValue"), "0")
	assert_eq(_text("ExploredValue"), "1 / 23")
	for index: int in ExpeditionPage.MAX_LOOT:
		assert_false(_loot_icon(index).visible, "socket %d is empty again" % (index + 1))

func test_an_item_with_no_icon_leaves_its_socket_empty() -> void:
	var bare := ItemDefinitionData.new()
	var loot: Array[ItemDefinitionData] = [bare, CRUDE_SCALE]
	_page.set_run_stats(0, 0, 0, 0, 0, loot)
	assert_false(_loot_icon(0).visible, "nothing to draw")
	assert_true(_loot_icon(1).visible, "the next item keeps its own socket")

func test_the_ledger_does_not_touch_the_tile() -> void:
	_page.show_tile(AURA_WELL, "", null)
	watch_signals(_page)
	var height: float = _page.get_content_height()
	_page.set_run_stats(3, 13, 50, 9, 23, [CRUDE_SCALE] as Array[ItemDefinitionData])
	assert_eq(_text("NameLabel"), "Aura Well")
	assert_eq(_shown_drawers(), 2)
	assert_eq(_page.get_content_height(), height, "the ledger is a fixed 128 px")
	assert_signal_not_emitted(_page, "content_resized")

func test_the_six_sockets_are_always_there() -> void:
	for index: int in ExpeditionPage.MAX_LOOT:
		var socket := _control("LootSocket%d" % (index + 1))
		assert_true(socket.visible, "socket %d shows, empty or not" % (index + 1))
		assert_eq(_rect_of(socket), Rect2(48.0 + 46.0 * index, 86.0, 40.0, 40.0))
		assert_eq((socket as TextureRect).texture.resource_path, LOOT_SOCKET_PATH)
		assert_eq(_rect_of(_loot_icon(index)), Rect2(4.0, 4.0, 32.0, 32.0), "the icon sits at +4, 32 square")

func test_ledger_pieces_sit_where_the_kit_puts_them() -> void:
	await wait_process_frames(2)
	var ledger: Control = _control("RunLedger")
	assert_eq(ledger.size, Vector2(408.0, 128.0))
	var run_label := _node("RunLabel") as Label
	assert_eq(run_label.text, "Run")
	assert_eq(run_label.theme_type_variation, &"LabelLacquerSection")
	assert_eq((run_label.get_parent() as Control).position, Vector2(0.0, -3.0), "the header sits 3 px above the ledger, as the zone chest's Activities header does")
	var groove := _node("Groove") as TextureRect
	assert_eq(groove.texture.resource_path, GROOVE_PATH)
	assert_eq(groove.stretch_mode, TextureRect.STRETCH_TILE, "the groove tiles")
	assert_eq(groove.size.y, 6.0)
	assert_eq(groove.global_position.y - ledger.global_position.y, 10.0, "the groove 10 under the ledger's top")
	assert_eq(groove.global_position.x - ledger.global_position.x, run_label.size.x + 12.0, "and 12 px after the word")
	var groove_end := _node("GrooveEnd") as TextureRect
	assert_eq(groove_end.texture.resource_path, GROOVE_END_PATH)
	assert_eq(groove_end.get_global_rect().end.x - ledger.global_position.x, 408.0 - 12.0, "ending 12 px short of the ledger's right edge")
	assert_eq(groove_end.global_position.x, groove.get_global_rect().end.x, "with its cap right after the groove")
	var figures: Array = [
		["FightsIcon", "FightsValue", "FightsCaption", 0.0, "fights", COMBAT_ICON_PATH],
		["GoldIcon", "GoldValue", "GoldCaption", 140.0, "gold", GOLD_ICON_PATH],
		["ExploredIcon", "ExploredValue", "ExploredCaption", 280.0, "explored", MAP_ICON_PATH],
	]
	for figure: Array in figures:
		var icon := _node(figure[0]) as TextureRect
		var value := _node(figure[1]) as Label
		var caption := _node(figure[2]) as Label
		var x: float = figure[3]
		assert_eq(_rect_of(icon), Rect2(x, 36.0, 32.0, 32.0), "%s: 64 px art at 32" % figure[0])
		assert_eq(icon.texture.resource_path, figure[5])
		assert_eq(value.position, Vector2(x + 40.0, 34.0), "%s sits beside its icon" % figure[1])
		assert_eq(value.theme_type_variation, &"LabelLacquerName")
		assert_eq(caption.position, Vector2(x + 40.0, 54.0))
		assert_eq(caption.text, figure[4])
		assert_eq(caption.theme_type_variation, &"LabelLacquerDetail")
	var loot_caption := _node("LootCaption") as Label
	assert_eq(loot_caption.text, "Loot")
	assert_eq(loot_caption.position, Vector2(0.0, 96.0))
	assert_eq(loot_caption.theme_type_variation, &"LabelLacquerDetail")

#-----------------------------------------------------------------------------
# WHERE EACH PIECE SITS
#-----------------------------------------------------------------------------

func test_here_tray_pieces_sit_where_the_kit_puts_them() -> void:
	await wait_process_frames(2)
	assert_eq(_page.size.x, 408.0)
	assert_eq(_page.theme, load(LACQUER_THEME_PATH))
	assert_eq(_page.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the page is only a place for its pieces")
	assert_eq(_rect_of(_control("HereTray")), Rect2(0.0, 0.0, 408.0, 88.0))
	var tray := _node("Tray") as NinePatchRect
	assert_eq(_rect_of(tray), Rect2(0.0, 0.0, 408.0, 88.0), "the face fills the tray")
	assert_eq(tray.texture.resource_path, TRAY_PATH)
	assert_eq([tray.patch_margin_left, tray.patch_margin_top, tray.patch_margin_right, tray.patch_margin_bottom], [4, 4, 2, 2], "a 9-slice: 4 of ink top and left, a 2 px lit rim bottom and right")
	assert_true(tray.draw_center)
	var plate := _node("HerePlate") as TextureRect
	assert_eq(_rect_of(plate), Rect2(8.0, -11.0, 62.0, 24.0), "the plate rides over the tray's top edge, its left edge over the socket column")
	assert_eq(plate.texture.resource_path, PLATE_PATH)
	var plate_label := _node("HereLabel") as Label
	assert_eq(plate_label.theme_type_variation, &"LabelLacquerLegend")
	assert_eq(_rect_of(plate_label), Rect2(1.0, 0.0, 60.0, 22.0), "as the Now plate's")
	assert_eq(plate_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(plate_label.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)
	var socket := _node("Socket") as TextureRect
	assert_eq(_rect_of(socket), Rect2(8.0, 20.0, 48.0, 48.0), "the socket in the drawers' column, at the tray's own y")
	assert_eq(socket.texture.resource_path, SOCKET_PATH)
	assert_eq(_rect_of(_control("Glyph")), Rect2(16.0, 28.0, 32.0, 32.0), "the glyph in theirs")
	var column := _control("TextColumn")
	assert_eq(column.position, Vector2(64.0, 18.0), "the text column starts where the drawers' text does")
	assert_eq(column.size.x, 332.0, "to x 396, where a drawer's detail ends")
	var name_label := _node("NameLabel") as Label
	assert_eq(name_label.global_position - _page.global_position, Vector2(64.0, 18.0))
	assert_eq(name_label.size.x, 250.0)
	assert_eq(name_label.theme_type_variation, &"LabelLacquerNowName")
	assert_eq(name_label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(name_label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)
	var tag := _node("Tag") as TextureRect
	assert_eq(_rect_of(tag), Rect2(320.0, 17.0, 76.0, 22.0))
	assert_eq(tag.texture.resource_path, TAG_PATH)
	assert_eq((_node("TagLabel") as Label).theme_type_variation, &"LabelLacquerTag")
	var seal := _node("BossSeal") as TextureRect
	assert_eq(_rect_of(seal), Rect2(308.0, 17.0, 88.0, 22.0))
	assert_eq(seal.texture.resource_path, SEAL_PATH)
	assert_eq((_node("BossSealLabel") as Label).theme_type_variation, &"LabelLacquerSeal")
	var line := _node("LineLabel") as Label
	assert_eq(line.global_position - _page.global_position, Vector2(64.0, 48.0), "the line 8 px under the name")
	assert_eq(line.size.x, 332.0, "to x 396")
	assert_eq(line.theme_type_variation, &"LabelLacquerDetail")
	assert_eq(line.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(line.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)

func test_the_plate_is_drawn_over_the_tray_and_the_tray_under_its_pieces() -> void:
	var tray_pieces: Array[Node] = _control("HereTray").get_children()
	var names: Array[String] = []
	for piece: Node in tray_pieces:
		names.append(piece.name)
	assert_eq(names.front(), "Tray", "the tray is the bottom of the pile")
	assert_eq(names.back(), "HerePlate", "and the plate is on top of it")

## Given a lore of one line, the flow stacks as the brief says: the lore (22), the
## lock line 10 under it (18 tall), the divider 14 under that, the first drawer 12
## under the divider, the drawers 8 apart and the ledger 28 under the last of them.
func test_the_flow_stacks_as_the_kit_says() -> void:
	_page.show_tile(_encounter(Type.TREASURE, "Cache", [_plain_choice("A"), _plain_choice("B")], "Short lore."), "", null)
	await wait_process_frames(2)
	var flow := _node("Flow") as VBoxContainer
	assert_eq(flow.position, Vector2(0.0, 104.0))
	assert_eq(flow.size.x, 408.0)
	var top: float = flow.global_position.y
	assert_eq(_control("LoreLabel").global_position.y - top, 0.0, "the lore starts the flow")
	assert_eq(_control("LoreLabel").size.y, 22.0, "one line of lore")
	assert_eq(_control("LockLine").global_position.y - top, 22.0 + 10.0, "the lock line 10 under the lore")
	assert_eq(_control("HintRow").size.y, 28.0, "10 and an 18 px line")
	assert_eq(_control("Divider").global_position.y - top, 22.0 + 28.0 + 14.0, "the divider 14 under the hint row")
	assert_eq(_control("Divider").size, Vector2(408.0, 6.0))
	assert_eq((_node("Divider") as TextureRect).texture.resource_path, DIVIDER_PATH)
	assert_eq(_drawer(0).global_position.y - top, 22.0 + 28.0 + 14.0 + 6.0 + 12.0, "the first drawer 12 under the divider")
	assert_eq(_drawer(1).global_position.y - _drawer(0).global_position.y, 72.0 + 8.0, "the drawers are 8 apart")
	assert_eq(_control("RunLedger").global_position.y - (_drawer(1).global_position.y + 72.0), 28.0, "the ledger 28 under the last drawer")
	assert_eq(_control("RunLedger").size, Vector2(408.0, 128.0))
	assert_eq(flow.size.y, _control("RunLedger").global_position.y - top + 128.0, "and the flow ends with the ledger")
	for index: int in 2:
		assert_eq(_drawer(index).size, Vector2(408.0, 72.0), "a drawer is as wide as the page")
		assert_eq(_drawer(index).global_position.x, flow.global_position.x, "flush with the page's left")

func test_the_flow_stacks_as_the_kit_says_on_a_resolved_tile() -> void:
	_page.show_tile(_encounter(Type.TREASURE, "Cache", [_plain_choice("A")], "Short lore.", "Bare now."), "Done", null)
	await wait_process_frames(2)
	var top: float = _control("Flow").global_position.y
	assert_eq(_control("LoreLabel").size.y, 22.0)
	assert_eq(_control("WalkHint").global_position.y - top, 22.0 + 10.0, "the hint 10 under the lore")
	assert_eq(_control("HintRow").size.y, 28.0, "10 and an 18 px line")
	assert_eq(_control("RunLedger").global_position.y - top, 22.0 + 28.0 + 28.0, "the ledger 28 under the hint")

func test_every_flowed_piece_stands_on_an_even_row() -> void:
	var tiles: Array = [
		[NoOpEncounter.new(), ""],
		[AURA_WELL, ""],
		[AURA_WELL, "Done"],
		[AMORPHOUS_SPIRIT_ENCOUNTER, ""],
		[_encounter(Type.TREASURE, "Cache", [_plain_choice("A"), _plain_choice("B"), _plain_choice("C")], "A long lore. ".repeat(14)), ""],
		[_encounter(Type.TREASURE, "Cache", [_plain_choice("A")], "A long lore. ".repeat(14), "A longer completed text. ".repeat(9)), "Done"],
	]
	for tile: Array in tiles:
		var encounter: AdventureEncounter = tile[0]
		_page.show_tile(encounter, tile[1], null)
		await wait_process_frames(2)
		for child: Node in (_node("Flow") as Control).get_children():
			var control := child as Control
			if control.visible:
				assert_eq(fposmod(control.position.y, 2.0), 0.0, "%s sits on an even row (y %s) on %s" % [control.name, control.position.y, encounter.encounter_name])
		assert_eq(fposmod(_page.get_content_height(), 2.0), 0.0, "the page's content height is even on %s" % encounter.encounter_name)

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

#-----------------------------------------------------------------------------
# THE POINTER
#-----------------------------------------------------------------------------

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

func test_hovering_a_drawer_frames_it() -> void:
	var chest: AdventureChest = _hosted_chest()
	var page: ExpeditionPage = chest.get_expedition_page()
	page.show_tile(AURA_WELL, "", null)
	await wait_process_frames(2)
	var frame := page.get_drawer(0).get_node("%HoverFrame") as LacquerFrameOverlay
	assert_false(frame.visible, "precondition")

	await _move_pointer_to(page.get_drawer(0).get_global_rect().get_center())
	assert_true(frame.visible, "the pointer over it")

	await _move_pointer_to(page.get_drawer(0).get_global_rect().end + Vector2(40.0, 40.0))
	assert_false(frame.visible, "and off it")

#-----------------------------------------------------------------------------
# LONG TEXTS (REVIEW FOCUS 3)
#-----------------------------------------------------------------------------

func test_long_texts_wrap_and_do_not_widen_the_chest() -> void:
	var long_text: String = "Wandering Spirit of the Endless Mist and Bamboo ".repeat(2).left(80)
	assert_eq(long_text.length(), 80, "precondition: 80 characters")
	var choice: EncounterChoice = _plain_choice(long_text, long_text)
	var encounter: AdventureEncounter = _encounter(Type.REST_SITE, long_text, [choice], long_text, long_text)
	var chest := CHEST_SCENE.instantiate() as AdventureChest
	add_child_autofree(chest)
	var page: ExpeditionPage = chest.get_expedition_page()

	page.show_tile(encounter, "", null)
	await wait_process_frames(2)

	var name_label: Label = page.get_node("%NameLabel") as Label
	assert_gt(_text_width(name_label, long_text), 250.0, "precondition: the name is wider than its slot")
	assert_lte(name_label.size.x, 250.0, "the name stays in its 250 px, and wraps there")
	assert_gt(name_label.get_line_count(), 1)
	var title := page.get_drawer(0).get_node("%Title") as Label
	assert_gt(_text_width(title, long_text), 250.0, "precondition: so is the drawer's label")
	assert_lte(title.size.x, 250.0, "the drawer's label stays in its 250 px")
	assert_gt(title.get_line_count(), 1)
	var detail := page.get_drawer(0).get_node("%Detail") as Label
	assert_gt(_text_width(detail, long_text), 332.0, "precondition: and its detail")
	assert_lte(detail.size.x, 332.0, "the detail stays in its 332 px")
	assert_gt(detail.get_line_count(), 1)
	assert_lte((page.get_node("%LineLabel") as Label).size.x, 332.0)
	assert_eq(page.size.x, 408.0, "the page stays 408 wide")
	assert_eq((page.get_node("%Flow") as Control).size.x, 408.0, "so does its flow")
	assert_eq(chest.size.x, 440.0, "and the chest 440")
	# The drawers' faces carry their 2 px shadow just past the page's edge.
	assert_lte(_widest_right_edge(page), page.get_global_rect().end.x + 2.0, "nothing of the page reaches past its right edge but a drawer's shadow")

	page.show_tile(encounter, long_text, null)
	await wait_process_frames(2)
	assert_eq(page.size.x, 408.0, "a long summary and completed text change nothing either")
	assert_eq((page.get_node("%Flow") as Control).size.x, 408.0)
	assert_lte((page.get_node("%LineLabel") as Label).size.x, 332.0)
	assert_eq(chest.size.x, 440.0)
	assert_lte(_widest_right_edge(page), page.get_global_rect().end.x + 2.0)

func test_a_long_walk_hint_and_lore_stay_in_their_width() -> void:
	PlayerManager.vitals_manager.current_stamina = 1e15
	var lore: String = "word ".repeat(120)
	_page.show_tile(_encounter(Type.TREASURE, "Cache", [_plain_choice("Open")], lore, lore), "Done", null)
	await wait_process_frames(2)
	var hint := _node("WalkHint") as Label
	assert_gt(_text_width(hint, hint.text), 408.0, "precondition: the hint is wider than the page")
	assert_eq((_node("Flow") as Control).size.x, 408.0)
	assert_lte(_widest_right_edge(_page), _page.get_global_rect().end.x)
	assert_lte((_node("WalkHint") as Label).size.x, 408.0, "the hint wraps in its 408")
	assert_gt((_node("LoreLabel") as Label).size.y, 100.0, "the lore wraps onto many lines instead of widening")

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
	assert_eq(open_height, 260.0, "open ground: 104 + the 28 gap and the 128 ledger")
	assert_signal_emit_count(_page, "content_resized", 1, "a new tile says its content changed")

	_page.show_tile(one, "", null)
	var one_height: float = _page.get_content_height()
	assert_signal_emit_count(_page, "content_resized", 2)

	_page.show_tile(two, "", null)
	var two_height: float = _page.get_content_height()
	assert_signal_emit_count(_page, "content_resized", 3)

	assert_eq(one_height, 414.0, "one line of lore (22), the lock line (10 + 18), the divider (14 + 6), one drawer (12 + 72), the ledger (156)")
	assert_eq(two_height, 494.0, "a second drawer adds 8 + 72")
	assert_ne(two_height, open_height, "two drawers and none differ")
	assert_gt(two_height, one_height)
	assert_gt(one_height, open_height)

	_page.show_resolved("Done")
	assert_signal_emit_count(_page, "content_resized", 4, "resolving changes the content too")
	assert_eq(_page.get_content_height(), 310.0, "the lore (22), the hint (10 + 18), the ledger (156)")

func test_content_height_is_right_without_waiting_a_frame() -> void:
	var encounter: AdventureEncounter = _encounter(Type.TREASURE, "Cache", [_plain_choice("A"), _plain_choice("B")], "A longer lore that runs on and on, past one line of the page's width, and then a little further still.")
	_page.show_tile(encounter, "", null)
	var at_once: float = _page.get_content_height()
	await wait_process_frames(3)
	assert_eq(_page.get_content_height(), at_once, "the answer the chest gets in the signal is the settled one")
	var flow := _node("Flow") as Control
	assert_eq(_page.get_content_height(), flow.position.y + flow.size.y, "the flow's own bottom")

## The lore sits on the mock's 22 px line boxes: its glyphs 2 px down in the first
## line (measured against the mock's render) and 1 px of room under the last, so
## n lines come to 22 n.
func test_the_lore_is_seated_as_the_mocks_line_boxes_seat_it() -> void:
	var margins: StyleBox = (_node("LoreLabel") as Label).get_theme_stylebox(&"normal")
	assert_eq(margins.get_margin(SIDE_TOP), 2.0)
	assert_eq(margins.get_margin(SIDE_BOTTOM), 1.0)

func test_lore_height_is_whole_lines() -> void:
	var lore := _node("LoreLabel") as Label
	_page.show_tile(_encounter(Type.TREASURE, "Cache", [_plain_choice("A")], "One."), "", null)
	assert_eq(lore.get_combined_minimum_size().y, 22.0, "a line of the kit's lore is 22 px")
	_page.show_tile(_encounter(Type.TREASURE, "Cache", [_plain_choice("A")], "word ".repeat(80)), "", null)
	await wait_process_frames(2)
	var lines: int = lore.get_line_count()
	assert_gt(lines, 3, "precondition: it wraps")
	assert_eq(lore.get_combined_minimum_size().y, 22.0 * lines, "so many lines, 22 each: an even height")

func test_a_long_lore_pushes_the_rest_down() -> void:
	var short_tile: AdventureEncounter = _encounter(Type.TREASURE, "Cache", [_plain_choice("A")], "Short.")
	var long_tile: AdventureEncounter = _encounter(Type.TREASURE, "Cache", [_plain_choice("A")], "word ".repeat(100))
	_page.show_tile(short_tile, "", null)
	var short_height: float = _page.get_content_height()
	_page.show_tile(long_tile, "", null)
	assert_gt(_page.get_content_height(), short_height + 60.0, "many more lines of lore")

func test_the_chest_hugs_the_expedition_page() -> void:
	var chest := CHEST_SCENE.instantiate() as AdventureChest
	add_child_autofree(chest)
	var page: ExpeditionPage = chest.get_expedition_page()
	assert_not_null(page, "the chest holds the expedition page")
	assert_same(page, chest.get_node("%ExpeditionPage"))
	assert_eq(page.get_parent(), chest.get_node("%PageSlot"), "in the page slot")
	assert_eq(page.position, Vector2.ZERO, "at its top-left corner")
	assert_eq(page.size.x, 408.0)
	assert_true(page.visible)
	assert_eq(chest.size.y, 366.0, "on open ground: 82 + 260 + 24")

	page.show_tile(AURA_WELL, "", null)
	var expected: float = roundf((82.0 + page.get_content_height() + 24.0) / 2.0) * 2.0
	assert_eq(chest.size.y, expected, "the chest follows what the page shows")
	assert_gt(chest.size.y, 366.0)

	page.show_tile(NoOpEncounter.new(), "", null)
	assert_eq(chest.size.y, 366.0, "and shrinks back")

func test_the_page_carries_the_lacquer_theme_itself() -> void:
	var label := _node("NameLabel") as Label
	assert_eq(label.get_theme_font_size(&"font_size"), 18, "the variant's size, with no chest around the page")
	assert_eq((_node("LineLabel") as Label).get_theme_font_size(&"font_size"), 15)
	assert_eq((_node("LoreLabel") as Label).get_theme_font_size(&"font_size"), 16)

#-----------------------------------------------------------------------------
# THE SHAKE
#-----------------------------------------------------------------------------

## A refused click shakes the tray softly, as a refused technique shakes its
## slot (review round 2: the lock shake's 8 px was too much for a refusal).
func test_here_shake_runs_in_even_steps() -> void:
	var tray: Control = _control("HereTray")
	var home_x: float = tray.position.x
	assert_false(_page.is_here_shaking(), "still before the shake")

	_page.shake_here()
	assert_true(_page.is_here_shaking())
	assert_eq(tray.position.x, home_x, "a shake starts at home")

	# MapGlyph's soft keyframes (the lock shake's rhythm at half its travel):
	# 0, -4, 4, -2, 2, 0, each held 0.088 s.
	simulate(_page, 1, 0.1)
	assert_eq(tray.position.x, home_x - 4.0, "0.1 s in")
	simulate(_page, 1, 0.1)
	assert_eq(tray.position.x, home_x + 4.0, "0.2 s in")
	simulate(_page, 1, 0.1)
	assert_eq(tray.position.x, home_x - 2.0, "0.3 s in")
	simulate(_page, 1, 0.1)
	assert_eq(tray.position.x, home_x + 2.0, "0.4 s in")
	assert_true(_page.is_here_shaking())
	simulate(_page, 1, 0.045)
	assert_eq(tray.position.x, home_x, "back home after 0.44 s")
	assert_false(_page.is_here_shaking(), "and done")
	simulate(_page, 1, 0.1)
	assert_eq(tray.position.x, home_x, "home for good")
	assert_eq(tray.position.y, 0.0, "it only ever moves along x")

func test_here_shake_only_ever_shows_the_keyframes() -> void:
	var tray: Control = _control("HereTray")
	_page.shake_here()
	var seen: Array[float] = []
	for _frame: int in 60:
		simulate(_page, 1, 0.01)
		if not seen.has(tray.position.x):
			seen.append(tray.position.x)
	seen.sort()
	assert_eq(seen, [-4.0, -2.0, 0.0, 2.0, 4.0] as Array[float], "whole even steps, the soft keyframes and no others")

func test_here_shake_moves_only_the_tray() -> void:
	_page.show_tile(AURA_WELL, "", null)
	var flow: Control = _control("Flow")
	var flow_position: Vector2 = flow.position
	_page.shake_here()
	simulate(_page, 1, 0.1)
	assert_ne(_control("HereTray").position.x, 0.0, "precondition: the tray moved")
	assert_eq(flow.position, flow_position, "what is under the tray stays put")
	assert_eq(_page.position, Vector2.ZERO, "and so does the page")

func test_here_shake_again_restarts_it() -> void:
	var tray: Control = _control("HereTray")
	_page.shake_here()
	simulate(_page, 1, 0.3)
	assert_eq(tray.position.x, -2.0, "precondition: mid-shake")

	_page.shake_here()
	assert_eq(tray.position.x, 0.0, "a new shake starts from home")
	simulate(_page, 1, 0.1)
	assert_eq(tray.position.x, -4.0, "and runs from its first keyframe")

func test_here_shake_does_not_hold_the_page_awake() -> void:
	assert_false(_page.is_processing(), "a page at rest does no work each frame")
	_page.shake_here()
	assert_true(_page.is_processing())
	simulate(_page, 1, 0.5)
	assert_false(_page.is_processing(), "and stops when the shake does")

func test_a_shake_goes_on_over_a_new_tile() -> void:
	var tray: Control = _control("HereTray")
	_page.shake_here()
	simulate(_page, 1, 0.1)
	_page.show_tile(AMORPHOUS_SPIRIT_ENCOUNTER, "", null)
	assert_true(_page.is_here_shaking(), "a new tile does not cut it short")
	simulate(_page, 1, 0.1)
	assert_eq(tray.position.x, 4.0)

#-----------------------------------------------------------------------------
# NO TEXT IS CUT OFF (the developer's rule: "increase the size, go to the next line")
#-----------------------------------------------------------------------------

## Long enough for three lines in the tray's name and in a drawer's title (250 px each).
const LONG_NAME: String = "The Starving Dreadbeast of the Misty Bamboo Hollow Attacks From The Dark"
## Long enough for two lines in the tray's line (332 px), as a fight's summary can run.
const LONG_LINE: String = "Rested · +80 Health · +24 Madra · +10 Spirit · +10 Body · +10 Mind · +10 Soul"
## Long enough for two or three lines in a drawer's detail (332 px).
const LONG_DETAIL: String = "Commit the well's site to memory so you can find your way back, and mark every path you took to reach it."
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
	assert_eq(fposmod(_tray_height(), 2.0), 0.0, "an even height")

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

func test_a_long_line_wraps_and_grows_the_tray() -> void:
	_page.show_tile(AURA_WELL, LONG_LINE, null)
	var line := _node("LineLabel") as Label

	assert_gt(_lines("LineLabel"), 1, "precondition: the line needs more than one line in its 332 px")
	assert_eq(line.text_overrun_behavior, NO_TRIMMING)
	assert_eq(line.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(_tray_height(), 88.0 + 18.0 * (_lines("LineLabel") - 1), "every line after the first adds the line's 18 px")
	assert_eq(fposmod(_tray_height(), 2.0), 0.0)

func test_a_long_name_and_a_long_line_grow_the_tray_together() -> void:
	_page.show_tile(_long_name_fight(), "", null)
	_page.show_resolved(LONG_LINE)
	assert_eq(_tray_height(), 88.0 + 22.0 * (_lines("NameLabel") - 1) + 18.0 * (_lines("LineLabel") - 1))

func test_the_tray_takes_its_height_back_for_short_text() -> void:
	_page.show_tile(_long_name_fight(), "", null)
	assert_gt(_tray_height(), 88.0, "precondition: grown")
	_page.show_tile(AURA_WELL, "", null)
	assert_eq(_tray_height(), 88.0, "the kit's 88 again")
	_page.show_tile(NoOpEncounter.new(), "", null)
	assert_eq(_tray_height(), 88.0)

## The socket, the glyph, the plate, the tag and the seal stay where they are:
## it is the text that grows, and the face under it.
func test_a_grown_tray_keeps_its_socket_glyph_plate_and_tag_at_the_top() -> void:
	_page.show_tile(_long_name_fight(), "", null)
	await wait_process_frames(2)
	assert_gt(_tray_height(), 88.0, "precondition: grown")
	assert_eq(_rect_of(_control("Socket")), Rect2(8.0, 20.0, 48.0, 48.0))
	assert_eq(_rect_of(_control("Glyph")), Rect2(16.0, 28.0, 32.0, 32.0))
	assert_eq(_rect_of(_control("HerePlate")), Rect2(8.0, -11.0, 62.0, 24.0))
	assert_eq(_rect_of(_control("Tag")), Rect2(320.0, 17.0, 76.0, 22.0))
	_page.show_tile(BOSS_ENCOUNTER, "", null)
	assert_eq(_rect_of(_control("BossSeal")), Rect2(308.0, 17.0, 88.0, 22.0))
	var tray := _control("Tray")
	assert_eq(_rect_of(tray), Rect2(0.0, 0.0, 408.0, _tray_height()), "the face follows the tray")

## Everything under the tray moves down with it: the flow starts 16 px under.
func test_what_is_under_a_grown_tray_moves_down() -> void:
	_page.show_tile(AURA_WELL, "", null)
	var flow := _control("Flow")
	assert_eq(flow.position.y, 104.0, "precondition: under the kit's 88 tray")
	var height_before: float = _page.get_content_height()
	_page.show_tile(_encounter(Type.REST_SITE, LONG_NAME, AURA_WELL.choices, AURA_WELL.description), "", null)
	assert_gt(_tray_height(), 88.0)
	assert_eq(flow.position.y, _tray_height() + 16.0, "16 px under the tray, wherever its bottom is")
	assert_eq(_page.get_content_height(), height_before + (_tray_height() - 88.0), "the page is as much taller as the tray")

func test_the_chest_grows_with_a_grown_tray() -> void:
	var chest := CHEST_SCENE.instantiate() as AdventureChest
	add_child_autofree(chest)
	var page: ExpeditionPage = chest.get_expedition_page()
	page.show_tile(AURA_WELL, "", null)
	var chest_before: float = chest.size.y
	page.show_tile(_encounter(Type.REST_SITE, LONG_NAME, AURA_WELL.choices, AURA_WELL.description), "", null)
	assert_gt(chest.size.y, chest_before, "the chest hugs the taller page")
	assert_eq(chest.size.y, roundf((82.0 + page.get_content_height() + 24.0) / 2.0) * 2.0)

func test_a_long_boss_name_wraps_beside_the_seal() -> void:
	var boss: AdventureEncounter = _encounter(Type.COMBAT_BOSS, "Manifested Spirit of the Endless Misty Bamboo Hollow", [_combat_choice(_enemy("Spirit"))])
	_page.show_tile(boss, "", null)
	var name_label := _node("NameLabel") as Label
	assert_eq(name_label.size.x, 238.0, "the seal leaves 238 px")
	assert_gt(_text_width(name_label, boss.encounter_name), 238.0, "precondition: the boss's name needs more than the seal leaves")
	assert_gt(_lines("NameLabel"), 1, "so it wraps instead of running under the seal")
	assert_eq(name_label.text_overrun_behavior, NO_TRIMMING)
	assert_eq(_tray_height(), 88.0 + 22.0 * (_lines("NameLabel") - 1))

func test_a_long_drawer_title_wraps_and_grows_the_drawer() -> void:
	_page.show_tile(_one_drawer(LONG_NAME, "Short."), "", null)
	var drawer: ChoiceDrawer = _drawer(0)
	var title := _drawer_node(0, "Title") as Label

	assert_gt(title.get_line_count(), 2, "precondition: the label needs three lines in its 250 px")
	assert_eq(title.text_overrun_behavior, NO_TRIMMING)
	assert_eq(title.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(drawer.size.y, 72.0 + 20.0 * (title.get_line_count() - 1), "every line after the first adds the title's 20 px")
	assert_eq(fposmod(drawer.size.y, 2.0), 0.0)

func test_a_long_drawer_detail_wraps_and_grows_the_drawer() -> void:
	_page.show_tile(_one_drawer("Rest", LONG_DETAIL), "", null)
	var drawer: ChoiceDrawer = _drawer(0)
	var detail := _drawer_node(0, "Detail") as Label

	assert_gt(detail.get_line_count(), 1, "precondition: the detail needs more than one line in its 332 px")
	assert_eq(detail.text_overrun_behavior, NO_TRIMMING)
	assert_eq(detail.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(drawer.size.y, 72.0 + 18.0 * (detail.get_line_count() - 1), "every line after the first adds the detail's 18 px")
	assert_eq(fposmod(drawer.size.y, 2.0), 0.0)

func test_a_grown_drawer_pushes_the_next_one_and_the_ledger_down() -> void:
	var encounter: AdventureEncounter = _encounter(Type.TREASURE, "Cache", [_plain_choice("Rest", LONG_DETAIL), _plain_choice("Wait", "Short.")], "Short lore.")
	_page.show_tile(encounter, "", null)
	await wait_process_frames(2)
	assert_gt(_drawer(0).size.y, 72.0, "precondition: the first drawer grew")
	assert_eq(_drawer(1).global_position.y - _drawer(0).global_position.y, _drawer(0).size.y + 8.0, "the next stands 8 px under it")
	assert_eq(_control("RunLedger").global_position.y - (_drawer(1).global_position.y + _drawer(1).size.y), 28.0, "and the ledger 28 under the last")

func test_a_drawer_without_a_detail_centres_its_title() -> void:
	_page.show_tile(_one_drawer("Search the roots", ""), "", null)
	await wait_process_frames(2)
	var drawer: ChoiceDrawer = _drawer(0)
	var title := _drawer_node(0, "Title") as Label
	var detail := _drawer_node(0, "Detail") as Label

	assert_false(detail.visible, "no empty second line")
	assert_eq(drawer.size.y, 72.0, "the kit's 72")
	assert_eq(title.global_position.y - drawer.global_position.y, 26.0, "20 px of title centred in 72")
	assert_eq(_rect_of(_drawer_node(0, "Glyph") as Control), Rect2(16.0, 20.0, 32.0, 32.0), "the glyph is centred too")

func test_a_drawer_with_a_detail_keeps_the_cards_rows() -> void:
	_page.show_tile(_one_drawer("Search the roots", "Look for what was buried."), "", null)
	await wait_process_frames(2)
	var drawer: ChoiceDrawer = _drawer(0)
	var title := _drawer_node(0, "Title") as Label
	var detail := _drawer_node(0, "Detail") as Label
	assert_true(detail.visible)
	assert_eq(drawer.size.y, 72.0)
	assert_eq(title.global_position.y - drawer.global_position.y, 14.0, "the title at (64, 14), as the zone card's")
	assert_eq(detail.global_position.y - drawer.global_position.y, 38.0, "and the detail at 38")

func test_the_tag_follows_the_title_up_and_down() -> void:
	var tag := _drawer_node(0, "Tag") as Control
	var seal := _drawer_node(0, "LockedSeal") as Control
	var title := _drawer_node(0, "Title") as Label
	var combat: CombatChoice = _combat_choice(_enemy("Wolf"), "Fight the wolf")
	_page.show_tile(_encounter(Type.COMBAT_REGULAR, "Wolf", [combat]), "", null)
	await wait_process_frames(2)
	assert_eq(tag.global_position.y - title.global_position.y, -1.0, "the tag stands 1 px above the title's line")
	assert_eq(tag.global_position.y - _drawer(0).global_position.y, 25.0, "centred with the title when there is no detail")
	assert_eq(seal.position.y, tag.position.y, "and the seal where the tag would be")
	combat.tooltip = "Wolves hunt in packs."
	_page.show_tile(_encounter(Type.COMBAT_REGULAR, "Wolf", [combat]), "", null)
	await wait_process_frames(2)
	assert_eq(tag.global_position.y - _drawer(0).global_position.y, 13.0, "13 with a detail, as the card's")

func test_a_grown_drawer_centres_its_glyph_on_the_2_px_grid() -> void:
	_page.show_tile(_one_drawer("Rest", LONG_DETAIL), "", null)
	await wait_process_frames(2)
	var drawer: ChoiceDrawer = _drawer(0)
	var socket := _drawer_node(0, "Socket") as Control
	var glyph := _drawer_node(0, "Glyph") as Control
	assert_gt(drawer.size.y, 72.0, "precondition: grown")
	assert_eq(fposmod(socket.position.y, 2.0), 0.0, "the socket on an even row")
	assert_lte(absf(socket.position.y + 24.0 - drawer.size.y / 2.0), 1.0, "centred, give or take the grid's px")
	assert_eq(glyph.position.y, socket.position.y + 8.0, "the glyph 8 px into its socket")

func test_the_walk_hint_wraps_and_the_row_grows() -> void:
	PlayerManager.vitals_manager.current_stamina = 1e15
	_page.show_tile(AURA_WELL, "Done", null)
	var hint := _node("WalkHint") as Label
	assert_gt(hint.get_line_count(), 1, "precondition: the hint is wider than the page")
	assert_eq(hint.text_overrun_behavior, NO_TRIMMING)
	assert_eq(hint.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(_control("HintRow").get_combined_minimum_size().y, 10.0 + 18.0 * hint.get_line_count(), "10 and each line's 18")

## The page's rows and the board's heights stay even whatever wraps.
func test_every_grown_height_is_even() -> void:
	PlayerManager.vitals_manager.current_stamina = 1e15
	var tiles: Array = [
		[_long_name_fight(), ""],
		[_long_name_fight(), LONG_LINE],
		[_one_drawer(LONG_NAME, LONG_DETAIL), ""],
		[_one_drawer("Rest", LONG_DETAIL), ""],
		[_one_drawer(LONG_NAME, ""), ""],
		[_encounter(Type.TREASURE, LONG_NAME, [_plain_choice(LONG_NAME, LONG_DETAIL), _plain_choice("Wait", ""), _plain_choice(LONG_NAME, "Short.")], LONG_DETAIL), ""],
		[_encounter(Type.TREASURE, LONG_NAME, [_plain_choice("Open", "")], LONG_DETAIL, LONG_DETAIL), LONG_LINE],
		[BOSS_ENCOUNTER, LONG_LINE],
	]
	for tile: Array in tiles:
		_page.show_tile(tile[0], tile[1], null)
		await wait_process_frames(2)
		var label: String = "%s / %s" % [(tile[0] as AdventureEncounter).encounter_name.left(20), str(tile[1]).left(12)]
		assert_eq(fposmod(_tray_height(), 2.0), 0.0, "the tray's height is even on %s" % label)
		for index: int in ExpeditionPage.MAX_DRAWERS:
			if _drawer(index).visible:
				assert_eq(fposmod(_drawer(index).size.y, 2.0), 0.0, "drawer %d's height is even on %s" % [index, label])
				assert_eq(fposmod(_drawer(index).global_position.y - _page.global_position.y, 2.0), 0.0, "and so is where it stands on %s" % label)
		for child: Node in (_node("Flow") as Control).get_children():
			var control := child as Control
			if control.visible:
				assert_eq(fposmod(control.position.y, 2.0), 0.0, "%s sits on an even row on %s" % [control.name, label])
				assert_eq(fposmod(control.size.y, 2.0), 0.0, "%s is an even height on %s" % [control.name, label])
		assert_eq(fposmod(_page.get_content_height(), 2.0), 0.0, "the page's content height is even on %s" % label)

## No Label of the page ellipsizes, and none of its drawers: a Label that could run
## long wraps. (test_boards_never_cut_text.gd walks every board's scene.)
func test_nothing_on_the_page_keeps_an_ellipsis() -> void:
	_page.show_tile(AURA_WELL, "", null)
	var checked: int = 0
	for node: Node in _page.find_children("*", "Label", true, false):
		assert_eq((node as Label).text_overrun_behavior, NO_TRIMMING, "%s does not trim its text" % node.name)
		checked += 1
	assert_gt(checked, 20, "precondition: the walk met the page's and its drawers' labels")

#-----------------------------------------------------------------------------
# THE TRAY AND THE DRAWERS LINE UP
#-----------------------------------------------------------------------------

## The drawers are as wide as the tray and start where it does: one left edge and
## one right edge down the column.
func test_the_drawers_are_as_wide_as_the_tray() -> void:
	_page.show_tile(AURA_WELL, "", null)
	await wait_process_frames(2)
	var tray := _control("HereTray")
	assert_eq(tray.size.x, 408.0)
	assert_eq(_control("Tray").size.x, 408.0, "and so is its face")
	assert_gt(_shown_drawers(), 1, "precondition: more than one drawer")
	for index: int in _shown_drawers():
		var drawer: ChoiceDrawer = _drawer(index)
		assert_eq(drawer.size.x, tray.size.x, "drawer %d is as wide as the tray" % index)
		assert_eq(drawer.global_position.x, tray.global_position.x, "and starts where it does")
		assert_eq(drawer.get_global_rect().end.x, tray.get_global_rect().end.x, "and ends where it does")
		var face := _drawer_node(index, "Face") as Control
		assert_eq(face.size.x, drawer.size.x + 2.0, "the face adds the 2 px shadow")

## The tray's left columns are the drawers': its socket (the same 48 px piece) at
## x 8, its glyph at x 16, its text at x 64 and its line to x 396 (where a drawer's
## detail ends), and its "Here" plate's left edge is over the socket column. The
## tray and every drawer under it share one column each for socket, glyph and text.
func test_the_trays_socket_glyph_and_text_are_in_the_drawers_columns() -> void:
	_page.show_tile(AURA_WELL, "", null)
	await wait_process_frames(2)
	var tray := _control("HereTray")
	var socket := _control("Socket")
	var glyph := _control("Glyph")
	var name_label := _node("NameLabel") as Label
	var line := _node("LineLabel") as Label
	assert_true(glyph.visible, "precondition: the rest's glyph shows")
	assert_gt(_shown_drawers(), 1, "precondition: more than one drawer")
	var socket_x: float = socket.global_position.x - tray.global_position.x
	var glyph_x: float = glyph.global_position.x - tray.global_position.x
	var text_x: float = name_label.global_position.x - tray.global_position.x
	assert_eq([socket_x, glyph_x, text_x], [8.0, 16.0, 64.0], "socket, glyph and text, from the tray's left edge")
	assert_eq(_control("HerePlate").global_position.x - tray.global_position.x, socket_x, "the plate's left edge is over the socket column")
	for index: int in _shown_drawers():
		var drawer: ChoiceDrawer = _drawer(index)
		var drawer_socket := _drawer_node(index, "Socket") as Control
		var drawer_glyph := _drawer_node(index, "Glyph") as Control
		var title := _drawer_node(index, "Title") as Label
		var detail := _drawer_node(index, "Detail") as Label
		assert_eq(drawer_socket.global_position.x - drawer.global_position.x, socket_x, "drawer %d's socket is in the tray's column" % index)
		assert_eq(drawer_socket.size, socket.size, "the same 48 px piece")
		assert_eq(drawer_glyph.global_position.x - drawer.global_position.x, glyph_x, "so is its glyph")
		assert_eq(drawer_glyph.size, glyph.size)
		assert_eq(title.global_position.x - drawer.global_position.x, text_x, "and its text")
		assert_eq(title.size.x, name_label.size.x, "with the tray's name's room beside a tag")
		assert_eq(detail.get_global_rect().end.x - drawer.global_position.x, line.get_global_rect().end.x - tray.global_position.x, "the tray's line reaches where the detail does")

## The tray's tag and the drawers' stand at the same x, to the same right edge.
func test_the_drawers_tag_stands_where_the_trays_does() -> void:
	_page.show_tile(_encounter(Type.COMBAT_REGULAR, "Wolf", [_combat_choice(_enemy("Wolf"), "Fight the wolf", "Wolves hunt in packs.")]), "", null)
	await wait_process_frames(2)
	var tray_tag := _control("Tag")
	var drawer_tag := _drawer_node(0, "Tag") as Control
	assert_true(tray_tag.visible and drawer_tag.visible, "precondition: both wear the FIGHT tag")
	assert_eq(drawer_tag.position.x, tray_tag.position.x, "the same x")
	assert_eq(drawer_tag.get_global_rect().end.x - _drawer(0).global_position.x, tray_tag.get_global_rect().end.x - _control("HereTray").global_position.x, "the same right edge")
	assert_eq(drawer_tag.size, tray_tag.size, "the same carved tag")
	assert_eq(_rect_of(drawer_tag), Rect2(320.0, 13.0, 76.0, 22.0), "at x 320 to 396")

## The LOCKED seal stands where the BOSS seal does.
func test_the_locked_seal_stands_where_the_boss_seal_does() -> void:
	var guardian: EncounterChoice = _combat_choice(_enemy("Guardian"), "Face the guardian", "Needs the key.")
	guardian.requirements = {_event_condition("has_the_key"): true}
	_page.show_tile(_encounter(Type.COMBAT_BOSS, "Gate", [guardian]), "", null)
	await wait_process_frames(2)
	var boss_seal := _control("BossSeal")
	var locked_seal := _drawer_node(0, "LockedSeal") as Control
	assert_true(boss_seal.visible and locked_seal.visible, "precondition: the tray wears the BOSS seal and the drawer the LOCKED one")
	assert_eq(locked_seal.position.x, boss_seal.position.x, "the same x")
	assert_eq(locked_seal.get_global_rect().end.x - _drawer(0).global_position.x, boss_seal.get_global_rect().end.x - _control("HereTray").global_position.x, "the same right edge")
	assert_eq(locked_seal.size, boss_seal.size, "the same seal")
	assert_eq(_rect_of(locked_seal), Rect2(308.0, 13.0, 88.0, 22.0), "at x 308 to 396")

func test_the_detail_reaches_the_trays_edge_and_the_title_stops_short_of_the_tag() -> void:
	var locked: EncounterChoice = _plain_choice("Enter the gate", "Needs the key.")
	locked.requirements = {_event_condition("has_the_key"): true}
	_page.show_tile(_encounter(Type.COMBAT_REGULAR, "Gate", [_combat_choice(_enemy("Wolf"), "Fight", "Wolves."), locked]), "", null)
	await wait_process_frames(2)
	for index: int in 2:
		var drawer: ChoiceDrawer = _drawer(index)
		var detail := _drawer_node(index, "Detail") as Label
		var title := _drawer_node(index, "Title") as Label
		assert_eq(detail.get_global_rect().end.x - drawer.global_position.x, 396.0, "drawer %d's detail reaches x 396" % index)
		assert_eq(detail.get_global_rect().position.x - drawer.global_position.x, 64.0, "from the card's text column")
		var neighbour: Control = _drawer_node(index, "LockedSeal" if index == 1 else "Tag") as Control
		assert_eq(neighbour.get_global_rect().position.x - title.get_global_rect().end.x, 6.0, "drawer %d's title stops 6 px short of its %s" % [index, neighbour.name])
		assert_eq(title.get_global_rect().position.x - drawer.global_position.x, 64.0)

#-----------------------------------------------------------------------------
# THE LOCK
#-----------------------------------------------------------------------------

func test_the_lock_line_reads_as_the_developer_asked() -> void:
	assert_eq(ExpeditionPage.LOCK_LINE, "Choose what to do here before you walk on")
	var lock := _node("LockLine") as Label
	assert_eq(lock.text, ExpeditionPage.LOCK_LINE)
	assert_eq(lock.theme_type_variation, &"LabelLacquerDetail", "in the walk hint's style")
	assert_eq(lock.theme_type_variation, (_node("WalkHint") as Label).theme_type_variation)
	assert_false(lock.has_theme_color_override(&"font_color"), "its own tan until a click is refused")
	assert_eq(_font_color_hex(lock), TAN_HEX)

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

## The hint row's place, between the lore and the divider.
func test_the_lock_line_sits_between_the_lore_and_the_divider() -> void:
	_page.show_tile(AURA_WELL, "", null)
	await wait_process_frames(2)
	var lore := _control("LoreLabel")
	var lock := _node("LockLine") as Label
	var divider := _control("DividerRow")
	assert_true(lore.global_position.y < lock.global_position.y, "under the lore")
	assert_true(lock.global_position.y < divider.global_position.y, "over the divider")
	assert_eq(lock.global_position.y - (lore.global_position.y + lore.size.y), 10.0, "10 px under the lore, where the walk hint stands")
	assert_eq(_control("HintRow").get_parent(), _control("Flow"))
	assert_eq(_control("HintRow").size.y, 28.0, "10 and an 18 px line")

## A refused click: the lock line turns to the warning colour for the length of
## the shake and then back to its own.
func test_a_refused_click_turns_the_lock_line_to_the_warning_colour_and_back() -> void:
	_page.show_tile(AURA_WELL, "", null)
	var lock := _node("LockLine") as Label
	assert_eq(_font_color_hex(lock), TAN_HEX, "precondition: tan")

	_page.shake_here()
	assert_eq(lock.get_theme_color(&"font_color"), ExpeditionPage.LOCK_WARNING_COLOUR, "the warning colour as the shake starts")
	assert_true(lock.has_theme_color_override(&"font_color"), "a font_color override, as other state colours are set")

	simulate(_page, 1, 0.2)
	simulate(_page, 1, 0.2)
	assert_true(_page.is_here_shaking(), "precondition: 0.4 s in, still shaking")
	assert_eq(lock.get_theme_color(&"font_color"), ExpeditionPage.LOCK_WARNING_COLOUR, "warm for as long as the shake lasts")

	simulate(_page, 1, 0.1)
	assert_false(_page.is_here_shaking(), "0.5 s: the shake is over")
	assert_eq(_font_color_hex(lock), TAN_HEX, "and the line is its own tan again")
	assert_false(lock.has_theme_color_override(&"font_color"), "with the override gone")

func test_a_new_refusal_restarts_the_warm_colour() -> void:
	_page.show_tile(AURA_WELL, "", null)
	var lock := _node("LockLine") as Label
	_page.shake_here()
	simulate(_page, 1, 0.4)
	_page.shake_here()
	simulate(_page, 1, 0.3)
	assert_eq(lock.get_theme_color(&"font_color"), ExpeditionPage.LOCK_WARNING_COLOUR, "0.7 s after the first click, 0.3 s after the second: still warm")
	simulate(_page, 1, 0.2)
	assert_eq(_font_color_hex(lock), TAN_HEX)

## The warning colour reads on the board: the kit's floor for text on lacquer is
## 4.56:1 (STYLE_GUIDE, Palette), against the field of the board the line sits on.
func test_the_warning_colour_reads_on_the_board() -> void:
	var field := Color("#2C1414")
	assert_gte(_contrast(ExpeditionPage.LOCK_WARNING_COLOUR, field), 4.56, "the lock line's warning colour on the lacquer field")
	assert_gte(_contrast(Color(TAN_HEX), field), 4.56, "precondition: the tan it replaces")

## The WCAG contrast ratio of two colours.
func _contrast(a: Color, b: Color) -> float:
	var lighter: float = maxf(_luminance(a), _luminance(b))
	var darker: float = minf(_luminance(a), _luminance(b))
	return (lighter + 0.05) / (darker + 0.05)

func _luminance(colour: Color) -> float:
	var channels: Array[float] = []
	for value: float in [colour.r, colour.g, colour.b]:
		channels.append(value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4))
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
