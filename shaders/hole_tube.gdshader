shader_type spatial;
render_mode unshaded, cull_front;
// Inside wall of the hole: tinted near the rim, fading to black with depth, plus a soft lip shadow, so it reads as a deep pit.
uniform vec4 rim_color : source_color = vec4(0.12, 0.32, 0.5, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.02, 0.04, 1.0);
uniform float fade_depth = 4.0;     // world units until fully dark
uniform float lip_depth = 0.35;     // dark band right under the rim
uniform vec4 occluders[8];          // larger holes: x, z, radius, active
varying float world_y;
varying vec2 world_xz;
void vertex() { vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; world_y = w.y; world_xz = w.xz; }
void fragment() {
	for (int i = 0; i < 8; i++) {
		if (occluders[i].w > 0.5 && distance(world_xz, occluders[i].xy) < occluders[i].z) { discard; }
	}
	float d = max(-world_y, 0.0);
	float t = smoothstep(0.0, fade_depth, d);
	vec3 c = mix(rim_color.rgb, deep_color.rgb, pow(t, 0.6));
	c *= mix(0.55, 1.0, smoothstep(0.0, lip_depth, d)); // lip shadow at the edge
	ALBEDO = c;
}
