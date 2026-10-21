class_name AbilitiesPanel
extends PanelContainer

## AbilitiesPanel
## The player's technique bar: four fixed slots matching the Q/W/E/R loadout.
## Outside combat it previews the equipped loadout (hover to read a technique);
## in combat the slots bind to ability instances and accept clicks and keybinds.
## Casting progress is shown separately by a CastBar, so the slots never hide.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal ability_selected(instance: CombatAbilityInstance)
## Emitted while a technique slot is hovered (used for cost previews).
signal ability_hovered(ability_data: AbilityData)
signal ability_unhovered

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const SLOT_ACTIONS: PackedStringArray = [
	"ability_slot_1", "ability_slot_2", "ability_slot_3", "ability_slot_4"
]

#-----------------------------------------------------------------------------
# NODES
#-----------------------------------------------------------------------------

@onready var _slots: Array[AbilityButton] = [%Slot1, %Slot2, %Slot3, %Slot4]
@onready var _tooltip: CombatAbilityTooltip = %CombatAbilityTooltip

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _is_active: bool = false

func _ready() -> void:
	for slot: AbilityButton in _slots:
		slot.pressed.connect(_activate.bind(slot))
		slot.hovered.connect(_on_slot_hovered.bind(slot))
		slot.unhovered.connect(_on_slot_unhovered)
	show_loadout()

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Shows the equipped loadout without making it usable (outside combat).
func show_loadout() -> void:
	_is_active = false
	_hide_tooltip()
	for i: int in range(_slots.size()):
		_slots[i].show_empty(i)
	for data: AbilityData in AbilityManager.get_equipped_abilities():
		var slot_index: int = _find_equip_slot(data.ability_id)
		if slot_index >= 0 and slot_index < _slots.size():
			_slots[slot_index].show_preview(data, slot_index)

## Binds the slots to the given combat abilities and enables input.
func bind(ability_manager: CombatAbilityManager, vitals_manager: VitalsManager) -> void:
	_hide_tooltip()
	for i: int in range(_slots.size()):
		_slots[i].show_empty(i)

	var used: Dictionary = {}
	for instance: CombatAbilityInstance in ability_manager.abilities:
		var slot_index: int = _find_equip_slot(instance.ability_data.ability_id)
		if slot_index < 0 or slot_index >= _slots.size() or used.has(slot_index):
			slot_index = _first_free_slot(used)
		if slot_index < 0:
			Log.warn("AbilitiesPanel: No free slot for %s" % instance.ability_data.ability_name)
			continue
		_slots[slot_index].setup(instance, slot_index, vitals_manager)
		used[slot_index] = true
	_is_active = true

## Returns to the out-of-combat loadout preview.
func reset() -> void:
	show_loadout()

#-----------------------------------------------------------------------------
# INPUT
#-----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active or not is_visible_in_tree():
		return
	for i: int in range(SLOT_ACTIONS.size()):
		if event.is_action_pressed(SLOT_ACTIONS[i]):
			var slot: AbilityButton = _slots[i]
			if slot.state == AbilityButton.SlotState.ACTIVE and not slot.button.disabled:
				_activate(slot)
				_hide_tooltip()
			get_viewport().set_input_as_handled()
			return

func _activate(slot: AbilityButton) -> void:
	if not _is_active or not slot.ability_instance:
		return
	slot.flash_press()
	ability_selected.emit(slot.ability_instance)

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

func _find_equip_slot(ability_id: String) -> int:
	for i: int in range(AbilityManager.get_max_slots()):
		if AbilityManager.get_ability_at_slot(i) == ability_id:
			return i
	return -1

func _first_free_slot(used: Dictionary) -> int:
	for i: int in range(_slots.size()):
		if not used.has(i):
			return i
	return -1

#-----------------------------------------------------------------------------
# TOOLTIP
#-----------------------------------------------------------------------------

func _on_slot_hovered(ability_data: AbilityData, slot: AbilityButton) -> void:
	_tooltip.show_for_ability(ability_data)
	_tooltip.position_above(slot)
	ability_hovered.emit(ability_data)

func _on_slot_unhovered() -> void:
	_hide_tooltip()
	ability_unhovered.emit()

func _hide_tooltip() -> void:
	if _tooltip:
		_tooltip.hide_tooltip()
