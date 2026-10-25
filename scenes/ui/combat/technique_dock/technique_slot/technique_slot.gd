class_name TechniqueSlot
extends Control

## One technique slot in the technique dock (spec: The technique dock): the
## carved socket with the technique's icon, its key cap and the cost line
## under it. The dock puts each slot in one of three states:
## - EMPTY: the socket and the key cap; no icon, no cost.
## - PREVIEW (on the map): the icon, the cost and a tan key. Not usable.
## - ACTIVE (in a fight, bound to the player's CombatAbilityInstance): a cream
##   key and the cost in cream, tan while it cannot be paid (checked each frame
##   while the technique neither recharges nor casts), the cooldown sweep, a
##   steady brass frame while it casts and one brass flash when it is ready.
## The sweep is lacquer_cooldown_sweep.gdshader on the icon: while the
## technique recharges, the part still to recharge shows in the kit's dark
## locked veil, uncovered clockwise in SWEEP_STEPS whole steps, with the whole
## seconds left in the centre. The script only hands the shader its step,
## worked out against the running cooldown's own length (the timer's
## wait_time), so the 1.5 s every fight starts on sweeps as fully as a
## technique's own cooldown. Techniques start that cooldown before the dock
## binds them, so bind() reads the running timer.
## Hover shows the hover frame and emits hovered (the dock opens the tooltip);
## a left press on an ACTIVE slot emits pressed, and the dock decides. A refused
## press shakes the socket in the soft shake's steps (refuse()): the zone map's
## lock shake at half its travel (MapGlyph.SOFT_SHAKE_KEYFRAMES, 4 px at most),
## since a fight presses a slot again and again. As the mock's button shakes
## alone, the slot (what the pointer hovers), its key cap and its cost line stay
## put.
## The cost line (the resource's mini icon and the amount) is centred under the
## slot in a box 81 px wide, not 80: a BoxContainer floors a centre that falls
## on a half pixel, and the extra pixel makes it round up instead, as the mock's
## CSS does, so a one-digit cost sits where the mock puts it.
## The step and seconds rules are statics, so the tests and the slot ask the
## same code.

## Emitted on a left press while the slot is ACTIVE.
signal pressed
## Emitted when the pointer comes onto a slot that holds a technique.
signal hovered(ability_data: AbilityData)
## Emitted when the pointer leaves a slot that emitted hovered.
signal unhovered

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

enum SlotState { EMPTY, PREVIEW, ACTIVE }

## The sweep's whole steps from all veiled (0) to the plain icon.
const SWEEP_STEPS: int = 24
## The sweep shader's only uniform: the recharged steps / SWEEP_STEPS.
const SWEEP_PARAMETER: StringName = &"progress"
## The keys a slot shows when its action has no key in the input map.
const FALLBACK_KEY_LABELS: PackedStringArray = ["Q", "W", "E", "R"]
## The mini icon of each resource a technique can cost.
const MINI_HEALTH: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_health_ai.png")
const MINI_MADRA: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_madra_ai.png")
const MINI_STAMINA: Texture2D = preload("res://assets/ui/lacquer/lacquer_mini_stamina_ai.png")

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _body: Control = %Body
@onready var _icon: TextureRect = %Icon
@onready var _sweep: ShaderMaterial = _icon.material
@onready var _seconds_label: Label = %SecondsLabel
@onready var _hover_frame: LacquerFrameOverlay = %HoverFrame
@onready var _cast_frame: LacquerFrameOverlay = %CastFrame
@onready var _ready_flash: LacquerFrameOverlay = %ReadyFlash
@onready var _key_cap: Control = %KeyCap
@onready var _key_label: Label = %KeyLabel
@onready var _cost_line: Control = %CostLine
@onready var _cost_icon: TextureRect = %CostIcon
@onready var _cost_label: Label = %CostLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _state: SlotState = SlotState.EMPTY
var _slot_index: int = -1
var _ability_data: AbilityData = null
var _instance: CombatAbilityInstance = null
var _vitals_manager: VitalsManager = null
var _is_cooling: bool = false
var _is_casting: bool = false
## The sweep's step and the seconds shown in the centre ("" for none).
var _sweep_step: int = SWEEP_STEPS
var _seconds_text: String = ""
## Whether the cost shows in cream (true) or tan.
var _cost_affordable: bool = true
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
	_refresh()

## Runs while the slot is ACTIVE (the cost check) or shaking.
func _process(delta: float) -> void:
	if is_shaking():
		_step_shake(delta)
	if _state == SlotState.ACTIVE and _vitals_manager != null and not _is_cooling and not _is_casting:
		var affordable: bool = _ability_data.can_afford(_vitals_manager)
		if affordable != _cost_affordable:
			_set_cost_affordable(affordable)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Shows the slot empty: the socket and its key cap. Lets go of any instance.
func show_empty(slot_index: int) -> void:
	_unbind_instance()
	_state = SlotState.EMPTY
	_slot_index = slot_index
	_ability_data = null
	_refresh()

## Shows an equipped technique outside a fight: its icon, its cost and a tan
## key. Lets go of any instance.
func show_preview(data: AbilityData, slot_index: int) -> void:
	_unbind_instance()
	_state = SlotState.PREVIEW if data != null else SlotState.EMPTY
	_slot_index = slot_index
	_ability_data = data
	_refresh()

## Binds the slot to a fight's ability instance: its technique, a cream key and
## a cost checked against vitals_manager. A cooldown already running (every
## technique starts a fight on one) shows at once.
func bind(instance: CombatAbilityInstance, slot_index: int, vitals_manager: VitalsManager) -> void:
	_unbind_instance()
	_state = SlotState.ACTIVE
	_instance = instance
	_ability_data = instance.ability_data
	_slot_index = slot_index
	_vitals_manager = vitals_manager
	instance.cooldown_started.connect(_on_cooldown_started)
	instance.cooldown_updated.connect(_on_cooldown_updated)
	instance.cooldown_ready.connect(_on_cooldown_ready)
	instance.cast_started.connect(_on_cast_started)
	instance.cast_finished.connect(_on_cast_finished)
	instance.cast_cancelled.connect(_on_cast_cancelled)
	_is_casting = instance.is_casting
	if instance.cooldown_timer != null and not instance.cooldown_timer.is_stopped():
		_show_cooldown(instance.cooldown_timer.time_left)
	_refresh()

## Shakes the socket side to side in the soft shake's steps (the lock shake's
## rhythm at half its travel), to say a press was refused. A new shake restarts
## it.
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

## Returns the instance the slot is bound to, or null outside a fight.
func get_ability_instance() -> CombatAbilityInstance:
	return _instance

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

## Returns the mini icon of the resource a technique's cost line shows: its
## first cost in the order AbilityRow.format_cost() lists them (Health, Madra,
## Stamina), so a technique with two costs shows the first under its slot (its
## tooltip lists them all); null for a free technique.
static func cost_icon(data: AbilityData) -> Texture2D:
	if data.health_cost > 0.0:
		return MINI_HEALTH
	if data.madra_cost > 0.0:
		return MINI_MADRA
	if data.stamina_cost > 0.0:
		return MINI_STAMINA
	return null

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## The amount of the cost the cost line shows (see cost_icon()).
static func _shown_cost(data: AbilityData) -> float:
	if data.health_cost > 0.0:
		return data.health_cost
	if data.madra_cost > 0.0:
		return data.madra_cost
	return maxf(data.stamina_cost, 0.0)

## Puts the state on the nodes.
func _refresh() -> void:
	if not is_node_ready():
		return
	var has_technique: bool = _state != SlotState.EMPTY and _ability_data != null
	_icon.texture = _ability_data.icon if has_technique else null
	_icon.visible = has_technique
	_apply_sweep()
	var key_text: String = _key_text()
	_key_label.text = key_text
	_key_cap.visible = key_text != ""
	_key_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_CREAM if _state == SlotState.ACTIVE else ThemeConstants.LACQUER_TAN)
	var mini_icon: Texture2D = cost_icon(_ability_data) if has_technique else null
	_cost_icon.texture = mini_icon
	_cost_label.text = AbilityRow.format_number(_shown_cost(_ability_data)) if mini_icon != null else ""
	_cost_line.visible = mini_icon != null
	_set_cost_affordable(true)
	_cast_frame.visible = _state == SlotState.ACTIVE and _is_casting
	_hover_frame.visible = _pointer_over and has_technique
	if _state != SlotState.ACTIVE:
		_ready_flash.flash(0)
	_update_processing()

## Hands the shader the sweep's step and shows the seconds while recharging.
func _apply_sweep() -> void:
	if not is_node_ready():
		return
	_sweep.set_shader_parameter(SWEEP_PARAMETER, float(_sweep_step) / SWEEP_STEPS)
	_seconds_label.text = _seconds_text
	_seconds_label.visible = _state == SlotState.ACTIVE and _is_cooling and _seconds_text != ""

## The sweep for time_left of the bound instance's running cooldown.
func _show_cooldown(time_left: float) -> void:
	_is_cooling = true
	_sweep_step = sweep_step(time_left, _instance.cooldown_timer.wait_time)
	_seconds_text = seconds_text(time_left)
	_apply_sweep()

func _set_cost_affordable(affordable: bool) -> void:
	_cost_affordable = affordable
	_cost_label.add_theme_color_override(&"font_color", ThemeConstants.LACQUER_CREAM if affordable else ThemeConstants.LACQUER_TAN)

## Returns the key the input map binds to action, so a key cap follows a remap,
## or fallback when the action has no key. The dock's consumable sockets read
## their keys through it too.
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

## The slot's key, read from the input map so it follows a remap.
func _key_text() -> String:
	if _slot_index < 0:
		return ""
	var fallback: String = FALLBACK_KEY_LABELS[_slot_index] if _slot_index < FALLBACK_KEY_LABELS.size() else ""
	return key_label(StringName("ability_slot_%d" % (_slot_index + 1)), fallback)

## Lets go of the bound instance and forgets its cooldown and cast.
func _unbind_instance() -> void:
	if is_instance_valid(_instance):
		for connection: Array in [
			[_instance.cooldown_started, _on_cooldown_started],
			[_instance.cooldown_updated, _on_cooldown_updated],
			[_instance.cooldown_ready, _on_cooldown_ready],
			[_instance.cast_started, _on_cast_started],
			[_instance.cast_finished, _on_cast_finished],
			[_instance.cast_cancelled, _on_cast_cancelled],
		]:
			var sig: Signal = connection[0]
			if sig.is_connected(connection[1]):
				sig.disconnect(connection[1])
	_instance = null
	_vitals_manager = null
	_is_cooling = false
	_is_casting = false
	_sweep_step = SWEEP_STEPS
	_seconds_text = ""

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

## Processes only while there is something to do each frame.
func _update_processing() -> void:
	set_process(_state == SlotState.ACTIVE or is_shaking())

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
	if _state == SlotState.EMPTY or _ability_data == null:
		return
	_hover_frame.show()
	_hover_emitted = true
	hovered.emit(_ability_data)

func _on_mouse_exited() -> void:
	_pointer_over = false
	_hover_frame.hide()
	if _hover_emitted:
		_hover_emitted = false
		unhovered.emit()

func _on_cooldown_started(_duration: float) -> void:
	_show_cooldown(_instance.cooldown_timer.time_left)

func _on_cooldown_updated(time_left: float) -> void:
	_show_cooldown(time_left)

## Recharged: the plain icon, no seconds, and one brass flash.
func _on_cooldown_ready() -> void:
	_is_cooling = false
	_sweep_step = SWEEP_STEPS
	_seconds_text = ""
	_apply_sweep()
	_ready_flash.flash(1)

func _on_cast_started(_cast_instance: CombatAbilityInstance, _duration: float) -> void:
	_is_casting = true
	_cast_frame.show()

func _on_cast_finished(_cast_instance: CombatAbilityInstance) -> void:
	_is_casting = false
	_cast_frame.hide()

func _on_cast_cancelled(_cast_instance: CombatAbilityInstance) -> void:
	_is_casting = false
	_cast_frame.hide()
