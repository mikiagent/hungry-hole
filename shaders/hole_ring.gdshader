shader_type spatial;
render_mode unshaded;
// Hole rim. Hidden wherever a larger hole overlaps, so the larger hole reads as in front.
uniform vec4 color : source_color = vec4(0.24, 0.66, 0.98, 1.0);
uniform vec4 occluders[8];   // larger holes: x, z, radius, active
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	for (int i = 0; i < 8; i++) {
		if (occluders[i].w > 0.5 && distance(wp.xz, occluders[i].xy) < occluders[i].z) { discard; }
	}
	ALBEDO = color.rgb * 1.15;
}
