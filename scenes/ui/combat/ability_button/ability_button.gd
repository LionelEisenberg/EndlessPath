class_name AbilityButton
extends MarginContainer

## AbilityButton
## UI component representing a combat ability.
## Displays cooldown status and handles user interaction.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal pressed

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var ability_instance: CombatAbilityInstance

@onready var button: TextureButton = %Button
@onready var cooldown_progress_bar: TextureProgressBar = %CooldownProgressBar
@onready var cooldown_label: Label = %CooldownLabel

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if button:
		button.pressed.connect(_on_button_pressed)
	
	cooldown_label.visible = false
	cooldown_progress_bar.visible = false
	
	cooldown_label.text = ""
	cooldown_progress_bar.value = 0.0

## Sets up the button with the given ability instance.
func setup(instance: CombatAbilityInstance) -> void:
	ability_instance = instance
	
	# Set Visuals
	 #button.text = instance.ability_data.ability_name # TextureButton doesn't have text property directly usually, but maybe custom? 
	# Assuming we rely on icon or tooltip for now since it's a TextureButton.
	button.tooltip_text = instance.ability_data.ability_name
	button.texture_normal = instance.ability_data.icon
	button.texture_pressed = instance.ability_data.icon
	button.texture_disabled = instance.ability_data.icon
	button.texture_hover = instance.ability_data.icon
	button.texture_focused = instance.ability_data.icon
	
	# Connect Signals
	ability_instance.cooldown_started.connect(_on_cooldown_started)
	ability_instance.cooldown_updated.connect(_on_cooldown_updated)
	ability_instance.cooldown_ready.connect(_on_cooldown_ready)

	# Initial State
	button.disabled = not ability_instance.is_ready()

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_button_pressed() -> void:
	pressed.emit()

func _on_cooldown_started(_duration: float) -> void:
	button.disabled = true
	_show_cooldown()

func _on_cooldown_updated(time_left: float) -> void:
	_show_cooldown()
	cooldown_label.text = "%.1f (s)" % time_left
	cooldown_progress_bar.value = time_left / ability_instance.ability_data.base_cooldown

func _on_cooldown_ready() -> void:
	button.disabled = false
	_hide_cooldown()

func _show_cooldown() -> void:
	cooldown_label.visible = true
	cooldown_progress_bar.visible = true

func _hide_cooldown() -> void:
	cooldown_label.visible = false
	cooldown_progress_bar.visible = false
