extends Control

## Main Views
@onready var zone_view: Control = %ZoneView
@onready var adventure_view: Control = %AdventureView
@onready var inventory_view: Control = %InventoryView
@onready var cycling_view: Control = %CyclingView
@onready var grey_background: Panel = %GreyBackground

## Buttons
@onready var inventory_button: TextureButton = %InventoryButton

enum State {
	ZONE_VIEW,
	ADVENTURE_VIEW,
	CYCLING_VIEW,
	INVENTORY_VIEW
}

var current_state: State = State.ZONE_VIEW

func _ready() -> void:
	# Initialize view visibility based on initial state
	_update_view_visibility()

	# Connect to inventory view signals
	inventory_view.open_inventory.connect(show_inventory_view)
	inventory_view.close_inventory.connect(show_zone_view)
	
	# Connect to ActionManager
	if ActionManager:
		# Cycling
		ActionManager.start_cycling.connect(show_and_initialize_action_popup)
		ActionManager.stop_cycling.connect(show_zone_view)
		
		# Adventure
		ActionManager.start_adventure.connect(show_adventure_view.unbind(1))
		ActionManager.stop_adventure.connect(show_zone_view)
	
	# Connect buttons
	inventory_button.pressed.connect(show_inventory_view)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Shows and initializes the action popup with the given data.
func show_and_initialize_action_popup(zone_action_data: ZoneActionData) -> void:
	match zone_action_data.action_type:
		ZoneActionData.ActionType.CYCLING:
			cycling_view.initialize_cycling_action_data(zone_action_data)
			_set_state(State.CYCLING_VIEW)
		_:
			# For other action types, keep showing zone view for now
			_set_state(State.ZONE_VIEW)

## Shows the inventory view.
func show_inventory_view() -> void:
	_set_state(State.INVENTORY_VIEW)

## Shows the zone view.
func show_zone_view() -> void:
	_set_state(State.ZONE_VIEW)

## Shows the adventure view.
func show_adventure_view() -> void:
	_set_state(State.ADVENTURE_VIEW)
	

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	_update_view_visibility()

func _update_view_visibility() -> void:
	match current_state:
		State.ZONE_VIEW:
			zone_view.visible = true
			adventure_view.visible = false
			grey_background.visible = false
			cycling_view.visible = false
			inventory_view.visible = false
		State.ADVENTURE_VIEW:
			zone_view.visible = false
			adventure_view.visible = true
			grey_background.visible = false
			cycling_view.visible = false
			inventory_view.visible = false
		State.CYCLING_VIEW:
			grey_background.visible = true
			cycling_view.visible = true
			inventory_view.visible = false
		State.INVENTORY_VIEW:
			grey_background.visible = true
			cycling_view.visible = false
			inventory_view.visible = true
