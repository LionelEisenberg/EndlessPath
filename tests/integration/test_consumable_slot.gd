extends GutTest

## Integration tests for what ConsumableSlot adds to DockSlot (spec:
## 2026-10-25-combat-consumables-lacquer-design.md): its scene (the kit's glyph
## socket, the 32 px icon under the sweep, the count seal off its corner), how
## each state shows a consumable and its count, and the socket with none left
## (all veiled at 0, no seconds, no ready flash). The key cap, hover, presses and
## the refusal shake are DockSlot's, tested through the technique slots
## (test_technique_dock.gd) and the dock's consumable row
## (test_technique_dock_consumables.gd); the seal is LacquerCountSeal's
## (test_lacquer_count_seal.gd). The slot is tested alone, on a fresh save, with
## instances made as CombatConsumableManager makes them.

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
const CountingEffect := preload("res://tests/unit/counting_effect.gd")

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

## The count on the socket's seal (a LacquerCountSeal, which owns its label).
func _count_text() -> String:
	return (_node("CountSeal").get_node("%CountLabel") as Label).text

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
	assert_eq(_count_text(), "3")
	assert_eq((_node("KeyLabel") as Label).text, "3", "slot 2 is key 3")
	assert_eq(_font_colour(_node("KeyLabel")), ThemeConstants.LACQUER_TAN, "not usable on the map")
	assert_eq(_slot.get_sweep_step(), ConsumableSlot.SWEEP_STEPS, "the plain icon")
	assert_eq(_sweep_progress(), 1.0)

#-----------------------------------------------------------------------------
# COOLDOWN AND NONE LEFT
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
	assert_eq(_count_text(), "2", "one came off")
	instance.cooldown_updated.emit(5.0)
	assert_eq(_slot.get_sweep_step(), 12, "half recharged: half the steps")
	assert_eq(_sweep_progress(), 0.5)
	assert_eq(seconds.text, "5")
	await _finish_cooldown(instance)
	assert_eq(_slot.get_sweep_step(), ConsumableSlot.SWEEP_STEPS, "the plain icon again")
	assert_false(seconds.visible, "no seconds once ready")
	assert_true((_node("ReadyFlash") as LacquerFrameOverlay).is_flashing(), "a brass flash says it is ready")

func test_using_the_last_one_leaves_it_veiled_at_zero() -> void:
	var instance := _make_instance(1)
	_slot.bind(instance, 0)

	assert_true(instance.use(), "precondition: the last one used")
	_slot.refresh_count()

	assert_eq(_count_text(), "0")
	assert_eq(_slot.get_sweep_step(), 0, "all veiled")
	assert_false((_node("SecondsLabel") as Control).visible, "no seconds for a socket that cannot be used")
	await _finish_cooldown(instance)
	assert_false((_node("ReadyFlash") as LacquerFrameOverlay).is_flashing(), "nothing to be ready for: no flash")
	assert_eq(_slot.get_sweep_step(), 0, "still veiled")

#-----------------------------------------------------------------------------
# THE SCENE
#-----------------------------------------------------------------------------

func test_scene_uses_the_kit() -> void:
	assert_eq(_slot.size, Vector2(48.0, 48.0))
	assert_eq(_slot.theme, load(LACQUER_THEME_PATH))
	var socket := _slot.get_node("Body/Socket") as TextureRect
	assert_eq(socket.texture.resource_path, KIT_PATH % "socket_glyph", "the kit's 48 px glyph socket, as the Here tray's")
	assert_eq(socket.size, Vector2(48.0, 48.0))
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
	var seal := _node("CountSeal") as LacquerCountSeal
	assert_not_null(seal, "the count is the shared LacquerCountSeal")
	assert_eq(seal.get_parent(), _slot, "outside the socket, so it stays put in a shake")
	assert_eq(seal.position, Vector2(28.0, 30.0), "off the socket's bottom right corner")
	assert_true(seal.grows_left, "a long count widens it leftward")
	var seconds: Label = _node("SecondsLabel")
	assert_eq(seconds.theme_type_variation, &"LabelLacquerCooldown")
	assert_eq(seconds.get_theme_font_size(&"font_size"), 15, "the seconds sized to the 32 px icon")
	assert_eq((_node("ReadyFlash") as Panel).get_theme_stylebox(&"panel"), load(FRAME_BRASS_PATH))
	assert_eq((_node("HoverFrame") as Panel).get_theme_stylebox(&"panel"), load(FRAME_HOVER_PATH))
	for node: Node in _slot.find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s leaves the pointer to the slot" % node.name)
	for label: Node in _slot.find_children("*", "Label", true, false):
		assert_false((label as Label).clip_text, "%s never clips" % label.name)
		assert_eq((label as Label).text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "%s never trims" % label.name)
