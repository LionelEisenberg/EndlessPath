shader_type canvas_item;

// Circling pulsating border on the damage total pill.
// Bright golden highlight orbits the edges.

uniform vec4 border_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float border_thickness : hint_range(0.02, 0.25) = 0.12;
uniform float glow_spread : hint_range(0.05, 0.5) = 0.2;
uniform float speed : hint_range(0.5, 4.0) = 1.5;
uniform float base_glow : hint_range(0.0, 0.5) = 0.2;
uniform float peak_brightness : hint_range(0.5, 2.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Distance from nearest edge in UV space
	float dx = min(UV.x, 1.0 - UV.x);
	float dy = min(UV.y, 1.0 - UV.y);
	float dist = min(dx, dy);

	// Border mask: 1 at edge, fades to 0 inside
	float border = 1.0 - smoothstep(0.0, border_thickness, dist);

	// Circling highlight
	vec2 from_center = (UV - 0.5) * 2.0;
	float angle = atan(from_center.y, from_center.x);
	float moving = cos(angle - TIME * speed) * 0.5 + 0.5;
	float highlight = pow(moving, 1.0 / glow_spread);

	// Combine
	float intensity = border * (base_glow + highlight * peak_brightness);

	COLOR = tex + border_color * intensity;
}
