extends GutTest

## Unit tests for DevPasswordModal.check_password.
## Pure-function tests — no scene instantiation needed.

const DevPasswordModal = preload("res://scenes/ui/dev_panel/dev_password_modal.gd")

var _test_password_path: String = "user://test_dev_password.txt"

func after_each() -> void:
    if FileAccess.file_exists(_test_password_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_password_path))

func _write_password_file(contents: String) -> void:
    var f: FileAccess = FileAccess.open(_test_password_path, FileAccess.WRITE)
    f.store_string(contents)
    f.close()

func test_check_password_returns_false_when_file_missing() -> void:
    var result: bool = DevPasswordModal.check_password("anything", _test_password_path)
    assert_false(result, "should return false when password file does not exist")

func test_check_password_returns_true_on_exact_match() -> void:
    _write_password_file("hunter2")
    var result: bool = DevPasswordModal.check_password("hunter2", _test_password_path)
    assert_true(result, "should return true on exact match")

func test_check_password_returns_false_on_mismatch() -> void:
    _write_password_file("hunter2")
    var result: bool = DevPasswordModal.check_password("wrong", _test_password_path)
    assert_false(result, "should return false on mismatch")

func test_check_password_trims_whitespace_both_sides() -> void:
    _write_password_file("hunter2\n")
    var result: bool = DevPasswordModal.check_password("  hunter2  ", _test_password_path)
    assert_true(result, "should trim whitespace on both sides for comparison")

func test_check_password_empty_entry_fails() -> void:
    _write_password_file("hunter2")
    var result: bool = DevPasswordModal.check_password("", _test_password_path)
    assert_false(result, "empty entry should not match")
