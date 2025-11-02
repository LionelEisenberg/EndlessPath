extends Button

signal action_selected(action_data: ZoneActionData)

@export var action_data: ZoneActionData = null
@export var is_unlocked: bool = true
@export var is_completed: bool = false
@export var completion_count: int = 0

@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel
@onready var lock_indicator: Control = %LockIndicator
@onready var completed_indicator: Control = %CompletedIndicator

func _ready():
	if action_data:
		setup_action(action_data)
	
	pressed.connect(_on_button_pressed)

func setup_action(data: ZoneActionData) -> void:
	action_data = data
	
	if name_label:
		name_label.text = data.action_name
	
	if icon_texture and data.icon:
		icon_texture.texture = data.icon
	
	update_button_state()

func update_button_state() -> void:
	if not action_data:
		return
	
	# Check if action is unlocked (TODO: integrate with UnlockManager)
	# For now, use the is_unlocked property
	var unlocked = is_unlocked
	if unlocked and action_data.unlock_conditions.size() > 0:
		unlocked = action_data.evaluate_unlock_conditions()
	
	# Update disabled state
	disabled = not unlocked or (action_data.max_completions > 0 and completion_count >= action_data.max_completions)
	
	# Update visual indicators
	if lock_indicator:
		lock_indicator.visible = not unlocked
	
	if completed_indicator:
		completed_indicator.visible = action_data.max_completions > 0 and completion_count >= action_data.max_completions
	
	# Update text color based on state
	if disabled:
		modulate = Color(0.5, 0.5, 0.5, 1.0)  # Grayed out
	else:
		modulate = Color.WHITE

func _on_button_pressed() -> void:
	if action_data and not disabled:
		action_selected.emit(action_data)

func set_unlocked(value: bool) -> void:
	is_unlocked = value
	update_button_state()

func set_completed(value: bool) -> void:
	is_completed = value
	if value:
		completion_count += 1
	update_button_state()

