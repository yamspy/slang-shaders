#version 450

/* 
Part of the crt-sony-pvm-4k-hdr shader group. Does the exact same thing as RetroArch does internally to map into HDR10 space.

This is used to do this mapping BEFORE screen effects are applied.

Originally part of the crt\crt-sony-pvm-4k-hdr.slangp but can be used for any shader
*/

#pragma format A2B10G10R10_UNORM_PACK32

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
   float PaperWhiteNits;
   float ExpandGamut;
} params;

#pragma parameter PaperWhiteNits    "Paper White Luminance"    450.0    0.0 10000.0 10.0
#pragma parameter ExpandGamut       "ExpandGamut"              1.0      0.0 1.0     1.0

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

#define kMaxNitsFor2084     10000.0f

const mat3 k709to2020 = mat3 (
   0.6274040f, 0.3292820f, 0.0433136f,
   0.0690970f, 0.9195400f, 0.0113612f,
   0.0163916f, 0.0880132f, 0.8955950f);

/* START Converted from (Copyright (c) Microsoft Corporation - Licensed under the MIT License.)  https://github.com/microsoft/Xbox-ATG-Samples/tree/master/Kits/ATGTK/HDR */
const mat3 kExpanded709to2020 = mat3 (
    0.6274040f, 0.3292820f, 0.0433136f,
    0.0457456,  0.941777,   0.0124772,
   -0.00121055, 0.0176041,  0.983607);

vec3 LinearToST2084(vec3 normalizedLinearValue)
{
   vec3 ST2084 = pow((0.8359375f + 18.8515625f * pow(abs(normalizedLinearValue), vec3(0.1593017578f))) / (1.0f + 18.6875f * pow(abs(normalizedLinearValue), vec3(0.1593017578f))), vec3(78.84375f));
   return ST2084;  /* Don't clamp between [0..1], so we can still perform operations on scene values higher than 10,000 nits */
}
/* END Converted from (Copyright (c) Microsoft Corporation - Licensed under the MIT License.)  https://github.com/microsoft/Xbox-ATG-Samples/tree/master/Kits/ATGTK/HDR */

vec3 Hdr10(vec3 hdr)
{
   /* Now convert into HDR10 */
   vec3 rec2020 = hdr * k709to2020;

   if(params.ExpandGamut > 0.0f)
   {
      rec2020 = hdr * kExpanded709to2020;
   }

   vec3 linearColour  = rec2020 * (params.PaperWhiteNits / kMaxNitsFor2084);
   vec3 hdr10         = LinearToST2084(linearColour);

   return hdr10;
}

void main()
{
   vec4 hdr = texture(Source, vTexCoord);
   FragColor = vec4(Hdr10(hdr.rgb), hdr.a); 
}

