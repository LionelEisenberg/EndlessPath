class_name TribulationPhaseData
extends Resource

## TribulationPhaseData
## One phase of a Tribulation: a run of breaths, with the tip the board shows
## while it plays. TribulationData lists its phases in the order they play.
## Durations are in seconds at tempo 1.0.

#-----------------------------------------------------------------------------
# EXPORTED PROPERTIES
#-----------------------------------------------------------------------------

## The phase's name, as the schedule lists it ("Steady breath").
@export var phase_name: String = ""

## The tip the board shows while the phase plays.
@export var tip: String = ""

## Seconds of stillness before the phase starts, counted from the end of the
## phase before it. 0.0 starts it at once.
@export var gap_before: float = 0.0

## How long each breath of the phase's sphere takes. Each breath is one beat.
@export var breath_periods: PackedFloat32Array

## How long each breath of the echo takes: a second sphere that answers the
## first, one beat per breath. Empty when the phase has no echo.
@export var echo_periods: PackedFloat32Array

## Seconds after the first sphere starts breathing before the echo starts.
@export var echo_offset: float = 0.0

## Whether Madra pellets stream into the core while the phase plays.
@export var aura_rush: bool = false
