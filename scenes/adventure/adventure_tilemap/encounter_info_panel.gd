class_name EncounterInfoPanel
extends PanelContainer

## EncounterInfoPanel
## Displays information about the current tile's encounter and provides choices.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## Duration of the modulate fade used by show_panel() / hide_panel().
## Short enough to feel responsive, long enough that the panel slides
## in rather than popping.
const FADE_DURATION: float = 0.25

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal choice_selected(choice: EncounterChoice)

#-----------------------------------------------------------------------------
# PRIVATE STATE
#-----------------------------------------------------------------------------

## In-flight fade tween, reused so rapid show/hide toggles cancel cleanly
## instead of stacking.
var _fade_tween: Tween

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

## Sets up the panel with the given encounter.
func setup(encounter: AdventureEncounter, is_completed: bool) -> void:
	current_encounter = encounter
	
	title_label.text = encounter.encounter_name
	
	if is_completed:
		show_completed_state()
	else:
		description_label.text = encounter.description
		_generate_choice_buttons(encounter.choices)
		choices_container.visible = true

## Fades the panel in by tweening modulate alpha to 1. If the panel
## is currently hidden (visible = false), snaps alpha to 0 first so
## the fade starts from transparent. If a hide fade is mid-flight,
## kills it so the two don't overlap — we continue upward from
## whatever the current alpha happens to be.
func show_panel() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if not visible:
		modulate.a = 0.0
		visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)

## Fades the panel out by tweening modulate alpha to 0, then hides
## it at the end so it stops consuming layout space. Kills any
## in-flight show fade first.
func hide_panel() -> void:
	if not visible:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_fade_tween.tween_callback(func() -> void: visible = false)

## Updates the UI to show the completed state.
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
		var fill_color: Color = Color.WHITE
		if choice is CombatChoice:
			fill_color = Color.DARK_RED

		var is_complete: bool = choice.is_completed()
		var is_available: bool = choice.evaluate_requirements()

		var label_text: String = choice.label
		if is_complete and choice.completed_label != "":
			label_text = choice.completed_label

		var disabled: bool = is_complete or not is_available

		var button = encounter_choice_button_scene.instantiate()
		button.setup(label_text, null, fill_color, disabled)
		button.button_pressed.connect(choice_selected.emit.bind(choice))
		choices_container.add_child(button)
