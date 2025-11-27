class_name EncounterInfoPanel
extends Panel

## EncounterInfoPanel
## Displays information about the current tile's encounter and provides choices.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal choice_selected(choice: EncounterChoice)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var title_label: Label = %TitleLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer

#-----------------------------------------------------------------------------
# STATE VARIABLES
#-----------------------------------------------------------------------------

var current_encounter: AdventureEncounter = null

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var encounter_choice_button_scene: PackedScene = preload("res://scenes/adventure/adventure_tilemap/encounter_choice_button.tscn")

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

func setup(encounter: AdventureEncounter, is_completed: bool) -> void:
	current_encounter = encounter
	
	title_label.text = encounter.encounter_name
	
	if is_completed:
		show_completed_state()
	else:
		description_label.text = encounter.description
		_generate_choice_buttons(encounter.choices)
		choices_container.visible = true

func show_completed_state() -> void:
	if current_encounter and current_encounter.text_description_completed != "":
		description_label.text = current_encounter.text_description_completed
	else:
		description_label.text = "Encounter completed."
		
	choices_container.visible = false

#-----------------------------------------------------------------------------
# PRIVATE METHODS
#-----------------------------------------------------------------------------

func _generate_choice_buttons(choices: Array[EncounterChoice]) -> void:
	# Clear existing buttons
	for child in choices_container.get_children():
		child.queue_free()
	
	# Create new buttons
	for choice in choices:
		var fill_color = Color.WHITE
		if choice is CombatChoice:
			fill_color = Color.DARK_RED
		var button = encounter_choice_button_scene.instantiate()
		button.setup(choice.label, null, fill_color)
		button.button_pressed.connect(_on_choice_button_pressed.bind(choice))
		choices_container.add_child(button)
		
func _on_choice_button_pressed(choice: EncounterChoice) -> void:
	choice_selected.emit(choice)
