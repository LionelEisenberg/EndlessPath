class_name ConsumableSlot
extends Control

## One consumable socket in the technique dock's top row (spec: Combat
## Consumables in the Lacquer Dock), over the technique slot whose key sits
## under its own on the keyboard: the technique slot's lipped socket at 48 px
## with the hotbar consumable's icon at 32, its key cap (1 to 4) and a count
## seal. The dock puts each socket in one of three states:
## - EMPTY: the socket and the key cap; no icon, no seal (no consumable on that
##   hotbar slot).
## - PREVIEW (on the map): the icon, the count and a tan key. Not usable.
## - ACTIVE (in a fight, bound to the player's CombatConsumableInstance): a
##   cream key, the cooldown sweep with its whole seconds, and one brass flash
##   when it is ready again.
## A socket whose consumable has none left keeps it: the icon all in the locked
## veil (the sweep at step 0, a palette state, never alpha) and the seal at 0.
## It shows no seconds and never flashes, since it cannot be used.
## The count is read from InventoryManager when the state changes and when the
## dock calls refresh_count() (on InventoryManager.inventory_changed). The seal
## is a 9-slice that grows leftward from its right edge to fit a long count, so
## no count is cut off.
## Hover shows the hover frame and emits hovered (the dock opens the tooltip);
## a left press on an ACTIVE socket emits pressed, and the dock decides. A
## refused press shakes the socket in the soft shake's steps (refuse()), as a
## technique slot's does, while the key cap and the seal stay put.

## Emitted on a left press while the socket is ACTIVE.
signal pressed
## Emitted when the pointer comes onto a socket that holds a consumable.
signal hovered(consumable_data: ConsumableDefinitionData)
## Emitted when the pointer leaves a socket that emitted hovered.
signal unhovered

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

enum SlotState { EMPTY, PREVIEW, ACTIVE }

## The count seal's narrowest width, the seal art's own 24 px.
const SEAL_MIN_WIDTH: float = 24.0
## The seal's room around its count: 4 px on each side.
const SEAL_PADDING: float = 8.0
## The seal's right edge, 4 px past the socket's (as on the cabinet's buff
## sockets); a wider seal grows leftward from it.
const SEAL_RIGHT: float = 52.0
## The keys a socket shows when its action has no key in the input map.
const FALLBACK_KEY_LABELS: PackedStringArray = ["1", "2", "3", "4"]
## The sweep shader's only uniform a script sets.
const SWEEP_PARAMETER: StringName = &"progress"

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _body: Control = %Body
@onready var _icon: TextureRect = %Icon
@onready var _sweep: ShaderMaterial = _icon.material
@onready var _seconds_label: Label = %SecondsLabel
@onready var _hover_frame: LacquerFrameOverlay = %HoverFrame
@onready var _ready_flash: LacquerFrameOverlay = %ReadyFlash
@onready var _key_cap: Control = %KeyCap
@onready var _key_label: Label = %KeyLabel
@onready var _count_seal: Control = %CountSeal
@onready var _count_label: Label = %CountLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _state: SlotState = SlotState.EMPTY
var _slot_index: int = -1
var _data: ConsumableDefinitionData = null
var _instance: CombatConsumableInstance = null
## How many the player holds, as last read.
var _count: int = 0
var _is_cooling: bool = false
var _time_left: float = 0.0
## The sweep's step shown, from 0 (all veiled) to TechniqueSlot.SWEEP_STEPS.
var _sweep_step: int = TechniqueSlot.SWEEP_STEPS
## Whether the pointer is over the socket, and whether that emitted hovered.
var _pointer_over: bool = false
var _hover_emitted: bool = false
## Seconds into the socket's shake, or -1 while it is not shaking.
var _shake_elapsed: float = -1.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	set_process(false)
	_refresh()

## Runs only while the socket shakes.
func _process(delta: float) -> void:
	if is_shaking():
		_step_shake(delta)

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
## key and its cooldown. A cooldown already running shows at once.
func bind(instance: CombatConsumableInstance, slot_index: int) -> void:
	_unbind_instance()
	_state = SlotState.ACTIVE
	_instance = instance
	_data = instance.consumable_data
	_slot_index = slot_index
	instance.cooldown_started.connect(_on_cooldown_started)
	instance.cooldown_updated.connect(_on_cooldown_updated)
	instance.cooldown_ready.connect(_on_cooldown_ready)
	if instance.cooldown_timer != null and not instance.cooldown_timer.is_stopped():
		_is_cooling = true
		_time_left = instance.cooldown_timer.time_left
	_refresh()

## Reads the count again (the dock calls it when the inventory changes).
func refresh_count() -> void:
	_refresh()

## Shakes the socket side to side in the soft shake's steps, to say a press was
## refused. A new shake restarts it.
func refuse() -> void:
	_shake_elapsed = 0.0
	_apply_shake_offset()
	set_process(true)

## Returns true while the socket is shaking.
func is_shaking() -> bool:
	return _shake_elapsed >= 0.0

## Returns the socket's state.
func get_state() -> SlotState:
	return _state

## Returns the instance the socket is bound to, or null outside a fight.
func get_consumable_instance() -> CombatConsumableInstance:
	return _instance

## Returns the consumable the socket shows, or null when it is empty.
func get_consumable_data() -> ConsumableDefinitionData:
	return _data

## Returns the count the seal shows.
func get_count() -> int:
	return _count

## Returns the sweep's step shown, from 0 (all veiled) to
## TechniqueSlot.SWEEP_STEPS (plain).
func get_sweep_step() -> int:
	return _sweep_step

## Returns the count seal's width for a count text_width px wide: the text and
## its padding, rounded up to even, and never under the seal's own 24 px.
static func seal_width(text_width: float) -> float:
	return maxf(SEAL_MIN_WIDTH, ceilf((text_width + SEAL_PADDING) / 2.0) * 2.0)

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _has_consumable() -> bool:
	return _state != SlotState.EMPTY and _data != null

## Puts the state on the nodes, reading the count again.
func _refresh() -> void:
	if not is_node_ready():
		return
	var has_consumable: bool = _has_consumable()
	_count = InventoryManager.get_consumable_count(_data) if has_consumable else 0
	_icon.texture = _data.icon if has_consumable else null
	_icon.visible = has_consumable
	_count_seal.visible = has_consumable
	if has_consumable:
		_count_label.text = str(_count)
		_fit_seal()
	var key_text: String = _key_text()
	_key_label.text = key_text
	_key_cap.visible = key_text != ""
	_key_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_CREAM if _state == SlotState.ACTIVE else ThemeConstants.LACQUER_TAN)
	_hover_frame.visible = _pointer_over and has_consumable
	if _state != SlotState.ACTIVE:
		_ready_flash.flash(0)
	_apply_sweep()

## Hands the shader the sweep's step and shows the seconds while recharging: all
## veiled with none left, the recharged steps while recharging, plain otherwise.
func _apply_sweep() -> void:
	if not is_node_ready():
		return
	var seconds: String = ""
	if _has_consumable() and _count <= 0:
		_sweep_step = 0
	elif _is_cooling and is_instance_valid(_instance):
		_sweep_step = TechniqueSlot.sweep_step(_time_left, _instance.cooldown_timer.wait_time)
		seconds = TechniqueSlot.seconds_text(_time_left)
	else:
		_sweep_step = TechniqueSlot.SWEEP_STEPS
	_sweep.set_shader_parameter(SWEEP_PARAMETER, float(_sweep_step) / TechniqueSlot.SWEEP_STEPS)
	_seconds_label.text = seconds
	_seconds_label.visible = _state == SlotState.ACTIVE and seconds != ""

## Widens the seal to its count, growing leftward from its right edge.
func _fit_seal() -> void:
	var width: float = seal_width(_count_label.get_minimum_size().x)
	_count_seal.position.x = SEAL_RIGHT - width
	_count_seal.size.x = width

## The socket's key, read from the input map so it follows a remap.
func _key_text() -> String:
	if _slot_index < 0:
		return ""
	var fallback: String = FALLBACK_KEY_LABELS[_slot_index] if _slot_index < FALLBACK_KEY_LABELS.size() else ""
	return TechniqueSlot.key_label(StringName("consumable_slot_%d" % (_slot_index + 1)), fallback)

## Lets go of the bound instance and forgets its cooldown.
func _unbind_instance() -> void:
	if is_instance_valid(_instance):
		for connection: Array in [
			[_instance.cooldown_started, _on_cooldown_started],
			[_instance.cooldown_updated, _on_cooldown_updated],
			[_instance.cooldown_ready, _on_cooldown_ready],
		]:
			var sig: Signal = connection[0]
			if sig.is_connected(connection[1]):
				sig.disconnect(connection[1])
	_instance = null
	_is_cooling = false
	_time_left = 0.0

func _step_shake(delta: float) -> void:
	_shake_elapsed += delta
	_apply_shake_offset()
	if _shake_elapsed >= MapGlyph.SHAKE_SECONDS:
		_shake_elapsed = -1.0
		_body.position.x = 0.0
		set_process(false)

## Puts the socket where the soft shake is, _shake_elapsed seconds into it.
func _apply_shake_offset() -> void:
	_body.position.x = MapGlyph.shake_offset_at(_shake_elapsed, MapGlyph.SOFT_SHAKE_KEYFRAMES)

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if _state == SlotState.ACTIVE:
		pressed.emit()

func _on_mouse_entered() -> void:
	_pointer_over = true
	if not _has_consumable():
		return
	_hover_frame.show()
	_hover_emitted = true
	hovered.emit(_data)

func _on_mouse_exited() -> void:
	_pointer_over = false
	_hover_frame.hide()
	if _hover_emitted:
		_hover_emitted = false
		unhovered.emit()

func _on_cooldown_started(_duration: float) -> void:
	_is_cooling = true
	_time_left = _instance.cooldown_timer.time_left
	_apply_sweep()

func _on_cooldown_updated(time_left: float) -> void:
	_time_left = time_left
	_apply_sweep()

## Recharged: the plain icon, no seconds, and one brass flash when some are left.
func _on_cooldown_ready() -> void:
	_is_cooling = false
	_time_left = 0.0
	_apply_sweep()
	if _count > 0:
		_ready_flash.flash(1)
