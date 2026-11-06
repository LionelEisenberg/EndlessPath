extends SaveGameData

## A SaveGameData that finds CultivationManager missing, as when that autoload
## failed to load, so its version 2 step cannot run. A hand-written save file
## names this script to load as one.

func _can_read_stage_caps() -> bool:
	return false
