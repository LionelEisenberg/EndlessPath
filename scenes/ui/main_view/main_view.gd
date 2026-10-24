class_name MainView
extends Control
## Main View Manager.
##
## Handles switching between different main views (Zone, Adventure, Inventory, Cycling) using a State Machine pattern.
## Cycling is the one overlay with no backdrop: its board sits in the map gap
## with the zone view still up around it, so set_cycling_mode() turns the zone
## view's own furniture over to it (see CyclingViewState).

## Main Views
@onready var zone_view: Control = %ZoneView
@onready var adventure_view: Control = %AdventureView
@onready var inventory_view: Control = %InventoryView
@onready var cycling_view: Control = %CyclingView
@onready var adventure_end_card: AdventureEndCard = %AdventureEndCard
@onready var path_tree_view: PathTreeView = %PathTreeView
@onready var abilities_view: Control = %AbilitiesView
@onready var character_view: CharacterView = %CharacterView
@onready var merchant_view: MerchantView = %MerchantView

## The zone view's furniture the cycling board works with. The cabinet takes the
## board's pellets (it is handed to the CyclingView in _ready()); the chest, the
## dock and the map's SubViewport are turned over by set_cycling_mode().
@onready var cultivator_plate: CultivatorPlate = %CultivatorPlate
@onready var zone_panel: ZonePanel = %ZonePanel
@onready var dock: Control = %Dock
@onready var zone_map_viewport: SubViewport = %SubViewport

## View Components
@onready var grey_background: GreyBackground = %GreyBackground
@onready var log_window: Control = %LogWindow
## The Goals board, shared by the zone and adventure views; each view state
## places it.
@onready var goals_panel: Control = %GoalsPanel

## State machine states
@onready var zone_view_state: MainViewState = %MainViewStateMachine/ZoneViewState
@onready var adventure_view_state: MainViewState = %MainViewStateMachine/AdventureViewState
@onready var inventory_view_state: MainViewState = %MainViewStateMachine/InventoryViewState
@onready var cycling_view_state: MainViewState = %MainViewStateMachine/CyclingViewState
@onready var adventure_end_card_state: MainViewState = %MainViewStateMachine/AdventureEndCardState
@onready var path_tree_view_state: MainViewState = %MainViewStateMachine/PathTreeViewState
@onready var abilities_view_state: MainViewState = %MainViewStateMachine/AbilitiesViewState
@onready var character_view_state: MainViewState = %MainViewStateMachine/CharacterViewState
@onready var merchant_view_state: MainViewState = %MainViewStateMachine/MerchantViewState

## State stack
@onready var state_stack: Array[MainViewState] = []
var base_current_state: MainViewState = null

## The overlay states that hide the HUD boards (log and Goals), and the
## visibility each board had before the first of them hid it.
var _hud_board_holders: Array[MainViewState] = []
var _hud_board_visibility: Dictionary[Control, bool] = {}

func _ready() -> void:
	zone_view_state.scene_root = self
	adventure_view_state.scene_root = self
	inventory_view_state.scene_root = self
	cycling_view_state.scene_root = self
	adventure_end_card_state.scene_root = self
	path_tree_view_state.scene_root = self
	abilities_view_state.scene_root = self
	character_view_state.scene_root = self
	merchant_view_state.scene_root = self

	_hand_cabinet_to_cycling_view()

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

## Remove a state from wherever it sits in the stack, leaving the states above it open.
func remove_state(state: MainViewState) -> void:
	if not state_stack.has(state):
		return

	state_stack.erase(state)
	state.exit()

## Hides the log and the Goals board while `holder` covers the view. An
## overlay calls it on enter, and release_hud_boards() on exit.
func hide_hud_boards(holder: MainViewState) -> void:
	if _hud_board_holders.has(holder):
		return
	if _hud_board_holders.is_empty():
		for board: Control in _get_hud_boards():
			_hud_board_visibility[board] = board.visible
			board.visible = false
	_hud_board_holders.append(holder)

## Lets `holder` stop hiding the HUD boards. Once no overlay hides them, they
## get back the visibility they had before the first one did, whatever order
## the overlays closed in.
func release_hud_boards(holder: MainViewState) -> void:
	if not _hud_board_holders.has(holder):
		return
	_hud_board_holders.erase(holder)
	if not _hud_board_holders.is_empty():
		return
	for board: Control in _hud_board_visibility:
		if is_instance_valid(board):
			board.visible = _hud_board_visibility[board]
	_hud_board_visibility.clear()

## Turns the zone view's furniture over to the cycling board, or gives it back.
## While cycling, the chest lists the techniques, the dock hides and the map's
## SubViewport takes no input: the SubViewportContainer pushes a press into it
## with push_input(), which a viewport with its input off drops, so a click on
## the map beside the board travels nowhere. Each piece is skipped when it is
## missing, as it is on the MainViews the view-state tests build.
func set_cycling_mode(on: bool) -> void:
	if zone_panel != null:
		zone_panel.set_techniques_mode(on)
	if dock != null:
		dock.visible = not on
	if zone_map_viewport != null:
		zone_map_viewport.gui_disable_input = on

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

## The cycling board sends its Madra and XP pellets into the cultivator cabinet,
## so it is handed the cabinet. A cycling_view that is not a CyclingView (the
## view-state tests stand a plain Control in) is left alone.
func _hand_cabinet_to_cycling_view() -> void:
	if cycling_view is CyclingView:
		(cycling_view as CyclingView).cultivator_plate = cultivator_plate

## The HUD boards the overlays hide: the log and the Goals board.
func _get_hud_boards() -> Array[Control]:
	var boards: Array[Control] = []
	for board: Control in [log_window, goals_panel]:
		if board != null:
			boards.append(board)
	return boards

func _get_current_state() -> MainViewState:
	if not state_stack.is_empty():
		return state_stack.back()
	return base_current_state
