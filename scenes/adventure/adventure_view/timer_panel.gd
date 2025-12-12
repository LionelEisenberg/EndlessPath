class_name TimerPanel
extends PanelContainer

## TimerPanel
## Displays and manages the adventure timer

@onready var timer_label: RichTextLabel = %TimerLabel
@onready var timer: Timer = %Timer

## Starts the timer with the given duration in seconds
func start(time_sec: float) -> void:
	timer.start(time_sec)

## Stops the timer
func stop() -> void:
	timer.stop()

func _process(_delta: float) -> void:
	if not timer.is_stopped():
		var time_left: float = timer.time_left
		var minutes: int = floor(time_left / 60)
		var seconds: int = int(time_left) % 60
		timer_label.text = "Time Left: %02d:%02d" % [minutes, seconds]
