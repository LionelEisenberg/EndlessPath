shader_type canvas_item;

// Circling pulsating border on a PanelContainer.
// Works in UV space — no texture dependency.

uniform vec4 border_color : source_color = vec4(0.83, 0.66, 0.29, 0.9);
uniform float border_thickness : hint_range(0.01, 0.15) = 0.06;
uniform float glow_spread : hint_range(0.05, 0.4) = 0.15;
uniform float speed : hint_range(0.5, 4.0) = 1.2;
uniform float base_glow : hint_range(0.0, 0.3) = 0.1;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Distance from nearest edge in UV space (0 at edge, 0.5 at center)
	float dx = min(UV.x, 1.0 - UV.x);
	float dy = min(UV.y, 1.0 - UV.y);
	float dist = min(dx, dy);

	// Border mask: 1 at edge, fades to 0 inside
	float border = 1.0 - smoothstep(0.0, border_thickness, dist);

	// Circling highlight using angle from center
	vec2 from_center = (UV - 0.5) * 2.0;
	float angle = atan(from_center.y, from_center.x);
	float moving = cos(angle - TIME * speed) * 0.5 + 0.5;
	float highlight = pow(moving, 1.0 / glow_spread);

	// Combine: subtle base border glow + bright moving spot
	float intensity = border * (base_glow + highlight * (1.0 - base_glow));

	COLOR = tex + border_color * intensity;
}
