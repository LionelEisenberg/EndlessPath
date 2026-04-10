shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_softness : hint_range(0.0, 0.15) = 0.06;

void fragment() {
	// Scale fill so at 1.0 the soft edge falls beyond the card boundary
	float adjusted_fill = fill_amount * (1.0 + edge_softness);

	// Soft leading edge
	float edge = smoothstep(adjusted_fill, adjusted_fill - edge_softness, UV.x);

	// Gradient: builds from subtle on the left to full intensity at the leading edge
	float gradient = UV.x / max(fill_amount, 0.001);
	float alpha_ramp = mix(0.5, 1.0, gradient);

	// Slight brightness boost at the leading edge for a glow feel
	float edge_glow = smoothstep(adjusted_fill - edge_softness * 3.0, adjusted_fill, UV.x) * edge;
	COLOR.rgb += vec3(edge_glow * 0.15);

	COLOR.a *= edge * alpha_ramp;
}
