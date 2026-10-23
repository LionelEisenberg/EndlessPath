extends GutTest

## Integration tests for the adventure's vitals cabinet (VitalsPlate) and its
## lacquer buff tooltip (BuffTooltip): the figures and orb fills it reads from
## the player's VitalsManager and how it follows that manager's signals, the
## Stamina rod and its shake, the three buff sockets (they fill from the left,
## flash when a buff lands, show a count seal for stacks and clear when the
## buffs go), and the tooltip a hovered socket opens.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const PLATE_SCENE_PATH: String = "res://scenes/adventure/vitals_plate/vitals_plate.tscn"
const TOOLTIP_SCENE_PATH: String = "res://scenes/ui/combat/buff_tooltip/buff_tooltip.tscn"
const COMBATANT_SCENE_PATH: String = "res://scenes/combat/combatant/combatant_node.tscn"
const COMBATANT_DATA: CombatantData = preload("res://resources/combat/combatant_data/amorphous_spirit.tres")
const LACQUER_THEME_PATH: String = "res://assets/themes/lacquer/lacquer_theme.tres"
const MADRA_ORB_SHADER_PATH: String = "res://assets/shaders/lacquer_madra_orb.gdshader"
const HEALTH_ORB_TEXTURE_PATH: String = "res://assets/ui/lacquer/lacquer_orb_health_ai.png"
const MADRA_STRIP_PATH: String = "res://assets/ui/lacquer/lacquer_orb_madra_strip_ai.png"
## Four ability icons, so a socket's icon says which buff it holds.
const ENFORCE_ICON: Texture2D = preload("res://assets/sprites/abilities/enforce.png")
const BASIC_STRIKE_ICON: Texture2D = preload("res://assets/sprites/abilities/basic_strike.png")
const EMPTY_PALM_ICON: Texture2D = preload("res://assets/sprites/abilities/empty_palm.png")
const POWER_FONT_ICON: Texture2D = preload("res://assets/sprites/abilities/power_font.png")
## Where the cabinet stands on screen, and the tooltip's gap to its right edge.
const PLATE_HOME: Vector2 = Vector2(24.0, 24.0)
const TOOLTIP_GAP: float = 8.0
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

func _count(index: int) -> Label:
	return _node("BuffCount%d" % (index + 1)) as Label

func _flash(index: int) -> LacquerFrameOverlay:
	return _node("BuffFlash%d" % (index + 1)) as LacquerFrameOverlay

## Which of the three sockets show.
func _shown_sockets() -> Array:
	var shown: Array = []
	for index: int in VitalsPlate.MAX_BUFF_SOCKETS:
		shown.append(_socket(index).visible)
	return shown

## A tween's first step carries the whole frame it was created in, and a test
## frame that loaded scenes and swapped the save can be 100 ms long: that would
## carry a shake past its first keyframe. So a shake starts in a fresh frame.
func _start_in_a_fresh_frame() -> void:
	await wait_process_frames(2)

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

func test_fills_stop_at_the_orb() -> void:
	_vitals.current_health = 200.0
	_vitals.current_madra = 0.0
	assert_almost_eq(_fill("HealthOrb"), 1.0, 0.0001, "above the max the orb is full")
	assert_almost_eq(_fill("MadraOrb"), 0.0, 0.0001, "no Madra, no liquid")
	_vitals.max_health = 0.0
	_vitals.current_health = 10.0
	assert_almost_eq(_fill("HealthOrb"), 0.0, 0.0001, "no max, no fill (and no division by zero)")

func test_health_rounds_up_and_the_rest_round_down() -> void:
	_set_vitals(141.2, 160.7, 79.9, 120.9, 39.9, 80.9)
	assert_eq(_text("HealthValueLabel"), "142", "a sliver of Health still reads as one")
	assert_eq(_text("HealthMaxLabel"), "/ 160")
	assert_eq(_text("MadraValueLabel"), "79")
	assert_eq(_text("MadraMaxLabel"), "/ 120")
	assert_eq(_text("StaminaValueLabel"), "39")
	assert_eq(_text("StaminaMaxLabel"), "/ 80")

func test_orbs_draw_the_liquid_shader_on_their_sockets() -> void:
	var health_orb: TextureRect = _node("HealthOrb")
	assert_eq(health_orb.texture.resource_path, HEALTH_ORB_TEXTURE_PATH, "the crimson socket")
	assert_eq(((health_orb.material as ShaderMaterial).shader as Shader).resource_path, MADRA_ORB_SHADER_PATH)
	var madra_orb: TextureRect = _node("MadraOrb")
	var socket: AtlasTexture = madra_orb.texture as AtlasTexture
	assert_not_null(socket, "the empty frame of the strip")
	assert_eq(socket.atlas.resource_path, MADRA_STRIP_PATH)
	assert_eq(socket.region, Rect2(0.0, 0.0, 80.0, 80.0))
	assert_eq(((madra_orb.material as ShaderMaterial).shader as Shader).resource_path, MADRA_ORB_SHADER_PATH)

func test_health_orb_uses_the_crimson_ramp() -> void:
	var material: ShaderMaterial = (_node("HealthOrb") as CanvasItem).material as ShaderMaterial
	assert_eq((material.get_shader_parameter("light") as Color).to_html(false), Color("#FFD9D2").to_html(false), "light")
	assert_eq((material.get_shader_parameter("pale") as Color).to_html(false), Color("#E8737A").to_html(false), "pale")
	assert_eq((material.get_shader_parameter("blue") as Color).to_html(false), Color("#B8304A").to_html(false), "blue")

## The Madra orb sets no ramp of its own: the shader's defaults are Madra's.
func test_madra_orb_keeps_the_default_ramp() -> void:
	var material: ShaderMaterial = (_node("MadraOrb") as CanvasItem).material as ShaderMaterial
	for parameter: String in ["light", "pale", "blue"]:
		assert_null(material.get_shader_parameter(parameter), "%s is left at the shader's default" % parameter)

## Each plate fills its own materials, so one scene instance never moves
## another's orbs.
func test_orb_materials_are_per_plate() -> void:
	var other: VitalsPlate = _add_plate()
	assert_ne((_node("HealthOrb") as CanvasItem).material, (other.get_node("%HealthOrb") as CanvasItem).material)
	assert_ne((_node("MadraOrb") as CanvasItem).material, (other.get_node("%MadraOrb") as CanvasItem).material)

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
# STAMINA SHAKE
#-----------------------------------------------------------------------------

## A refused walk shakes the Stamina row through the zone map's lock-shake
## steps (0, -8, 8, -6, 4, 0 px, each held 0.088 s), read frame by frame:
## every offset is a whole even step, in the keyframe order, and the row ends
## at home and not shaking.
func test_stamina_shake_runs_in_even_steps() -> void:
	var row: Control = _node("StaminaRow")
	assert_false(_plate.is_stamina_shaking(), "still before the shake")
	assert_eq(row.position.x, 0.0)
	await _start_in_a_fresh_frame()
	_plate.shake_stamina()
	assert_true(_plate.is_stamina_shaking())
	var offsets: Array[float] = [row.position.x]
	var settled: bool = await wait_until(func() -> bool:
		if row.position.x != offsets[-1]:
			offsets.append(row.position.x)
		return not _plate.is_stamina_shaking(), 2.0)
	assert_true(settled, "the shake ends by itself")
	assert_eq(offsets, [0.0, -8.0, 8.0, -6.0, 4.0, 0.0] as Array[float], "the keyframes in order, each a whole even px")
	assert_eq(row.position.x, 0.0, "and the row is back home")

## The rod, the icon and the figures shake with their row; the orbs and the
## rest of the cabinet stay put.
func test_stamina_shake_moves_only_the_stamina_row() -> void:
	var health_orb: Control = _node("HealthOrb")
	var health_home: Vector2 = health_orb.position
	var rod_home: Vector2 = (_node("StaminaRod") as Control).global_position
	await _start_in_a_fresh_frame()
	_plate.shake_stamina()
	await wait_until(func() -> bool: return (_node("StaminaRow") as Control).position.x == -8.0, 2.0)
	assert_eq((_node("StaminaRod") as Control).global_position, rod_home + Vector2(-8.0, 0.0), "the rod goes with its row")
	assert_eq(health_orb.position, health_home, "the orbs stay")
	assert_eq(_plate.position, PLATE_HOME, "and so does the cabinet")

func test_a_new_stamina_shake_restarts_it() -> void:
	var row: Control = _node("StaminaRow")
	await _start_in_a_fresh_frame()
	_plate.shake_stamina()
	await wait_until(func() -> bool: return row.position.x != 0.0, 2.0)
	_plate.shake_stamina()
	assert_eq(row.position.x, 0.0, "a new shake starts from home")
	assert_true(_plate.is_stamina_shaking())

#-----------------------------------------------------------------------------
# BUFF SOCKETS
#-----------------------------------------------------------------------------

func test_no_socket_shows_until_buffs_are_bound() -> void:
	assert_eq(_shown_sockets(), [false, false, false], "a fresh plate has no sockets")
	var manager: CombatBuffManager = _bind_a_combatant()
	assert_eq(_shown_sockets(), [false, false, false], "bound with no buff, still none")
	manager.apply_buff(_make_buff("enforce"))
	assert_eq(_shown_sockets(), [true, false, false])

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

func test_a_new_buff_flashes_its_socket() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	assert_false(_flash(0).is_flashing(), "nothing flashes before a buff lands")
	manager.apply_buff(_make_buff("enforce"))
	assert_true(_flash(0).is_flashing(), "the new buff's socket flashes")
	assert_true(_flash(0).visible, "the brass frame shows")
	assert_false(_flash(1).is_flashing(), "and only that socket")
	var ended: bool = await wait_until(func() -> bool: return not _flash(0).is_flashing(), 2.0)
	assert_true(ended, "the flash is a single one")
	assert_false(_flash(0).visible, "and it ends hidden")
	manager.apply_buff(_make_buff("brace", BASIC_STRIKE_ICON))
	assert_true(_flash(1).is_flashing(), "the next buff flashes the next socket")
	assert_false(_flash(0).is_flashing(), "not the first again")

## A buff that was already on when the plate was bound is not landing now.
func test_buffs_already_active_show_without_a_flash() -> void:
	_combatant = load(COMBATANT_SCENE_PATH).instantiate()
	add_child_autofree(_combatant)
	_combatant.setup(COMBATANT_DATA, null, false)
	_combatant.buff_manager.apply_buff(_make_buff("enforce", ENFORCE_ICON))
	_combatant.buff_manager.apply_buff(_make_buff("brace", BASIC_STRIKE_ICON))
	_plate.bind_buffs(_combatant.buff_manager)
	assert_eq(_shown_sockets(), [true, true, false], "both are shown")
	assert_eq(_icon(1).texture, BASIC_STRIKE_ICON)
	assert_false(_flash(0).is_flashing())
	assert_false(_flash(1).is_flashing())

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

## A buff that does not stack (an attribute multiplier) shows no seal however
## often it is applied again.
func test_a_buff_that_does_not_stack_shows_no_seal() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	var buff: BuffEffectData = _make_buff("brace")
	buff.buff_type = BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE
	buff.attribute_modifiers = {CharacterAttributesData.AttributeType.RESILIENCE: 2.0}
	manager.apply_buff(buff)
	manager.apply_buff(buff)
	assert_eq(manager.get_active_buff("brace").stack_count, 1, "precondition: it only refreshes")
	assert_false(_seal(0).visible)

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
	for index: int in VitalsPlate.MAX_BUFF_SOCKETS:
		assert_false(_flash(index).is_flashing(), "no flash is left running (socket %d)" % index)
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
	var cabinet_right: float = _plate.global_position.x + _plate.size.x
	assert_eq(_tooltip().get_global_rect().position, Vector2(cabinet_right + TOOLTIP_GAP, _socket(0).global_position.y), "8 px right of the cabinet, level with the socket")
	assert_eq(_tooltip().get_global_rect().position, Vector2(472.0, 76.0), "screen (472, 76) with the cabinet at home")
	_socket(0).mouse_exited.emit()
	assert_false(_tooltip().visible, "and goes when the pointer leaves")

func test_each_socket_opens_its_own_buffs_tooltip() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	manager.apply_buff(_make_buff("enforce"))
	manager.apply_buff(_make_buff("brace", BASIC_STRIKE_ICON))
	_socket(1).mouse_entered.emit()
	assert_eq(_tooltip_text("NameLabel"), "Brace", "the second socket holds the second buff")
	_socket(1).mouse_exited.emit()
	_socket(0).mouse_entered.emit()
	assert_eq(_tooltip_text("NameLabel"), "Enforce")

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

func test_tooltip_shows_stacks() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	var buff: BuffEffectData = _make_buff("enforce")
	manager.apply_buff(buff)
	_socket(0).mouse_entered.emit()
	assert_eq(_tooltip_text("TimeLabel"), "20 s left", "one stack: no count")
	manager.apply_buff(buff)
	await wait_process_frames(2)
	assert_eq(_tooltip_text("TimeLabel"), "20 s left · ×2", "a second stack, while the tooltip is open")

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

## A buff can end without running out: stripped (Power Font) or cleared (the
## fight is over), which leaves its time unspent.
func test_tooltip_hides_when_its_buff_is_stripped_or_cleared() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	manager.apply_buff(_make_buff("enforce"))
	_socket(0).mouse_entered.emit()
	manager.strip_all_buffs()
	assert_false(_tooltip().visible, "stripped")
	manager.apply_buff(_make_buff("enforce"))
	_socket(0).mouse_entered.emit()
	assert_true(_tooltip().visible, "precondition: open again")
	manager.clear_all_buffs()
	assert_false(_tooltip().visible, "cleared")

func test_tooltip_stays_when_another_buff_ends() -> void:
	var manager: CombatBuffManager = _bind_a_combatant()
	manager.apply_buff(_make_buff("enforce"))
	manager.apply_buff(_make_buff("brace", BASIC_STRIKE_ICON))
	_socket(0).mouse_entered.emit()
	manager.get_active_buff("brace").time_remaining = 0.0
	await wait_process_frames(2)
	assert_eq(manager.active_buffs.size(), 1, "precondition: the other buff ended")
	assert_true(_tooltip().visible, "the hovered buff is still on")
	assert_eq(_tooltip_text("NameLabel"), "Enforce")

## The board is 304 wide and as tall as its text, rounded up to even: a long
## effect line grows it and a short one takes it back.
func test_tooltip_is_304_wide_and_hugs_its_height() -> void:
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
	assert_eq(tooltip.size.x, 304.0)
	assert_eq(tooltip.size.y, ceilf(tooltip.get_combined_minimum_size().y / 2.0) * 2.0, "as tall as its content, rounded up to even")
	assert_eq(tooltip.get_global_rect().position, Vector2(100.0, 50.0), "its top-left is the one it was given")
	var short_height: float = tooltip.size.y
	tooltip.show_for_buff(ActiveBuff.new(long_buff), Vector2(100.0, 50.0))
	await wait_process_frames(2)
	assert_gt(tooltip.size.y, short_height, "a long effect line wraps and the board grows")
	assert_eq(tooltip.size.y, ceilf(tooltip.get_combined_minimum_size().y / 2.0) * 2.0)
	tooltip.show_for_buff(ActiveBuff.new(short_buff), Vector2(100.0, 50.0))
	await wait_process_frames(2)
	assert_eq(tooltip.size.y, short_height, "and a short one takes it back")
	assert_eq(tooltip.size.x, 304.0)

## The board hangs from a socket's even y, so an odd height would put its bottom
## edge, and the 2x art of its lower slice, 1 px off the 2 px grid. The rows add
## up to 91 + 20 n px for a description of n lines (111 for one, 131 for two),
## always odd, so the board's height is rounded up to an even one, as the
## technique tooltip's is.
func test_tooltip_height_is_even_whatever_the_description_takes() -> void:
	var tooltip: BuffTooltip = load(TOOLTIP_SCENE_PATH).instantiate()
	add_child_autofree(tooltip)
	var one_line: BuffEffectData = _make_buff("enforce")
	var two_lines := BuffEffectData.new()
	two_lines.buff_id = "great_surge"
	two_lines.duration = 10.0
	two_lines.buff_type = BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE
	two_lines.attribute_modifiers = {
		CharacterAttributesData.AttributeType.STRENGTH: 1.5,
		CharacterAttributesData.AttributeType.BODY: 1.5,
		CharacterAttributesData.AttributeType.AGILITY: 1.5,
		CharacterAttributesData.AttributeType.SPIRIT: 1.5,
		CharacterAttributesData.AttributeType.FOUNDATION: 1.5,
	}
	var description: Label = tooltip.get_node("%DescriptionLabel")
	var buffs: Dictionary[int, BuffEffectData] = {1: one_line, 2: two_lines}
	for lines: int in buffs:
		tooltip.show_for_buff(ActiveBuff.new(buffs[lines]), Vector2(100.0, 50.0))
		await wait_process_frames(2)
		assert_eq(description.get_line_count(), lines, "precondition: the description takes %d line(s)" % lines)
		var content_height: float = tooltip.get_combined_minimum_size().y
		assert_eq(tooltip.size.y, ceilf(content_height / 2.0) * 2.0, "%d line(s): as tall as its content, rounded up to even" % lines)
		assert_eq(fmod(tooltip.size.y, 2.0), 0.0, "%d line(s): an even height" % lines)
		assert_eq(fmod(tooltip.get_global_rect().end.y, 2.0), 0.0, "%d line(s): the bottom edge on the 2 px grid, as the top is" % lines)

## The tooltip draws above whatever sits beside the cabinet (it is top-level)
## and lets the pointer through to the sockets and the map.
func test_tooltip_floats_above_and_never_takes_the_pointer() -> void:
	var tooltip: BuffTooltip = load(TOOLTIP_SCENE_PATH).instantiate()
	add_child_autofree(tooltip)
	assert_false(tooltip.visible, "hidden until a buff is shown")
	assert_true(tooltip.top_level, "placed by screen position and drawn above its siblings")
	assert_eq(tooltip.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for node: Node in tooltip.find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s lets the pointer through" % node.name)

#-----------------------------------------------------------------------------
# LAYOUT AND ROOT
#-----------------------------------------------------------------------------

func test_root_is_the_cabinet_and_stops_clicks() -> void:
	assert_eq(_plate.position, PLATE_HOME)
	assert_eq(_plate.size, Vector2(440.0, 252.0))
	assert_eq(_plate.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(_plate.theme, load(LACQUER_THEME_PATH))

## The pieces sit where the kit puts them (cabinet-local; the mock's screen
## coordinates minus (24, 24)). The two big figures sit 1 px below the mock's
## CSS tops (43 and 131), as the zone cabinet's Madra figure does (mock 44, row
## 45): the 36 px CSS line box centres the 30 px glyphs 1 px lower than a
## Label, which is the font's own height, draws them.
func test_layout_matches_the_kit() -> void:
	assert_eq((_plate.get_node("Board") as Control).position, Vector2(0.0, 0.0))
	assert_eq(((_plate.get_node("Board") as TextureRect).texture as Texture2D).resource_path, "res://assets/ui/lacquer/lacquer_cult_ai.png")
	assert_eq(Rect2((_node("HealthOrb") as Control).position, (_node("HealthOrb") as Control).size), Rect2(18.0, 16.0, 80.0, 80.0))
	assert_eq((_plate.find_child("HealthTitleLabel", true, false) as Control).position, Vector2(114.0, 22.0))
	assert_eq((_plate.find_child("HealthRow", true, false) as Control).position, Vector2(114.0, 44.0))
	assert_eq(Rect2((_node("MadraOrb") as Control).position, (_node("MadraOrb") as Control).size), Rect2(18.0, 108.0, 80.0, 80.0))
	assert_eq((_plate.find_child("MadraTitleLabel", true, false) as Control).position, Vector2(114.0, 110.0))
	assert_eq((_plate.find_child("MadraRow", true, false) as Control).position, Vector2(114.0, 132.0))
	assert_eq((_plate.find_child("Divider", true, false) as Control).position, Vector2(16.0, 198.0))
	assert_eq((_node("StaminaRow") as Control).position, Vector2(0.0, 214.0))
	assert_eq((_plate.find_child("StaminaIcon", true, false) as Control).position, Vector2(18.0, 5.0))
	assert_eq((_plate.find_child("StaminaTitleLabel", true, false) as Control).position, Vector2(40.0, 3.0))
	assert_eq(Rect2((_node("StaminaRod") as Control).position, (_node("StaminaRod") as Control).size), Rect2(112.0, 7.0, 240.0, 10.0))
	assert_eq((_node("StaminaRod") as LacquerRod).steps, 119)
	var value_row: Control = _plate.find_child("StaminaValueRow", true, false)
	assert_eq(Rect2(value_row.position, value_row.size), Rect2(342.0, 0.0, 80.0, 20.0), "the Stamina figures end on the cabinet's right text edge")

func test_buff_sockets_sit_in_a_row_and_take_the_pointer() -> void:
	var expected_x: Array[float] = [294.0, 338.0, 382.0]
	for index: int in VitalsPlate.MAX_BUFF_SOCKETS:
		var socket: Control = _socket(index)
		assert_eq(Rect2(socket.position, socket.size), Rect2(expected_x[index], 52.0, 40.0, 40.0), "socket %d" % index)
		assert_eq(socket.mouse_filter, Control.MOUSE_FILTER_STOP, "it can be hovered")
		assert_eq(_icon(index).position, Vector2(4.0, 4.0), "the icon sits 4 px in")
		assert_eq(_icon(index).size, Vector2(32.0, 32.0), "and shows at 32x32")
		assert_eq(_icon(index).mouse_filter, Control.MOUSE_FILTER_IGNORE, "so the socket gets the pointer")

func test_count_seal_sits_at_the_sockets_top_right() -> void:
	for index: int in VitalsPlate.MAX_BUFF_SOCKETS:
		var seal_rect: Rect2 = Rect2(_seal(index).position, _seal(index).size)
		assert_eq(seal_rect.size, Vector2(24.0, 24.0), "the seal is the kit's 24x24")
		assert_gt(seal_rect.get_center().x, _socket(index).size.x * 0.5, "right of the socket's middle (socket %d)" % index)
		assert_lt(seal_rect.position.y, 0.0, "it rides above the socket's top edge")
		assert_eq(_count(index).theme_type_variation, &"LabelLacquerSeal")
