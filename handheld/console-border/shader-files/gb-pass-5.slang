#version 450

layout(push_constant) uniform Push
{
	vec4 OutputSize;
	vec4 SourceSize;
	vec4 OriginalSize;
	float video_scale;
} params;

#pragma parameter video_scale "Video Scale" 3.0 2.0 20.0 1.0

vec2 middle	= vec2(0.5, 0.5);
vec2 screen_scale = params.OutputSize.xy * params.SourceSize.zw;
vec2 border_scale = vec2(800, 400) * (params.SourceSize.y / params.OriginalSize.y);

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out vec2 tex_border;

void main()
{
	gl_Position	=	global.MVP * Position;

	vec2 diff	=	TexCoord.xy - middle;
	vTexCoord	=	middle + diff * screen_scale;
	tex_border	=	middle + diff * params.OutputSize.xy / border_scale;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 tex_border;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D BORDER;

void main()
{
	vec4 frame	=	texture(Source, vTexCoord).rgba;
	vec4 border	=	texture(BORDER, tex_border).rgba;
	FragColor	=	vec4(mix(frame, border, border.a));
}
