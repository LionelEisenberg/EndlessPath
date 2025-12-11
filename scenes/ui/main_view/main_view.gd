class_name MainView
extends Control
## Main View Manager.
##
## Handles switching between different main views (Zone, Adventure, Inventory, Cycling) using a State Machine pattern.

## Main Views
@onready var zone_view: Control = %ZoneView
@onready var adventure_view: Control = %AdventureView
@onready var inventory_view: Control = %InventoryView
@onready var cycling_view: Control = %CyclingView
@onready var grey_background: Panel = %GreyBackground

## State machine states
@onready var zone_view_state: MainViewState = %MainViewStateMachine/ZoneViewState
@onready var adventure_view_state: MainViewState = %MainViewStateMachine/AdventureViewState
@onready var inventory_view_state: MainViewState = %MainViewStateMachine/InventoryViewState
@onready var cycling_view_state: MainViewState = %MainViewStateMachine/CyclingViewState

## State stack
@onready var state_stack: Array[MainViewState] = []
var base_current_state: MainViewState = null

func _ready() -> void:
	zone_view_state.scene_root = self
	adventure_view_state.scene_root = self
	inventory_view_state.scene_root = self
	cycling_view_state.scene_root = self

	# Initialize view visibility based on initial state
	change_state(zone_view_state)
	
	# Connect to ActionManager
	if ActionManager:
		# Cycling
		ActionManager.start_cycling.connect(_stack_cycling.unbind(1))
		ActionManager.stop_cycling.connect(pop_state)
		
		# Adventure
		ActionManager.start_adventure.connect(_switch_to_adventure.unbind(1))
		ActionManager.stop_adventure.connect(change_state.bind(zone_view_state))

func _unhandled_input(event: InputEvent) -> void:
	var current_state: MainViewState = _get_current_state()
	if current_state:
		current_state.handle_input(event)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Switch to adventure view state.
func _switch_to_adventure() -> void:
	change_state(adventure_view_state)

## Push cycling view state onto the stack.
func _stack_cycling() -> void:
	push_state(cycling_view_state)

## Push a new state onto the stack.
func push_state(state: MainViewState) -> void:
	state_stack.append(state)
	state.enter()

## Pop the current state from the stack.
func pop_state() -> void:
	if state_stack.is_empty():
		return
	
	state_stack.pop_back().exit()

## Change the base state, clearing the stack.
func change_state(new_state: MainViewState) -> void:
	if base_current_state == new_state:
		return
	
	state_stack.clear()
	
	if base_current_state:
		base_current_state.exit()
	base_current_state = new_state
	base_current_state.enter()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _get_current_state() -> MainViewState:
	if not state_stack.is_empty():
		return state_stack.back()
	return base_current_state
