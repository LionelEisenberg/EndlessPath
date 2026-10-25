extends GutTest

## Integration tests for ConsumableSlot, one consumable socket on the technique
## dock (spec: 2026-10-25-combat-consumables-lacquer-design.md). Covers its
## states (EMPTY, PREVIEW on the map, ACTIVE in a fight), the count seal that
## grows to fit a long count, the cooldown sweep on the 32 px icon, the socket
## at none left (all veiled, at 0), the ready flash, presses, hover and the
## refusal shake. The slot is tested alone, on a fresh save, with instances
## made as CombatConsumableManager makes them.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const SLOT_SCENE_PATH: String = "res://scenes/ui/combat/technique_dock/consumable_slot/consumable_slot.tscn"
const CRUDE_SCALE: ConsumableDefinitionData = preload("res://resources/items/consumables/crude_scale.tres")
const SWEEP_SHADER_PATH: String = "res://assets/shaders/lacquer_cooldown_sweep.gdshader"
const KIT_PATH: String = "res://assets/ui/lacquer/lacquer_%s_ai.png"
const FRAME_BRASS_PATH: String = "res://assets/styleboxes/lacquer/frame_brass.tres"
const FRAME_HOVER_PATH: String = "res://assets/styleboxes/lacquer/frame_hover.tres"
const LACQUER_THEME_PATH: String = "res://assets/themes/lacquer/lacquer_theme.tres"
const Slot := ConsumableSlot.SlotState

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## An effect that counts how often it fires, so no test touches the vitals.
class CountingEffect extends EffectData:
	var call_count: int = 0

	func process() -> void:
		call_count += 1

	func _to_string() -> String:
		return "CountingEffect"

var _slot: ConsumableSlot = null
var _original_save: SaveGameData = null
## Crude Scale with a counting effect in place of its Madra.
var _scale: ConsumableDefinitionData = null

func before_each() -> void:
	_original_save = PersistenceManager.save_game_data
	PersistenceManager.save_game_data = SaveGameData.new()
	PersistenceManager.save_data_reset.emit()
	_scale = CRUDE_SCALE.duplicate() as ConsumableDefinitionData
	_scale.effects = [CountingEffect.new()]
	_slot = load(SLOT_SCENE_PATH).instantiate()
	add_child_autofree(_slot)

func after_each() -> void:
	if is_instance_valid(_slot):
		_slot.free()
	PersistenceManager.save_game_data = _original_save
	PersistenceManager.save_data_reset.emit()

func _node(unique_name: String) -> Node:
	return _slot.get_node("%" + unique_name)

func _font_colour(control: Control) -> Color:
	return control.get_theme_color(&"font_color")

## The step the sweep shader draws, 0 to 1.
func _sweep_progress() -> float:
	return ((_node("Icon") as CanvasItem).material as ShaderMaterial).get_shader_parameter("progress")

## An instance of _scale in hotbar slot 0, with held of it, as the manager
## makes one.
func _make_instance(held: int) -> CombatConsumableInstance:
	if held > 0:
		InventoryManager.award_items(_scale, held)
	var instance := CombatConsumableInstance.new(_scale, 0)
	add_child_autofree(instance)
	return instance

func _left_press() -> InputEventMouseButton:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	return press

## Ends an instance's running cooldown for real: its timer runs down in a frame
## or two and fires cooldown_ready.
func _finish_cooldown(instance: CombatConsumableInstance) -> void:
	instance.cooldown_timer.start(0.01)
	var fired: bool = await wait_for_signal(instance.cooldown_ready, 1.0)
	assert_true(fired, "precondition: the cooldown ended")

#-----------------------------------------------------------------------------
# STATES
#-----------------------------------------------------------------------------

func test_empty_shows_the_socket_and_key() -> void:
	_slot.show_empty(0)

	assert_eq(_slot.get_state(), Slot.EMPTY)
	assert_false((_node("Icon") as Control).visible, "no icon")
	assert_false((_node("CountSeal") as Control).visible, "no seal")
	assert_true((_node("KeyCap") as Control).visible, "the key cap stays")
	assert_eq((_node("KeyLabel") as Label).text, "1", "slot 0 is key 1")
	assert_eq(_font_colour(_node("KeyLabel")), ThemeConstants.LACQUER_TAN)

func test_preview_shows_icon_count_and_a_tan_key() -> void:
	InventoryManager.award_items(_scale, 3)

	_slot.show_preview(_scale, 2)

	assert_eq(_slot.get_state(), Slot.PREVIEW)
	assert_eq((_node("Icon") as TextureRect).texture, _scale.icon)
	assert_true((_node("Icon") as Control).visible)
	assert_true((_node("CountSeal") as Control).visible, "the count seal shows")
	assert_eq((_node("CountLabel") as Label).text, "3")
	assert_eq(_slot.get_count(), 3)
	assert_eq((_node("KeyLabel") as Label).text, "3", "slot 2 is key 3")
	assert_eq(_font_colour(_node("KeyLabel")), ThemeConstants.LACQUER_TAN, "not usable on the map")
	assert_eq(_slot.get_sweep_step(), TechniqueSlot.SWEEP_STEPS, "the plain icon")
	assert_eq(_sweep_progress(), 1.0)

func test_preview_with_none_left_is_veiled_at_zero() -> void:
	_slot.show_preview(_scale, 0)

	assert_eq(_slot.get_state(), Slot.PREVIEW, "it keeps its consumable")
	assert_eq((_node("CountLabel") as Label).text, "0")
	assert_eq(_slot.get_sweep_step(), 0, "all in the locked veil")
	assert_eq(_sweep_progress(), 0.0)
	assert_false((_node("SecondsLabel") as Control).visible, "no seconds")

func test_bind_shows_a_cream_key() -> void:
	var instance := _make_instance(3)

	_slot.bind(instance, 0)

	assert_eq(_slot.get_state(), Slot.ACTIVE)
	assert_eq(_slot.get_consumable_instance(), instance)
	assert_eq(_slot.get_consumable_data(), _scale)
	assert_eq(_font_colour(_node("KeyLabel")), ThemeConstants.LACQUER_CREAM)
	assert_eq(_slot.get_sweep_step(), TechniqueSlot.SWEEP_STEPS, "ready as the fight opens")

#-----------------------------------------------------------------------------
# COOLDOWN
#-----------------------------------------------------------------------------

func test_the_sweep_follows_the_cooldown() -> void:
	var instance := _make_instance(3)
	_slot.bind(instance, 0)
	var seconds: Label = _node("SecondsLabel")

	assert_true(instance.use(), "precondition: used")
	_slot.refresh_count()

	assert_eq(_slot.get_sweep_step(), 0, "all veiled as the cooldown starts")
	assert_true(seconds.visible)
	assert_eq(seconds.text, "10")
	assert_eq((_node("CountLabel") as Label).text, "2", "one came off")
	instance.cooldown_updated.emit(5.0)
	assert_eq(_slot.get_sweep_step(), 12, "half recharged: half the steps")
	assert_eq(_sweep_progress(), 0.5)
	assert_eq(seconds.text, "5")
	await _finish_cooldown(instance)
	assert_eq(_slot.get_sweep_step(), TechniqueSlot.SWEEP_STEPS, "the plain icon again")
	assert_false(seconds.visible, "no seconds once ready")
	assert_true((_node("ReadyFlash") as LacquerFrameOverlay).is_flashing(), "a brass flash says it is ready")

func test_using_the_last_one_leaves_it_veiled_at_zero() -> void:
	var instance := _make_instance(1)
	_slot.bind(instance, 0)

	assert_true(instance.use(), "precondition: the last one used")
	_slot.refresh_count()

	assert_eq((_node("CountLabel") as Label).text, "0")
	assert_eq(_slot.get_sweep_step(), 0, "all veiled")
	assert_false((_node("SecondsLabel") as Control).visible, "no seconds for a socket that cannot be used")
	await _finish_cooldown(instance)
	assert_false((_node("ReadyFlash") as LacquerFrameOverlay).is_flashing(), "nothing to be ready for: no flash")
	assert_eq(_slot.get_sweep_step(), 0, "still veiled")

#-----------------------------------------------------------------------------
# POINTER AND REFUSAL
#-----------------------------------------------------------------------------

func test_a_left_press_emits_pressed_only_when_active() -> void:
	InventoryManager.award_items(_scale, 1)
	_slot.show_preview(_scale, 0)
	watch_signals(_slot)

	_slot.gui_input.emit(_left_press())
	assert_signal_not_emitted(_slot, "pressed", "not on the map")

	_slot.bind(_make_instance(0), 0)
	_slot.gui_input.emit(_left_press())
	assert_signal_emitted(_slot, "pressed", "in a fight")

func test_hover_emits_with_the_data_and_shows_the_frame() -> void:
	InventoryManager.award_items(_scale, 1)
	_slot.show_preview(_scale, 0)
	watch_signals(_slot)

	_slot.mouse_entered.emit()
	assert_signal_emitted_with_parameters(_slot, "hovered", [_scale])
	assert_true((_node("HoverFrame") as Control).visible)
	_slot.mouse_exited.emit()
	assert_signal_emitted(_slot, "unhovered")
	assert_false((_node("HoverFrame") as Control).visible)

	_slot.show_empty(1)
	_slot.mouse_entered.emit()
	assert_signal_emit_count(_slot, "hovered", 1, "an empty socket opens no tooltip")
	assert_false((_node("HoverFrame") as Control).visible, "and has no hover frame")

func test_refuse_shakes_the_body_and_not_the_key_or_seal() -> void:
	_slot.bind(_make_instance(1), 0)
	var key_cap: Control = _node("KeyCap")
	var seal: Control = _node("CountSeal")
	var key_home: Vector2 = key_cap.position
	var seal_home: Vector2 = seal.position

	_slot.refuse()
	simulate(_slot, 1, 0.1)

	assert_true(_slot.is_shaking())
	assert_eq((_node("Body") as Control).position, Vector2(-4.0, 0.0), "the socket is mid-shake")
	assert_eq(key_cap.position, key_home, "the key cap stays")
	assert_eq(seal.position, seal_home, "the seal stays")
	simulate(_slot, 10, 0.05)
	assert_false(_slot.is_shaking(), "the shake ends")
	assert_eq((_node("Body") as Control).position.x, 0.0, "back home")

#-----------------------------------------------------------------------------
# THE COUNT SEAL
#-----------------------------------------------------------------------------

func test_seal_width() -> void:
	assert_eq(ConsumableSlot.seal_width(10.0), 24.0, "a short count keeps the seal's 24 px")
	assert_eq(ConsumableSlot.seal_width(30.0), 38.0, "a long one adds its padding")
	assert_eq(ConsumableSlot.seal_width(31.0), 40.0, "rounded up to even")

func test_a_long_count_grows_the_seal_leftward() -> void:
	InventoryManager.award_items(_scale, 1234)

	_slot.show_preview(_scale, 0)

	var seal: Control = _node("CountSeal")
	var label: Label = _node("CountLabel")
	assert_eq(label.text, "1234")
	assert_gt(seal.size.x, 24.0, "the seal widened")
	assert_eq(fmod(seal.size.x, 2.0), 0.0, "to an even width")
	assert_eq(seal.position.x + seal.size.x, ConsumableSlot.SEAL_RIGHT, "its right edge stays")
	assert_eq(fmod(seal.position.x, 2.0), 0.0, "on the 2 px grid")
	assert_lte(label.get_minimum_size().x, seal.size.x, "the count fits in it")
	assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)

	InventoryManager.get_inventory().consumables[_scale] = 3
	_slot.refresh_count()
	assert_eq(seal.size.x, 24.0, "a short count takes the seal back to 24 px")
	assert_eq(seal.position.x, ConsumableSlot.SEAL_RIGHT - 24.0)

#-----------------------------------------------------------------------------
# THE SCENE
#-----------------------------------------------------------------------------

func test_scene_uses_the_kit() -> void:
	assert_eq(_slot.size, Vector2(48.0, 48.0))
	assert_eq(_slot.theme, load(LACQUER_THEME_PATH))
	var socket := _slot.get_node("Body/Socket") as TextureRect
	assert_eq(socket.texture.resource_path, KIT_PATH % "slot_consumable")
	assert_eq(socket.size, Vector2(50.0, 50.0), "at file size, its 2 px shadow beyond the socket")
	var icon: TextureRect = _node("Icon")
	assert_eq(Rect2(icon.position, icon.size), Rect2(8.0, 8.0, 32.0, 32.0), "a 32 px icon at +8")
	var material := icon.material as ShaderMaterial
	assert_eq(material.shader.resource_path, SWEEP_SHADER_PATH)
	assert_eq(material.get_shader_parameter(&"icon_size"), 32.0, "the sweep centred on a 32 px icon")
	assert_true(material.resource_local_to_scene)
	var key_cap: TextureRect = _node("KeyCap")
	assert_eq(key_cap.texture.resource_path, KIT_PATH % "keycap")
	assert_eq(key_cap.position, Vector2(-6.0, -6.0))
	assert_eq((_node("KeyLabel") as Label).theme_type_variation, &"LabelLacquerHotkey")
	var seal_face := _slot.get_node("CountSeal/Seal") as NinePatchRect
	assert_eq(seal_face.texture.resource_path, KIT_PATH % "seal_count9")
	assert_eq([seal_face.patch_margin_left, seal_face.patch_margin_right], [6, 6], "a 9-slice that stretches its plain middle")
	assert_eq((_node("CountLabel") as Label).theme_type_variation, &"LabelLacquerSeal")
	assert_eq((_node("SecondsLabel") as Label).theme_type_variation, &"LabelLacquerCooldown")
	assert_eq((_node("ReadyFlash") as Panel).get_theme_stylebox(&"panel"), load(FRAME_BRASS_PATH))
	assert_eq((_node("HoverFrame") as Panel).get_theme_stylebox(&"panel"), load(FRAME_HOVER_PATH))
	for node: Node in _slot.find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s leaves the pointer to the slot" % node.name)
	for label: Node in _slot.find_children("*", "Label", true, false):
		assert_false((label as Label).clip_text, "%s never clips" % label.name)
		assert_eq((label as Label).text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "%s never trims" % label.name)
