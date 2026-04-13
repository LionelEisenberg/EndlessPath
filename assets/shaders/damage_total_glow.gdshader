shader_type canvas_item;

// Circling pulsating border effect for the damage total pill.
// A bright golden highlight travels around the border edges.

uniform vec4 border_color : source_color = vec4(0.83, 0.66, 0.29, 0.8);
uniform float border_width : hint_range(1.0, 6.0) = 3.0;
uniform float glow_size : hint_range(0.05, 0.5) = 0.2;
uniform float speed : hint_range(0.5, 4.0) = 1.2;
uniform float base_brightness : hint_range(0.0, 0.5) = 0.15;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec2 pixel_size = TEXTURE_PIXEL_SIZE;
    vec2 size = 1.0 / pixel_size;

    // Distance from each edge in pixels
    float dist_left = UV.x * size.x;
    float dist_right = (1.0 - UV.x) * size.x;
    float dist_top = UV.y * size.y;
    float dist_bottom = (1.0 - UV.y) * size.y;
    float dist_to_edge = min(min(dist_left, dist_right), min(dist_top, dist_bottom));

    // Border mask: 1.0 at edge, 0.0 inside
    float border_mask = 1.0 - smoothstep(0.0, border_width, dist_to_edge);

    // Angle from center for the circling effect
    vec2 center_uv = UV - 0.5;
    float angle = atan(center_uv.y, center_uv.x);

    // Moving highlight: a soft spot that travels around the border
    float moving_angle = TIME * speed;
    float highlight = cos(angle - moving_angle) * 0.5 + 0.5;
    highlight = pow(highlight, 1.0 / glow_size); // Sharpen the highlight

    // Combine: base subtle border + moving bright spot
    float intensity = border_mask * (base_brightness + highlight * (1.0 - base_brightness));

    COLOR = tex + border_color * intensity * tex.a;
}
