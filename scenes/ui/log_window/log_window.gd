extends Control

@onready var rich_text_label: RichTextLabel = %RichTextLabel

func _ready() -> void:
	if LogManager:
		LogManager.message_logged.connect(_on_message_logged)
		LogManager.visibility_toggled.connect(_on_visibility_toggled)
	
	# Default state
	visible = true

func _on_message_logged(bbcode: String) -> void:
	rich_text_label.append_text(bbcode + "\n")

func _on_visibility_toggled() -> void:
	visible = not visible
