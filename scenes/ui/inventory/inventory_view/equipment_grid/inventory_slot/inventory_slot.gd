class_name InventorySlot
extends TextureRect

signal clicked(slot: InventorySlot, event: InputEvent)

@onready var item_instance_scene : PackedScene = preload("res://scenes/ui/inventory/item_instance/item_instance.tscn")

var item_instance = null

const empty_slot_textures : Array[Texture2D] = [
	preload("res://assets/asperite/inventory/inventory_slot/UI_NoteBook_Slot01a.png"),
	preload("res://assets/asperite/inventory/inventory_slot/UI_NoteBook_Slot01b.png"),
	preload("res://assets/asperite/inventory/inventory_slot/UI_NoteBook_Slot01c.png"),
	preload("res://assets/asperite/inventory/inventory_slot/UI_NoteBook_Slot01d.png")
]

const full_slot_textures : Array[Texture2D] = [
	preload("res://assets/asperite/inventory/inventory_slot/UI_NoteBook_Slot02a.png"),
	preload("res://assets/asperite/inventory/inventory_slot/UI_NoteBook_Slot02b.png"),
	preload("res://assets/asperite/inventory/inventory_slot/UI_NoteBook_Slot02c.png"),
	preload("res://assets/asperite/inventory/inventory_slot/UI_NoteBook_Slot02d.png")
	
]

var empty_texture = empty_slot_textures[randi() % empty_slot_textures.size()]
var full_texture = full_slot_textures[randi() % full_slot_textures.size()]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gui_input.connect(_on_gui_input)
	_update_slot()

func _on_gui_input(event: InputEvent) -> void:
	clicked.emit(self, event)

func setup(data: ItemInstanceData) -> void:
	if item_instance != null:
		Log.error("InventorySlot: Can't setup inventory slot which already has an item instance")
		
	if data != null and item_instance == null:
		item_instance = item_instance_scene.instantiate()
		add_child(item_instance)
		item_instance.setup(data)
		self.texture = full_slot_textures[randi() % full_slot_textures.size()]
	
	_update_slot()

func grab_item() -> Control:
	if item_instance == null:
		return null
	
	var grabbed_instance = item_instance
	remove_child(item_instance)
	item_instance = null
	_update_slot()
	return grabbed_instance

func equip_item(instance: Control) -> void:
	# If we already have an item, this should probably be handled by the caller (swap), 
	# but for safety let's free it if it exists and wasn't grabbed.
	if item_instance != null:
		item_instance.queue_free()
	
	item_instance = instance
	
	if item_instance.get_parent():
		item_instance.get_parent().remove_child(item_instance)
		
	add_child(item_instance)
	# Reset position in case it was dragged
	item_instance.position = Vector2.ZERO
	
	_update_slot()

func _update_slot() -> void:
	if item_instance != null:
		self.texture = full_texture
	else:
		self.texture = empty_texture
