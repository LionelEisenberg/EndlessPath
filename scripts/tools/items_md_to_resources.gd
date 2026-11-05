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
## CharacterManager), so this script names none of them. A worker that is
## missing or does not compile stops the run with 1, naming its path: an error
## raised here would skip quit() and leave the headless process running.

const GENERATOR_PATH := "res://scripts/tools/items_md_generator.gd"

func _initialize() -> void:
	var generator_script := load(GENERATOR_PATH) as GDScript
	if generator_script == null or not generator_script.can_instantiate():
		push_error("ItemsMdGenerator: failed to load the generator at %s" % GENERATOR_PATH)
		quit(1)
		return
	var generator: RefCounted = generator_script.new()
	quit(generator.run())
