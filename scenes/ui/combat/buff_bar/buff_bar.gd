class_name BuffBar
extends HFlowContainer

## BuffBar
## Wrapping row of BuffIcons mirroring a CombatBuffManager, with a hover tooltip.

#-----------------------------------------------------------------------------
# SCENES & NODES
#-----------------------------------------------------------------------------

var buff_icon_scene: PackedScene = preload("res://scenes/ui/combat/buff_icon/buff_icon.tscn")

@onready var _tooltip: CombatBuffTooltip = %CombatBuffTooltip

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _buff_manager: CombatBuffManager
var _icons: Dictionary = {} # buff_id → BuffIcon

#-----------------------------------------------------------------------------
# PUBLIC METHODS
#-----------------------------------------------------------------------------

## Starts mirroring the given buff manager. Pass null to clear.
func bind(buff_manager: CombatBuffManager) -> void:
	unbind()
	_buff_manager = buff_manager
	if not _buff_manager:
		return

	_buff_manager.buff_applied.connect(_on_buff_applied)
	_buff_manager.buff_removed.connect(_on_buff_removed)
	_buff_manager.buff_refreshed.connect(_on_buff_refreshed)
	_buff_manager.buff_stacked.connect(_on_buff_stacked)
	_buff_manager.tree_exiting.connect(unbind)

	for buff: ActiveBuff in _buff_manager.active_buffs:
		_on_buff_applied(buff.buff_data.buff_id, buff.time_remaining)
		if buff.stack_count > 1:
			_on_buff_stacked(buff.buff_data.buff_id, buff.stack_count)

## Disconnects from the current buff manager and removes all icons.
func unbind() -> void:
	if _buff_manager and is_instance_valid(_buff_manager):
		for pair: Array in [
			[_buff_manager.buff_applied, _on_buff_applied],
			[_buff_manager.buff_removed, _on_buff_removed],
			[_buff_manager.buff_refreshed, _on_buff_refreshed],
			[_buff_manager.buff_stacked, _on_buff_stacked],
			[_buff_manager.tree_exiting, unbind],
		]:
			var sig: Signal = pair[0]
			if sig.is_connected(pair[1]):
				sig.disconnect(pair[1])
	_buff_manager = null

	for icon: BuffIcon in _icons.values():
		icon.queue_free()
	_icons.clear()
	if _tooltip:
		_tooltip.hide_tooltip()

#-----------------------------------------------------------------------------
# DURATION SYNC
#-----------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not _buff_manager or _icons.is_empty():
		return
	for buff_id: String in _icons:
		var buff: ActiveBuff = _buff_manager.get_active_buff(buff_id)
		if buff:
			_icons[buff_id].update_duration(buff.time_remaining)

#-----------------------------------------------------------------------------
# BUFF HANDLERS
#-----------------------------------------------------------------------------

func _on_buff_applied(buff_id: String, duration: float) -> void:
	if _icons.has(buff_id):
		_on_buff_refreshed(buff_id, duration)
		return
	var buff: ActiveBuff = _buff_manager.get_active_buff(buff_id)
	if not buff:
		return

	var icon: BuffIcon = buff_icon_scene.instantiate() as BuffIcon
	add_child(icon)
	icon.setup(buff.buff_data, duration, buff.stack_count)
	icon.hovered.connect(_on_icon_hovered.bind(buff_id))
	icon.unhovered.connect(_on_icon_unhovered)
	_icons[buff_id] = icon

func _on_buff_removed(buff_id: String) -> void:
	if _icons.has(buff_id):
		_icons[buff_id].queue_free()
		_icons.erase(buff_id)
		_tooltip.hide_tooltip()

func _on_buff_refreshed(buff_id: String, new_duration: float) -> void:
	if _icons.has(buff_id):
		var icon: BuffIcon = _icons[buff_id]
		icon.max_duration = new_duration
		icon.update_duration(new_duration)

func _on_buff_stacked(buff_id: String, stack_count: int) -> void:
	if _icons.has(buff_id):
		_icons[buff_id].update_stacks(stack_count)

#-----------------------------------------------------------------------------
# TOOLTIP
#-----------------------------------------------------------------------------

func _on_icon_hovered(_buff_data: BuffEffectData, buff_id: String) -> void:
	if not _buff_manager or not _icons.has(buff_id):
		return
	var buff: ActiveBuff = _buff_manager.get_active_buff(buff_id)
	if not buff:
		return
	_tooltip.show_for_buff(buff)
	var icon: BuffIcon = _icons[buff_id]
	(func() -> void: _tooltip.position_beside(icon)).call_deferred()

func _on_icon_unhovered() -> void:
	_tooltip.hide_tooltip()
