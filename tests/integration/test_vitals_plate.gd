extends GutTest

## Integration tests for the adventure's vitals cabinet (VitalsPlate) and its
## lacquer buff tooltip (BuffTooltip): the figures and orb fills it reads from
## the player's VitalsManager and how it follows that manager's signals, the
## Stamina rod, the three buff sockets (they fill from the left, show a count
## seal for stacks and clear when the buffs go), and the tooltip a hovered
## socket opens.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const PLATE_SCENE_PATH: String = "res://scenes/adventure/vitals_plate/vitals_plate.tscn"
const TOOLTIP_SCENE_PATH: String = "res://scenes/ui/combat/buff_tooltip/buff_tooltip.tscn"
const COMBATANT_SCENE_PATH: String = "res://scenes/combat/combatant/combatant_node.tscn"
const COMBATANT_DATA: CombatantData = preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
## Four ability icons, so a socket's icon says which buff it holds.
const ENFORCE_ICON: Texture2D = preload("res://assets/sprites/abilities/enforce.png")
const BASIC_STRIKE_ICON: Texture2D = preload("res://assets/sprites/abilities/basic_strike.png")
const EMPTY_PALM_ICON: Texture2D = preload("res://assets/sprites/abilities/empty_palm.png")
const POWER_FONT_ICON: Texture2D = preload("res://assets/sprites/abilities/power_font.png")
## GUT's output window covers the screen on this canvas layer; a pointer test
## shows what it moves over above it.
const GUT_OUTPUT_LAYER: int = 128

var _plate: VitalsPlate = null
var _vitals: VitalsManager = null
var _combatant: CombatantNode = null
## The player's vitals before the test, in the order _set_vitals() takes them.
var _original_vitals: Array = []
## True once a test has moved the pointer, which every later test file would
## otherwise find where it was left (the zone map reads it to hover a hex).
var _pointer_moved: bool = false

#-----------------------------------------------------------------------------
# SETUP
#-----------------------------------------------------------------------------

func before_each() -> void:
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_vitals = PlayerManager.vitals_manager
	_combatant = null
	_pointer_moved = false
	_original_vitals = [
		_vitals.current_health, _vitals.max_health,
		_vitals.current_madra, _vitals.max_madra,
		_vitals.current_stamina, _vitals.max_stamina,
	]
	_set_vitals(142.0, 160.0, 80.0, 120.0, 80.0, 80.0)
	_plate = _add_plate()
	_plate.setup_vitals(_vitals)

func after_each() -> void:
	# Free whatever listens to the player's vitals first, so restoring them
	# below does not reach a plate that is still connected.
	if is_instance_valid(_plate):
		_plate.free()
	if is_instance_valid(_combatant):
		_combatant.free()
	_set_vitals.callv(_original_vitals)
	while ActionManager.get_current_action() != null:
		ActionManager.stop_action()
	if _pointer_moved:
		await _move_pointer_to_window_point(Vector2.ZERO)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _add_plate() -> VitalsPlate:
	var plate: VitalsPlate = load(PLATE_SCENE_PATH).instantiate()
	add_child_autofree(plate)
	return plate

## Sets the player's vitals: the three current values and their maxima.
func _set_vitals(health: float, max_health: float, madra: float, max_madra: float, stamina: float, max_stamina: float) -> void:
	_vitals.max_health = max_health
	_vitals.max_madra = max_madra
	_vitals.max_stamina = max_stamina
	_vitals.current_health = health
	_vitals.current_madra = madra
	_vitals.current_stamina = stamina

## A player combatant (a real CombatantNode, so the buff manager is the real
## one with its timer and ticks) and its buff manager, bound to the plate.
func _bind_a_combatant() -> CombatBuffManager:
	_combatant = load(COMBATANT_SCENE_PATH).instantiate()
	add_child_autofree(_combatant)
	_combatant.setup(COMBATANT_DATA, null, false)
	_plate.bind_buffs(_combatant.buff_manager)
	return _combatant.buff_manager

## A buff of the given id. The default type, OUTGOING_DAMAGE_MODIFIER, stacks
## when applied again.
func _make_buff(buff_id: String, icon: Texture2D = ENFORCE_ICON, duration: float = 20.0) -> BuffEffectData:
	var buff := BuffEffectData.new()
	buff.buff_id = buff_id
	buff.buff_icon = icon
	buff.duration = duration
	buff.buff_type = BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER
	buff.damage_multiplier = 1.5
	return buff

func _node(unique_name: String) -> Node:
	return _plate.get_node("%" + unique_name)

func _text(unique_name: String) -> String:
	return (_node(unique_name) as Label).text.strip_edges()

## The fill an orb's shader draws, 0 to 1.
func _fill(unique_name: String) -> float:
	return ((_node(unique_name) as CanvasItem).material as ShaderMaterial).get_shader_parameter("progress")

## The buff sockets by index, 0 to 2 (the scene names them 1 to 3).
func _socket(index: int) -> Control:
	return _node("BuffSocket%d" % (index + 1)) as Control

func _icon(index: int) -> TextureRect:
	return _node("BuffIcon%d" % (index + 1)) as TextureRect

func _seal(index: int) -> Control:
	return _node("BuffSeal%d" % (index + 1)) as Control

## The count on a socket's seal (a LacquerCountSeal, which owns its label).
func _count(index: int) -> Label:
	return _seal(index).get_node("%CountLabel") as Label

## Which of the three sockets show.
func _shown_sockets() -> Array:
	var shown: Array = []
	for index: int in VitalsPlate.MAX_BUFF_SOCKETS:
		shown.append(_socket(index).visible)
	return shown

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

func _tooltip() -> BuffTooltip:
	return _node("BuffTooltip") as BuffTooltip

func _tooltip_text(label_name: String) -> String:
	return (_tooltip().get_node("%" + label_name) as Label).text

#-----------------------------------------------------------------------------
# VITALS
#-----------------------------------------------------------------------------

func test_shows_the_runs_vitals() -> void:
	assert_eq(_text("HealthValueLabel"), "142")
	assert_eq(_text("HealthMaxLabel"), "/ 160")
	assert_eq(_text("MadraValueLabel"), "80")
	assert_eq(_text("MadraMaxLabel"), "/ 120")
	assert_eq(_text("StaminaValueLabel"), "80")
	assert_eq(_text("StaminaMaxLabel"), "/ 80")

func test_orbs_fill_to_the_fraction() -> void:
	_vitals.current_health = 80.0
	assert_almost_eq(_fill("HealthOrb"), 0.5, 0.0001, "80 of 160 Health")
	_vitals.current_madra = 30.0
	assert_almost_eq(_fill("MadraOrb"), 0.25, 0.0001, "30 of 120 Madra")

func test_health_rounds_up_and_the_rest_round_down() -> void:
	_set_vitals(141.2, 160.7, 79.9, 120.9, 39.9, 80.9)
	assert_eq(_text("HealthValueLabel"), "142", "a sliver of Health still reads as one")
	assert_eq(_text("HealthMaxLabel"), "/ 160")
	assert_eq(_text("MadraValueLabel"), "79")
	assert_eq(_text("MadraMaxLabel"), "/ 120")
	assert_eq(_text("StaminaValueLabel"), "39")
	assert_eq(_text("StaminaMaxLabel"), "/ 80")

func test_follows_the_vitals_signals() -> void:
	_vitals.apply_vitals_change(-20.0)
	assert_eq(_text("HealthValueLabel"), "122")
	_vitals.apply_vitals_change(0.0, -10.0, -5.0)
	assert_eq(_text("StaminaValueLabel"), "70")
	assert_eq(_text("MadraValueLabel"), "75")

func test_stamina_rod_steps() -> void:
	_vitals.current_stamina = 40.0
	assert_eq((_node("StaminaRod") as LacquerRod).get_step(), 60, "40 of 80 on the 119 step rod: round(59.5)")
	_vitals.current_stamina = 80.0
	assert_eq((_node("StaminaRod") as LacquerRod).get_step(), 119, "full")
	_vitals.current_stamina = 0.0
	assert_eq((_node("StaminaRod") as LacquerRod).get_step(), 0, "empty")

## setup_vitals follows the manager it is handed and lets the previous one go,
## so a new run (or a second call with the same manager) never doubles up.
func test_setup_vitals_follows_the_latest_manager() -> void:
	var other: VitalsManager = autofree(VitalsManager.new())
	other.max_health = 50.0
	other.max_madra = 40.0
	other.max_stamina = 30.0
	other.initialize_current_values()
	_plate.setup_vitals(other)
	assert_eq(_text("HealthValueLabel"), "50", "read at once")
	assert_eq(_text("HealthMaxLabel"), "/ 50")
	assert_eq(_text("StaminaMaxLabel"), "/ 30")
	_vitals.current_health = 10.0
	assert_eq(_text("HealthValueLabel"), "50", "the previous manager no longer moves it")
	other.current_health = 20.0
	assert_eq(_text("HealthValueLabel"), "20")
	_plate.setup_vitals(other)
	other.current_health = 25.0
	assert_eq(_text("HealthValueLabel"), "25", "the same manager again changes nothing")

#-----------------------------------------------------------------------------
# BUFF SOCKETS
#-----------------------------------------------------------------------------

func test_buffs_fill_from_the_left_and_clear() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	manager.apply_buff(_make_buff("enforce", ENFORCE_ICON))
	assert_eq(_shown_sockets(), [true, false, false], "the first buff takes the first socket")
	assert_eq(_icon(0).texture, ENFORCE_ICON)
	manager.apply_buff(_make_buff("brace", BASIC_STRIKE_ICON))
	assert_eq(_shown_sockets(), [true, true, false], "the second takes the next one")
	assert_eq(_icon(1).texture, BASIC_STRIKE_ICON)
	manager.get_active_buff("enforce").time_remaining = 0.0
	await wait_process_frames(2)
	assert_eq(manager.active_buffs.size(), 1, "precondition: the first buff ended")
	assert_eq(_shown_sockets(), [true, false, false], "the sockets close up on the left")
	assert_eq(_icon(0).texture, BASIC_STRIKE_ICON, "the second buff slid into the first socket")
	manager.clear_all_buffs()
	assert_eq(_shown_sockets(), [false, false, false], "clearing the buffs clears the sockets")

## A buff that was already on when the plate was bound shows at once.
func test_buffs_already_active_show_when_bound() -> void:
	_combatant = load(COMBATANT_SCENE_PATH).instantiate()
	add_child_autofree(_combatant)
	_combatant.setup(COMBATANT_DATA, null, false)
	_combatant.buff_manager.apply_buff(_make_buff("enforce", ENFORCE_ICON))
	_combatant.buff_manager.apply_buff(_make_buff("brace", BASIC_STRIKE_ICON))
	_plate.bind_buffs(_combatant.buff_manager)
	assert_eq(_shown_sockets(), [true, true, false], "both are shown")
	assert_eq(_icon(1).texture, BASIC_STRIKE_ICON)

func test_stacks_show_a_count_seal() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	var buff: BuffEffectData = _make_buff("enforce")
	manager.apply_buff(buff)
	assert_false(_seal(0).visible, "one stack: no seal")
	manager.apply_buff(buff)
	assert_true(_seal(0).visible, "two stacks: the seal")
	assert_eq(_count(0).text, "2")
	manager.apply_buff(buff)
	assert_eq(_count(0).text, "3", "it follows the count")
	assert_false(_seal(1).visible, "only its own socket's seal")

func test_more_than_three_buffs_show_three() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	manager.apply_buff(_make_buff("one", ENFORCE_ICON))
	manager.apply_buff(_make_buff("two", BASIC_STRIKE_ICON))
	manager.apply_buff(_make_buff("three", EMPTY_PALM_ICON))
	manager.apply_buff(_make_buff("four", POWER_FONT_ICON))
	assert_eq(manager.active_buffs.size(), 4, "precondition: four buffs are on")
	assert_eq(_shown_sockets(), [true, true, true], "three sockets, no more")
	assert_eq([_icon(0).texture, _icon(1).texture, _icon(2).texture], [ENFORCE_ICON, BASIC_STRIKE_ICON, EMPTY_PALM_ICON] as Array, "the first three")
	manager.get_active_buff("one").time_remaining = 0.0
	await wait_process_frames(2)
	assert_eq([_icon(0).texture, _icon(1).texture, _icon(2).texture], [BASIC_STRIKE_ICON, EMPTY_PALM_ICON, POWER_FONT_ICON] as Array, "the fourth comes into view when one ends")

func test_unbind_hides_every_socket() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	manager.apply_buff(_make_buff("enforce", ENFORCE_ICON))
	manager.apply_buff(_make_buff("brace", BASIC_STRIKE_ICON))
	_socket(0).mouse_entered.emit()
	assert_true(_tooltip().visible, "precondition: a tooltip is open")
	_plate.unbind_buffs()
	assert_eq(_shown_sockets(), [false, false, false])
	assert_false(_tooltip().visible, "the tooltip goes with them")
	manager.apply_buff(_make_buff("power_font", POWER_FONT_ICON))
	assert_eq(_shown_sockets(), [false, false, false], "an unbound plate ignores that manager")
	_plate.unbind_buffs()
	assert_eq(_shown_sockets(), [false, false, false], "unbinding again changes nothing")

func test_binding_another_manager_replaces_the_first() -> void:
	var first: CombatBuffManager = _bind_a_combatant()
	first.apply_buff(_make_buff("enforce", ENFORCE_ICON))
	var second: CombatBuffManager = autofree(CombatBuffManager.new())
	add_child(second)
	_plate.bind_buffs(second)
	assert_eq(_shown_sockets(), [false, false, false], "the first manager's buffs are gone")
	first.apply_buff(_make_buff("brace", BASIC_STRIKE_ICON))
	assert_eq(_shown_sockets(), [false, false, false], "and it no longer reaches the plate")
	second.apply_buff(_make_buff("power_font", POWER_FONT_ICON))
	assert_eq(_shown_sockets(), [true, false, false])
	assert_eq(_icon(0).texture, POWER_FONT_ICON)

## A fight that frees its combatants takes the buffs with it.
func test_a_freed_buff_manager_clears_the_sockets() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	manager.apply_buff(_make_buff("enforce"))
	assert_eq(_shown_sockets(), [true, false, false], "precondition")
	_combatant.free()
	assert_eq(_shown_sockets(), [false, false, false])

#-----------------------------------------------------------------------------
# BUFF TOOLTIP
#-----------------------------------------------------------------------------

func test_hovering_a_buff_shows_its_tooltip() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	manager.apply_buff(_make_buff("enforce"))
	assert_false(_tooltip().visible, "nothing shows until the pointer arrives")
	_socket(0).mouse_entered.emit()
	assert_true(_tooltip().visible)
	assert_eq(_tooltip_text("NameLabel"), "Enforce")
	assert_eq(_tooltip_text("TimeLabel"), "20 s left")
	assert_eq(_tooltip_text("DescriptionLabel"), "Outgoing damage x1.5")
	_socket(0).mouse_exited.emit()
	assert_false(_tooltip().visible, "and goes when the pointer leaves")

## The signal tests above emit mouse_entered themselves. Here the pointer
## really moves, as the player's would: onto a socket (its buff's tooltip
## opens), over to the next one (the tooltip follows) and away (it closes).
func test_a_pointer_over_a_socket_opens_its_tooltip() -> void:
	var layer := CanvasLayer.new()
	layer.layer = GUT_OUTPUT_LAYER + 1
	add_child_autofree(layer)
	_plate.reparent(layer)
	var manager: CombatBuffManager = _bind_a_combatant()
	manager.apply_buff(_make_buff("enforce"))
	manager.apply_buff(_make_buff("brace", BASIC_STRIKE_ICON))
	await wait_process_frames(2)
	await _move_pointer_to(_socket(1).get_global_rect().get_center())
	assert_true(_tooltip().visible, "the pointer is on the second socket")
	assert_eq(_tooltip_text("NameLabel"), "Brace")
	await _move_pointer_to(_socket(0).get_global_rect().get_center())
	assert_eq(_tooltip_text("NameLabel"), "Enforce", "moving to the first socket swaps the tooltip")
	await _move_pointer_to(Vector2(1000.0, 800.0))
	assert_false(_tooltip().visible, "and it closes when the pointer is away")

## The time left counts down while the tooltip is open, in whole seconds
## rounded up (a buff with 0.9 s left has "1 s left").
func test_tooltip_counts_down_in_whole_seconds() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	manager.apply_buff(_make_buff("enforce"))
	_socket(0).mouse_entered.emit()
	manager.get_active_buff("enforce").time_remaining = 4.9
	await wait_process_frames(2)
	assert_eq(_tooltip_text("TimeLabel"), "5 s left")
	manager.get_active_buff("enforce").time_remaining = 0.9
	await wait_process_frames(2)
	assert_eq(_tooltip_text("TimeLabel"), "1 s left")

func test_tooltip_hides_when_its_buff_ends() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	manager.apply_buff(_make_buff("enforce"))
	_socket(0).mouse_entered.emit()
	assert_true(_tooltip().visible, "precondition")
	manager.get_active_buff("enforce").time_remaining = 0.0
	await wait_process_frames(2)
	assert_eq(manager.active_buffs.size(), 0, "precondition: the buff ran out")
	assert_false(_tooltip().visible)

## The board is as tall as its text: a long effect line grows it and a short
## one takes it back.
func test_tooltip_grows_with_a_long_effect_line() -> void:
	var tooltip: BuffTooltip = load(TOOLTIP_SCENE_PATH).instantiate()
	add_child_autofree(tooltip)
	var short_buff := BuffEffectData.new()
	short_buff.buff_id = "brace"
	short_buff.duration = 10.0
	short_buff.buff_type = BuffEffectData.BuffType.DAMAGE_OVER_TIME
	short_buff.dot_damage_per_tick = 2.0
	var long_buff := BuffEffectData.new()
	long_buff.buff_id = "great_surge"
	long_buff.duration = 10.0
	long_buff.buff_type = BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE
	long_buff.attribute_modifiers = {
		CharacterAttributesData.AttributeType.STRENGTH: 1.5,
		CharacterAttributesData.AttributeType.BODY: 1.5,
		CharacterAttributesData.AttributeType.AGILITY: 1.5,
		CharacterAttributesData.AttributeType.SPIRIT: 1.5,
		CharacterAttributesData.AttributeType.FOUNDATION: 1.5,
		CharacterAttributesData.AttributeType.CONTROL: 1.5,
	}
	tooltip.show_for_buff(ActiveBuff.new(short_buff), Vector2(100.0, 50.0))
	await wait_process_frames(2)
	var short_height: float = tooltip.size.y
	tooltip.show_for_buff(ActiveBuff.new(long_buff), Vector2(100.0, 50.0))
	await wait_process_frames(2)
	assert_gt(tooltip.size.y, short_height, "a long effect line wraps and the board grows")
	tooltip.show_for_buff(ActiveBuff.new(short_buff), Vector2(100.0, 50.0))
	await wait_process_frames(2)
	assert_eq(tooltip.size.y, short_height, "and a short one takes it back")

## The tooltip lets the pointer through to the sockets and the map.
func test_tooltip_never_takes_the_pointer() -> void:
	var tooltip: BuffTooltip = load(TOOLTIP_SCENE_PATH).instantiate()
	add_child_autofree(tooltip)
	assert_false(tooltip.visible, "hidden until a buff is shown")
	assert_eq(tooltip.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for node: Node in tooltip.find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s lets the pointer through" % node.name)

#-----------------------------------------------------------------------------
# ROOT
#-----------------------------------------------------------------------------

func test_root_stops_clicks() -> void:
	assert_eq(_plate.mouse_filter, Control.MOUSE_FILTER_STOP)
