class_name DockSlot
extends Control

## What the technique dock's two kinds of slot share: TechniqueSlot, a
## technique (80 px, Q to R), and ConsumableSlot, a hotbar consumable (48 px,
## 1 to 4; spec 2026-10-25-combat-consumables-lacquer-design.md). Both scenes
## have the same parts under the same unique names: the socket (Body, which
## shakes, holding the Icon, its SecondsLabel and the HoverFrame and ReadyFlash
## overlays) and a KeyCap with its KeyLabel outside it.
## A slot is EMPTY, PREVIEW (on the map) or ACTIVE (bound to a fight's
## instance), and this script gives it:
## - the key cap, read from the input map (key_label()) so it follows a remap:
##   cream while ACTIVE, tan otherwise;
## - the cooldown sweep, lacquer_cooldown_sweep.gdshader on the icon: while the
##   bound instance recharges, the part still to recharge shows in the kit's
##   dark locked veil, uncovered clockwise in SWEEP_STEPS whole steps worked out
##   against the running cooldown's own length (the timer's wait_time), with the
##   whole seconds left in the centre; the whole icon veiled while the slot is
##   spent (_is_spent()); one brass flash when the cooldown ends, unless spent;
## - hover: the hover frame, and hovered and unhovered for the dock's tooltip;
## - a left press while ACTIVE emits pressed, and the dock decides;
## - refuse(): a refused press shakes the socket in the soft shake's steps
##   (MapGlyph.SOFT_SHAKE_KEYFRAMES, the zone map's lock shake at half its
##   travel), while the key cap and anything else outside Body stay put.
## A subclass follows its instance's cooldown with _bind_cooldown(), and says
## what it holds (_hover_data()), which action its key is (_key_action(), with
## a _fallback_key()), whether it is spent (_is_spent()) and whether it needs to
## process every frame (_needs_process()). The step and seconds rules are
## statics, so the tests and the slots ask the same code.

## Emitted on a left press while the slot is ACTIVE.
signal pressed
## Emitted when the pointer comes onto a slot that holds something: what it
## holds (an AbilityData or a ConsumableDefinitionData).
signal hovered(data: Resource)
## Emitted when the pointer leaves a slot that emitted hovered.
signal unhovered

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

enum SlotState { EMPTY, PREVIEW, ACTIVE }

## The sweep's whole steps from all veiled (0) to the plain icon.
const SWEEP_STEPS: int = 24
## The sweep shader's only uniform a script sets: the recharged steps / SWEEP_STEPS.
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

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _state: SlotState = SlotState.EMPTY
var _slot_index: int = -1
## The cooldown followed: its timer and its three signals, or none.
var _cooldown_timer: Timer = null
var _cooldown_signals: Array[Signal] = []
var _is_cooling: bool = false
var _time_left: float = 0.0
## The sweep's step shown, from 0 (all veiled) to SWEEP_STEPS (plain).
var _sweep_step: int = SWEEP_STEPS
## Whether the pointer is over the slot, and whether that emitted hovered.
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

func _process(delta: float) -> void:
	if is_shaking():
		_step_shake(delta)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shakes the socket side to side in the soft shake's steps, to say a press was
## refused. A new shake restarts it.
func refuse() -> void:
	_shake_elapsed = 0.0
	_apply_shake_offset()
	_update_processing()

## Returns true while the socket is shaking.
func is_shaking() -> bool:
	return _shake_elapsed >= 0.0

## Returns the slot's state.
func get_state() -> SlotState:
	return _state

## Returns the sweep's step shown, from 0 (all veiled) to SWEEP_STEPS (plain).
func get_sweep_step() -> int:
	return _sweep_step

## Returns how many of the sweep's steps are recharged with time_left of a
## cooldown of duration seconds: whole steps only (a hair under one, from float
## rounding, still counts), SWEEP_STEPS once nothing is left or for a cooldown
## of no length.
static func sweep_step(time_left: float, duration: float) -> int:
	if time_left <= 0.0 or duration <= 0.0:
		return SWEEP_STEPS
	return clampi(floori((1.0 - time_left / duration) * SWEEP_STEPS + 1e-6), 0, SWEEP_STEPS)

## Returns the whole seconds left, rounded up ("3" for 2.1 s), or "" once none
## are left.
static func seconds_text(time_left: float) -> String:
	if time_left <= 0.0:
		return ""
	return str(ceili(time_left))

## Returns the key the input map binds to action, so a key cap follows a remap,
## or fallback when the action has no key.
static func key_label(action: StringName, fallback: String) -> String:
	if InputMap.has_action(action):
		for event: InputEvent in InputMap.action_get_events(action):
			var key_event := event as InputEventKey
			if key_event == null:
				continue
			# Slot actions are bound by physical key; name that key directly rather than
			# asking the DisplayServer for a layout (unsupported on headless servers).
			var keycode: Key = key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
			var label: String = OS.get_keycode_string(keycode)
			if not label.is_empty():
				return label
	return fallback

#-----------------------------------------------------------------------------
# FOR SUBCLASSES
#-----------------------------------------------------------------------------

## What the slot holds, for the tooltip, or null when it holds nothing.
func _hover_data() -> Resource:
	return null

## The input action of the slot at index (0 to 3).
func _key_action(_index: int) -> StringName:
	return &""

## The key shown for the slot at index when its action has none.
func _fallback_key(_index: int) -> String:
	return ""

## True when the slot's icon shows all veiled, whatever its cooldown.
func _is_spent() -> bool:
	return false

## True when the slot has per-frame work beyond a shake.
func _needs_process() -> bool:
	return false

## Follows a fight instance's cooldown: its three signals and its timer. A
## cooldown already running shows at the next refresh.
func _bind_cooldown(started: Signal, updated: Signal, ready: Signal, timer: Timer) -> void:
	_cooldown_timer = timer
	_cooldown_signals = [started, updated, ready]
	started.connect(_on_cooldown_started)
	updated.connect(_on_cooldown_updated)
	ready.connect(_on_cooldown_ready)
	if timer != null and not timer.is_stopped():
		_is_cooling = true
		_time_left = timer.time_left

## Lets go of the cooldown followed and forgets it.
func _unbind_cooldown() -> void:
	var handlers: Array[Callable] = [_on_cooldown_started, _on_cooldown_updated, _on_cooldown_ready]
	for index: int in _cooldown_signals.size():
		var sig: Signal = _cooldown_signals[index]
		if is_instance_valid(sig.get_object()) and sig.is_connected(handlers[index]):
			sig.disconnect(handlers[index])
	_cooldown_signals.clear()
	_cooldown_timer = null
	_is_cooling = false
	_time_left = 0.0
	_sweep_step = SWEEP_STEPS

## Puts the shared parts of the state on the nodes: the key, the hover frame,
## the sweep, no flash outside a fight, and the processing.
func _refresh_shared() -> void:
	var key_text: String = key_label(_key_action(_slot_index), _fallback_key(_slot_index)) if _slot_index >= 0 else ""
	_key_label.text = key_text
	_key_cap.visible = key_text != ""
	_key_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_CREAM if _state == SlotState.ACTIVE else ThemeConstants.LACQUER_TAN)
	_hover_frame.visible = _pointer_over and _hover_data() != null
	if _state != SlotState.ACTIVE:
		_ready_flash.flash(0)
	_apply_sweep()
	_update_processing()

## Hands the shader the sweep's step and shows the seconds: all veiled while
## the slot is spent, the recharged steps while its cooldown runs, the plain
## icon otherwise.
func _apply_sweep() -> void:
	if not is_node_ready():
		return
	var seconds: String = ""
	if _is_spent():
		_sweep_step = 0
	elif _is_cooling and is_instance_valid(_cooldown_timer):
		_sweep_step = sweep_step(_time_left, _cooldown_timer.wait_time)
		seconds = seconds_text(_time_left)
	else:
		_sweep_step = SWEEP_STEPS
	_sweep.set_shader_parameter(SWEEP_PARAMETER, float(_sweep_step) / SWEEP_STEPS)
	_seconds_label.text = seconds
	_seconds_label.visible = _state == SlotState.ACTIVE and seconds != ""

## Processes only while there is something to do each frame.
func _update_processing() -> void:
	set_process(is_shaking() or _needs_process())

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _step_shake(delta: float) -> void:
	_shake_elapsed += delta
	_apply_shake_offset()
	if _shake_elapsed >= MapGlyph.SHAKE_SECONDS:
		_shake_elapsed = -1.0
		_body.position.x = 0.0
		_update_processing()

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
	var data: Resource = _hover_data()
	if data == null:
		return
	_hover_frame.show()
	_hover_emitted = true
	hovered.emit(data)

func _on_mouse_exited() -> void:
	_pointer_over = false
	_hover_frame.hide()
	if _hover_emitted:
		_hover_emitted = false
		unhovered.emit()

func _on_cooldown_started(_duration: float) -> void:
	_is_cooling = true
	_time_left = _cooldown_timer.time_left if is_instance_valid(_cooldown_timer) else 0.0
	_apply_sweep()

func _on_cooldown_updated(time_left: float) -> void:
	_is_cooling = true
	_time_left = time_left
	_apply_sweep()

## Recharged: the plain icon, no seconds, and one brass flash unless spent.
func _on_cooldown_ready() -> void:
	_is_cooling = false
	_time_left = 0.0
	_apply_sweep()
	if not _is_spent():
		_ready_flash.flash(1)
