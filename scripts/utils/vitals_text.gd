class_name VitalsText

## How every screen prints the player's Health, so one run shows one Health
## number: the vitals plate and the end card both read it from here. The figure
## rounds up, so a player still alive never reads 0, and the max rounds down.

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## "91": Health rounded up.
static func health_figure(health: float) -> String:
	return str(ceili(health))

## "100": max Health rounded down.
static func health_max_figure(max_health: float) -> String:
	return str(floori(max_health))

## "91 / 100": Health over its max, each rounded as above.
static func health_pair(health: float, max_health: float) -> String:
	return "%s / %s" % [health_figure(health), health_max_figure(max_health)]
