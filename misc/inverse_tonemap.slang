#version 450

/* 
Part of the crt-sony-pvm-4k-hdr shader group. Does the exact same thing as RetroArch does internally to inverse tonemap from a SDR image to HDR.

This is used to do this mapping BEFORE screen effects are applied.

Originally part of the crt\crt-sony-pvm-4k-hdr.slangp but can be used for any shader
*/

#pragma format R16G16B16A16_SFLOAT

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
   float Contrast;
   float PaperWhiteNits;
   float MaxNits;
} params;

#pragma parameter Contrast          "Contrast"              5.0      0.0 10.0    0.01
#pragma parameter PaperWhiteNits    "Paper White Luminance" 400.0    0.0 10000.0 10.0
#pragma parameter MaxNits           "Peak Luminance"        700.0    0.0 10000.0 10.0

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
#define kEpsilon            0.0001f
#define kLumaChannelRatio   0.25f

vec3 InverseTonemap(vec3 sdr)
{
   sdr = pow(abs(sdr), vec3(params.Contrast / 2.2f));       /* Display Gamma - needs to be determined by calibration screen */

   float luma = dot(sdr, vec3(0.2126, 0.7152, 0.0722));  /* Rec BT.709 luma coefficients - https://en.wikipedia.org/wiki/Luma_(video) */

   /* Inverse reinhard tonemap */
   float maxValue             = (params.MaxNits / params.PaperWhiteNits) + kEpsilon;
   float elbow                = maxValue / (maxValue - 1.0f);                          
   float offset               = 1.0f - ((0.5f * elbow) / (elbow - 0.5f));              
   
   float hdrLumaInvTonemap    = offset + ((luma * elbow) / (elbow - luma));
   float sdrLumaInvTonemap    = luma / ((1.0f + kEpsilon) - luma);                     /* Convert the srd < 0.5 to 0.0 -> 1.0 range */

   float lumaInvTonemap       = (luma > 0.5f) ? hdrLumaInvTonemap : sdrLumaInvTonemap;
   vec3 perLuma               = sdr / (luma + kEpsilon) * lumaInvTonemap;

   vec3 hdrInvTonemap         = offset + ((sdr * elbow) / (elbow - sdr));         
   vec3 sdrInvTonemap         = sdr / ((1.0f + kEpsilon) - sdr);                       /* Convert the srd < 0.5 to 0.0 -> 1.0 range */

   vec3 perChannel            = vec3(sdr.x > 0.5f ? hdrInvTonemap.x : sdrInvTonemap.x,
                                     sdr.y > 0.5f ? hdrInvTonemap.y : sdrInvTonemap.y,
                                     sdr.z > 0.5f ? hdrInvTonemap.z : sdrInvTonemap.z);

   vec3 hdr = mix(perLuma, perChannel, vec3(kLumaChannelRatio));

   return hdr;
}

void main()
{
   vec4 sdr = texture(Source, vTexCoord);
   FragColor = vec4(InverseTonemap(sdr.rgb), sdr.a); 
}

