class_name LockedZoneOverlay
extends Node2D

## LockedZoneOverlay
## A single locked-zone indicator: grey hex background + centered lock icon.
## Instanced per locked zone by ZoneTilemap._refresh_locked_overlays().
## Exposes shake() for "denied" feedback when the player clicks a locked tile.

@onready var _lock_icon: Sprite2D = $LockIcon

var _shake_tween: Tween

## Shakes the lock icon horizontally with decaying amplitude, as "denied"
## feedback when the player clicks a locked zone. Kills any in-progress
## shake first so rapid clicks restart cleanly.
func shake() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_lock_icon.position.x = 0.0
	_shake_tween = create_tween()
	_shake_tween.set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(_lock_icon, "position:x", -8.0, 0.05)
	_shake_tween.tween_property(_lock_icon, "position:x", 8.0, 0.08)
	_shake_tween.tween_property(_lock_icon, "position:x", -5.0, 0.07)
	_shake_tween.tween_property(_lock_icon, "position:x", 5.0, 0.07)
	_shake_tween.tween_property(_lock_icon, "position:x", -3.0, 0.06)
	_shake_tween.tween_property(_lock_icon, "position:x", 3.0, 0.06)
	_shake_tween.tween_property(_lock_icon, "position:x", 0.0, 0.05)
