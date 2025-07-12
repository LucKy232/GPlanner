shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform bool can_draw;
uniform vec2 mouse_pos;
uniform vec2 p1;
uniform vec2 p2;
uniform float pressure;
uniform sampler2D prev_img;
uniform sampler2D brush;
uniform vec2 brush_scale;
uniform vec4 brush_color;
uniform vec2 zoom;


vec2 tangentIntersect( in vec2 p ) {
    float dist = distance(p1, p2);
    float u = (((p.x - p1.x) * (p2.x - p1.x)) + ((p.y - p1.y) * (p2.y - p1.y))) / (dist * dist);
    return vec2(p1.x + u * (p2.x - p1.x),
                p1.y + u * (p2.y - p1.y));
}

vec2 NearestPointOnFiniteLine( in vec2 p )
{
    vec2 line = normalize(p2 - p1);
    vec2 v = p - p1;
    float d = dot(v, line);
    d = clamp(d, 0.0, distance(p1, p2));
    return p1 + line * d;
}

void fragment() {
	vec4 prev_sample = texture(prev_img, SCREEN_UV);
	if (can_draw) {
		vec2 tangent = NearestPointOnFiniteLine(SCREEN_UV);
		// Pressure = Size
		vec4 brush_sample = texture(brush, (SCREEN_UV - tangent) * (1.0 / brush_scale / pressure) + vec2(0.5));
		COLOR = prev_sample;
		if (brush_sample.a == 1.0)
			COLOR.a -= brush_sample.a;
			
		// Pressure = Opacity?
		//vec4 brush_sample = texture(brush, (UV.xy - mouse_pos) * (1.0 / brush_scale) + vec2(0.5));
		//COLOR = mix(prev_sample, vec4(UV.x, UV.y, 0.0, 1.0), brush_sample.a * pressure);
	}
	else {
		COLOR = prev_sample;
	}
}
