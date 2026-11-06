class_name CyclingZoneData
extends Resource

## Exact position where this zone appears in world coordinates.
@export var position: Vector2 = Vector2.ZERO

## How lenient the timing window is (larger value = easier).
## We can use this instead of a fixed TIMING_WINDOW.
@export var timing_window_ratio: float = 0.05

## The XP of the technique's other stat (its minor_stat, Control) a press of
## each tier pays. Every zone file writes all three out.
@export var perfect_xp: int = 15
@export var good_xp: int = 10
@export var ok_xp: int = 5
