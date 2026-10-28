class_name TechniqueDock
extends Control

## The technique dock at the bottom centre of the adventure view, where the
## zone view keeps its dock (spec: The technique dock): the board, four
## TechniqueSlots for Q, W, E and R, the CastTray over the board while the
## player casts, and the TechniqueTooltip a hovered slot opens.
## Along its top runs a row of four ConsumableSlots for the inventory's hotbar,
## each over the technique whose key sits under its own on the keyboard (1 over
## Q to 4 over R; spec 2026-10-25-combat-consumables-lacquer-design.md).
## On the map it previews the equipped loadout and the hotbar (show_loadout()):
## each equipped technique in its loadout slot, each hotbar consumable in its
## socket with its count. A fight binds the slots to the player's ability
## instances (bind()), each in the slot its technique is equipped in (the first
## free slot otherwise), and the sockets to the player's consumable instances by
## hotbar slot; reset() returns to the preview.
## In a fight, and only while the dock is visible, Q/W/E/R (ability_slot_1 to
## ability_slot_4), 1 to 4 (consumable_slot_1 to consumable_slot_4, in
## _unhandled_input) and clicks press a slot or a socket. A technique press asks
## the player's CombatAbilityManager whether the technique can be cast
## (can_cast_ability_instance(): not casting, not recharging, affordable); a
## consumable press asks the player's CombatConsumableManager
## (can_use_consumable_instance(): not recharging, some left; a cast never
## blocks it). Refused, the slot shakes and nothing else happens: no log line,
## since the sweep, the cast tray, the tan cost and the count seal already say
## why. Accepted, the dock emits ability_selected or consumable_selected for
## AdventureCombat to use.
## The counts follow InventoryManager.inventory_changed: in a fight each socket
## reads its count again, and on the map the hotbar is previewed again.
## The root takes the pointer, so presses on the board never reach the map.

## Emitted when a press on a technique slot is accepted: the instance to use.
signal ability_selected(instance: CombatAbilityInstance)
## Emitted when a press on a consumable socket is accepted: the instance to use.
signal consumable_selected(instance: CombatConsumableInstance)

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The input actions of the four slots, Q, W, E and R by default.
const SLOT_ACTIONS: Array[StringName] = [&"ability_slot_1", &"ability_slot_2", &"ability_slot_3", &"ability_slot_4"]
## The input actions of the four consumable sockets, 1 to 4 by default.
const CONSUMABLE_ACTIONS: Array[StringName] = [&"consumable_slot_1", &"consumable_slot_2", &"consumable_slot_3", &"consumable_slot_4"]

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _slots: Array[TechniqueSlot] = [%Slot1, %Slot2, %Slot3, %Slot4]
@onready var _consumable_slots: Array[ConsumableSlot] = [%ConsumableSlot1, %ConsumableSlot2, %ConsumableSlot3, %ConsumableSlot4]
@onready var _cast_tray: CastTray = %CastTray
@onready var _tooltip: TechniqueTooltip = %TechniqueTooltip

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _is_active: bool = false
## The player's ability manager in a fight, which a technique press asks.
var _ability_manager: CombatAbilityManager = null
## The player's consumable manager in a fight, which a consumable press asks.
var _consumable_manager: CombatConsumableManager = null
## The slot or socket whose tooltip is open, and what it holds (an AbilityData
## or a ConsumableDefinitionData), or null.
var _hovered_slot: Control = null
var _hovered_data: Resource = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	for index: int in _slots.size():
		var slot: TechniqueSlot = _slots[index]
		slot.pressed.connect(_press.bind(index))
		slot.hovered.connect(_on_slot_hovered.bind(slot))
		slot.unhovered.connect(_on_slot_unhovered.bind(slot))
	for index: int in _consumable_slots.size():
		var socket: ConsumableSlot = _consumable_slots[index]
		socket.pressed.connect(_press_consumable.bind(index))
		socket.hovered.connect(_on_slot_hovered.bind(socket))
		socket.unhovered.connect(_on_slot_unhovered.bind(socket))
	_cast_tray.visibility_changed.connect(_on_cast_tray_visibility_changed)
	_cast_tray.resized.connect(_on_cast_tray_visibility_changed)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	show_loadout()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the equipped loadout and the hotbar without making them usable (on the
## map): each equipped technique in its loadout slot and each hotbar consumable
## in its socket, the rest empty. Lets go of a fight.
func show_loadout() -> void:
	_is_active = false
	_ability_manager = null
	_consumable_manager = null
	_cast_tray.unbind()
	_hide_tooltip()
	for index: int in _slots.size():
		_slots[index].show_empty(index)
	for data: AbilityData in AbilityManager.get_equipped_abilities():
		var slot_index: int = _find_equip_slot(data.ability_id)
		if slot_index >= 0 and slot_index < _slots.size():
			_slots[slot_index].show_preview(data, slot_index)
	_show_hotbar()

## Binds the slots to the player's ability instances in a fight and takes its
## keys and clicks: each instance in the slot its technique is equipped in, or
## the first free slot. vitals_manager pays the costs the slots check. The
## sockets bind to consumable_manager's instances, each in its hotbar slot's
## socket; without one, the sockets show empty.
func bind(ability_manager: CombatAbilityManager, vitals_manager: VitalsManager, consumable_manager: CombatConsumableManager = null) -> void:
	_hide_tooltip()
	_cast_tray.unbind()
	for index: int in _slots.size():
		_slots[index].show_empty(index)
	_ability_manager = ability_manager
	_consumable_manager = consumable_manager
	_is_active = ability_manager != null
	_bind_consumables()
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

## Returns the consumable socket at index (0 to 3, for keys 1 to 4), or null
## outside them.
func get_consumable_slot(index: int) -> ConsumableSlot:
	if index < 0 or index >= _consumable_slots.size():
		return null
	return _consumable_slots[index]

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
	for index: int in CONSUMABLE_ACTIONS.size():
		if event.is_action_pressed(CONSUMABLE_ACTIONS[index]):
			_press_consumable(index)
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

## A key or a click on the consumable socket at index: an accepted press emits
## consumable_selected, a refused one (recharging, none left) shakes the socket.
## Does nothing outside a fight or on an empty socket.
func _press_consumable(index: int) -> void:
	var socket: ConsumableSlot = _consumable_slots[index]
	var instance: CombatConsumableInstance = socket.get_consumable_instance()
	if not _is_active or instance == null or not is_instance_valid(_consumable_manager):
		return
	if _consumable_manager.can_use_consumable_instance(instance):
		consumable_selected.emit(instance)
	else:
		socket.refuse()

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

## Previews the inventory's hotbar in the sockets: each consumable in its hotbar
## slot's socket, the rest empty.
func _show_hotbar() -> void:
	var hotbar: Dictionary[int, ConsumableDefinitionData] = InventoryManager.get_inventory().equipped_consumables
	for index: int in _consumable_slots.size():
		_consumable_slots[index].show_preview(hotbar.get(index, null), index)

## Binds each socket to the consumable manager's instance for its hotbar slot,
## or shows it empty.
func _bind_consumables() -> void:
	for index: int in _consumable_slots.size():
		var instance: CombatConsumableInstance = null
		if is_instance_valid(_consumable_manager):
			instance = _consumable_manager.get_instance_at_slot(index)
		if instance != null:
			_consumable_slots[index].bind(instance, index)
		else:
			_consumable_slots[index].show_empty(index)

func _hide_tooltip() -> void:
	_hovered_slot = null
	_hovered_data = null
	_tooltip.hide_tooltip()

## Opens the tooltip for what the hovered slot or socket holds, over the cast
## tray while it shows.
func _show_tooltip() -> void:
	var tray_top: float = _cast_tray.get_global_rect().position.y
	if _hovered_data is AbilityData:
		_tooltip.show_for_ability(_hovered_data as AbilityData, _hovered_slot, _cast_tray.visible, tray_top)
	elif _hovered_data is ConsumableDefinitionData:
		_tooltip.show_for_consumable(_hovered_data as ConsumableDefinitionData, _hovered_slot, _cast_tray.visible, tray_top)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_slot_hovered(data: Resource, slot: Control) -> void:
	_hovered_slot = slot
	_hovered_data = data
	_show_tooltip()

func _on_slot_unhovered(slot: Control) -> void:
	if slot == _hovered_slot:
		_hide_tooltip()

## A cast starting or ending under an open tooltip moves it above or back
## below the tray, and a tray that grows (a long name) pushes it higher.
func _on_cast_tray_visibility_changed() -> void:
	if _hovered_slot != null and _tooltip.visible:
		_show_tooltip()

## The counts changed (a use, an award): in a fight each socket reads its count
## again; on the map the hotbar is previewed again. The techniques and an open
## tooltip are left as they are.
func _on_inventory_changed(_inventory: InventoryData) -> void:
	if _is_active:
		for socket: ConsumableSlot in _consumable_slots:
			socket.refresh_count()
	else:
		_show_hotbar()
