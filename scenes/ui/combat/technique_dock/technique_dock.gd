class_name TechniqueDock
extends Control

## The technique dock at the bottom centre of the adventure view, where the
## zone view keeps its dock (spec: The technique dock): the board, four
## TechniqueSlots for Q, W, E and R, the CastTray over the board while the
## player casts, and the TechniqueTooltip a hovered slot opens.
## On the map it previews the equipped loadout (show_loadout()): each equipped
## technique in its loadout slot. A fight binds the slots to the player's
## ability instances (bind()), each in the slot its technique is equipped in
## (the first free slot otherwise), and reset() returns to the preview.
## In a fight, and only while the dock is visible, Q/W/E/R (ability_slot_1 to
## ability_slot_4, in _unhandled_input) and clicks press a slot. A press asks
## the player's CombatAbilityManager whether the technique can be cast
## (can_cast_ability_instance(): not casting, not recharging, affordable).
## Refused, the slot shakes and nothing else happens: no log line, since the
## sweep, the cast tray and the tan cost already say why. Accepted, the dock
## emits ability_selected for AdventureCombat to use, as PlayerHud did.
## The root takes the pointer, so presses on the board never reach the map.

## Emitted when a press on a slot is accepted: the instance to use.
signal ability_selected(instance: CombatAbilityInstance)

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The input actions of the four slots, Q, W, E and R by default.
const SLOT_ACTIONS: Array[StringName] = [&"ability_slot_1", &"ability_slot_2", &"ability_slot_3", &"ability_slot_4"]

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _slots: Array[TechniqueSlot] = [%Slot1, %Slot2, %Slot3, %Slot4]
@onready var _cast_tray: CastTray = %CastTray
@onready var _tooltip: TechniqueTooltip = %TechniqueTooltip

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _is_active: bool = false
## The player's ability manager in a fight, which a press asks.
var _ability_manager: CombatAbilityManager = null
## The slot whose tooltip is open and its technique, or null.
var _hovered_slot: TechniqueSlot = null
var _hovered_data: AbilityData = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	for index: int in _slots.size():
		var slot: TechniqueSlot = _slots[index]
		slot.pressed.connect(_press.bind(index))
		slot.hovered.connect(_on_slot_hovered.bind(slot))
		slot.unhovered.connect(_on_slot_unhovered.bind(slot))
	_cast_tray.visibility_changed.connect(_on_cast_tray_visibility_changed)
	show_loadout()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the equipped loadout without making it usable (on the map): each
## equipped technique in its loadout slot, the rest empty. Lets go of a fight.
func show_loadout() -> void:
	_is_active = false
	_ability_manager = null
	_cast_tray.unbind()
	_hide_tooltip()
	for index: int in _slots.size():
		_slots[index].show_empty(index)
	for data: AbilityData in AbilityManager.get_equipped_abilities():
		var slot_index: int = _find_equip_slot(data.ability_id)
		if slot_index >= 0 and slot_index < _slots.size():
			_slots[slot_index].show_preview(data, slot_index)

## Binds the slots to the player's ability instances in a fight and takes its
## keys and clicks: each instance in the slot its technique is equipped in, or
## the first free slot. vitals_manager pays the costs the slots check.
func bind(ability_manager: CombatAbilityManager, vitals_manager: VitalsManager) -> void:
	_hide_tooltip()
	_cast_tray.unbind()
	for index: int in _slots.size():
		_slots[index].show_empty(index)
	_ability_manager = ability_manager
	_is_active = ability_manager != null
	if ability_manager == null:
		Log.error("TechniqueDock: bind() needs the player's CombatAbilityManager")
		return
	var used: Dictionary[int, bool] = {}
	for instance: CombatAbilityInstance in ability_manager.abilities:
		var slot_index: int = _find_equip_slot(instance.ability_data.ability_id)
		if slot_index < 0 or slot_index >= _slots.size() or used.has(slot_index):
			slot_index = _first_free_slot(used)
		if slot_index < 0:
			Log.warn("TechniqueDock: No free slot for %s" % instance.ability_data.ability_name)
			continue
		_slots[slot_index].bind(instance, slot_index, vitals_manager)
		used[slot_index] = true
	_cast_tray.bind(ability_manager)

## Returns to the loadout preview after a fight.
func reset() -> void:
	show_loadout()

## Returns true while the dock is bound to a fight and takes presses.
func is_active() -> bool:
	return _is_active

## Returns the slot at index (0 to 3, for Q to R), or null outside them.
func get_slot(index: int) -> TechniqueSlot:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]

## Returns the cast tray over the dock.
func get_cast_tray() -> CastTray:
	return _cast_tray

## Returns the tooltip the slots open. (Not get_tooltip(): Control already has
## get_tooltip(at_position) for its own tooltip text.)
func get_technique_tooltip() -> TechniqueTooltip:
	return _tooltip

#-----------------------------------------------------------------------------
# INPUT
#-----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active or not is_visible_in_tree():
		return
	for index: int in SLOT_ACTIONS.size():
		if event.is_action_pressed(SLOT_ACTIONS[index]):
			_press(index)
			get_viewport().set_input_as_handled()
			return

## A key or a click on the slot at index: an accepted press emits
## ability_selected, a refused one shakes the slot. Does nothing outside a
## fight or on an empty slot.
func _press(index: int) -> void:
	var slot: TechniqueSlot = _slots[index]
	var instance: CombatAbilityInstance = slot.get_ability_instance()
	if not _is_active or instance == null or not is_instance_valid(_ability_manager):
		return
	if _ability_manager.can_cast_ability_instance(instance, null):
		ability_selected.emit(instance)
	else:
		slot.refuse()

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## The loadout slot ability_id is equipped in, or -1.
func _find_equip_slot(ability_id: String) -> int:
	for index: int in AbilityManager.get_max_slots():
		if AbilityManager.get_ability_at_slot(index) == ability_id:
			return index
	return -1

func _first_free_slot(used: Dictionary[int, bool]) -> int:
	for index: int in _slots.size():
		if not used.has(index):
			return index
	return -1

func _hide_tooltip() -> void:
	_hovered_slot = null
	_hovered_data = null
	_tooltip.hide_tooltip()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_slot_hovered(ability_data: AbilityData, slot: TechniqueSlot) -> void:
	_hovered_slot = slot
	_hovered_data = ability_data
	_tooltip.show_for_ability(ability_data, slot, _cast_tray.visible)

func _on_slot_unhovered(slot: TechniqueSlot) -> void:
	if slot == _hovered_slot:
		_hide_tooltip()

## A cast starting or ending under an open tooltip moves it above or back
## below the tray.
func _on_cast_tray_visibility_changed() -> void:
	if _hovered_slot != null and _tooltip.visible:
		_tooltip.show_for_ability(_hovered_data, _hovered_slot, _cast_tray.visible)
