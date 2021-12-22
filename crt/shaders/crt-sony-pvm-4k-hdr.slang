#version 450

/* 
A shader that tries to emulate a sony PVM type aperture grille screen but with full brightness.

The novel thing about this shader is that it relies on the HDR shaders to brighten up the image so that when 
we apply this shader which emulates the apperture grille the resulting screen isn't left too dark.  

I think you'd need a HDR 1000 monitor to get close to CRT levels of brightness but my HDR 700 does an alright job of it.

Please Enable HDR in RetroArch NOTE: when the hdr10 and inverse_tonemap shaders are envoked the Peak Luminance and Paper White Luminance in the menu do nothing instead set those values through the shader parameters instead 

Set Peak Luminance to the peak luminance of your monitor and set Paper White Luminance to roughly half dependent on the game and the monitor.   

Also try to use a integer scaling - its just better - overscaling is fine.

This shader doesn't do any geometry warping or bouncing of light around inside the screen etc - I think these effects just add unwanted noise, I know people disagree. Please feel free to make you own and add them

Dont use this shader directly - use the crt\crt-sony-pvm-4k-hdr.slangp to have the proper chain of effects.
*/

#pragma format A2B10G10R10_UNORM_PACK32

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
   float ScanlineWidth;
   float ScreenWidth;
   float ScreenHeight; 
} params;

/* #pragma parameter ScanlineWidth "Scanline Width"  4.0    0.0 20.0   1.0 */
#pragma parameter ScanlineWidth "Scanline Width"  0.5    0.0 1.0    0.01 
#pragma parameter ScreenWidth   "Screen Width"    3840.0 0.0 7680.0 1.0
#pragma parameter ScreenHeight  "Screen Height"   2160.0 0.0 4320.0 1.0

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float Scale;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;

   vec2 ScreenSize = max(params.OutputSize.xy, vec2(params.ScreenWidth, params.ScreenHeight));

   if((params.SourceSize.x > ScreenSize.x) || (params.SourceSize.y > ScreenSize.y))
   {
	   Scale = 1.0;
   }
   else 
   {
      float ScaleFactor = 2.0;
        
      while(((params.SourceSize.x * ScaleFactor) <= ScreenSize.x) && ((params.SourceSize.y * ScaleFactor) <= ScreenSize.y))
    	{
	      ScaleFactor += 1.0;
      }

	   Scale = ScaleFactor - 1.0;
   }
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float Scale;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;
layout(set = 0, binding = 3) uniform sampler2D StockPass;

float ModInteger(float a, float b) 
{
    float m = a - floor((a + 0.5) / b) * b;
    return floor(m + 0.5);
}

#define kPi    3.1415926536
#define kEuler 2.718281828459
#define kMax   1.0

#define kGuassianMin   1.1
#define kGuassianMax   3.0
#define Sharpness      2.5

float Ramp(const float gaussian, float colour)
{
    return clamp(gaussian * colour, 0.0, 1.0); 
}

void main()
{
   float ScanlineSize = params.OutputSize.y / params.SourceSize.y; 

   /* vec2 InPixels = (vTexCoord * params.SourceSize.xy) * vec2(Scale); */
   const vec2 InPixels = (vTexCoord * params.OutputSize.xy);

   const float ScanlinePosition = (floor(vTexCoord.y * params.SourceSize.y) * ScanlineSize) + (ScanlineSize * 0.5);

   float ScanlineDistance = ScanlinePosition - (floor(InPixels.y) + 0.5);

   /*
   if(ModInteger(floor(InPixels.y), Scale) < params.ScanlineWidth)
   {
      FragColor = vec4(texture(Source, vTexCoord).xyz, 1.0);
   }
   else
   {
      FragColor = vec4(0.0,0.0,0.0,1.0);
   }
   */

   ScanlineDistance /= ScanlineSize * params.ScanlineWidth;
   ScanlineDistance = clamp(abs(ScanlineDistance * 2.0), 0.0, 1.0);

   /* Gaussian distribution */
   const float gaussian = pow(kEuler, -0.5 * pow(ScanlineDistance/0.3, 2.0));

   //const float guassianf = gaussian * clamp(ScanlineSize / 2, 1.2, 5.0);
   //const float guassian_clamp = clamp(guassianf, 0.0, 1.0); 

   float Ratio = (vTexCoord.x * params.SourceSize.x) - (floor(vTexCoord.x * params.SourceSize.x)); 
   Ratio = clamp(((Ratio - 0.5) * Sharpness) + 0.5, 0.0f, 1.0);

   const vec2 SourceTexCoord0 = vec2(vTexCoord.x, ScanlinePosition / params.OutputSize.y);

   vec3 hdr_colour0 = texture(Source, SourceTexCoord0).xyz;
   vec3 sdr_colour0 = texture(StockPass, SourceTexCoord0).xyz;

   const vec2 SourceTexCoord1 = vec2(vTexCoord.x + (1.0 / params.SourceSize.x), ScanlinePosition / params.OutputSize.y);

   vec3 hdr_colour1 = texture(Source, SourceTexCoord1).xyz;
   vec3 sdr_colour1 = texture(StockPass, SourceTexCoord1).xyz;
   
   vec3 hdr_colour  = mix(hdr_colour0, hdr_colour1, vec3(Ratio));
   vec3 sdr_colour  = mix(sdr_colour0, sdr_colour1, vec3(Ratio));

   /* TODO: Below needs optimising - just needs a mask array rather than doing if's! Ran out of time */ 

#if 0  /* 12 pattern - 8K screens */
   float x = ModInteger(floor(InPixels.x), 12.0);

   if(x < 3.0)
   {
      float red = Ramp(gaussian, (sdr_colour.x * kGuassianMax) + kGuassianMin); 
      FragColor = vec4(red * hdr_colour.x, 0.0, 0.0, 1.0);
   }
   else if(x < 4.0)
   {
      FragColor = vec4(0.0, 0.0, 0.0, 1.0);  /* black */
   }
   else if(x < 7.0)
   {
      float green = Ramp(gaussian, (sdr_colour.y * kGuassianMax) + kGuassianMin);
      FragColor = vec4(0.0, green * hdr_colour.y, 0.0, 1.0);
   }
   else if(x < 8.0)
   {
      FragColor = vec4(0.0, 0.0, 0.0, 1.0);  /* black */
   }
   else if(x < 11.0)
   {
      float blue = Ramp(gaussian, (sdr_colour.z * kGuassianMax) + kGuassianMin);
      FragColor = vec4(0.0, 0.0, blue * hdr_colour.z, 1.0);
   }
   else /* if(x < 12.0) */
   {
      FragColor = vec4(0.0, 0.0, 0.0, 1.0);  /* black */
   }
#endif /* 0 */

#if 0  /* 9 pattern - 8K screens */
   float x = ModInteger(floor(InPixels.x), 9.0);

   if(x < 2.0)
   {
      float red = Ramp(gaussian, (sdr_colour.x * kGuassianMax) + kGuassianMin); 
      FragColor = vec4(red * hdr_colour.x, 0.0, 0.0, 1.0);
   }
   else if(x < 3.0)
   {
      FragColor = vec4(0.0, 0.0, 0.0, 1.0);  /* black */
   }
   else if(x < 5.0)
   {
      float green = Ramp(gaussian, (sdr_colour.y * kGuassianMax) + kGuassianMin);
      FragColor = vec4(0.0, green * hdr_colour.y, 0.0, 1.0);
   }
   else if(x < 6.0)
   {
      FragColor = vec4(0.0, 0.0, 0.0, 1.0);  /* black */
   }
   else if(x < 8.0)
   {
      float blue = Ramp(gaussian, (sdr_colour.z * kGuassianMax) + kGuassianMin);
      FragColor = vec4(0.0, 0.0, blue * hdr_colour.z, 1.0);
   }
   else /* if(x < 9.0) */
   {
      FragColor = vec4(0.0, 0.0, 0.0, 1.0);  /* black */
   }
#endif /* 0 */

#if 1   /* 6 pattern - 4K screens */
   float x = ModInteger(floor(InPixels.x), 6.0);

   if(x < 2.0)
   {
      float red = Ramp(gaussian, (sdr_colour.x * kGuassianMax) + kGuassianMin); 
      FragColor = vec4(red * hdr_colour.x, 0.0, 0.0, 1.0);
   }
   else if(x < 4.0)
   {
      float green = Ramp(gaussian, (sdr_colour.y * kGuassianMax) + kGuassianMin);
      FragColor = vec4(0.0, green * hdr_colour.y, 0.0, 1.0);
   }
   else /* if(x < 6.0) */
   {
      float blue = Ramp(gaussian, (sdr_colour.z * kGuassianMax) + kGuassianMin);
      FragColor = vec4(0.0, 0.0, blue * hdr_colour.z, 1.0);
   }
#endif /* 1 */

#if 0   /* 3 pattern - 1080-1440p screens */
   float x = ModInteger(floor(InPixels.x), 3.0);

   if(x < 1.0)
   {
      float red = Ramp(gaussian, (sdr_colour.x * kGuassianMax) + kGuassianMin); 
      FragColor = vec4(red * hdr_colour.x, 0.0, 0.0, 1.0);
   }
   else if(x < 2.0)
   {
      float green = Ramp(gaussian, (sdr_colour.y * kGuassianMax) + kGuassianMin);
      FragColor = vec4(0.0, green * hdr_colour.y, 0.0, 1.0);
   }
   else /* if(x < 3.0) */
   {
      float blue = Ramp(gaussian, (sdr_colour.z * kGuassianMax) + kGuassianMin);
      FragColor = vec4(0.0, 0.0, blue * hdr_colour.z, 1.0);
   }
#endif /* 0 */
}
