shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float edge = smoothstep(0.35, 1.4, length(centered));
	COLOR = vec4(0.025, 0.045, 0.075, edge * 0.56);
}
