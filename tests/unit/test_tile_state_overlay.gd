extends GutTest

## Unit tests for TileStateOverlay
## Tests pool / transition / clear behavior

const TileStateOverlayScene := preload("res://scenes/adventure/tile_state_overlay/tile_state_overlay.tscn")

var overlay: TileStateOverlay

func before_each() -> void:
	overlay = TileStateOverlayScene.instantiate()
	add_child_autofree(overlay)

func test_starts_empty() -> void:
	assert_eq(overlay.get_overlay_count(), 0)

func test_set_tile_state_creates_overlay() -> void:
	overlay.set_tile_state(Vector3i(0, 0, 0), TileStateOverlay.TileState.REVEAL, Vector2(100, 100))
	assert_eq(overlay.get_overlay_count(), 1)
	assert_eq(overlay.get_state(Vector3i(0, 0, 0)), TileStateOverlay.TileState.REVEAL)

func test_set_tile_state_does_not_create_duplicate() -> void:
	overlay.set_tile_state(Vector3i(0, 0, 0), TileStateOverlay.TileState.REVEAL, Vector2(100, 100))
	overlay.set_tile_state(Vector3i(0, 0, 0), TileStateOverlay.TileState.CURRENT, Vector2(100, 100))
	assert_eq(overlay.get_overlay_count(), 1)
	assert_eq(overlay.get_state(Vector3i(0, 0, 0)), TileStateOverlay.TileState.CURRENT)

func test_set_tile_state_creates_distinct_for_different_coords() -> void:
	overlay.set_tile_state(Vector3i(0, 0, 0), TileStateOverlay.TileState.REVEAL, Vector2(0, 0))
	overlay.set_tile_state(Vector3i(1, -1, 0), TileStateOverlay.TileState.REVEAL, Vector2(64, 0))
	overlay.set_tile_state(Vector3i(2, -2, 0), TileStateOverlay.TileState.HOVER_TARGET, Vector2(128, 0))
	assert_eq(overlay.get_overlay_count(), 3)

func test_remove_tile_frees_sprite() -> void:
	overlay.set_tile_state(Vector3i(0, 0, 0), TileStateOverlay.TileState.REVEAL, Vector2(0, 0))
	overlay.set_tile_state(Vector3i(1, -1, 0), TileStateOverlay.TileState.REVEAL, Vector2(64, 0))
	overlay.remove_tile(Vector3i(0, 0, 0))
	assert_eq(overlay.get_overlay_count(), 1)
	assert_eq(overlay.get_state(Vector3i(0, 0, 0)), -1)
	assert_eq(overlay.get_state(Vector3i(1, -1, 0)), TileStateOverlay.TileState.REVEAL)

func test_clear_all_removes_everything() -> void:
	overlay.set_tile_state(Vector3i(0, 0, 0), TileStateOverlay.TileState.REVEAL, Vector2(0, 0))
	overlay.set_tile_state(Vector3i(1, -1, 0), TileStateOverlay.TileState.REVEAL, Vector2(64, 0))
	overlay.set_tile_state(Vector3i(2, -2, 0), TileStateOverlay.TileState.CURRENT, Vector2(128, 0))
	overlay.clear_all()
	assert_eq(overlay.get_overlay_count(), 0)

func test_remove_nonexistent_tile_is_safe() -> void:
	overlay.remove_tile(Vector3i(99, 99, -198))
	assert_eq(overlay.get_overlay_count(), 0)
