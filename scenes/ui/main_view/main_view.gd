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
@onready var adventure_end_card: AdventureEndCard = %AdventureEndCard
@onready var path_tree_view: PathTreeView = %PathTreeView
@onready var abilities_view: Control = %AbilitiesView

## View Components
@onready var grey_background: Panel = %GreyBackground

## State machine states
@onready var zone_view_state: MainViewState = %MainViewStateMachine/ZoneViewState
@onready var adventure_view_state: MainViewState = %MainViewStateMachine/AdventureViewState
@onready var inventory_view_state: MainViewState = %MainViewStateMachine/InventoryViewState
@onready var cycling_view_state: MainViewState = %MainViewStateMachine/CyclingViewState
@onready var adventure_end_card_state: MainViewState = %MainViewStateMachine/AdventureEndCardState
@onready var path_tree_view_state: MainViewState = %MainViewStateMachine/PathTreeViewState
@onready var abilities_view_state: MainViewState = %MainViewStateMachine/AbilitiesViewState

## State stack
@onready var state_stack: Array[MainViewState] = []
var base_current_state: MainViewState = null

func _ready() -> void:
	zone_view_state.scene_root = self
	adventure_view_state.scene_root = self
	inventory_view_state.scene_root = self
	cycling_view_state.scene_root = self
	adventure_end_card_state.scene_root = self
	path_tree_view_state.scene_root = self
	abilities_view_state.scene_root = self

	# Initialize view visibility based on initial state
	change_state(zone_view_state)
	
	# State transitions are handled by individual ViewState scripts
	# which connect to ActionManager signals in their own _ready()

func _unhandled_input(event: InputEvent) -> void:
	var current_state: MainViewState = _get_current_state()
	if current_state:
		current_state.handle_input(event)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

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
