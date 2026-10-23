shader_type spatial;

render_mode cull_front, unshaded, depth_draw_never;

global uniform vec4 outline_color;
global uniform float outline_width;

void vertex() {
	vec4 clip_position = 
			PROJECTION_MATRIX *
			(MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 clip_normal =
			mat3(PROJECTION_MATRIX) *
			(mat3(MODELVIEW_MATRIX) * NORMAL);
	// تلاشي الحد على الوجوه الحادّة (شبه موازية لمستوى العرض): الحد المقلوب
	// يتحوّل هناك إلى خطوط رفيعة مقطّعة عبر الواجهات عند زوايا الميلان.
	// الوجوه المواجهة للعرض تحتفظ بحدّها الكامل (الظلال/الحواف الرئيسية).
	vec3 view_normal = mat3(MODELVIEW_MATRIX) * NORMAL;
	float vlen = length(view_normal);
	float facing = 1.0;
	if (vlen > 0.0001) {
		facing = abs(view_normal.z / vlen);
	}
	float fade = smoothstep(0.18, 0.42, facing);
	vec2 n2 = clip_normal.xy;
	float n_len = length(n2);
	if (n_len > 0.0001) {
		clip_position.xy +=
				(n2 / n_len) /
				VIEWPORT_SIZE *
				clip_position.w *
				outline_width *
				fade;
	}
	POSITION = clip_position;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
