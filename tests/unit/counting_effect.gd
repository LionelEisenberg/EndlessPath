extends EffectData

## An effect for tests that counts how often it fires (process()), so a test
## can use a consumable without touching the player's vitals. Preloaded by the
## consumable tests: const CountingEffect := preload("res://tests/unit/counting_effect.gd").

var call_count: int = 0

func process() -> void:
	call_count += 1

func _to_string() -> String:
	return "CountingEffect"
