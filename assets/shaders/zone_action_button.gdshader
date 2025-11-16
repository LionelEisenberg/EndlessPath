shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 white_color = vec4(1.0, 1.0, 1.0, original_color.a);

	if (fill_amount > UV.x ) {
		COLOR = white_color;
	}
}