extends GutTest

## Tab banners must show their per-tab title at RUNTIME. Property overrides on
## the instanced Label child silently fail to apply when the scene is loaded in
## game (and the editor drops them on save), so each tab sets the title through
## the TabBanner root export property instead. These tests instantiate the tab
## scenes the same way the game does and assert the rendered title text.

func _banner_title(scene_path: String, banner_name: String) -> String:
	var tab: Control = load(scene_path).instantiate()
	add_child_autofree(tab)
	var banner: Node = tab.get_node(banner_name)
	var title: Label = banner.get_node("Title")
	return title.text

func test_consumables_banner_title_at_runtime() -> void:
	var text := _banner_title("res://scenes/inventory/inventory_view/consumables_tab/consumables_tab.tscn", "ConsumablesBanner")
	assert_eq(text, "Consumables", "consumables banner shows its own title at runtime")

func test_journal_banner_title_at_runtime() -> void:
	var text := _banner_title("res://scenes/inventory/inventory_view/quest_items_tab/quest_items_tab.tscn", "JournalBanner")
	assert_eq(text, "Journal", "journal banner shows its own title at runtime")
