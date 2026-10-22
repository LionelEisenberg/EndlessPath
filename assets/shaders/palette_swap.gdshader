shader_type canvas_item;

// Redraws pixel art that uses a fixed palette: every texel matching
// source_colors[i] is drawn in target_colors[i]. Unmatched texels keep their
// colour. Needs nearest filtering so texels keep their exact colours.
const int MAX_COLORS = 8;

uniform vec4 source_colors[MAX_COLORS] : source_color;
uniform vec4 target_colors[MAX_COLORS] : source_color;
uniform int color_count : hint_range(0, 8) = 0;
uniform float match_tolerance : hint_range(0.0, 0.1) = 0.01;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	for (int i = 0; i < MAX_COLORS; i++) {
		if (i >= color_count) {
			break;
		}
		if (distance(texel.rgb, source_colors[i].rgb) < match_tolerance) {
			texel.rgb = target_colors[i].rgb;
			break;
		}
	}
	COLOR = texel * modulate;
}
