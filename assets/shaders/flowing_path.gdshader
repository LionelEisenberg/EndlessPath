shader_type canvas_item;

// Tint multiplied over the interpolated vertex color (Line2D gradient alpha is preserved)
uniform vec4 stroke_color : source_color = vec4(0.55, 0.78, 1.0, 1.0);

// How fast the brightness wave scrolls along the line (UV.x direction)
uniform float scroll_speed : hint_range(0.0, 4.0) = 1.0;

// How much the brightness pulses between dim and bright (0 = constant, 1 = full sweep)
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	// Preserve the Line2D's gradient alpha (interpolated vertex color)
	float vertex_alpha = COLOR.a;

	// Animate brightness along the line via UV.x scrolling
	float wave = sin((UV.x - TIME * scroll_speed) * 6.2831);
	float bright = 1.0 - pulse_strength + (wave * 0.5 + 0.5) * pulse_strength;

	COLOR = vec4(stroke_color.rgb * bright, vertex_alpha * stroke_color.a);
}
