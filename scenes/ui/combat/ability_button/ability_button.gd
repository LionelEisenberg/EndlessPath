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

@onready var button: TextureButton = $Button

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready() -> void:
	if button:
		button.pressed.connect(_on_button_pressed)

func setup(instance: CombatAbilityInstance) -> void:
	ability_instance = instance
	
	# Set Visuals
	# button.text = instance.ability_data.ability_name # TextureButton doesn't have text property directly usually, but maybe custom? 
	# Assuming we rely on icon or tooltip for now since it's a TextureButton.
	button.tooltip_text = instance.ability_data.ability_name

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

func _on_cooldown_started(duration: float) -> void:
	button.disabled = true
	# TODO: Show cooldown overlay/text

func _on_cooldown_updated(time_left: float) -> void:
	Log.debug("Cooldown updated for %s: %s" % [ability_instance.ability_data.ability_name, time_left])

func _on_cooldown_ready() -> void:
	button.disabled = false
