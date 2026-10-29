extends GutTest

## Integration tests for what ConsumableSlot adds to DockSlot (spec:
## 2026-10-25-combat-consumables-lacquer-design.md): how each state shows a
## consumable and its count, the sweep following the cooldown, the socket with
## none left (all veiled at 0, no seconds, no ready flash), and its scene
## leaving the pointer to the slot. The key cap, hover, presses and the refusal
## shake are DockSlot's, tested through the technique slots
## (test_technique_dock.gd) and the dock's consumable row
## (test_technique_dock_consumables.gd); the seal is LacquerCountSeal's
## (test_lacquer_count_seal.gd). The slot is tested alone, on a fresh save, with
## instances made as CombatConsumableManager makes them.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const SLOT_SCENE_PATH: String = "res://scenes/ui/combat/technique_dock/consumable_slot/consumable_slot.tscn"
const CRUDE_SCALE: ConsumableDefinitionData = preload("res://resources/items/consumables/crude_scale.tres")
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

func test_preview_shows_icon_and_count() -> void:
	InventoryManager.award_items(_scale, 3)

	_slot.show_preview(_scale, 2)

	assert_eq(_slot.get_state(), Slot.PREVIEW)
	assert_eq((_node("Icon") as TextureRect).texture, _scale.icon)
	assert_true((_node("Icon") as Control).visible)
	assert_true((_node("CountSeal") as Control).visible, "the count seal shows")
	assert_eq(_count_text(), "3")
	assert_eq((_node("KeyLabel") as Label).text, "3", "slot 2 is key 3")
	assert_eq(_slot.get_sweep_step(), ConsumableSlot.SWEEP_STEPS, "the plain icon")

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

func test_its_pieces_leave_the_pointer_to_the_slot() -> void:
	for node: Node in _slot.find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s leaves the pointer to the slot" % node.name)
