shader_type canvas_item;
render_mode blend_add;

uniform bool can_draw;
uniform vec2 p1;
uniform vec2 p2;
uniform float pressure;
uniform sampler2D prev_img;
uniform sampler2D brush;
uniform vec2 brush_scale;
uniform vec4 brush_color;
uniform vec2 screen_size;
uniform float scale;


void fragment() {
	if (!can_draw) {
		discard;
	}
	float press = clamp(pressure, 0.1, 1.0);		// Avoid 0.0 step size & infinite loop
	vec2 brush_size = brush_scale * press / scale / screen_size;
	float size_min = min(brush_size.x, brush_size.y);
	float uv_step = clamp(size_min * sqrt(size_min), 0.001, 0.05);	// Bigger brushes get bigger steps & less iterations
	vec4 prev_sample = texture(prev_img, SCREEN_UV);
	float dist = distance(p1, p2);
	for (float i = 0.0; i <= dist; i = i + uv_step) {
		vec2 p = mix(SCREEN_UV - p1, SCREEN_UV - p2, i / dist);
		vec4 brush_sample = texture(brush, p / brush_size + vec2(0.5));
		if (brush_sample.a > 0.01 && COLOR.a < 0.0001) {
			COLOR = brush_color;
		}
	}
	if (COLOR.a < 0.0001) {
		COLOR = prev_sample;
	}
}

	//vec2 tangent = NearestPointOnFiniteLine(SCREEN_UV);
	//vec4 brush_sample = texture(brush, (SCREEN_UV - tangent) * (1.0 / brush_scale / pressure) * vec2(screen_ratio, 1.0) + vec2(0.5));
	//vec4 brush_sample1 = texture(brush, (SCREEN_UV - p1) * (1.0 / brush_scale / pressure) * vec2(screen_ratio, 1.0) + vec2(0.5));
	//vec4 brush_sample2 = texture(brush, (SCREEN_UV - p2) * (1.0 / brush_scale / pressure) * vec2(screen_ratio, 1.0) + vec2(0.5));
//
	//if (brush_sample1.a > 0.01 || brush_sample2.a > 0.01) {
		//COLOR = brush_color;
	//}
	//else
	//{
		//COLOR = prev_sample;
	//}


/*
vec2 tangentIntersect( in vec2 p ) {
    float dist = distance(p1, p2);
    float u = (((p.x - p1.x) * (p2.x - p1.x)) + ((p.y - p1.y) * (p2.y - p1.y))) / (dist * dist);
    return vec2(p1.x + u * (p2.x - p1.x),
                p1.y + u * (p2.y - p1.y));
}
*/

//vec2 NearestPointOnFiniteLine( in vec2 p )
//{
    //vec2 line = normalize(p2 - p1);
    //vec2 v = p - p1;
    //float d = dot(v, line);
    //d = clamp(d, 0.0, distance(p1, p2));
    //return p1 + line * d;
//}