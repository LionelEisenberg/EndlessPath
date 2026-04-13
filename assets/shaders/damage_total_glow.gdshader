shader_type canvas_item;

// Circling golden border on the damage total pill.
// Replaces edge pixels with animated gold — center untouched.

uniform vec4 border_color : source_color = vec4(0.83, 0.66, 0.29, 1.0);
uniform float border_thickness : hint_range(0.01, 0.15) = 0.04;
uniform float speed : hint_range(0.5, 4.0) = 1.5;
uniform float glow_spread : hint_range(0.05, 0.5) = 0.2;
uniform float dim_brightness : hint_range(0.1, 0.8) = 0.3;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Distance from nearest edge in UV space
	float dx = min(UV.x, 1.0 - UV.x);
	float dy = min(UV.y, 1.0 - UV.y);
	float dist = min(dx, dy);

	// Border mask: 1 at edge, 0 inside
	float border = 1.0 - smoothstep(0.0, border_thickness, dist);

	// Circling highlight angle
	vec2 from_center = (UV - 0.5) * 2.0;
	float angle = atan(from_center.y, from_center.x);
	float highlight = cos(angle - TIME * speed) * 0.5 + 0.5;
	highlight = pow(highlight, 1.0 / glow_spread);

	// Border brightness: dim base + bright moving spot
	float brightness = dim_brightness + highlight * (1.0 - dim_brightness);

	// Replace edge pixels with animated gold, keep center as-is
	vec4 border_pixel = vec4(border_color.rgb * brightness, tex.a);
	COLOR = mix(tex, border_pixel, border);
}
