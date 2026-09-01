## 수색 완료 컨테이너(차량/집)를 "어두운 회색"으로 표시하기 위한 셰이더.
## render_mode unshaded 로 조명(ambient·태양)의 영향을 완전히 배제하고,
## 전체를 균일한 어두운 회색으로 칠한다. 어떤 조명 환경에서도 일정하게 보인다.
## 알파는 원본 텍스처 알파(창문·유리 등)를 보존한다.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float search_tone : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	float a = clamp(texture(albedo_tex, UV).a * base_color.a * COLOR.a, 0.0, 1.0);
	ALBEDO = vec3(search_tone);
	ALPHA = a;
}
