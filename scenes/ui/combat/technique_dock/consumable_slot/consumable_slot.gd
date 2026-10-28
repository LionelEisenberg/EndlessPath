class_name ConsumableSlot
extends DockSlot

## One consumable socket in the technique dock's top row (spec: Combat
## Consumables in the Lacquer Dock), over the technique slot whose key sits
## under its own on the keyboard: the kit's 48 px glyph socket with the hotbar
## consumable's icon at 32, its key cap (1 to 4) at the top left and a count
## seal (LacquerCountSeal) off its bottom right corner, which widens leftward to
## fit a long count. The dock puts each socket in one of three states:
## - EMPTY: the socket and the key cap; no icon, no seal (no consumable on that
##   hotbar slot).
## - PREVIEW (on the map): the icon, the count and a tan key. Not usable.
## - ACTIVE (in a fight, bound to the player's CombatConsumableInstance): a
##   cream key and the cooldown sweep, its seconds in LabelLacquerCooldown at
##   15 px, sized to the 32 px icon.
## A socket whose consumable has none left keeps it: the icon all in the locked
## veil (a palette state, never alpha) and the seal at 0, with no seconds and no
## ready flash, since it cannot be used. The count is read from InventoryManager
## whenever the state changes, and the dock calls refresh_count() when the
## inventory changes. The key cap, the sweep, hover, the press and the refusal
## shake are DockSlot's; the seal, outside the socket, stays put in a shake.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The keys a socket shows when its action has no key in the input map.
const FALLBACK_KEY_LABELS: PackedStringArray = ["1", "2", "3", "4"]

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _count_seal: LacquerCountSeal = %CountSeal

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _data: ConsumableDefinitionData = null
var _instance: CombatConsumableInstance = null
## How many the player holds, as last read.
var _count: int = 0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	super()
	_refresh()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the socket empty: the socket and its key cap. Lets go of any instance.
func show_empty(slot_index: int) -> void:
	_unbind_instance()
	_state = SlotState.EMPTY
	_slot_index = slot_index
	_data = null
	_refresh()

## Shows a hotbar consumable outside a fight: its icon, its count and a tan
## key. Lets go of any instance.
func show_preview(data: ConsumableDefinitionData, slot_index: int) -> void:
	_unbind_instance()
	_state = SlotState.PREVIEW if data != null else SlotState.EMPTY
	_slot_index = slot_index
	_data = data
	_refresh()

## Binds the socket to a fight's consumable instance: its consumable, a cream
## key and its cooldown.
func bind(instance: CombatConsumableInstance, slot_index: int) -> void:
	_unbind_instance()
	_state = SlotState.ACTIVE
	_instance = instance
	_data = instance.consumable_data
	_slot_index = slot_index
	_bind_cooldown(instance.cooldown_started, instance.cooldown_updated, instance.cooldown_ready, instance.cooldown_timer)
	_refresh()

## Reads the count again (the dock calls it when the inventory changes).
func refresh_count() -> void:
	_refresh()

## Returns the instance the socket is bound to, or null outside a fight.
func get_consumable_instance() -> CombatConsumableInstance:
	return _instance

#-----------------------------------------------------------------------------
# DOCK SLOT
#-----------------------------------------------------------------------------

func _hover_data() -> Resource:
	return _data if _state != SlotState.EMPTY else null

func _key_action(index: int) -> StringName:
	return StringName("consumable_slot_%d" % (index + 1))

func _fallback_key(index: int) -> String:
	return FALLBACK_KEY_LABELS[index] if index < FALLBACK_KEY_LABELS.size() else ""

## A consumable with none left is spent: all veiled, whatever its cooldown.
func _is_spent() -> bool:
	return _hover_data() != null and _count <= 0

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## Puts the state on the nodes, reading the count again.
func _refresh() -> void:
	if not is_node_ready():
		return
	var has_consumable: bool = _hover_data() != null
	_count = InventoryManager.get_consumable_count(_data) if has_consumable else 0
	_icon.texture = _data.icon if has_consumable else null
	_icon.visible = has_consumable
	_count_seal.visible = has_consumable
	if has_consumable:
		_count_seal.show_count(_count)
	_refresh_shared()

## Lets go of the bound instance and forgets its cooldown.
func _unbind_instance() -> void:
	_unbind_cooldown()
	_instance = null
