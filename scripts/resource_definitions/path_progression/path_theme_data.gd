class_name PathThemeData
extends Resource

## Visual theme for a specific Madra path.
## Controls colors for nodes, borders, connections, and shaders.

@export_group("Swirl Colors (Keystones)")
@export var swirl_primary: Color = Color(0.7, 0.85, 1.0, 0.7)
@export var swirl_secondary: Color = Color(0.6, 0.75, 0.9, 1.0)
@export var swirl_tertiary: Color = Color(0.5, 0.65, 0.8, 1.0)

@export_group("Node Colors")
@export var border_color: Color = Color(0.85, 0.65, 0.29)
@export var border_glow_color: Color = Color(0.95, 0.78, 0.35)
@export var fill_available: Color = Color(0.38, 0.30, 0.20, 1.0)
@export var fill_purchased: Color = Color(0.44, 0.34, 0.20, 1.0)

@export_group("Line Colors")
@export var line_available: Color = Color(0.65, 0.52, 0.36)
@export var line_purchased: Color = Color(0.831, 0.659, 0.290)
@export var line_energy_color: Color = Color(1.0, 0.9, 0.7)

@export_group("Panel")
@export var panel_accent_color: Color = Color(0.769, 0.533, 0.290)
