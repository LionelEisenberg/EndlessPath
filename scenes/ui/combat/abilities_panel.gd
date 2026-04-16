class_name AbilitiesPanel
extends PanelContainer

## AbilitiesPanel
## Manages ability buttons in combat, handles keybinding input,
## and hosts the ability tooltip.

#-----------------------------------------------------------------------------
# NODES
#-----------------------------------------------------------------------------

@onready var ability_container: HBoxContainer = %AbilitiesContainer
@onready var casting_indicator: VBoxContainer = %CastingIndicator
@onready var ability_info_label: Label = %AbilityInformation
@onready var ability_type_icon: TextureRect = %AbilityTypeIcon
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var cast_timer_label: Label = %CastTimer

#-----------------------------------------------------------------------------
# SCENES
#-----------------------------------------------------------------------------

var ability_button_scene: PackedScene = preload("res://scenes/ui/combat/ability_button/ability_button.tscn")

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _vitals_manager: VitalsManager
var _ability_buttons: Array[AbilityButton] = []
var _slot_counter: int = 0

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal ability_selected(instance: CombatAbilityInstance)

#-----------------------------------------------------------------------------
# INPUT ACTION NAMES
#-----------------------------------------------------------------------------

const SLOT_ACTIONS: PackedStringArray = [
	"ability_slot_1", "ability_slot_2", "ability_slot_3", "ability_slot_4"
]

func _ready() -> void:
	hide_casting_state()

## Sets the vitals manager for affordability checks on buttons.
func set_vitals_manager(vm: VitalsManager) -> void:
	_vitals_manager = vm

## Registers an ability and creates a button for it.
func register_ability(instance: CombatAbilityInstance) -> void:
	var button: AbilityButton = ability_button_scene.instantiate() as AbilityButton
	ability_container.add_child(button)
	button.setup(instance, _slot_counter, _vitals_manager)

	# Connect button signals
	button.pressed.connect(func() -> void: ability_selected.emit(instance))
	button.hovered.connect(_on_ability_hovered)
	button.unhovered.connect(_on_ability_unhovered)

	# Connect casting signals
	instance.cast_started.connect(_on_cast_started)
	instance.cast_updated.connect(_on_cast_updated)
	instance.cast_finished.connect(_on_cast_finished)

	_ability_buttons.append(button)
	_slot_counter += 1

## Resets the panel by removing all buttons and cleaning up connections.
func reset() -> void:
	hide_casting_state()
	_hide_tooltip()

	for child in ability_container.get_children():
		if child is AbilityButton and is_instance_valid(child.ability_instance):
			var instance: CombatAbilityInstance = child.ability_instance
			if instance.cast_started.is_connected(_on_cast_started):
				instance.cast_started.disconnect(_on_cast_started)
			if instance.cast_updated.is_connected(_on_cast_updated):
				instance.cast_updated.disconnect(_on_cast_updated)
			if instance.cast_finished.is_connected(_on_cast_finished):
				instance.cast_finished.disconnect(_on_cast_finished)

		child.queue_free()

	_ability_buttons.clear()
	_slot_counter = 0
	_vitals_manager = null

#-----------------------------------------------------------------------------
# KEYBINDING INPUT
#-----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	for i: int in range(mini(SLOT_ACTIONS.size(), _ability_buttons.size())):
		if event.is_action_pressed(SLOT_ACTIONS[i]):
			var btn: AbilityButton = _ability_buttons[i]
			if btn.ability_instance and not btn.button.disabled:
				ability_selected.emit(btn.ability_instance)
				_hide_tooltip()
			get_viewport().set_input_as_handled()
			return

#-----------------------------------------------------------------------------
# TOOLTIP
#-----------------------------------------------------------------------------

const CombatAbilityTooltipScene: PackedScene = preload("res://scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.tscn")
var _tooltip: CombatAbilityTooltip = null

func _setup_tooltip() -> void:
	_tooltip = CombatAbilityTooltipScene.instantiate()
	add_child(_tooltip)

func _on_ability_hovered(instance: CombatAbilityInstance) -> void:
	if not _tooltip:
		_setup_tooltip()

	_tooltip.show_for_ability(instance.ability_data)

	# Find the button that emitted this
	for btn: AbilityButton in _ability_buttons:
		if btn.ability_instance == instance:
			# Defer positioning to next frame so tooltip sizes itself first
			(func() -> void: _tooltip.position_above(btn)).call_deferred()
			break

func _on_ability_unhovered() -> void:
	_hide_tooltip()

func _hide_tooltip() -> void:
	if _tooltip:
		_tooltip.hide_tooltip()

#-----------------------------------------------------------------------------
# CASTING UI HANDLERS
#-----------------------------------------------------------------------------

func _on_cast_started(instance: CombatAbilityInstance, duration: float) -> void:
	show_casting_state(instance, duration)

func _on_cast_updated(_instance: CombatAbilityInstance, time_left: float) -> void:
	update_cast_progress(time_left)

func _on_cast_finished(_instance: CombatAbilityInstance) -> void:
	hide_casting_state()

## Shows the casting UI with ability name and progress bar.
func show_casting_state(instance: CombatAbilityInstance, total_duration: float) -> void:
	ability_container.visible = false
	casting_indicator.visible = true

	ability_info_label.text = instance.ability_data.ability_name
	progress_bar.max_value = total_duration
	progress_bar.value = total_duration

	update_cast_progress(total_duration)

## Updates the cast progress bar and timer label.
func update_cast_progress(time_left: float) -> void:
	progress_bar.value = time_left
	cast_timer_label.text = "%.1f / %.1fs" % [time_left, progress_bar.max_value]

## Hides the casting UI and shows ability buttons again.
func hide_casting_state() -> void:
	casting_indicator.visible = false
	ability_container.visible = true
