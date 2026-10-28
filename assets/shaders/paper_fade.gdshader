shader_type canvas_item;

// Fades a texture into the book's paper: an opaque mix of each texel's colour
// towards the paper colour, keeping the texel's own alpha. The Equipment filter
// draws the items it leaves out this way, so it never uses alpha.
uniform vec4 paper_color : source_color = vec4(0.968627, 0.901961, 0.792157, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.7;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, paper_color.rgb, amount), c.a);
}
