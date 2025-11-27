extends Control

@export var icon_texture: Texture2D
@onready var icon = %Icon
@onready var button = %Button

signal tab_opened()

func _ready() -> void:
	icon.texture = icon_texture
	button.pressed.connect(tab_opened.emit)

func open() -> void:
	$AnimationPlayer.play_backwards("TabButtonAnimation")

func close() -> void:
	$AnimationPlayer.play("TabButtonAnimation")
