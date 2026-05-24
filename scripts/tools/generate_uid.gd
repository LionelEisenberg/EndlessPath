extends SceneTree

func _init() -> void:
	for i in 5:
		print(ResourceUID.id_to_text(ResourceUID.create_id()))
	quit()
