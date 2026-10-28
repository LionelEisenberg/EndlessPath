extends GutTest

## Tab banners must show their per-book title at RUNTIME. Property overrides on
## the instanced Label child silently fail to apply when the scene is loaded in
## game (and the editor drops them on save), so each book sets the title through
## the TabBanner root export property instead. These tests instantiate the book
## scenes the same way the game does and assert the rendered title text.

func _banner_title(scene_path: String, banner_path: String) -> String:
	var book: Control = load(scene_path).instantiate()
	add_child_autofree(book)
	var banner: Node = book.get_node(banner_path)
	var title: Label = banner.get_node("Title")
	return title.text

func test_character_banner_title_at_runtime() -> void:
	var text := _banner_title("res://scenes/character/character_view.tscn", "BookLayer/BookContent/TitleBanner")
	assert_eq(text, "Character", "the Character book's banner shows its own title at runtime")
