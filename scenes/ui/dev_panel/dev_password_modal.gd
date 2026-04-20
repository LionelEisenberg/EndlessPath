class_name DevPasswordModal
extends Control

## Password entry modal for the dev panel.
## Shown when user hits Ctrl+Shift+D and user://dev_password.txt exists.
## Emits `unlocked` on correct entry; closes silently on wrong entry.

signal unlocked

const PASSWORD_FILE_PATH: String = "user://dev_password.txt"

@onready var _password_input: LineEdit = %PasswordInput
@onready var _submit_button: Button = %SubmitButton

func _ready() -> void:
    _submit_button.pressed.connect(_on_submit)
    _password_input.text_submitted.connect(_on_text_submitted)

## Static: checks the entered password against the file at `path`.
## Returns true iff the file exists and its trimmed contents match `entered` trimmed.
static func check_password(entered: String, path: String = PASSWORD_FILE_PATH) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var f: FileAccess = FileAccess.open(path, FileAccess.READ)
    if f == null:
        return false
    var contents: String = f.get_as_text()
    f.close()
    return entered.strip_edges() == contents.strip_edges()

## Opens the modal, clears any prior entry, focuses the input.
func open() -> void:
    _password_input.text = ""
    visible = true
    _password_input.grab_focus()

func _on_submit() -> void:
    var entered: String = _password_input.text
    visible = false
    if check_password(entered):
        unlocked.emit()

func _on_text_submitted(_text: String) -> void:
    _on_submit()
