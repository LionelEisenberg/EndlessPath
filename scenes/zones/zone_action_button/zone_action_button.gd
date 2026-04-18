extends MarginContainer
## Action card button for zone actions.
## Owns card styling, click routing, and the three slots (OverlaySlot / InlineSlot /
## FooterSlot). Type-specific visuals live in per-type presenter scenes plugged in
## via PRESENTER_SCENES, selected on _ready() by action_data.action_type.

const CARD_NORMAL: StyleBox = preload("res://assets/styleboxes/zones/action_card_normal.tres")
const CARD_HOVER: StyleBox = preload("res://assets/styleboxes/zones/action_card_hover.tres")
const CARD_SELECTED: StyleBox = preload("res://assets/styleboxes/zones/action_card_selected.tres")
const DIMMED_MODULATE: Color = Color(0.55, 0.55, 0.55, 1.0)
const NORMAL_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)

## Maps active ActionTypes to their category color. Unmapped types fall back to
## DEFAULT_CATEGORY_COLOR.
const CATEGORY_COLORS: Dictionary = {
	ZoneActionData.ActionType.FORAGE: Color(0.42, 0.67, 0.37),
	ZoneActionData.ActionType.CYCLING: Color(0.37, 0.66, 0.62),
	ZoneActionData.ActionType.ADVENTURE: Color(0.61, 0.25, 0.25),
	ZoneActionData.ActionType.NPC_DIALOGUE: Color(0.83, 0.66, 0.29),
}
const DEFAULT_CATEGORY_COLOR: Color = Color(0.5, 0.5, 0.5)

## Maps ActionType to presenter scene. Types not listed here fall back to DEFAULT_PRESENTER_SCENE.
const DEFAULT_PRESENTER_SCENE: PackedScene = preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn")
const PRESENTER_SCENES: Dictionary = {
	ZoneActionData.ActionType.FORAGE: preload("res://scenes/zones/zone_action_button/presenters/foraging_presenter.tscn"),
	ZoneActionData.ActionType.CYCLING: preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn"),
	ZoneActionData.ActionType.NPC_DIALOGUE: preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn"),
}

@export var action_data: ZoneActionData
@export var is_current_action: bool = false:
	set(value):
		is_current_action = value
		if is_instance_valid(_action_card):
			_update_card_style()
		if _presenter:
			_presenter.set_is_current(is_current_action)

@onready var _action_card: PanelContainer = %ActionCard
@onready var _action_name_label: Label = %ActionNameLabel
@onready var _action_desc_label: RichTextLabel = %ActionDescLabel
@onready var _overlay_slot: Control = %OverlaySlot
@onready var _inline_slot: Control = %InlineSlot
@onready var _footer_slot: Control = %FooterSlot

var _presenter: ZoneActionPresenter = null
var _cached_selected_style: StyleBoxFlat = null
var _zone_resource_panel: ZoneResourcePanel = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	ActionManager.current_action_changed.connect(_on_current_action_changed)
	_action_card.mouse_entered.connect(_on_mouse_entered)
	_action_card.mouse_exited.connect(_on_mouse_exited)
	_action_card.gui_input.connect(_on_card_input)

	_zone_resource_panel = get_tree().current_scene.find_child("ZoneResourcePanel", true, false) as ZoneResourcePanel

	if action_data:
		_setup_labels()
		_spawn_presenter()

	if ActionManager.get_current_action() == action_data:
		is_current_action = true

func _exit_tree() -> void:
	if ActionManager.current_action_changed.is_connected(_on_current_action_changed):
		ActionManager.current_action_changed.disconnect(_on_current_action_changed)
	if _presenter:
		_presenter.teardown()

## Sets up the card with action data.
func setup_action(data: ZoneActionData) -> void:
	action_data = data
	if is_instance_valid(_action_name_label):
		_setup_labels()
	if is_instance_valid(_overlay_slot):
		_spawn_presenter()

#-----------------------------------------------------------------------------
# PUBLIC API (called by presenters)
#-----------------------------------------------------------------------------

## Returns the color bucket for this action's type. Presenters use it for tinting.
func get_category_color() -> Color:
	if action_data == null:
		return DEFAULT_CATEGORY_COLOR
	return CATEGORY_COLORS.get(action_data.action_type, DEFAULT_CATEGORY_COLOR)

## Returns the global position of the Madra orb on the zone resource panel,
## or Vector2.ZERO if the panel couldn't be located.
func get_madra_target_global_position() -> Vector2:
	if _zone_resource_panel:
		return _zone_resource_panel.get_madra_orb_global_position()
	return Vector2.ZERO

## Dim the name+description labels (used by AdventurePresenter when unaffordable).
func set_text_dimmed(dimmed: bool) -> void:
	var modulate_color: Color = DIMMED_MODULATE if dimmed else NORMAL_MODULATE
	if is_instance_valid(_action_name_label):
		_action_name_label.modulate = modulate_color
	if is_instance_valid(_action_desc_label):
		_action_desc_label.modulate = modulate_color

## The card's global rect, used by presenters that need spawn positions.
func get_action_card() -> PanelContainer:
	return _action_card

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _spawn_presenter() -> void:
	if _presenter:
		_presenter.teardown()
		_presenter.queue_free()
		_presenter = null

	var scene: PackedScene = PRESENTER_SCENES.get(action_data.action_type, DEFAULT_PRESENTER_SCENE) as PackedScene
	if scene == null:
		Log.error("ZoneActionButton: no presenter scene for action_type %s" % action_data.action_type)
		return
	_presenter = scene.instantiate() as ZoneActionPresenter
	add_child(_presenter)
	_presenter.setup(action_data, self, _overlay_slot, _inline_slot, _footer_slot)

func _setup_labels() -> void:
	_action_name_label.text = action_data.action_name
	if action_data.description != "":
		_action_desc_label.text = action_data.description
		_action_desc_label.visible = true
	else:
		_action_desc_label.text = ""
		_action_desc_label.visible = false

func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_current_action:
			return
		if _presenter and not _presenter.can_activate():
			_presenter.on_activation_rejected()
			return
		ActionManager.select_action(action_data)

func _on_mouse_entered() -> void:
	var can_hover: bool = _presenter == null or _presenter.can_activate()
	if not is_current_action and can_hover:
		_action_card.add_theme_stylebox_override("panel", CARD_HOVER)

func _on_mouse_exited() -> void:
	_update_card_style()

func _update_card_style() -> void:
	if is_current_action:
		if _cached_selected_style == null:
			_cached_selected_style = CARD_SELECTED.duplicate() as StyleBoxFlat
		var cat_color: Color = get_category_color()
		_cached_selected_style.border_color = Color(cat_color.r, cat_color.g, cat_color.b, 0.4)
		_action_card.add_theme_stylebox_override("panel", _cached_selected_style)
	else:
		_action_card.add_theme_stylebox_override("panel", CARD_NORMAL)

func _on_current_action_changed(_new_action: ZoneActionData) -> void:
	is_current_action = ActionManager.get_current_action() == action_data
