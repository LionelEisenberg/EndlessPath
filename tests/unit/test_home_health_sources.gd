extends GutTest

## Content check for the one Health pool: at home only body refining refills it
## (spec, phase 5). Body refining heals in code; content may heal Health only in
## a run, on an adventure's tiles (the Aura Well's rest). Walks every resource
## file under res://resources/ and each resource it holds, so a quest reward, an
## unlock effect or a zone action that heals Health fails here.

const RESOURCES_DIR: String = "res://resources/"
## The content allowed to hold a Health heal: an adventure's encounters, which
## play only in a run.
const RUN_CONTENT_DIR: String = "res://resources/adventure/"
const AURA_WELL: String = "res://resources/adventure/encounters/shallow_woods/special_encounters/aura_well_encounter.tres"

#-----------------------------------------------------------------------------
# HELPERS
#-----------------------------------------------------------------------------

## Every .tres path under `dir`, depth first.
func _resource_paths(dir: String) -> Array[String]:
	var paths: Array[String] = []
	for sub: String in DirAccess.get_directories_at(dir):
		paths.append_array(_resource_paths(dir.path_join(sub)))
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			paths.append(dir.path_join(file))
	return paths

## Adds to `holders` the path of each resource reachable from `value` that holds
## a Health heal itself, in a property or in an array or dictionary there. Only
## scripted resources are walked: textures, fonts and the like hold no effects.
func _collect_holders(value: Variant, holders: Dictionary, visited: Dictionary) -> void:
	if value is Array:
		for item: Variant in value:
			_collect_holders(item, holders, visited)
		return
	if value is Dictionary:
		for key: Variant in value:
			_collect_holders(key, holders, visited)
			_collect_holders(value[key], holders, visited)
		return
	if not value is Resource:
		return
	var resource: Resource = value
	if resource.get_script() == null or visited.has(resource.get_instance_id()):
		return
	visited[resource.get_instance_id()] = true
	for property: Dictionary in resource.get_property_list():
		if not property.usage & PROPERTY_USAGE_STORAGE or property.name == "script":
			continue
		var held: Variant = resource.get(property.name)
		if _is_or_lists_a_health_heal(held):
			holders[resource.resource_path] = true
		_collect_holders(held, holders, visited)

## True when `value` is a vitals change that heals Health, or an array or
## dictionary holding one.
func _is_or_lists_a_health_heal(value: Variant) -> bool:
	if value is Array:
		return (value as Array).any(_is_or_lists_a_health_heal)
	if value is Dictionary:
		return (value as Dictionary).values().any(_is_or_lists_a_health_heal)
	var change := value as ChangeVitalsEffectData if value is Object else null
	return change != null and (change.health_change > 0.0 or change.body_hp_multiplier > 0.0)

## The resources that hold a Health heal: a file's path, or the file's path and
## "::" and the id for a resource written inside another file.
func _health_heal_holders() -> Array[String]:
	var holders: Dictionary = {}
	var visited: Dictionary = {}
	for path: String in _resource_paths(RESOURCES_DIR.trim_suffix("/")):
		_collect_holders(load(path), holders, visited)
	var paths: Array[String] = []
	paths.assign(holders.keys())
	paths.sort()
	return paths

#-----------------------------------------------------------------------------
# TESTS
#-----------------------------------------------------------------------------

func test_only_adventure_tiles_heal_health() -> void:
	var others: Array[String] = _health_heal_holders().filter(func(path: String) -> bool: return not path.begins_with(RUN_CONTENT_DIR))
	assert_eq(others, [] as Array[String], "content that heals Health at home besides body refining")

## The walk finds the Aura Well's rest, so a walk that finds nothing can't pass
## the check above.
func test_the_walk_finds_the_aura_wells_rest() -> void:
	var at_the_well: Array[String] = _health_heal_holders().filter(func(path: String) -> bool: return path.begins_with(AURA_WELL))
	assert_false(at_the_well.is_empty(), "the Aura Well's rest heals Health")
