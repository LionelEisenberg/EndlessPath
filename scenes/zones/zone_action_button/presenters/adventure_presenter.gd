class_name AdventurePresenter
extends ZoneActionPresenter
## Presenter for ADVENTURE actions. Owns the Madra badge (current / threshold or
## current / capacity) and the shake-reject animation. Gates activation on
## ResourceManager.can_start_adventure().

@onready var _madra_badge_container: HBoxContainer = %MadraBadgeContainer
@onready var _madra_badge: RichTextLabel = %MadraBadge

var _is_affordable: bool = true

func setup(data: ZoneActionData, owner_button: Control, _overlay_slot: Control, inline_slot: Control, _footer_slot: Control) -> void:
	action_data = data
	button = owner_button
	_madra_badge_container.reparent(inline_slot)
	_madra_badge_container.visible = true
	ResourceManager.madra_changed.connect(_on_madra_changed)
	_update_state()

func teardown() -> void:
	if ResourceManager.madra_changed.is_connected(_on_madra_changed):
		ResourceManager.madra_changed.disconnect(_on_madra_changed)

func can_activate() -> bool:
	return _is_affordable

func on_activation_rejected() -> void:
	_shake_reject()
	if LogManager:
		var threshold: float = ResourceManager.get_adventure_madra_threshold()
		var current: float = ResourceManager.get_madra()
		LogManager.log_message("[color=red]Not enough Madra! Need %.0f, have %.0f[/color]" % [threshold, current])

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _update_state() -> void:
	_is_affordable = ResourceManager.can_start_adventure()
	_update_madra_badge()
	button.set_text_dimmed(not _is_affordable)

func _update_madra_badge() -> void:
	var threshold: float = ResourceManager.get_adventure_madra_threshold()
	var current: float = ResourceManager.get_madra()
	var capacity: float = ResourceManager.get_adventure_madra_capacity()
	if current >= threshold:
		_madra_badge.text = "[right][font_size=20][color=#D4A84A]%.0f[/color][color=#7a6a52] / %.0f[/color][/font_size][/right]" % [current, capacity]
	else:
		_madra_badge.text = "[right][font_size=20][color=#E06060]%.0f[/color][color=#7a6a52] / %.0f[/color][/font_size][/right]" % [current, threshold]

func _on_madra_changed(_amount: float) -> void:
	_update_state()

func _shake_reject() -> void:
	_madra_badge_container.pivot_offset = _madra_badge_container.size * 0.5
	var tween: Tween = create_tween()
	var original_pos: Vector2 = _madra_badge_container.position
	tween.tween_property(_madra_badge_container, "scale", Vector2(1.10, 1.10), 0.05)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(-4, 0), 0.04)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(4, 0), 0.04)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(-3, 0), 0.04)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(3, 0), 0.04)
	tween.tween_property(_madra_badge_container, "position", original_pos + Vector2(-2, 0), 0.03)
	tween.tween_property(_madra_badge_container, "position", original_pos, 0.05)
	tween.tween_property(_madra_badge_container, "scale", Vector2(1.0, 1.0), 0.1)
