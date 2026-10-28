extends GutTest

## Integration tests for the technique dock's consumable row (spec:
## 2026-10-25-combat-consumables-lacquer-design.md): four ConsumableSlots over
## the four technique slots, previewing the inventory's hotbar on the map and
## bound to the player's CombatConsumableInstances in a fight. Keys 1 to 4
## (consumable_slot_1 to consumable_slot_4) and clicks press a socket in a fight
## only; an accepted press emits consumable_selected, a refused one (recharging,
## none left) shakes the socket. The counts follow the inventory. The dock's
## tooltip describes a hovered consumable and moves over the cast tray as it
## does for a technique. The dock is tested alone, on a fresh save, against a
## real player combatant set up as AdventureCombat sets one up.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DOCK_SCENE_PATH: String = "res://scenes/ui/combat/technique_dock/technique_dock.tscn"
const COMBATANT_SCENE_PATH: String = "res://scenes/combat/combatant/combatant_node.tscn"
const PLAYER_TEXTURE_PATH: String = "res://assets/sprites/combat/test_character_sprite.png"
const ENEMY_DATA: CombatantData = preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
const BASIC_STRIKE: AbilityData = preload("res://resources/abilities/basic_strike.tres")
const CRUDE_SCALE: ConsumableDefinitionData = preload("res://resources/items/consumables/crude_scale.tres")
const KIT_PATH: String = "res://assets/ui/lacquer/lacquer_%s_ai.png"
const CONSUMABLE_ACTIONS: Array[StringName] = [&"consumable_slot_1", &"consumable_slot_2", &"consumable_slot_3", &"consumable_slot_4"]
## Where the dock stands on screen, its consumable sockets and technique slots
## in it (spec: Layout).
const DOCK_HOME: Vector2 = Vector2(722.0, 856.0)
const CONSUMABLE_POSITIONS: Array[Vector2] = [Vector2(46.0, 18.0), Vector2(158.0, 18.0), Vector2(270.0, 18.0), Vector2(382.0, 18.0)]
const TECHNIQUE_POSITIONS: Array[Vector2] = [Vector2(30.0, 82.0), Vector2(142.0, 82.0), Vector2(254.0, 82.0), Vector2(366.0, 82.0)]
const Slot := ConsumableSlot.SlotState

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

## An effect that counts how often it fires, so no use touches the vitals.
const CountingEffect := preload("res://tests/unit/counting_effect.gd")

var _dock: TechniqueDock = null
var _player: CombatantNode = null
var _enemy: CombatantNode = null
var _vitals: VitalsManager = null
var _original_save: SaveGameData = null
## The player's vitals before the test, in the order _set_vitals() takes them.
var _original_vitals: Array = []
## Crude Scale with a counting effect in place of its Madra.
var _scale: ConsumableDefinitionData = null

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_vitals = PlayerManager.vitals_manager
	_player = null
	_enemy = null
	_original_vitals = [
		_vitals.current_health, _vitals.max_health,
		_vitals.current_madra, _vitals.max_madra,
		_vitals.current_stamina, _vitals.max_stamina,
	]
	_set_vitals(100.0, 100.0, 100.0, 100.0, 50.0, 50.0)
	_scale = CRUDE_SCALE.duplicate() as ConsumableDefinitionData
	_scale.effects = [CountingEffect.new()]
	_dock = load(DOCK_SCENE_PATH).instantiate()
	add_child_autofree(_dock)

func after_each() -> void:
	# Free whatever listens to the player's vitals first, so restoring them
	# below reaches nothing that is still connected.
	if is_instance_valid(_dock):
		_dock.free()
	if is_instance_valid(_player):
		_player.free()
	if is_instance_valid(_enemy):
		_enemy.free()
	_set_vitals.callv(_original_vitals)
	for action: StringName in CONSUMABLE_ACTIONS:
		Input.action_release(action)
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# A save reset starts the zone's idle action: stop what it started.
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _set_vitals(health: float, max_health: float, madra: float, max_madra: float, stamina: float, max_stamina: float) -> void:
	_vitals.max_health = max_health
	_vitals.max_madra = max_madra
	_vitals.max_stamina = max_stamina
	_vitals.current_health = health
	_vitals.current_madra = madra
	_vitals.current_stamina = stamina

## Puts def on hotbar slot slot_index with held of it in the inventory.
func _equip_consumable(def: ConsumableDefinitionData, slot_index: int, held: int) -> void:
	if held > 0:
		InventoryManager.award_items(def, held)
	InventoryManager.equip_consumable(def, slot_index)

## The player's combatant, set up as AdventureCombat._create_player_combatant()
## does: the equipped techniques (or `abilities`) and the player's own vitals.
func _add_player(abilities: Array[AbilityData] = []) -> CombatantNode:
	_player = load(COMBATANT_SCENE_PATH).instantiate()
	add_child_autofree(_player)
	var data := CombatantData.new()
	data.character_name = "Player"
	data.attributes = CharacterManager.get_total_attributes_data()
	data.abilities = abilities if not abilities.is_empty() else AbilityManager.get_equipped_abilities()
	data.texture = load(PLAYER_TEXTURE_PATH)
	_player.setup(data, _vitals, true)
	return _player

## An opponent to cast at. It has no AI, so it never acts.
func _add_enemy() -> CombatantNode:
	_enemy = load(COMBATANT_SCENE_PATH).instantiate()
	add_child_autofree(_enemy)
	_enemy.setup(ENEMY_DATA, null, false)
	return _enemy

## A fight's start: the player's combatant, bound to the dock with its
## consumables, as AdventureView binds it.
func _start_fight() -> void:
	_add_player()
	_dock.bind(_player.ability_manager, _vitals, _player.consumable_manager)

func _slot(index: int) -> ConsumableSlot:
	return _dock.get_consumable_slot(index)

func _slot_node(index: int, unique_name: String) -> Node:
	return _slot(index).get_node("%" + unique_name)

## The count on a socket's seal (a LacquerCountSeal, which owns its label).
func _count_text(index: int) -> String:
	return (_slot_node(index, "CountSeal").get_node("%CountLabel") as Label).text

func _instance_at(slot_index: int) -> CombatConsumableInstance:
	return _player.consumable_manager.get_instance_at_slot(slot_index)

func _font_colour(control: Control) -> Color:
	return control.get_theme_color(&"font_color")

## Presses a socket's key as the input map's action reaches the game: an
## InputEventAction pushed through the viewport, so the dock hears it in
## _unhandled_input.
func _press_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)

func _left_press() -> InputEventMouseButton:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	return press

func _tooltip_node(unique_name: String) -> Node:
	return _dock.get_technique_tooltip().get_node("%" + unique_name)

func _tooltip_rect() -> Rect2:
	return _dock.get_technique_tooltip().get_global_rect()

## Ends a technique's opening cooldown for real, so it can be cast.
func _finish_cooldown(instance: CombatAbilityInstance) -> void:
	instance.cooldown_timer.start(0.01)
	var fired: bool = await wait_for_signal(instance.cooldown_ready, 1.0)
	assert_true(fired, "precondition: %s is ready" % instance.ability_data.ability_name)

#-----------------------------------------------------------------------------
# LAYOUT
#-----------------------------------------------------------------------------

func test_layout_matches_the_spec() -> void:
	assert_eq(_dock.position, DOCK_HOME, "the dock grew upward: its bottom stays on y 1056")
	assert_eq(_dock.size, Vector2(476.0, 200.0))
	var board := _dock.get_node("Board") as TextureRect
	assert_eq(board.texture.resource_path, KIT_PATH % "tdock_consumables")
	assert_eq(board.size, Vector2(480.0, 204.0), "at file size, its 4 px shadow below and right")
	for index: int in 4:
		assert_eq(_slot(index).position, CONSUMABLE_POSITIONS[index], "consumable socket %d" % index)
		assert_eq(_slot(index).size, Vector2(48.0, 48.0))
		assert_eq(_dock.get_slot(index).position, TECHNIQUE_POSITIONS[index], "technique slot %d moved down" % index)
		assert_eq(_slot(index).position.x + 24.0, _dock.get_slot(index).position.x + 40.0, "socket %d centred over its technique" % index)
	var tray: CastTray = _dock.get_cast_tray()
	assert_eq(Rect2(tray.position, tray.size), Rect2(0.0, -52.0, 476.0, 44.0), "the cast tray stands 8 px over the dock")
	assert_eq(tray.get_global_rect().end.y, 848.0)

#-----------------------------------------------------------------------------
# THE HOTBAR ON THE MAP
#-----------------------------------------------------------------------------

func test_the_map_previews_the_hotbar() -> void:
	_equip_consumable(CRUDE_SCALE, 1, 3)

	assert_false(_dock.is_active(), "on the map the dock only shows the hotbar")
	for index: int in 4:
		if index == 1:
			assert_eq(_slot(index).get_state(), Slot.PREVIEW, "the hotbar's Crude Scale")
			assert_eq((_slot_node(index, "Icon") as TextureRect).texture, CRUDE_SCALE.icon)
			assert_eq(_count_text(index), "3")
		else:
			assert_eq(_slot(index).get_state(), Slot.EMPTY, "socket %d is empty" % index)
		assert_null(_slot(index).get_consumable_instance(), "no instance on the map")

func test_keys_show_one_to_four() -> void:
	for index: int in 4:
		assert_eq((_slot_node(index, "KeyLabel") as Label).text, str(index + 1), "socket %d's key, from the input map" % index)
		assert_true(InputMap.has_action(CONSUMABLE_ACTIONS[index]), "%s is in the input map" % CONSUMABLE_ACTIONS[index])

func test_counts_follow_the_inventory() -> void:
	_equip_consumable(_scale, 0, 3)
	InventoryManager.award_items(_scale, 2)
	assert_eq(_count_text(0), "5", "on the map")

	_start_fight()
	assert_true(_player.consumable_manager.use_consumable_instance(_instance_at(0)), "precondition: used")
	assert_eq(_count_text(0), "4", "in a fight")

func test_the_map_shows_zero_after_the_last_one() -> void:
	_equip_consumable(_scale, 0, 1)
	_start_fight()
	assert_true(_player.consumable_manager.use_consumable_instance(_instance_at(0)), "precondition: the last one used")
	assert_eq(_slot(0).get_sweep_step(), 0, "all veiled in the fight")
	assert_eq(_count_text(0), "0")

	_dock.reset()

	assert_eq(_slot(0).get_state(), Slot.PREVIEW, "the hotbar keeps it")
	assert_eq(_count_text(0), "0")
	assert_eq(_slot(0).get_sweep_step(), 0, "still veiled")

## Once the last one is used and its cooldown has run out, the socket is ready
## again but has none left: the next press is refused.
func test_the_last_one_used_refuses_the_next_press() -> void:
	_equip_consumable(_scale, 0, 1)
	_start_fight()
	var instance: CombatConsumableInstance = _instance_at(0)
	assert_true(_player.consumable_manager.use_consumable_instance(instance), "precondition: the last one used")
	instance.cooldown_timer.start(0.01)
	assert_true(await wait_for_signal(instance.cooldown_ready, 1.0), "precondition: recharged")
	watch_signals(_dock)

	_press_action(&"consumable_slot_1")

	assert_signal_not_emitted(_dock, "consumable_selected", "none left to use")
	assert_true(_slot(0).is_shaking(), "the socket refuses")

#-----------------------------------------------------------------------------
# A FIGHT
#-----------------------------------------------------------------------------

func test_a_fight_binds_each_socket_to_its_hotbar_slot() -> void:
	var pill := _scale.duplicate() as ConsumableDefinitionData
	pill.item_id = "test_pill"
	_equip_consumable(_scale, 0, 3)
	_equip_consumable(pill, 2, 1)

	_start_fight()

	assert_true(_dock.is_active())
	assert_eq(_slot(0).get_consumable_instance(), _instance_at(0))
	assert_eq(_slot(2).get_consumable_instance(), _instance_at(2))
	assert_eq(_slot(0).get_state(), Slot.ACTIVE)
	assert_eq(_slot(1).get_state(), Slot.EMPTY)
	assert_eq(_slot(3).get_state(), Slot.EMPTY)
	assert_eq(_font_colour(_slot_node(0, "KeyLabel")), ThemeConstants.LACQUER_CREAM, "a cream key: usable")

func test_a_key_presses_its_socket_in_a_fight() -> void:
	_equip_consumable(_scale, 2, 3)
	_start_fight()
	watch_signals(_dock)

	_press_action(&"consumable_slot_3")

	assert_signal_emitted_with_parameters(_dock, "consumable_selected", [_instance_at(2)])

func test_a_click_presses_its_socket_in_a_fight() -> void:
	_equip_consumable(_scale, 0, 3)
	_start_fight()
	watch_signals(_dock)

	_slot(0).gui_input.emit(_left_press())

	assert_signal_emitted_with_parameters(_dock, "consumable_selected", [_instance_at(0)])

func test_keys_and_clicks_do_nothing_on_the_map() -> void:
	_equip_consumable(_scale, 0, 3)
	watch_signals(_dock)

	_press_action(&"consumable_slot_1")
	_slot(0).gui_input.emit(_left_press())

	assert_signal_not_emitted(_dock, "consumable_selected")
	assert_false(_slot(0).is_shaking(), "no shake on the map")
	assert_eq(InventoryManager.get_consumable_count(_scale), 3, "nothing used")

func test_an_empty_socket_takes_no_press() -> void:
	_start_fight()
	watch_signals(_dock)

	_press_action(&"consumable_slot_4")

	assert_signal_not_emitted(_dock, "consumable_selected")
	assert_false(_slot(3).is_shaking(), "an empty socket does nothing at all")

func test_a_refused_press_shakes_and_emits_nothing() -> void:
	_equip_consumable(_scale, 0, 3)
	_start_fight()
	assert_true(_player.consumable_manager.use_consumable_instance(_instance_at(0)), "precondition: used, now recharging")
	watch_signals(_dock)

	_press_action(&"consumable_slot_1")

	assert_signal_not_emitted(_dock, "consumable_selected")
	assert_true(_slot(0).is_shaking(), "refused while recharging: the socket shakes")

func test_a_fight_that_opens_with_none_left_refuses() -> void:
	_equip_consumable(_scale, 0, 0)
	_start_fight()
	watch_signals(_dock)

	assert_eq(_slot(0).get_state(), Slot.ACTIVE)
	assert_eq(_slot(0).get_sweep_step(), 0, "all veiled from the start")
	assert_eq(_count_text(0), "0")
	_slot(0).gui_input.emit(_left_press())
	assert_signal_not_emitted(_dock, "consumable_selected")
	assert_true(_slot(0).is_shaking(), "refused: none left")

func test_a_consumable_can_be_pressed_while_a_technique_casts() -> void:
	_equip_consumable(_scale, 0, 3)
	_start_fight()
	_add_enemy()
	var strike: CombatAbilityInstance = _player.ability_manager.abilities[0]
	await _finish_cooldown(strike)
	assert_true(_player.ability_manager.use_ability_instance(strike, _enemy), "precondition: a cast starts")
	assert_true(_player.ability_manager.is_casting(), "precondition: casting")
	watch_signals(_dock)

	_press_action(&"consumable_slot_1")

	assert_signal_emitted_with_parameters(_dock, "consumable_selected", [_instance_at(0)])

func test_reset_lets_the_fight_go() -> void:
	_equip_consumable(_scale, 0, 3)
	_start_fight()

	_dock.reset()

	assert_false(_dock.is_active())
	assert_eq(_slot(0).get_state(), Slot.PREVIEW)
	for index: int in 4:
		assert_null(_slot(index).get_consumable_instance(), "socket %d holds no instance" % index)
	assert_eq(_font_colour(_slot_node(0, "KeyLabel")), ThemeConstants.LACQUER_TAN)

#-----------------------------------------------------------------------------
# THE TOOLTIP
#-----------------------------------------------------------------------------

func test_the_tooltip_describes_a_consumable() -> void:
	_equip_consumable(CRUDE_SCALE, 1, 3)

	_slot(1).mouse_entered.emit()
	await wait_process_frames(2)

	var tooltip: TechniqueTooltip = _dock.get_technique_tooltip()
	assert_true(tooltip.visible, "the tooltip opens on the map too")
	assert_eq((_tooltip_node("NameLabel") as Label).text, "Crude Scale")
	assert_eq((_tooltip_node("TimingText") as RichTextLabel).get_parsed_text(), "Instant · Cooldown 10 s")
	var effects: Label = _tooltip_node("EffectsLabel")
	assert_true(effects.visible)
	assert_eq(effects.text, "+20 Madra", "what it does, from the effect's describe()")
	assert_false((_tooltip_node("CostRow") as Control).visible, "a consumable has no cost")
	assert_false((_tooltip_node("DamageLabel") as Control).visible, "nor a damage line")
	assert_eq((_tooltip_node("DescriptionLabel") as Label).text, CRUDE_SCALE.description)
	assert_eq(_tooltip_rect().end.y, 848.0, "its bottom 8 px above the dock")
	assert_eq(_tooltip_rect().position.x, _slot(1).global_position.x - 8.0, "its left 8 px left of the socket's")
	_slot(1).mouse_exited.emit()
	assert_false(tooltip.visible)
	_slot(0).mouse_entered.emit()
	assert_false(tooltip.visible, "an empty socket opens no tooltip")
	assert_false((_slot_node(0, "HoverFrame") as Control).visible, "and shows no hover frame")

func test_the_consumable_tooltip_moves_over_the_cast_tray() -> void:
	_equip_consumable(CRUDE_SCALE, 0, 3)
	_start_fight()
	_add_enemy()
	var strike: CombatAbilityInstance = _player.ability_manager.abilities[0]
	await _finish_cooldown(strike)
	_slot(0).mouse_entered.emit()
	await wait_process_frames(2)
	assert_eq(_tooltip_rect().end.y, 848.0, "precondition: above the dock")

	_player.ability_manager.use_ability_instance(strike, _enemy)
	await wait_process_frames(1)

	assert_eq(_tooltip_rect().end.y, 796.0, "the tray shows: the tooltip rises above it")
	assert_eq((_tooltip_node("NameLabel") as Label).text, "Crude Scale", "still the consumable's tooltip")
	assert_true((_tooltip_node("EffectsLabel") as Control).visible)
	await wait_for_signal(strike.cast_finished, 2.0)
	await wait_process_frames(1)
	assert_eq(_tooltip_rect().end.y, 848.0, "the tray goes: back above the dock")

func test_a_consumable_with_no_cooldown_reads_instant() -> void:
	var quick := CRUDE_SCALE.duplicate() as ConsumableDefinitionData
	quick.cooldown_seconds = 0.0
	_equip_consumable(quick, 0, 1)

	_slot(0).mouse_entered.emit()

	assert_eq((_tooltip_node("TimingText") as RichTextLabel).get_parsed_text(), "Instant", "no cooldown to name")

func test_a_technique_tooltip_hides_the_effects_line() -> void:
	_equip_consumable(CRUDE_SCALE, 0, 3)
	_slot(0).mouse_entered.emit()
	_slot(0).mouse_exited.emit()

	_dock.get_slot(0).mouse_entered.emit()

	assert_eq((_tooltip_node("NameLabel") as Label).text, "Basic Strike")
	assert_false((_tooltip_node("EffectsLabel") as Control).visible, "no consumable line on a technique")
	assert_true((_tooltip_node("CostRow") as Control).visible, "the technique's cost is back")
