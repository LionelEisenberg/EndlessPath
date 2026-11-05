# scripts/tools/items_md_to_resources.gd
extends SceneTree

## Headless CLI tool. Reads docs/inventory/ITEMS.md, parses Equipment tables,
## writes one .tres per row under resources/items/equipment/<zone>/.
##
## Invoke:
##   "<godot>" --headless -s scripts/tools/items_md_to_resources.gd
##
## The work is in items_md_generator.gd, loaded in _initialize(). Godot compiles
## a -s script, with every class it names, before it registers the autoloads,
## and the item classes reach code that names one (an item's tooltip lines read
## CharacterManager), so this script names none of them.

const GENERATOR_PATH := "res://scripts/tools/items_md_generator.gd"

func _initialize() -> void:
	var generator: RefCounted = (load(GENERATOR_PATH) as GDScript).new()
	quit(generator.run())
