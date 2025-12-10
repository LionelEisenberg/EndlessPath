class_name AbilitiesPanel
extends Panel

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
# SIGNALS
#-----------------------------------------------------------------------------

# Only listened to by the combatant_info_panel
signal ability_selected(instance: CombatAbilityInstance)

func _ready() -> void:
	# Ensure casting state is hidden by default
	hide_casting_state()

## Registers an ability and creates a button for it.
func register_ability(instance: CombatAbilityInstance) -> void:
	var button = ability_button_scene.instantiate() as AbilityButton
	ability_container.add_child(button)
	button.setup(instance)
	
	# Connect button press to relay signal
	button.pressed.connect(func(): ability_selected.emit(instance))
	
	# Connect casting signals
	instance.cast_started.connect(_on_cast_started)
	instance.cast_updated.connect(_on_cast_updated)
	instance.cast_finished.connect(_on_cast_finished)

## Resets the panel by removing all buttons and cleaning up connections.
func reset() -> void:
	hide_casting_state()
	
	for child in ability_container.get_children():
		if child is AbilityButton and is_instance_valid(child.ability_instance):
			# Disconnect signals to prevent memory leaks or errors
			var instance = child.ability_instance
			if instance.cast_started.is_connected(_on_cast_started):
				instance.cast_started.disconnect(_on_cast_started)
			if instance.cast_updated.is_connected(_on_cast_updated):
				instance.cast_updated.disconnect(_on_cast_updated)
			if instance.cast_finished.is_connected(_on_cast_finished):
				instance.cast_finished.disconnect(_on_cast_finished)
				
		child.queue_free()

#-----------------------------------------------------------------------------
# CASTING UI HANDLERS
#-----------------------------------------------------------------------------

func _on_cast_started(instance: CombatAbilityInstance, duration: float) -> void:
	show_casting_state(instance, duration)

func _on_cast_updated(_instance: CombatAbilityInstance, time_left: float) -> void:
	update_cast_progress(time_left)

func _on_cast_finished(_instance: CombatAbilityInstance) -> void:
	hide_casting_state()

func show_casting_state(instance: CombatAbilityInstance, total_duration: float) -> void:
	ability_container.visible = false
	casting_indicator.visible = true
	
	ability_info_label.text = instance.ability_data.ability_name
	progress_bar.max_value = total_duration
	progress_bar.value = total_duration
	
	update_cast_progress(total_duration)

func update_cast_progress(time_left: float) -> void:
	progress_bar.value = time_left
	cast_timer_label.text = "%.1f / %.1fs" % [time_left, progress_bar.max_value]

func hide_casting_state() -> void:
	casting_indicator.visible = false
	ability_container.visible = true
