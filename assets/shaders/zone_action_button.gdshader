shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 0.3;
uniform vec4 fill_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	vec4 color = fill_color;
	color.a = original_color.a;

	if (fill_amount > UV.x ) {
		COLOR = color;
	}
}