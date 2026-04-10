shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	if (UV.x < fill_amount) {
		COLOR = COLOR;
	} else {
		COLOR.a = 0.0;
	}
}
