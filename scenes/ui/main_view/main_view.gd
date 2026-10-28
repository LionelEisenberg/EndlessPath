class_name MainView
extends Control
## Main View Manager.
##
## Handles switching between different main views (Zone, Adventure, Inventory, Cycling, Tribulation) using a State Machine pattern.
## Cycling and the Tribulation are the overlays with no backdrop: their boards sit
## in the map gap with the zone view still up around them. A state opens its board
## with open_board(spec) and closes it with close_board(spec, on_closed), where the
## BoardTransitionSpec says what the board needs of the zone view (see
## CyclingViewState and TribulationViewState). With a BoardTransition (the
## board_transition node, bound in _ready()), the board comes in as an animation
## and the map's input is off for as long as the board is up. Without one, as on
## the MainViews the view-state tests build, the open and the close are instant:
## the zone view's own furniture is turned over to the board at once and given
## back at once.

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
@onready var tribulation_view: TribulationView = %TribulationView

## The zone view's furniture the boards in the map gap work with. The cabinet takes
## the cycling board's pellets (it is handed to the CyclingView in _ready()); the
## chest, the dock and the map's SubViewport are turned over by open_board() when
## there is no transition, and the dock and the SubViewport by set_board_mode().
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
@onready var tribulation_view_state: MainViewState = %MainViewStateMachine/TribulationViewState

## State stack
@onready var state_stack: Array[MainViewState] = []
var base_current_state: MainViewState = null

## The overlay states that hide the HUD boards (log and Goals), and the
## visibility each board had before the first of them hid it.
var _hud_board_holders: Array[MainViewState] = []
var _hud_board_visibility: Dictionary[Control, bool] = {}

## The player that opens and closes the boards in the map gap as an animation, or
## null when there is none: the MainViews the view-state tests build never run
## _ready(), so they have none and their boards open and close at once.
var board_transition: BoardTransition = null

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
	tribulation_view_state.scene_root = self

	_hand_cabinet_to_cycling_view()
	board_transition = get_node_or_null("%BoardTransition") as BoardTransition
	_bind_board_transition()

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

## Opens the board `spec` describes (it must not be null). With a transition, the
## map's input goes off at once and the transition plays the board in; MainView
## turns nothing else over. Without one, the open is instant: the dock hides and the
## map takes no input (see set_board_mode()), the chest lists the techniques for a
## board that swaps it, the log and Goals hide, through spec.holder, for a board that
## moves them, and the board's view shows. Each piece is skipped when it is missing,
## as it is on the MainViews the view-state tests build.
func open_board(spec: BoardTransitionSpec) -> void:
	if board_transition != null:
		board_transition.open(spec)
		# After open(): opening this board snaps closed one that is up, whose
		# callback gives the map its input back.
		if zone_map_viewport != null:
			zone_map_viewport.gui_disable_input = true
		return
	set_board_mode(true)
	if spec.swaps_chest and zone_panel != null:
		zone_panel.set_techniques_mode(true)
	if spec.moves_hud_boards:
		hide_hud_boards(spec.holder)
	if spec.view != null:
		spec.view.visible = true

## Closes the board `spec` describes (it must not be null), then calls on_closed
## once. With a transition, the board plays out and the map takes input again when
## it has: on_closed is called after that. Without one, the close is instant and
## undoes open_board() in reverse.
func close_board(spec: BoardTransitionSpec, on_closed: Callable) -> void:
	if board_transition != null:
		board_transition.close(_on_board_closed.bind(on_closed))
		return
	if spec.view != null:
		spec.view.visible = false
	if spec.moves_hud_boards:
		release_hud_boards(spec.holder)
	if spec.swaps_chest and zone_panel != null:
		zone_panel.set_techniques_mode(false)
	set_board_mode(false)
	if on_closed.is_valid():
		on_closed.call()

## Returns true while a board opens or closes. Always false without a transition.
func is_board_moving() -> bool:
	return board_transition != null and board_transition.is_moving()

## Returns true while a board closes. Always false without a transition.
func is_board_closing() -> bool:
	return board_transition != null and board_transition.is_closing()

## Turns the zone view's furniture over to the cycling board, or gives it back.
## While cycling, the chest lists the techniques, and the dock and the map are
## turned off as for any board in the map gap (see set_board_mode()). The chest is
## skipped when it is missing, as it is on the MainViews the view-state tests build.
## CyclingViewState still switches the furniture this way; open_board() replaces it.
func set_cycling_mode(on: bool) -> void:
	if zone_panel != null:
		zone_panel.set_techniques_mode(on)
	set_board_mode(on)

## Turns the zone view's dock and map off for a board that stands in the map gap
## (the cycling board, the Tribulation board), or gives them back. The dock hides
## and the map's SubViewport takes no input: the SubViewportContainer pushes a
## press into it with push_input(), which a viewport with its input off drops, so
## a click on the map beside the board travels nowhere. Each piece is skipped when
## it is missing, as it is on the MainViews the view-state tests build.
func set_board_mode(on: bool) -> void:
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

## Hands the transition the pieces it moves: the dock, the chest, the HUD boards
## (the Goals board first, then the log: the order they step off the screen in),
## the zone map's camera and the cultivator the camera pushes in on. Does nothing
## without a transition, and binds no camera or cultivator without a zone map.
func _bind_board_transition() -> void:
	if board_transition == null:
		return
	var zone_map: ZoneTilemap = get_node_or_null("%ZoneTilemap") as ZoneTilemap
	var camera: Camera2D = zone_map.get_camera() if zone_map != null else null
	var cultivator: Node2D = zone_map.character_body if zone_map != null else null
	var hud_boards: Array[Control] = [goals_panel, log_window]
	board_transition.bind(dock, zone_panel, hud_boards, camera, cultivator)

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

#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

## A board's close has reached its end: the map takes input again, then whoever
## closed the board hears of it.
func _on_board_closed(on_closed: Callable) -> void:
	if zone_map_viewport != null:
		zone_map_viewport.gui_disable_input = false
	if on_closed.is_valid():
		on_closed.call()
