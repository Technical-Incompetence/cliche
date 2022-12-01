shader_type canvas_item;

uniform vec4 original_color: source_color;
uniform vec4 new_color: source_color;

void fragment() {
    vec4 current_px_color = texture(TEXTURE, UV);

    if (current_px_color == original_color)
        COLOR = new_color;
    else
        COLOR = current_px_color;
}