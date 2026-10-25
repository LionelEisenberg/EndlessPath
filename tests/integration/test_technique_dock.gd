extends GutTest

## Integration tests for the technique dock (TechniqueDock) at the bottom of
## the adventure view: its four slots (TechniqueSlot) previewing the equipped
## loadout on the map and bound to the player's ability instances in a fight
## (the cooldown sweep and its seconds, the ready flash, the steady brass frame
## while casting, the cost that turns tan while unaffordable), Q/W/E/R and
## clicks (a refused press shakes the slot and emits nothing; keys do nothing
## outside a fight), the cast tray over the dock and the lacquer tooltip. A
## technique's name that needs more room than its board gives it wraps there and
## grows the board (the developer's rule: no text is cut off): the cast tray
## upward from the dock, the tooltip with its text.
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
const SWEEP_SHADER_PATH: String = "res://assets/shaders/lacquer_cooldown_sweep.gdshader"
const LACQUER_THEME_PATH: String = "res://assets/themes/lacquer/lacquer_theme.tres"
const KIT_PATH: String = "res://assets/ui/lacquer/lacquer_%s_ai.png"
const FRAME_BRASS_PATH: String = "res://assets/styleboxes/lacquer/frame_brass.tres"
const FRAME_HOVER_PATH: String = "res://assets/styleboxes/lacquer/frame_hover.tres"
const BOARD9_PATH: String = "res://assets/styleboxes/lacquer/board9.tres"
const SLOT_ACTIONS: Array[StringName] = [&"ability_slot_1", &"ability_slot_2", &"ability_slot_3", &"ability_slot_4"]
## A technique's name that needs three lines in the cast tray's 150 px and in the
## tooltip's 268.
const LONG_TECHNIQUE: String = "Flowing River Strike of the Endless Misty Bamboo Hollow, Lit By The Cold Moon And The Hundred Silent Stars Above"
## Where the dock stands on screen, and its slots in it (spec: Layout).
const DOCK_HOME: Vector2 = Vector2(722.0, 920.0)
const SLOT_POSITIONS: Array[Vector2] = [Vector2(30.0, 18.0), Vector2(142.0, 18.0), Vector2(254.0, 18.0), Vector2(366.0, 18.0)]
## GUT's output window covers the screen on this canvas layer; a pointer test
## shows what it moves over above it.
const GUT_OUTPUT_LAYER: int = 128

var _dock: TechniqueDock = null
var _player: CombatantNode = null
var _enemy: CombatantNode = null
var _vitals: VitalsManager = null
var _original_save: SaveGameData = null
## The player's vitals before the test, in the order _set_vitals() takes them.
var _original_vitals: Array = []
## True once a test has moved the pointer, which every later test file would
## otherwise find where it was left (the zone map reads it to hover a hex).
var _pointer_moved: bool = false

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
	_pointer_moved = false
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
	if _pointer_moved:
		await _move_pointer_to_window_point(Vector2.ZERO)

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

func _font_colour(control: Control) -> Color:
	return control.get_theme_color(&"font_color")

## The step the sweep shader draws, 0 to 1.
func _sweep_progress(index: int) -> float:
	return ((_slot_node(index, "Icon") as CanvasItem).material as ShaderMaterial).get_shader_parameter("progress")

func _tooltip_node(unique_name: String) -> Node:
	return _dock.get_technique_tooltip().get_node("%" + unique_name)

func _tray_node(unique_name: String) -> Node:
	return _dock.get_cast_tray().get_node("%" + unique_name)

## The tooltip's rect on screen.
func _tooltip_rect() -> Rect2:
	return _dock.get_technique_tooltip().get_global_rect()

## The board hugs its content, rounded up to an even height, and its corner
## sits on the 2 px grid the dock and the cast tray sit on.
func _assert_hugs_on_the_grid(tooltip: TechniqueTooltip, what: String) -> void:
	var content_height: float = tooltip.get_combined_minimum_size().y
	assert_eq(tooltip.size.y, ceilf(content_height / 2.0) * 2.0, "%s: as tall as its content, rounded up to even" % what)
	assert_eq(fmod(tooltip.size.y, 2.0), 0.0, "%s: an even height" % what)
	assert_eq(fmod(tooltip.global_position.y, 2.0), 0.0, "%s: its top on the 2 px grid" % what)
	assert_eq(fmod(tooltip.global_position.x, 2.0), 0.0, "%s: its left on the 2 px grid" % what)

## Moves the pointer, through the window as the player would, to a point in
## the viewport (headless, the window is not 1920x1080).
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
		assert_true((_slot_node(index, "KeyCap") as Control).visible, "every slot keeps its key cap (slot %d)" % index)
		assert_eq(key_label.text, keys[index], "the key from the input map (slot %d)" % index)
		assert_eq(_font_colour(key_label), ThemeConstants.LACQUER_TAN, "a tan key: not usable on the map (slot %d)" % index)
		assert_null(slot.get_ability_instance(), "no instance on the map (slot %d)" % index)
		assert_false((_slot_node(index, "SecondsLabel") as Control).visible, "no seconds on the map (slot %d)" % index)
		var data: AbilityData = expected[index]
		if data == null:
			assert_eq(slot.get_state(), TechniqueSlot.SlotState.EMPTY, "slot %d is empty" % index)
			assert_false((_slot_node(index, "Icon") as Control).visible, "an empty slot shows no icon")
			assert_false((_slot_node(index, "CostLine") as Control).visible, "and no cost")
		else:
			assert_eq(slot.get_state(), TechniqueSlot.SlotState.PREVIEW, "slot %d previews %s" % [index, data.ability_name])
			assert_true((_slot_node(index, "Icon") as Control).visible)
			assert_eq((_slot_node(index, "Icon") as TextureRect).texture, data.icon)
			assert_eq(slot.get_sweep_step(), TechniqueSlot.SWEEP_STEPS, "the plain icon")
			assert_true((_slot_node(index, "CostLine") as Control).visible, "its cost under the slot")
			assert_eq(_font_colour(_slot_node(index, "CostLabel") as Control), ThemeConstants.LACQUER_CREAM)

## The key caps read the input map, so a remapped key shows on its slot. The
## map is put back before the assert, so a failure leaves no remap behind.
func test_key_caps_follow_the_input_map() -> void:
	var original: Array[InputEvent] = InputMap.action_get_events(&"ability_slot_1")
	var remapped := InputEventKey.new()
	remapped.physical_keycode = KEY_Z
	InputMap.action_erase_events(&"ability_slot_1")
	InputMap.action_add_event(&"ability_slot_1", remapped)
	_dock.show_loadout()
	var key_text: String = (_slot_node(0, "KeyLabel") as Label).text
	InputMap.action_erase_events(&"ability_slot_1")
	for event: InputEvent in original:
		InputMap.action_add_event(&"ability_slot_1", event)
	assert_eq(key_text, "Z", "the remapped key")
	_dock.show_loadout()
	assert_eq((_slot_node(0, "KeyLabel") as Label).text, "Q", "and Q again once the map is back")

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
	for index: int in [0, 1]:
		assert_eq(_font_colour(_slot_node(index, "KeyLabel") as Control), ThemeConstants.LACQUER_CREAM, "a cream key in a fight (slot %d)" % index)
		assert_eq(_font_colour(_slot_node(index, "CostLabel") as Control), ThemeConstants.LACQUER_CREAM, "a cream cost (slot %d)" % index)
	for index: int in [2, 3]:
		assert_eq(_slot(index).get_state(), TechniqueSlot.SlotState.EMPTY, "slot %d stays empty" % index)
		assert_null(_slot(index).get_ability_instance())
		assert_eq(_font_colour(_slot_node(index, "KeyLabel") as Control), ThemeConstants.LACQUER_TAN, "an empty slot's key stays tan")

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

func test_initial_cooldown_shows_the_sweep() -> void:
	_start_fight()
	var timer: Timer = _instance(0).cooldown_timer
	assert_false(timer.is_stopped(), "precondition: every technique starts a fight on a 1.5 s cooldown")
	assert_lt(_slot(0).get_sweep_step(), TechniqueSlot.SWEEP_STEPS, "the sweep veils the icon")
	assert_eq(_slot(0).get_sweep_step(), TechniqueSlot.sweep_step(timer.time_left, timer.wait_time), "read from the running timer")
	assert_almost_eq(_sweep_progress(0), _slot(0).get_sweep_step() / 24.0, 0.0001, "the shader draws that step")
	var seconds: Label = _slot_node(0, "SecondsLabel")
	assert_true(seconds.visible)
	assert_eq(seconds.text, "2", "1.5 s left reads 2")

## The sweep steps with cooldown_updated against the running timer's length
## (the initial 1.5 s, not the technique's base cooldown), and a new cooldown
## starts it over.
func test_the_sweep_follows_the_cooldown() -> void:
	_start_fight()
	var strike: CombatAbilityInstance = _instance(0)
	strike.cooldown_updated.emit(0.75)
	assert_eq(_slot(0).get_sweep_step(), 12, "0.75 of 1.5 s left: 12 of 24")
	assert_almost_eq(_sweep_progress(0), 0.5, 0.0001)
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

func test_cooldown_ready_flashes_the_slot() -> void:
	_start_fight()
	var flash: LacquerFrameOverlay = _slot_node(0, "ReadyFlash")
	assert_false(flash.is_flashing(), "no flash while it recharges")
	await _finish_cooldown(_instance(0))
	assert_eq(_slot(0).get_sweep_step(), TechniqueSlot.SWEEP_STEPS, "the plain icon again")
	assert_almost_eq(_sweep_progress(0), 1.0, 0.0001)
	assert_false((_slot_node(0, "SecondsLabel") as Control).visible, "no seconds once ready")
	assert_true(flash.is_flashing(), "a brass flash says it is ready")
	assert_true(flash.visible)
	assert_false((_slot_node(1, "ReadyFlash") as LacquerFrameOverlay).is_flashing(), "only that slot")
	var ended: bool = await wait_until(func() -> bool: return not flash.is_flashing(), 2.0)
	assert_true(ended, "a single flash")
	assert_false(flash.visible, "and it ends hidden")

func test_casting_shows_the_brass_frame_and_the_cast_tray() -> void:
	_start_fight()
	_add_enemy()
	var strike: CombatAbilityInstance = _instance(0)
	await _finish_cooldown(strike)
	var cast_frame: LacquerFrameOverlay = _slot_node(0, "CastFrame")
	var tray: CastTray = _dock.get_cast_tray()
	assert_false(cast_frame.visible, "no frame before the cast")
	assert_false(tray.visible, "no cast tray before the cast")
	assert_true(_player.ability_manager.use_ability_instance(strike, _enemy), "precondition: the cast starts")
	assert_true(cast_frame.visible, "a brass frame while it casts")
	assert_false(cast_frame.is_flashing(), "steady, not flashing")
	assert_false((_slot_node(1, "CastFrame") as Control).visible, "only on the casting slot")
	assert_true(tray.visible, "the cast tray shows outright")
	assert_eq((_tray_node("NameLabel") as Label).text, "Basic Strike")
	assert_eq((_tray_node("TimeText") as RichTextLabel).get_parsed_text(), "0.5 s", "its whole cast left")
	assert_eq((_tray_node("CastRod") as LacquerRod).get_step(), 0, "the rod starts empty")
	var landed: bool = await wait_for_signal(strike.cast_finished, 2.0)
	assert_true(landed, "precondition: Basic Strike's 0.5 s cast lands")
	assert_false(cast_frame.visible, "the frame goes when the cast lands")
	assert_false(tray.visible, "and so does the tray")

## The tray steps with cast_updated: the rod at 1 - time left / cast time, the
## time to a tenth with the Yatra decimal point.
func test_cast_tray_steps_with_the_cast() -> void:
	_start_fight()
	_add_enemy()
	var strike: CombatAbilityInstance = _instance(0)
	await _finish_cooldown(strike)
	_player.ability_manager.use_ability_instance(strike, _enemy)
	strike.cast_updated.emit(strike, 0.2)
	assert_eq((_tray_node("CastRod") as LacquerRod).get_step(), roundi(0.6 * 119.0), "0.2 of 0.5 s left: 60% of the rod's 119 steps")
	var time_text: RichTextLabel = _tray_node("TimeText")
	assert_eq(time_text.get_parsed_text(), "0.2 s")
	# The decimal point is set in Yatra One.
	assert_string_contains(time_text.text, LacquerText.DECIMAL_POINT_BBCODE)
	strike.cast_updated.emit(strike, 0.0)
	assert_eq((_tray_node("CastRod") as LacquerRod).get_step(), 119, "full as it lands")
	assert_eq(time_text.get_parsed_text(), "0.0 s")

## A cancelled cast (interrupted) hides the tray and the frame at once.
func test_a_cancelled_cast_hides_the_tray_and_frame() -> void:
	_start_fight()
	_add_enemy()
	var strike: CombatAbilityInstance = _instance(0)
	await _finish_cooldown(strike)
	_player.ability_manager.use_ability_instance(strike, _enemy)
	assert_true(_dock.get_cast_tray().visible, "precondition: casting")
	strike.cancel_cast()
	assert_false(_dock.get_cast_tray().visible)
	assert_false((_slot_node(0, "CastFrame") as Control).visible)
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
## by its 20 px a line, never ellipsizing: 44 for one line, an even height for
## any.
func test_a_long_technique_name_wraps_and_grows_the_cast_tray() -> void:
	_cast_long_named_technique()
	var tray: CastTray = _dock.get_cast_tray()
	var name_label: Label = _tray_node("NameLabel")
	assert_true(tray.visible, "precondition: casting")
	assert_gt(name_label.get_line_count(), 2, "precondition: the name needs three lines")
	assert_eq(name_label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)
	assert_eq(tray.size.y, 44.0 + 20.0 * (name_label.get_line_count() - 1), "every line after the first adds the name's 20 px")
	assert_eq(fmod(tray.size.y, 2.0), 0.0, "an even height")
	await wait_process_frames(2)
	assert_eq((tray.get_node("Tray") as Control).size, tray.size, "the face follows the tray")

## It grows upward: the bottom edge stays 8 px over the dock, and the rod and the
## time stay at the top beside the name's first line.
func test_the_cast_tray_grows_upward_from_the_dock() -> void:
	var tray: CastTray = _dock.get_cast_tray()
	var rod: Control = _tray_node("CastRod")
	var time_text: Control = _tray_node("TimeText")
	var bottom: float = tray.get_global_rect().end.y
	assert_eq(bottom, 912.0, "precondition: 8 px over the dock at y 920")
	_cast_long_named_technique()
	assert_gt(tray.size.y, 44.0, "precondition: grown")
	assert_eq(tray.get_global_rect().end.y, bottom, "the bottom edge does not move")
	assert_eq(tray.get_global_rect().position.y, bottom - tray.size.y, "the top rises")
	assert_eq(fmod(tray.position.y, 2.0), 0.0, "on the 2 px grid")
	assert_eq(rod.position, Vector2(170.0, 17.0), "the rod stays beside the first line")
	assert_eq(time_text.position, Vector2(300.0, 12.0), "and so does the time")

func test_the_cast_tray_takes_its_height_back_for_a_short_name() -> void:
	var instance: CombatAbilityInstance = _cast_long_named_technique()
	var tray: CastTray = _dock.get_cast_tray()
	assert_gt(tray.size.y, 44.0, "precondition: grown")
	instance.cast_finished.emit(instance)
	instance.ability_data.ability_name = "Strike"
	instance.cast_started.emit(instance, 1.0)
	assert_eq(tray.size.y, 44.0, "the kit's 44 for a short name")
	assert_eq(tray.position.y, -52.0, "in its place over the dock")

## The tooltip over a grown tray stands 8 px over its top, not over the 44 px
## tray's.
func test_the_tooltip_rises_over_a_grown_cast_tray() -> void:
	_cast_long_named_technique()
	var tray: CastTray = _dock.get_cast_tray()
	assert_gt(tray.size.y, 44.0, "precondition: grown")
	_slot(0).mouse_entered.emit()
	await wait_process_frames(2)
	assert_eq(_tooltip_rect().end.y, tray.get_global_rect().position.y - 8.0, "8 px over the tray's top")
	assert_lt(_tooltip_rect().end.y, 860.0, "higher than over the kit's tray")
	assert_eq(fmod(_tooltip_rect().position.y, 2.0), 0.0, "its top on the 2 px grid")

## A tray that grows under an open tooltip pushes it up.
func test_a_cast_tray_that_grows_pushes_an_open_tooltip_up() -> void:
	var long_strike := BASIC_STRIKE.duplicate() as AbilityData
	long_strike.ability_name = LONG_TECHNIQUE
	_add_player([long_strike] as Array[AbilityData])
	_dock.bind(_player.ability_manager, _vitals)
	var instance: CombatAbilityInstance = _instance(0)
	_slot(0).mouse_entered.emit()
	await wait_process_frames(2)
	assert_eq(_tooltip_rect().end.y, 912.0, "precondition: over the dock")
	instance.cast_started.emit(instance, 1.0)
	await wait_process_frames(2)
	assert_eq(_tooltip_rect().end.y, _dock.get_cast_tray().get_global_rect().position.y - 8.0, "over the grown tray")

## A tray that is already showing and grows under an open tooltip pushes it up as
## it resizes. No show() follows to announce the new top again, so the tray has to
## stand at its new top by the time it announces its new size: the tooltip is over
## it in the same frame, with nothing awaited.
func test_a_showing_cast_tray_that_grows_pushes_an_open_tooltip_up_at_once() -> void:
	var strike := BASIC_STRIKE.duplicate() as AbilityData
	strike.ability_name = "Strike"
	_add_player([strike] as Array[AbilityData])
	_dock.bind(_player.ability_manager, _vitals)
	var instance: CombatAbilityInstance = _instance(0)
	var tray: CastTray = _dock.get_cast_tray()
	instance.cast_started.emit(instance, 1.0)
	_slot(0).mouse_entered.emit()
	await wait_process_frames(2)
	assert_true(tray.visible, "precondition: the tray is showing")
	assert_eq(tray.size.y, 44.0, "precondition: the kit's tray")
	assert_eq(_tooltip_rect().end.y, 860.0, "precondition: 8 px over the kit's tray")

	instance.ability_data.ability_name = LONG_TECHNIQUE
	instance.cast_started.emit(instance, 1.0)

	assert_gt(tray.size.y, 44.0, "precondition: the tray grew")
	assert_eq(_tooltip_rect().end.y, tray.get_global_rect().position.y - 8.0, "8 px over the grown tray's top at once")

## The same when the tray takes its height back.
func test_a_showing_cast_tray_that_shrinks_lets_an_open_tooltip_down_at_once() -> void:
	var strike := BASIC_STRIKE.duplicate() as AbilityData
	strike.ability_name = LONG_TECHNIQUE
	_add_player([strike] as Array[AbilityData])
	_dock.bind(_player.ability_manager, _vitals)
	var instance: CombatAbilityInstance = _instance(0)
	var tray: CastTray = _dock.get_cast_tray()
	instance.cast_started.emit(instance, 1.0)
	_slot(0).mouse_entered.emit()
	await wait_process_frames(2)
	assert_gt(tray.size.y, 44.0, "precondition: the tray is grown")
	assert_eq(_tooltip_rect().end.y, tray.get_global_rect().position.y - 8.0, "precondition: over the grown tray")

	instance.ability_data.ability_name = "Strike"
	instance.cast_started.emit(instance, 1.0)

	assert_eq(tray.size.y, 44.0, "precondition: the tray is the kit's again")
	assert_eq(_tooltip_rect().end.y, 860.0, "8 px over the kit's tray at once")

## A name longer than the tooltip's 268 px wraps there and the board grows with
## it, still an even height on the grid and 304 wide.
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
	assert_eq(tooltip.size.x, 304.0, "and stayed 304 wide")
	_assert_hugs_on_the_grid(tooltip, "a long name")
	assert_eq(_tooltip_rect().end.y, 912.0, "its bottom stays over the dock")

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
	# MapGlyph's soft keyframes (the lock shake's rhythm at half its travel):
	# 0, -4, 4, -2, 2, 0, each held 0.088 s.
	var body: Control = _slot_node(0, "Body")
	simulate(_slot(0), 1, 0.1)
	assert_eq(body.position.x, -4.0, "0.1 s in")
	simulate(_slot(0), 1, 0.1)
	assert_eq(body.position.x, 4.0, "0.2 s in")
	simulate(_slot(0), 1, 0.1)
	assert_eq(body.position.x, -2.0, "0.3 s in")
	simulate(_slot(0), 1, 0.1)
	assert_eq(body.position.x, 2.0, "0.4 s in")
	simulate(_slot(0), 1, 0.045)
	assert_eq(body.position.x, 0.0, "home after 0.44 s")
	assert_false(_slot(0).is_shaking(), "and done")

## The refusal is a soft shake (review round 2: the lock shake's 8 px was too
## much for a button): at every moment of its 0.44 s, not only in the middle of
## each step the test above samples, the socket is in whole even px and never
## more than 4 px from home, and it does go the full 4 px each way.
func test_the_refusal_shake_stays_within_4_even_px() -> void:
	_start_fight()
	var body: Control = _slot_node(0, "Body")
	_slot(0).refuse()
	var offsets: Array[float] = [body.position.x]
	for _frame: int in 100:
		if not _slot(0).is_shaking():
			break
		simulate(_slot(0), 1, 0.01)
		offsets.append(body.position.x)
	assert_false(_slot(0).is_shaking(), "precondition: the shake ended while it was sampled")
	assert_gt(offsets.size(), 40, "precondition: sampled every 10 ms through the 0.44 s")
	for offset: float in offsets:
		assert_between(offset, -4.0, 4.0, "never more than 4 px from home")
		assert_eq(fmod(offset, 2.0), 0.0, "whole even px (%s)" % offset)
	assert_has(offsets, -4.0, "it goes the full 4 px left")
	assert_has(offsets, 4.0, "and the full 4 px right")
	assert_eq(offsets[offsets.size() - 1], 0.0, "and ends at home")

## The socket shakes; the slot itself (what the pointer hovers), its key cap and
## its cost line stay put, as the mock's button shakes alone.
func test_the_shake_moves_the_socket_not_the_slot() -> void:
	_start_fight()
	var key_cap: Control = _slot_node(0, "KeyCap")
	var cost_line: Control = _slot_node(0, "CostLine")
	var key_cap_home: Vector2 = key_cap.position
	var cost_line_home: Vector2 = cost_line.position
	_slot(0).refuse()
	simulate(_slot(0), 1, 0.1)
	assert_eq((_slot_node(0, "Body") as Control).position, Vector2(-4.0, 0.0), "precondition: mid-shake")
	assert_eq(_slot(0).position, SLOT_POSITIONS[0], "the slot stays")
	assert_eq(key_cap.position, key_cap_home, "the key cap stays")
	assert_eq(cost_line.position, cost_line_home, "the cost line stays")
	_slot(0).refuse()
	assert_eq((_slot_node(0, "Body") as Control).position.x, 0.0, "a new shake starts from home")
	simulate(_slot(0), 1, 0.1)
	assert_eq((_slot_node(0, "Body") as Control).position.x, -4.0, "and runs from its first keyframe")

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

func test_unaffordable_cost_turns_tan() -> void:
	_start_fight()
	var cost: Label = _slot_node(0, "CostLabel")
	_vitals.current_stamina = 0.0
	simulate(_slot(0), 1, 0.016)
	assert_eq(_font_colour(cost), ThemeConstants.LACQUER_CREAM, "while it recharges the cost is not checked")
	await _finish_cooldown(_instance(0))
	simulate(_slot(0), 1, 0.016)
	assert_eq(_font_colour(cost), ThemeConstants.LACQUER_TAN, "ready but unaffordable: tan")
	assert_eq(_font_colour(_slot_node(0, "KeyLabel") as Control), ThemeConstants.LACQUER_CREAM, "the key stays cream")
	_vitals.current_stamina = 3.0
	simulate(_slot(0), 1, 0.016)
	assert_eq(_font_colour(cost), ThemeConstants.LACQUER_CREAM, "affordable again: cream")

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

func test_hover_frames_the_slot_and_opens_the_tooltip() -> void:
	var hover_frame: LacquerFrameOverlay = _slot_node(0, "HoverFrame")
	assert_false(hover_frame.visible)
	_slot(0).mouse_entered.emit()
	assert_true(hover_frame.visible, "the hover frame")
	assert_true(_dock.get_technique_tooltip().visible, "and the tooltip, on the map too")
	_slot(0).mouse_exited.emit()
	assert_false(hover_frame.visible)
	assert_false(_dock.get_technique_tooltip().visible)
	_slot(2).mouse_entered.emit()
	assert_false((_slot_node(2, "HoverFrame") as Control).visible, "an empty slot has no hover frame")
	assert_false(_dock.get_technique_tooltip().visible, "and no tooltip")

func test_tooltip_sits_above_the_dock() -> void:
	_slot(1).mouse_entered.emit()
	await wait_process_frames(2)
	assert_eq(_tooltip_rect().end.y, 912.0, "its bottom 8 px above the dock")
	assert_eq(fmod(_tooltip_rect().position.y, 2.0), 0.0, "its top on the 2 px grid")
	assert_eq(_tooltip_rect().position.x, _slot(1).global_position.x - 8.0, "its left 8 px left of the slot's")
	assert_eq(_tooltip_rect().position.x, 856.0)
	_slot(1).mouse_exited.emit()
	_start_fight()
	_add_enemy()
	await _finish_cooldown(_instance(0))
	_player.ability_manager.use_ability_instance(_instance(0), _enemy)
	assert_true(_dock.get_cast_tray().visible, "precondition: the cast tray shows")
	_slot(0).mouse_entered.emit()
	await wait_process_frames(2)
	assert_eq(_tooltip_rect().end.y, 860.0, "above the cast tray while it shows")
	assert_eq(fmod(_tooltip_rect().position.y, 2.0), 0.0, "its top on the 2 px grid there too")
	assert_eq(_tooltip_rect().position.x, 744.0)

## A cast that starts or ends under an open tooltip moves it above or back
## below the tray.
func test_tooltip_moves_with_the_cast_tray() -> void:
	_start_fight()
	_add_enemy()
	var strike: CombatAbilityInstance = _instance(0)
	await _finish_cooldown(strike)
	_slot(0).mouse_entered.emit()
	await wait_process_frames(2)
	assert_eq(_tooltip_rect().end.y, 912.0, "precondition: above the dock")
	_player.ability_manager.use_ability_instance(strike, _enemy)
	await wait_process_frames(1)
	assert_eq(_tooltip_rect().end.y, 860.0, "the tray shows: the tooltip rises above it")
	await wait_for_signal(strike.cast_finished, 2.0)
	await wait_process_frames(1)
	assert_eq(_tooltip_rect().end.y, 912.0, "the tray goes: back above the dock")

func test_tooltip_content() -> void:
	_equip("empty_palm", 2)
	_dock.show_loadout()
	_slot(2).mouse_entered.emit()
	assert_eq((_tooltip_node("NameLabel") as Label).text, "Empty Palm")
	assert_eq((_tooltip_node("TimingText") as RichTextLabel).get_parsed_text(), "Instant · Cooldown 3 s")
	assert_eq((_tooltip_node("CostLabel") as Label).text, "8 Madra")
	assert_eq(_font_colour(_tooltip_node("CostLabel") as Control), ThemeConstants.LACQUER_CREAM, "the cost in cream")
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
	# Its decimal point is set in Yatra One.
	assert_string_contains(timing.text, LacquerText.DECIMAL_POINT_BBCODE)
	assert_eq((_tooltip_node("CostLabel") as Label).text, "3 Stamina")
	assert_eq((_tooltip_node("CostIcon") as TextureRect).texture.resource_path, KIT_PATH % "mini_stamina")
	_slot(0).mouse_exited.emit()
	_slot(1).mouse_entered.emit()
	assert_eq(timing.get_parsed_text(), "Cast 1 s · Cooldown 15 s", "whole seconds without a point")
	assert_false(damage.visible, "a self-buff has no damage line")

## The plain board, 304 wide and as tall as its content rounded up to an even
## height, its top on the 2 px grid: a longer description grows it, a shorter
## one takes it back, and a technique without a damage line or a cost is
## shorter still. It never takes the pointer.
func test_tooltip_is_304_wide_and_hugs_its_height() -> void:
	var tooltip: TechniqueTooltip = _dock.get_technique_tooltip()
	assert_eq(tooltip.get_theme_stylebox(&"panel"), load(BOARD9_PATH), "the plain board")
	assert_true(tooltip.top_level, "placed by screen position, above the boards")
	assert_eq(tooltip.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	# Every node of the scene (not the RichTextLabel's own hidden scrollbar).
	for node: Node in tooltip.find_children("*", "Control", true, true):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s lets the pointer through" % node.name)
	tooltip.show_for_ability(EMPTY_PALM, _slot(0), false)
	await wait_process_frames(2)
	assert_eq(tooltip.size.x, 304.0)
	assert_eq(fmod(tooltip.get_combined_minimum_size().y, 2.0), 1.0, "precondition: Empty Palm's rows add up to an odd height")
	_assert_hugs_on_the_grid(tooltip, "Empty Palm")
	var short_height: float = tooltip.size.y
	tooltip.show_for_ability(POWER_FONT, _slot(0), false)
	await wait_process_frames(2)
	assert_gt(tooltip.size.y, short_height, "Power Font's longer description wraps onto more lines")
	_assert_hugs_on_the_grid(tooltip, "Power Font")
	assert_eq(tooltip.size.x, 304.0, "and the board stays 304 wide")
	assert_eq(_tooltip_rect().end.y, 912.0, "its bottom stays put as it grows")
	tooltip.show_for_ability(ENFORCE, _slot(0), false)
	await wait_process_frames(2)
	assert_false((_tooltip_node("DamageLabel") as Control).visible, "precondition: no damage line")
	_assert_hugs_on_the_grid(tooltip, "Enforce")
	var free_technique := AbilityData.new()
	free_technique.ability_id = "breathe"
	free_technique.ability_name = "Breathe"
	free_technique.description = "Take a slow breath."
	tooltip.show_for_ability(free_technique, _slot(0), false)
	await wait_process_frames(2)
	assert_false((_tooltip_node("CostRow") as Control).visible, "precondition: no cost row")
	_assert_hugs_on_the_grid(tooltip, "a free technique")
	tooltip.show_for_ability(EMPTY_PALM, _slot(0), false)
	await wait_process_frames(2)
	assert_eq(tooltip.size.y, short_height, "a shorter one takes it back")
	tooltip.hide_tooltip()
	assert_false(tooltip.visible)

## The signal tests above emit mouse_entered themselves. Here the pointer
## really moves, as the player's would: onto a slot (the frame and its tooltip
## show), over to the next (they follow) and away (they go).
func test_a_pointer_over_a_slot_opens_its_tooltip() -> void:
	var layer := CanvasLayer.new()
	layer.layer = GUT_OUTPUT_LAYER + 1
	add_child_autofree(layer)
	_dock.reparent(layer)
	await wait_process_frames(2)
	await _move_pointer_to(_slot(1).get_global_rect().get_center())
	assert_true((_slot_node(1, "HoverFrame") as Control).visible, "the pointer is on W")
	assert_eq((_tooltip_node("NameLabel") as Label).text, "Enforce")
	await _move_pointer_to(_slot(0).get_global_rect().get_center())
	assert_false((_slot_node(1, "HoverFrame") as Control).visible)
	assert_true((_slot_node(0, "HoverFrame") as Control).visible, "on to Q")
	assert_eq((_tooltip_node("NameLabel") as Label).text, "Basic Strike")
	await _move_pointer_to(Vector2(960.0, 400.0))
	assert_false(_dock.get_technique_tooltip().visible, "and away")

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
		assert_false((_slot_node(index, "CastFrame") as Control).visible, "no brass frame (slot %d)" % index)
		assert_eq(_slot(index).get_sweep_step(), TechniqueSlot.SWEEP_STEPS, "the plain icon (slot %d)" % index)
		assert_false((_slot_node(index, "SecondsLabel") as Control).visible)
		assert_eq(_font_colour(_slot_node(index, "KeyLabel") as Control), ThemeConstants.LACQUER_TAN, "a tan key again")
	strike.cast_updated.emit(strike, 0.1)
	assert_false(_dock.get_cast_tray().visible, "the old fight no longer reaches the tray")
	_instance(1).cooldown_updated.emit(0.5)
	assert_eq(_slot(1).get_sweep_step(), TechniqueSlot.SWEEP_STEPS, "nor the slots")

#-----------------------------------------------------------------------------
# LAYOUT
#-----------------------------------------------------------------------------

func test_dock_root_is_the_board() -> void:
	assert_eq(_dock.position, DOCK_HOME)
	assert_eq(_dock.size, Vector2(476.0, 136.0))
	assert_eq(_dock.mouse_filter, Control.MOUSE_FILTER_STOP, "presses on the board do not reach the map")
	assert_eq(_dock.theme, load(LACQUER_THEME_PATH))
	var board: TextureRect = _dock.get_node("Board")
	assert_eq(board.position, Vector2.ZERO)
	assert_eq(board.texture.resource_path, KIT_PATH % "tdock")
	for index: int in 4:
		assert_eq(Rect2(_slot(index).position, _slot(index).size), Rect2(SLOT_POSITIONS[index], Vector2(80.0, 80.0)), "slot %d" % index)
		assert_eq(_slot(index).mouse_filter, Control.MOUSE_FILTER_STOP, "slot %d takes the pointer" % index)

func test_slot_layout_matches_the_kit() -> void:
	_equip("empty_palm", 2)
	_dock.show_loadout()
	await wait_process_frames(1)
	var socket: TextureRect = _slot_node(0, "Socket")
	assert_eq(socket.position, Vector2.ZERO)
	assert_eq(socket.texture.resource_path, KIT_PATH % "slot")
	var icon: TextureRect = _slot_node(0, "Icon")
	assert_eq(Rect2(icon.position, icon.size), Rect2(8.0, 8.0, 64.0, 64.0), "the icon at 64x64, 8 px in")
	var seconds: Label = _slot_node(0, "SecondsLabel")
	assert_eq(Rect2(seconds.position, seconds.size), Rect2(8.0, 26.0, 64.0, 28.0))
	assert_eq(seconds.theme_type_variation, &"LabelLacquerCooldown")
	assert_eq(seconds.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(seconds.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)
	var key_cap: TextureRect = _slot_node(0, "KeyCap")
	assert_eq(key_cap.position, Vector2(-6.0, -6.0))
	assert_eq(key_cap.texture.resource_path, KIT_PATH % "keycap")
	assert_eq((_slot_node(0, "KeyLabel") as Label).theme_type_variation, &"LabelLacquerHotkey")
	assert_eq((_slot_node(0, "CostLabel") as Label).theme_type_variation, &"LabelLacquerDetail")
	# The icon and cost are centred under the 80 px slot, a centre on a half pixel
	# rounding right as the mock's CSS does ("3" is 29 px: 25.5 -> 26): the
	# line's box is 81 wide, which turns the container's floor into that round.
	for index: int in 3:
		var cost_line: BoxContainer = _slot_node(index, "CostLine")
		assert_eq(cost_line.position, Vector2(0.0, 90.0), "the cost line under slot %d" % index)
		assert_eq(cost_line.size.x, 81.0)
		assert_eq(cost_line.alignment, BoxContainer.ALIGNMENT_CENTER)
		var content_width: float = cost_line.get_combined_minimum_size().x
		var cost_icon: Control = _slot_node(index, "CostIcon")
		assert_eq(cost_icon.position.x, ceilf((80.0 - content_width) / 2.0), "slot %d's cost sits centred on the slot" % index)
		assert_eq(cost_icon.position.y, 1.0, "the mini icon 1 px into the 18 px line")
	assert_eq((_slot_node(0, "CastFrame") as Panel).get_theme_stylebox(&"panel"), load(FRAME_BRASS_PATH))
	assert_eq((_slot_node(0, "ReadyFlash") as Panel).get_theme_stylebox(&"panel"), load(FRAME_BRASS_PATH))
	assert_eq((_slot_node(0, "HoverFrame") as Panel).get_theme_stylebox(&"panel"), load(FRAME_HOVER_PATH))
	for node: Node in _slot(0).find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s leaves the pointer to the slot" % node.name)

func test_cast_tray_layout_matches_the_kit() -> void:
	var tray: CastTray = _dock.get_cast_tray()
	assert_false(tray.visible, "hidden until the player casts")
	assert_eq(Rect2(tray.position, tray.size), Rect2(0.0, -52.0, 476.0, 44.0), "over the dock: screen (722, 868)")
	assert_eq(tray.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var face := tray.get_node("Tray") as NinePatchRect
	assert_eq(face.texture.resource_path, KIT_PATH % "cast_tray")
	assert_eq([face.patch_margin_left, face.patch_margin_top, face.patch_margin_right, face.patch_margin_bottom], [4, 4, 2, 2], "a 9-slice on the tray's art, so it can grow")
	var name_label: Label = _tray_node("NameLabel")
	assert_eq(name_label.position, Vector2(16.0, 12.0))
	assert_eq(name_label.size.x, 150.0, "the name has 150 px and wraps there")
	assert_eq(name_label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(name_label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "no ellipsis")
	assert_eq(name_label.theme_type_variation, &"LabelLacquerName")
	var rod: LacquerRod = _tray_node("CastRod")
	assert_eq(rod.position, Vector2(170.0, 17.0))
	assert_eq(rod.steps, 119)
	assert_eq(rod.empty_texture.resource_path, KIT_PATH % "rod_cast_empty")
	assert_eq(rod.full_texture.resource_path, KIT_PATH % "rod_cast_full")
	assert_eq(rod.end_texture.resource_path, KIT_PATH % "rod_cast_end")
	var time_text: RichTextLabel = _tray_node("TimeText")
	assert_eq(time_text.position, Vector2(300.0, 12.0))
	assert_eq(time_text.size.x, 160.0)
	assert_eq(time_text.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT)
	assert_eq(time_text.theme_type_variation, &"RichTextLacquer")

## One shader on each icon: progress is the only uniform a script sets, the
## icon's size keeps its default of 64 (a consumable socket sets 32 on its own
## material), each slot has its own material, and it draws in whole steps (no
## TIME, no blending).
func test_icon_draws_the_sweep_shader() -> void:
	var material: ShaderMaterial = (_slot_node(0, "Icon") as CanvasItem).material as ShaderMaterial
	assert_not_null(material, "a ShaderMaterial on the icon")
	assert_eq(material.shader.resource_path, SWEEP_SHADER_PATH)
	var uniforms: Dictionary = {}
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		uniforms[uniform["name"]] = uniform["type"]
	assert_eq(uniforms, {"progress": TYPE_FLOAT, "icon_size": TYPE_FLOAT}, "the step, and the icon's size")
	assert_string_contains(material.shader.code, "uniform float icon_size = 64.0;", "a 64 px icon by default")
	assert_true(material.get_shader_parameter(&"icon_size") in [null, 64.0], "a technique slot keeps the default")
	assert_true(material.resource_local_to_scene)
	assert_ne(material, (_slot_node(1, "Icon") as CanvasItem).material, "each slot sweeps its own icon")
	assert_string_contains(material.shader.code, "shader_type canvas_item;")
	# The code without its comments, which name what the sweep never uses.
	var code: String = ""
	for line: String in material.shader.code.split("\n"):
		code += line.get_slice("//", 0) + "\n"
	for banned: String in ["TIME", "smoothstep", "mix("]:
		assert_false(code.contains(banned), "the sweep never uses %s" % banned)
