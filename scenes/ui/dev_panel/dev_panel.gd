class_name DevPanel
extends PanelContainer

## Floating draggable dev panel.
## Routes input widgets to existing manager APIs.
## Always-on-top (z_index set in main scene).

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _title_bar: PanelContainer = %TitleBar
@onready var _close_button: Button = %CloseButton

@onready var _madra_spin: SpinBox = %MadraSpin
@onready var _madra_apply: Button = %MadraApply
@onready var _gold_spin: SpinBox = %GoldSpin
@onready var _gold_apply: Button = %GoldApply

@onready var _xp_spin: SpinBox = %XpSpin
@onready var _xp_apply: Button = %XpApply
@onready var _points_spin: SpinBox = %PointsSpin
@onready var _points_apply: Button = %PointsApply

@onready var _condition_option: OptionButton = %ConditionOption
@onready var _condition_apply: Button = %ConditionApply
@onready var _unlock_cycling_button: Button = %UnlockCyclingButton

@onready var _force_win_button: Button = %ForceWinButton

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _adventure_view: Node = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_title_bar.gui_input.connect(_on_titlebar_input)

	_madra_apply.pressed.connect(_on_apply_madra)
	_gold_apply.pressed.connect(_on_apply_gold)
	_xp_apply.pressed.connect(_on_apply_xp)
	_points_apply.pressed.connect(_on_apply_points)
	_condition_apply.pressed.connect(_on_apply_condition)
	_unlock_cycling_button.pressed.connect(_on_unlock_all_cycling)
	_force_win_button.pressed.connect(_on_force_win)

	_populate_condition_dropdown()
	_force_win_button.visible = false

func _process(_delta: float) -> void:
	if not visible:
		return
	_force_win_button.visible = _get_is_in_combat()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Opens the panel (called from main_game after unlock).
func open() -> void:
	visible = true

#-----------------------------------------------------------------------------
# PRIVATE: dropdown population
#-----------------------------------------------------------------------------

func _populate_condition_dropdown() -> void:
	_condition_option.clear()
	if UnlockManager == null or UnlockManager.unlock_condition_list == null:
		return
	for c: UnlockConditionData in UnlockManager.unlock_condition_list.list:
		if c == null or c.condition_id.is_empty():
			continue
		_condition_option.add_item(c.condition_id)
		_condition_option.set_item_metadata(_condition_option.item_count - 1, c.condition_id)

#-----------------------------------------------------------------------------
# PRIVATE: drag behavior (mirrors LogWindow)
#-----------------------------------------------------------------------------

func _on_titlebar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging = true
			_drag_offset = event.global_position - global_position
		else:
			_is_dragging = false
	elif event is InputEventMouseMotion and _is_dragging:
		global_position = event.global_position - _drag_offset

#-----------------------------------------------------------------------------
# PRIVATE: action handlers
#-----------------------------------------------------------------------------

func _on_close_pressed() -> void:
	visible = false

func _on_apply_madra() -> void:
	var v: float = _madra_spin.value
	ResourceManager.set_madra(v)
	LogManager.log_message("[color=magenta][DEV][/color] Set Madra to %d" % int(v))

func _on_apply_gold() -> void:
	var v: float = _gold_spin.value
	ResourceManager.set_gold(v)
	LogManager.log_message("[color=magenta][DEV][/color] Set Gold to %d" % int(v))

func _on_apply_xp() -> void:
	var v: float = _xp_spin.value
	CultivationManager.add_core_density_xp(v)
	LogManager.log_message("[color=magenta][DEV][/color] Added %d Core Density XP" % int(v))

func _on_apply_points() -> void:
	var v: int = int(_points_spin.value)
	PathManager.add_points(v)
	LogManager.log_message("[color=magenta][DEV][/color] Granted %d Path Points" % v)

func _on_apply_condition() -> void:
	var idx: int = _condition_option.selected
	if idx < 0:
		return
	var id: String = _condition_option.get_item_metadata(idx)
	UnlockManager.force_unlock_condition(id)
	LogManager.log_message("[color=magenta][DEV][/color] Force-triggered condition '%s'" % id)

func _on_unlock_all_cycling() -> void:
	if CyclingManager == null or CyclingManager._technique_catalog == null:
		return
	var count: int = 0
	for t: CyclingTechniqueData in CyclingManager._technique_catalog.cycling_techniques:
		if t and not t.id.is_empty():
			CyclingManager.unlock_technique(t.id)
			count += 1
	LogManager.log_message("[color=magenta][DEV][/color] Unlocked all %d cycling techniques" % count)

func _on_force_win() -> void:
	var av: Node = _get_adventure_view()
	if av == null:
		return
	av.force_win_combat()
	LogManager.log_message("[color=magenta][DEV][/color] Force-won current combat")

#-----------------------------------------------------------------------------
# PRIVATE: adventure view lookup
#-----------------------------------------------------------------------------

func _get_adventure_view() -> Node:
	if _adventure_view == null or not is_instance_valid(_adventure_view):
		_adventure_view = get_tree().root.get_node_or_null("MainGame/MainView/AdventureView")
	return _adventure_view

func _get_is_in_combat() -> bool:
	var av: Node = _get_adventure_view()
	if av == null:
		return false
	return av.is_in_combat
