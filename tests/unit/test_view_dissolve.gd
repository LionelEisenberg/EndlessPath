extends GutTest

## Unit tests for ViewDissolve, the style guide's 2-step dither dissolve (§8,
## Show and hide) from one whole view to the next: a still of the old view laid
## over the new one, drawn on half its art cells, then a quarter, 0.1 s each,
## then hidden. Nothing fades. The dissolve's tween is stepped by hand a 60 FPS
## frame at a time. play() itself takes no still headless, so the tests hand
## play_over() a still of their own.

const ViewDissolveScene := preload("res://scenes/ui/view_dissolve/view_dissolve.tscn")

const FRAME: float = 1.0 / 60.0

var _dissolve: ViewDissolve = null
var _still: ImageTexture = null

func before_each() -> void:
	_dissolve = ViewDissolveScene.instantiate()
	add_child_autofree(_dissolve)
	_still = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Steps the running tweens through `seconds` of 60 FPS frames.
func _run(seconds: float) -> void:
	for _frame: int in roundi(seconds / FRAME):
		for tween: Tween in get_tree().get_processed_tweens():
			if tween.is_valid() and tween.is_running():
				tween.custom_step(FRAME)

func _step() -> int:
	return (_dissolve.material as ShaderMaterial).get_shader_parameter("dissolve_step")

#-----------------------------------------------------------------------------
# SCENE
#-----------------------------------------------------------------------------

func test_starts_hidden_at_step_0() -> void:
	assert_false(_dissolve.visible)
	assert_false(_dissolve.is_playing())
	assert_eq(_step(), 0)

func test_takes_no_pointer() -> void:
	assert_eq(_dissolve.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the view under it takes the pointer from the first frame")

func test_covers_the_whole_screen_on_the_pixel_grid() -> void:
	assert_eq(_dissolve.anchor_right, 1.0)
	assert_eq(_dissolve.anchor_bottom, 1.0)
	assert_eq(_dissolve.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "the still keeps its pixels")

func test_dissolves_the_still_out_with_the_inverted_dither() -> void:
	var material: ShaderMaterial = _dissolve.material as ShaderMaterial
	assert_eq(material.shader.resource_path, "res://assets/shaders/dither_dissolve.gdshader")
	assert_true(material.get_shader_parameter("invert"), "the still keeps the cells the incoming view would not")

#-----------------------------------------------------------------------------
# PLAYING
#-----------------------------------------------------------------------------

func test_play_over_shows_the_still_on_half_its_cells() -> void:
	_dissolve.play_over(_still)
	assert_true(_dissolve.visible)
	assert_true(_dissolve.is_playing())
	assert_eq(_dissolve.texture, _still)
	assert_eq(_step(), 1, "half the still's art cells at once")

func test_second_step_after_a_tenth_of_a_second() -> void:
	_dissolve.play_over(_still)
	_run(0.05)
	assert_eq(_step(), 1, "the first step holds")
	_run(0.067)
	assert_eq(_step(), 2, "a quarter of the cells from 0.1 s")
	assert_true(_dissolve.visible)

func test_hides_and_lets_the_still_go_after_two_steps() -> void:
	watch_signals(_dissolve)
	_dissolve.play_over(_still)
	_run(0.217)
	assert_false(_dissolve.visible, "gone after 0.2 s")
	assert_false(_dissolve.is_playing())
	assert_null(_dissolve.texture, "the still is let go")
	assert_eq(_step(), 0)
	assert_signal_emitted(_dissolve, "finished")

func test_never_fades() -> void:
	_dissolve.play_over(_still)
	for _frame: int in 14:
		assert_eq(_dissolve.modulate.a, 1.0, "no alpha fade")
		assert_eq(_dissolve.self_modulate.a, 1.0, "no alpha fade")
		_run(FRAME)

func test_a_new_dissolve_starts_over() -> void:
	_dissolve.play_over(_still)
	_run(0.15)
	assert_eq(_step(), 2)
	var second_still: ImageTexture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	_dissolve.play_over(second_still)
	assert_eq(_step(), 1, "the new still starts at half its cells")
	assert_eq(_dissolve.texture, second_still)
	_run(0.117)
	assert_true(_dissolve.visible, "the first dissolve's end does not hide the second")
	_run(0.1)
	assert_false(_dissolve.visible, "the second ends 0.2 s after it started")

func test_play_takes_no_still_headless() -> void:
	_dissolve.play()
	assert_false(_dissolve.visible, "no frame is drawn headless, so there is nothing to dissolve")
