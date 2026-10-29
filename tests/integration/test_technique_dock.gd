extends GutTest

## Integration tests for the technique dock (TechniqueDock) at the bottom of
## the adventure view: its four slots (TechniqueSlot) previewing the equipped
## loadout and its costs on the map and bound to the player's ability instances
## in a fight (the cooldown sweep and its seconds), Q/W/E/R and clicks (a refused
## press shakes the slot and emits nothing; keys do nothing outside a fight),
## the cast tray over the dock, the tooltip a hovered slot opens, and the
## presses the dock keeps off the map. A technique's name that needs more room
## than its board gives it wraps there and grows the board (the developer's
## rule: no text is cut off): the cast tray and the tooltip.
## The dock is tested alone, on a fresh save, against a real player combatant
## (combatant_node.tscn) set up as AdventureCombat sets one up, with the
## player's own VitalsManager.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const DOCK_SCENE_PATH: String = "res://scenes/ui/combat/technique_dock/technique_dock.tscn"
const COMBATANT_SCENE_PATH: String = "res://scenes/combat/combatant/combatant_node.tscn"
const PLAYER_TEXTURE_PATH: String = "res://assets/sprites/combat/test_character_sprite.png"
const ENEMY_DATA: CombatantData = preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
const BASIC_STRIKE: AbilityData = preload("res://resources/abilities/basic_strike.tres")
const EMPTY_PALM: AbilityData = preload("res://resources/abilities/empty_palm.tres")
const ENFORCE: AbilityData = preload("res://resources/abilities/enforce.tres")
const POWER_FONT: AbilityData = preload("res://resources/abilities/power_font.tres")
const KIT_PATH: String = "res://assets/ui/lacquer/lacquer_%s_ai.png"
const SLOT_ACTIONS: Array[StringName] = [&"ability_slot_1", &"ability_slot_2", &"ability_slot_3", &"ability_slot_4"]
## A technique's name that needs three lines in the cast tray's 150 px and in the
## tooltip's 268.
const LONG_TECHNIQUE: String = "Flowing River Strike of the Endless Misty Bamboo Hollow, Lit By The Cold Moon And The Hundred Silent Stars Above"

var _dock: TechniqueDock = null
var _player: CombatantNode = null
var _enemy: CombatantNode = null
var _vitals: VitalsManager = null
var _original_save: SaveGameData = null
## The player's vitals before the test, in the order _set_vitals() takes them.
var _original_vitals: Array = []

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

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
	for action: StringName in SLOT_ACTIONS:
		Input.action_release(action)
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()
	# A save reset starts the zone's idle action: stop what it started.
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Sets the player's vitals: the three current values and their maxima.
func _set_vitals(health: float, max_health: float, madra: float, max_madra: float, stamina: float, max_stamina: float) -> void:
	_vitals.max_health = max_health
	_vitals.max_madra = max_madra
	_vitals.max_stamina = max_stamina
	_vitals.current_health = health
	_vitals.current_madra = madra
	_vitals.current_stamina = stamina

## Unlocks a technique and puts it in a loadout slot (0 to 3).
func _equip(ability_id: String, slot_index: int) -> void:
	AbilityManager.unlock_ability(ability_id)
	assert_true(AbilityManager.equip_ability_at_slot(ability_id, slot_index), "precondition: %s equips" % ability_id)

## The player's combatant, set up as AdventureCombat._create_player_combatant()
## does: the equipped techniques, the character's total attributes and the
## player's own vitals manager. `abilities` replaces the loadout when given.
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

## A fight's start: the player's combatant, bound to the dock.
func _start_fight() -> void:
	_add_player()
	_dock.bind(_player.ability_manager, _vitals)

## The player's ability instance at `index` in its ability manager.
func _instance(index: int) -> CombatAbilityInstance:
	return _player.ability_manager.abilities[index]

## Ends a technique's running cooldown for real: its timer runs down in a frame
## or two and fires cooldown_ready.
func _finish_cooldown(instance: CombatAbilityInstance) -> void:
	instance.cooldown_timer.start(0.01)
	var fired: bool = await wait_for_signal(instance.cooldown_ready, 1.0)
	assert_true(fired, "precondition: %s's cooldown ended" % instance.ability_data.ability_name)

## Presses a slot's key as the input map's action reaches the game: an
## InputEventAction pushed through the viewport, so the dock hears it in
## _unhandled_input (Input.action_press() only sets Input's state).
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

func _slot(index: int) -> TechniqueSlot:
	return _dock.get_slot(index)

func _slot_node(index: int, unique_name: String) -> Node:
	return _slot(index).get_node("%" + unique_name)

func _tooltip_node(unique_name: String) -> Node:
	return _dock.get_technique_tooltip().get_node("%" + unique_name)

func _tray_node(unique_name: String) -> Node:
	return _dock.get_cast_tray().get_node("%" + unique_name)

#-----------------------------------------------------------------------------
# THE LOADOUT ON THE MAP
#-----------------------------------------------------------------------------

func test_preview_shows_the_equipped_loadout() -> void:
	_equip("empty_palm", 3)
	_dock.show_loadout()
	assert_false(_dock.is_active(), "on the map the dock only shows the loadout")
	var expected: Array = [BASIC_STRIKE, ENFORCE, null, EMPTY_PALM]
	var keys: Array[String] = ["Q", "W", "E", "R"]
	for index: int in 4:
		var slot: TechniqueSlot = _slot(index)
		var key_label: Label = _slot_node(index, "KeyLabel")
		assert_eq(key_label.text, keys[index], "the key from the input map (slot %d)" % index)
		assert_null(slot.get_ability_instance(), "no instance on the map (slot %d)" % index)
		var data: AbilityData = expected[index]
		if data == null:
			assert_eq(slot.get_state(), TechniqueSlot.SlotState.EMPTY, "slot %d is empty" % index)
			assert_false((_slot_node(index, "Icon") as Control).visible, "an empty slot shows no icon")
			assert_false((_slot_node(index, "CostLine") as Control).visible, "and no cost")
		else:
			assert_eq(slot.get_state(), TechniqueSlot.SlotState.PREVIEW, "slot %d previews %s" % [index, data.ability_name])
			assert_true((_slot_node(index, "Icon") as Control).visible)
			assert_eq((_slot_node(index, "Icon") as TextureRect).texture, data.icon)
			assert_true((_slot_node(index, "CostLine") as Control).visible, "its cost under the slot")

## The cost line: the resource's mini icon and the amount.
func test_cost_line_shows_the_resource_and_amount() -> void:
	_equip("empty_palm", 2)
	_equip("power_font", 3)
	_dock.show_loadout()
	var expected: Array = [["3", "stamina"], ["10", "madra"], ["8", "madra"], ["30", "madra"]]
	for index: int in 4:
		assert_eq((_slot_node(index, "CostLabel") as Label).text, expected[index][0], "slot %d's cost" % index)
		var icon: Texture2D = (_slot_node(index, "CostIcon") as TextureRect).texture
		assert_eq(icon.resource_path, KIT_PATH % ("mini_" + expected[index][1]), "slot %d's resource" % index)
	var health_technique := AbilityData.new()
	health_technique.ability_id = "blood_price"
	health_technique.ability_name = "Blood Price"
	health_technique.health_cost = 6.0
	_slot(2).show_preview(health_technique, 2)
	assert_eq((_slot_node(2, "CostLabel") as Label).text, "6")
	assert_eq((_slot_node(2, "CostIcon") as TextureRect).texture.resource_path, KIT_PATH % "mini_health")
	var free_technique := AbilityData.new()
	free_technique.ability_id = "breathe"
	free_technique.ability_name = "Breathe"
	_slot(2).show_preview(free_technique, 2)
	assert_false((_slot_node(2, "CostLine") as Control).visible, "a free technique has no cost line")

#-----------------------------------------------------------------------------
# A FIGHT
#-----------------------------------------------------------------------------

func test_bind_activates_the_slots() -> void:
	_start_fight()
	assert_true(_dock.is_active())
	assert_eq(_slot(0).get_state(), TechniqueSlot.SlotState.ACTIVE)
	assert_eq(_slot(0).get_ability_instance(), _instance(0))
	assert_eq(_slot(0).get_ability_instance().ability_data, BASIC_STRIKE)
	assert_eq(_slot(1).get_state(), TechniqueSlot.SlotState.ACTIVE)
	assert_eq(_slot(1).get_ability_instance().ability_data, ENFORCE)
	for index: int in [2, 3]:
		assert_eq(_slot(index).get_state(), TechniqueSlot.SlotState.EMPTY, "slot %d stays empty" % index)
		assert_null(_slot(index).get_ability_instance())

## Each instance goes to the slot its technique is equipped in.
func test_bind_puts_each_technique_in_its_equip_slot() -> void:
	_equip("empty_palm", 3)
	_start_fight()
	assert_eq(_slot(3).get_ability_instance().ability_data, EMPTY_PALM, "R holds Empty Palm")
	assert_eq(_slot(2).get_state(), TechniqueSlot.SlotState.EMPTY, "E stays empty")

## An instance whose technique is not in the loadout takes the first free slot.
func test_a_technique_outside_the_loadout_takes_the_first_free_slot() -> void:
	var abilities: Array[AbilityData] = [ENFORCE, POWER_FONT]
	_add_player(abilities)
	_dock.bind(_player.ability_manager, _vitals)
	assert_eq(_slot(1).get_ability_instance().ability_data, ENFORCE, "Enforce in its own slot")
	assert_eq(_slot(0).get_ability_instance().ability_data, POWER_FONT, "Power Font in the first slot left free")
	assert_eq(_slot(2).get_state(), TechniqueSlot.SlotState.EMPTY)

## The sweep steps with cooldown_updated against the running timer's length
## (the initial 1.5 s, not the technique's base cooldown), and a new cooldown
## starts it over.
func test_the_sweep_follows_the_cooldown() -> void:
	_start_fight()
	var strike: CombatAbilityInstance = _instance(0)
	strike.cooldown_updated.emit(0.75)
	assert_eq(_slot(0).get_sweep_step(), 12, "0.75 of 1.5 s left: 12 of 24")
	assert_eq((_slot_node(0, "SecondsLabel") as Label).text, "1")
	strike.cooldown_updated.emit(0.05)
	assert_eq(_slot(0).get_sweep_step(), 23, "a sliver left: the last step still veiled")
	await _finish_cooldown(strike)
	_add_enemy()
	assert_true(_player.ability_manager.use_ability_instance(strike, _enemy), "precondition: the cast starts")
	var landed: bool = await wait_for_signal(strike.cast_finished, 2.0)
	assert_true(landed, "precondition: the cast lands")
	assert_eq(strike.cooldown_timer.wait_time, BASIC_STRIKE.base_cooldown, "precondition: its 2 s cooldown runs")
	assert_lt(_slot(0).get_sweep_step(), 2, "a new cooldown starts the sweep over")
	assert_eq((_slot_node(0, "SecondsLabel") as Label).text, "2")

func test_casting_shows_the_cast_tray() -> void:
	_start_fight()
	_add_enemy()
	var strike: CombatAbilityInstance = _instance(0)
	await _finish_cooldown(strike)
	var tray: CastTray = _dock.get_cast_tray()
	assert_false(tray.visible, "no cast tray before the cast")
	assert_true(_player.ability_manager.use_ability_instance(strike, _enemy), "precondition: the cast starts")
	assert_true(tray.visible, "the cast tray shows outright")
	assert_eq((_tray_node("NameLabel") as Label).text, "Basic Strike")
	assert_eq((_tray_node("TimeText") as RichTextLabel).get_parsed_text(), "0.5 s", "its whole cast left")
	assert_eq((_tray_node("CastRod") as LacquerRod).get_step(), 0, "the rod starts empty")
	var landed: bool = await wait_for_signal(strike.cast_finished, 2.0)
	assert_true(landed, "precondition: Basic Strike's 0.5 s cast lands")
	assert_false(tray.visible, "the tray goes when the cast lands")

## A cancelled cast (interrupted) hides the tray at once.
func test_a_cancelled_cast_hides_the_tray() -> void:
	_start_fight()
	_add_enemy()
	var strike: CombatAbilityInstance = _instance(0)
	await _finish_cooldown(strike)
	_player.ability_manager.use_ability_instance(strike, _enemy)
	assert_true(_dock.get_cast_tray().visible, "precondition: casting")
	strike.cancel_cast()
	assert_false(_dock.get_cast_tray().visible)
	assert_lt(_slot(0).get_sweep_step(), TechniqueSlot.SWEEP_STEPS, "a cancelled cast still starts the cooldown")

## A technique with a long name, cast: the player's combatant carries a copy of
## Basic Strike under that name.
func _cast_long_named_technique() -> CombatAbilityInstance:
	var long_strike := BASIC_STRIKE.duplicate() as AbilityData
	long_strike.ability_name = LONG_TECHNIQUE
	_add_player([long_strike] as Array[AbilityData])
	_dock.bind(_player.ability_manager, _vitals)
	var instance: CombatAbilityInstance = _instance(0)
	instance.cast_started.emit(instance, 1.0)
	return instance

## A name that needs more than the tray's 150 px wraps there and the tray grows
## by its 20 px a line, never ellipsizing: 44 for one line.
func test_a_long_technique_name_wraps_and_grows_the_cast_tray() -> void:
	_cast_long_named_technique()
	var tray: CastTray = _dock.get_cast_tray()
	var name_label: Label = _tray_node("NameLabel")
	assert_true(tray.visible, "precondition: casting")
	assert_gt(name_label.get_line_count(), 2, "precondition: the name needs three lines")
	assert_eq(name_label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)
	assert_eq(tray.size.y, 44.0 + 20.0 * (name_label.get_line_count() - 1), "every line after the first adds the name's 20 px")
	await wait_process_frames(2)
	assert_eq((tray.get_node("Tray") as Control).size, tray.size, "the face follows the tray")

## A name longer than the tooltip's 268 px wraps there and the board grows with
## it.
func test_a_long_technique_name_wraps_and_grows_the_tooltip() -> void:
	var long_strike := BASIC_STRIKE.duplicate() as AbilityData
	long_strike.ability_name = LONG_TECHNIQUE
	var tooltip: TechniqueTooltip = _dock.get_technique_tooltip()
	tooltip.show_for_ability(BASIC_STRIKE, _slot(0), false)
	await wait_process_frames(2)
	var short_height: float = tooltip.size.y
	tooltip.show_for_ability(long_strike, _slot(0), false)
	await wait_process_frames(2)
	var name_label: Label = _tooltip_node("NameLabel")
	assert_gt(name_label.get_line_count(), 1, "precondition: the name needs more than one line")
	assert_eq(name_label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "wrapped, never trimmed")
	assert_eq(name_label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_gt(tooltip.size.y, short_height, "the board grew")

#-----------------------------------------------------------------------------
# PRESSES
#-----------------------------------------------------------------------------

func test_refused_press_shakes_and_does_not_emit() -> void:
	_start_fight()
	watch_signals(_dock)
	watch_signals(LogManager)
	assert_false(_instance(0).is_ready(), "precondition: still on its first cooldown")
	_press_action(&"ability_slot_1")
	assert_true(_slot(0).is_shaking(), "the slot shakes")
	assert_false(_slot(1).is_shaking(), "only the pressed slot")
	assert_signal_not_emitted(_dock, "ability_selected")
	assert_signal_not_emitted(LogManager, "message_logged", "no log line: the sweep already says why")

## Too little of the resource, or another technique casting, refuses a press
## the same way, as can_cast_ability_instance() decides. A key over an empty
## slot does nothing at all.
func test_unaffordable_and_casting_presses_are_refused_too() -> void:
	_start_fight()
	_add_enemy()
	await _finish_cooldown(_instance(0))
	await _finish_cooldown(_instance(1))
	watch_signals(_dock)
	_vitals.current_stamina = 2.0
	_press_action(&"ability_slot_1")
	assert_true(_slot(0).is_shaking(), "2 Stamina for a 3 Stamina strike: refused")
	_vitals.current_stamina = 50.0
	assert_true(_player.ability_manager.use_ability_instance(_instance(0), _enemy), "precondition: Basic Strike casts")
	_press_action(&"ability_slot_2")
	assert_true(_slot(1).is_shaking(), "Enforce while Basic Strike casts: refused")
	_press_action(&"ability_slot_3")
	assert_false(_slot(2).is_shaking(), "E over an empty slot does nothing")
	assert_signal_not_emitted(_dock, "ability_selected")

func test_ready_press_emits_ability_selected() -> void:
	_start_fight()
	await _finish_cooldown(_instance(0))
	watch_signals(_dock)
	_press_action(&"ability_slot_1")
	assert_signal_emitted_with_parameters(_dock, "ability_selected", [_instance(0)])
	assert_signal_emit_count(_dock, "ability_selected", 1)
	assert_false(_slot(0).is_shaking(), "an accepted press does not shake")

## The physical Q key, as the input map binds it, presses the first slot.
func test_the_q_key_presses_the_first_slot() -> void:
	_start_fight()
	await _finish_cooldown(_instance(0))
	watch_signals(_dock)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	get_viewport().push_input(key)
	assert_signal_emitted_with_parameters(_dock, "ability_selected", [_instance(0)])

## A click is a press: refused while recharging, accepted once ready. Other
## buttons do nothing.
func test_a_click_on_a_slot_presses_it() -> void:
	_start_fight()
	watch_signals(_dock)
	_slot(0).gui_input.emit(_left_press())
	assert_true(_slot(0).is_shaking(), "clicked while recharging: refused")
	assert_signal_not_emitted(_dock, "ability_selected")
	await _finish_cooldown(_instance(0))
	var right_press := InputEventMouseButton.new()
	right_press.button_index = MOUSE_BUTTON_RIGHT
	right_press.pressed = true
	_slot(0).gui_input.emit(right_press)
	assert_signal_not_emitted(_dock, "ability_selected", "a right click does nothing")
	_slot(0).gui_input.emit(_left_press())
	assert_signal_emitted_with_parameters(_dock, "ability_selected", [_instance(0)])

## Review Focus 4: Q, W, E, R on the map, after a fight, or with the dock hidden
## do nothing: no emit, no shake.
func test_keys_do_nothing_outside_a_fight() -> void:
	watch_signals(_dock)
	for action: StringName in SLOT_ACTIONS:
		_press_action(action)
	assert_signal_not_emitted(_dock, "ability_selected", "on the map")
	for index: int in 4:
		assert_false(_slot(index).is_shaking(), "slot %d does not shake on the map" % index)
	_start_fight()
	await _finish_cooldown(_instance(0))
	_dock.reset()
	for action: StringName in SLOT_ACTIONS:
		_press_action(action)
	assert_signal_not_emitted(_dock, "ability_selected", "after the fight")
	for index: int in 4:
		assert_false(_slot(index).is_shaking(), "slot %d does not shake after the fight" % index)
	_dock.bind(_player.ability_manager, _vitals)
	_dock.hide()
	_press_action(&"ability_slot_1")
	assert_signal_not_emitted(_dock, "ability_selected", "a hidden dock ignores its keys")
	assert_false(_slot(0).is_shaking())

#-----------------------------------------------------------------------------
# HOVER AND THE TOOLTIP
#-----------------------------------------------------------------------------

func test_hover_opens_the_tooltip() -> void:
	_slot(0).mouse_entered.emit()
	assert_true(_dock.get_technique_tooltip().visible, "the tooltip, on the map too")
	_slot(0).mouse_exited.emit()
	assert_false(_dock.get_technique_tooltip().visible)
	_slot(2).mouse_entered.emit()
	assert_false(_dock.get_technique_tooltip().visible, "an empty slot opens no tooltip")

func test_tooltip_content() -> void:
	_equip("empty_palm", 2)
	_dock.show_loadout()
	_slot(2).mouse_entered.emit()
	assert_eq((_tooltip_node("NameLabel") as Label).text, "Empty Palm")
	assert_eq((_tooltip_node("TimingText") as RichTextLabel).get_parsed_text(), "Instant · Cooldown 3 s")
	assert_eq((_tooltip_node("CostLabel") as Label).text, "8 Madra")
	assert_eq((_tooltip_node("CostIcon") as TextureRect).texture.resource_path, KIT_PATH % "mini_madra")
	var damage: Label = _tooltip_node("DamageLabel")
	assert_true(damage.visible, "Empty Palm deals damage")
	assert_eq(damage.text, AbilityRow.format_damage(EMPTY_PALM, CharacterManager.get_total_attributes_data()))
	assert_string_contains(damage.text, "Spirit damage")
	assert_eq((_tooltip_node("DescriptionLabel") as Label).text, EMPTY_PALM.description)
	_slot(2).mouse_exited.emit()
	_slot(0).mouse_entered.emit()
	var timing: RichTextLabel = _tooltip_node("TimingText")
	assert_eq(timing.get_parsed_text(), "Cast 0.5 s · Cooldown 2 s", "Basic Strike casts")
	assert_eq((_tooltip_node("CostLabel") as Label).text, "3 Stamina")
	assert_eq((_tooltip_node("CostIcon") as TextureRect).texture.resource_path, KIT_PATH % "mini_stamina")
	_slot(0).mouse_exited.emit()
	_slot(1).mouse_entered.emit()
	assert_eq(timing.get_parsed_text(), "Cast 1 s · Cooldown 15 s", "whole seconds without a point")
	assert_false(damage.visible, "a self-buff has no damage line")

#-----------------------------------------------------------------------------
# RESET
#-----------------------------------------------------------------------------

func test_reset_returns_to_preview() -> void:
	_start_fight()
	_add_enemy()
	var strike: CombatAbilityInstance = _instance(0)
	await _finish_cooldown(strike)
	_player.ability_manager.use_ability_instance(strike, _enemy)
	assert_true(_dock.get_cast_tray().visible, "precondition: mid-cast")
	_dock.reset()
	assert_false(_dock.is_active())
	assert_false(_dock.get_cast_tray().visible, "the cast tray hides")
	assert_eq(_slot(0).get_state(), TechniqueSlot.SlotState.PREVIEW)
	assert_eq(_slot(1).get_state(), TechniqueSlot.SlotState.PREVIEW)
	assert_eq(_slot(2).get_state(), TechniqueSlot.SlotState.EMPTY)
	assert_eq(_slot(3).get_state(), TechniqueSlot.SlotState.EMPTY)
	for index: int in 2:
		assert_null(_slot(index).get_ability_instance())
		assert_eq(_slot(index).get_sweep_step(), TechniqueSlot.SWEEP_STEPS, "the plain icon (slot %d)" % index)
	strike.cast_updated.emit(strike, 0.1)
	assert_false(_dock.get_cast_tray().visible, "the old fight no longer reaches the tray")
	_instance(1).cooldown_updated.emit(0.5)
	assert_eq(_slot(1).get_sweep_step(), TechniqueSlot.SWEEP_STEPS, "nor the slots")

#-----------------------------------------------------------------------------
# THE POINTER
#-----------------------------------------------------------------------------

func test_the_dock_keeps_presses_off_the_map() -> void:
	assert_eq(_dock.mouse_filter, Control.MOUSE_FILTER_STOP, "presses on the board do not reach the map")
	for index: int in 4:
		assert_eq(_slot(index).mouse_filter, Control.MOUSE_FILTER_STOP, "slot %d takes the pointer" % index)

func test_a_slot_s_parts_leave_the_pointer_to_the_slot() -> void:
	_equip("empty_palm", 2)
	_dock.show_loadout()
	await wait_process_frames(1)
	for node: Node in _slot(0).find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s leaves the pointer to the slot" % node.name)
