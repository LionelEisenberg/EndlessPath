extends Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timeout.connect(PersistenceManager.save_data)
