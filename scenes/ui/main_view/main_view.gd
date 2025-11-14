extends Control

## Main Views
@onready var main_view_container : Panel = %MainViewContainer
@onready var inventory_view : Control = %InventoryView
@onready var cycling_view : Control = %CyclingView
@onready var grey_background : Panel = %GreyBackground

## Buttons
@onready var inventory_button : TextureButton = %InventoryButton

enum State {
	ZONE_VIEW,
	CYCLING_VIEW,
	INVENTORY_VIEW
}

var current_state: State = State.ZONE_VIEW

func _ready():
	# Initialize view visibility based on initial state
	_update_view_visibility()

	# Connect to inventory view signals
	inventory_view.open_inventory.connect(show_inventory_view)
	inventory_view.close_inventory.connect(show_zone_view)
	
	# Connect to cycling_view_signals
	cycling_view.close_cycling_view.connect(show_zone_view.unbind(1))
	
	# Connect buttons
	inventory_button.pressed.connect(show_inventory_view)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

func show_and_initialize_action_popup(zone_action_data: ZoneActionData):
	match zone_action_data.action_type:
		ZoneActionData.ActionType.CYCLING:
			cycling_view.initialize_cycling_action_data(zone_action_data)
			_set_state(State.CYCLING_VIEW)
		_:
			# For other action types, keep showing zone view for now
			_set_state(State.ZONE_VIEW)

func show_inventory_view():
	_set_state(State.INVENTORY_VIEW)

func show_zone_view():
	_set_state(State.ZONE_VIEW)

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
