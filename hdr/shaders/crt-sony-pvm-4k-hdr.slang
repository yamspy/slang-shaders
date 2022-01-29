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

#include "inverse_tonemap.h"
#include "hdr10.h"

layout(push_constant) uniform Push
{
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
   float PaperWhiteNits;
   float MaxNits;
   float ExpandGamut;
   float CRTGamma;
   float ScanlineMin;
   float ScanlineMax;
   float ResolutionPattern;
   float HorizontalSharpness;
   float HorizontalAttack;
   float VerticalAttack;
   float RedConvergence;
   float GreenConvergence;
   float BlueConvergence;
} params;

#pragma parameter PaperWhiteNits       "Paper White Luminance" 650.0 0.0   10000.0  10.0
#pragma parameter MaxNits              "Peak Luminance"        700.0 0.0   10000.0  10.0
#pragma parameter ExpandGamut          "ExpandGamut"           1.0   0.0   1.0      1.0
#pragma parameter CRTGamma             "CRTGamma"              1.8   0.0   5.0      0.05
#pragma parameter ScanlineMin          "Scanline Min"          0.55  0.0   2.0      0.01 
#pragma parameter ScanlineMax          "Scanline Max"          0.90  0.0   2.0      0.01 
#pragma parameter ResolutionPattern    "Resolution Pattern"    3.0   0.0   8.0      1.0
#pragma parameter HorizontalSharpness  "Horizontal Sharpness"  1.5   0.0   5.0      0.1
#pragma parameter HorizontalAttack     "Horizontal Attack"     0.60  0.0   1.0      0.05
#pragma parameter VerticalAttack       "Vertical Attack"       0.65  0.0   1.0      0.05
#pragma parameter RedConvergence       "Red Convergence"       0.0   -10.0 10.0     0.05
#pragma parameter GreenConvergence     "Green Convergence"     0.0   -10.0 10.0     0.05
#pragma parameter BlueConvergence      "Blue Convergence"      0.0   -10.0 10.0     0.05

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
layout(location = 1) out float ScanlineSize;
layout(location = 2) out float InverseScanlineSize;
layout(location = 3) out vec3 Convergence;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * vec2(1.00001);  // To resolve rounding issues when sampling

   ScanlineSize         = params.OutputSize.y / params.SourceSize.y; 
   InverseScanlineSize  = 1.0f / ScanlineSize;

   Convergence          = vec3(params.RedConvergence, params.GreenConvergence, params.BlueConvergence);
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in float ScanlineSize;
layout(location = 2) in float InverseScanlineSize;
layout(location = 3) in vec3 Convergence;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float ModInteger(float a, float b) 
{
    float m = a - floor((a + 0.5) / b) * b;
    return floor(m + 0.5);
}

#define kPi    3.1415926536f
#define kEuler 2.718281828459f
#define kMax   1.0f

#define kLumaRatio 0.5f

#define kRed     vec3(1.0, 0.0, 0.0)
#define kGreen   vec3(0.0, 1.0, 0.0)
#define kBlue    vec3(0.0, 0.0, 1.0)
#define kMagenta vec3(1.0, 0.0, 1.0)
#define kYellow  vec3(1.0, 1.0, 0.0)
#define kCyan    vec3(0.0, 1.0, 1.0)
#define kBlack   vec3(0.0, 0.0, 0.0)
#define kWhite   vec3(1.0, 1.0, 1.0)

const float PatternSize[10] = {2.0f, 3.0f, 4.0f, 4.0f, 5.0f, 5.0f, 6.0f, 7.0f, 9.0f, 12.0f};

const mat4 kCubicBezier = mat4( 1.0f,  0.0f,  0.0f,  0.0f,
					                -3.0f,  3.0f,  0.0f,  0.0f,
					                 3.0f, -6.0f,  3.0f,  0.0f,
					                -1.0f,  3.0f, -3.0f,  1.0f );

const vec4 kFallOffControlPoints    = vec4(0.0f, 0.0f, 0.0f, 1.0f);
const vec4 kAttackControlPoints     = vec4(0.0f, 1.0f, 1.0f, 1.0f);
//const vec4 kScanlineControlPoints   = vec4(1.0f, 1.0f, 0.0f, 0.0f);

vec4 HorizControlPoints(const bool falloff)
{
   return falloff ? kFallOffControlPoints + vec4(0.0f, 0.0f, params.HorizontalAttack, 0.0f) : kAttackControlPoints - vec4(0.0f, params.HorizontalAttack, 0.0f, 0.0f);
}

float Bezier(const float t0, const vec4 control_points)
{
   vec4 t = vec4(1.0, t0, t0*t0, t0*t0*t0);
   return dot(t, control_points * kCubicBezier);
}

float ToLinear1(float channel)
{
	return (channel > 0.04045f) ? pow(abs(channel) * (1.0f / 1.055f) + (0.055f / 1.055f), params.CRTGamma) : channel * (1.0f / 12.92f);
}

vec3 ToLinear(vec3 colour)
{
	return vec3(ToLinear1(colour.r), ToLinear1(colour.g), ToLinear1(colour.b));
}

vec3 Ramp(const vec3 luminance, const vec3 colour)
{
    return clamp(luminance * colour, 0.0, 1.0); 
}

vec3 ScanlineColour(const float current_position, const float current_center, const float source_tex_coord_x, const float narrowed_source_pixel_offset, inout float next_prev )
{
   const float current_source_position_y  = (vTexCoord.y * params.SourceSize.y) - next_prev;
   const float current_source_center_y    = floor(current_source_position_y) + 0.5f; 
   
   const float source_tex_coord_y         = current_source_center_y / params.SourceSize.y; 

   const vec2 source_tex_coord_0          = vec2(source_tex_coord_x, source_tex_coord_y);
   const vec2 source_tex_coord_1          = vec2(source_tex_coord_x + (1.0f / params.SourceSize.x), source_tex_coord_y);

   const float scanline_position        = current_source_center_y * ScanlineSize;
   const vec3 scanline_delta            = vec3(scanline_position) - (vec3(current_center) - Convergence);  
   const vec3 scanline_distance         = abs(scanline_delta * InverseScanlineSize * 2.0f);

   next_prev = scanline_delta.x > 0.0f ? 1.0f : -1.0f;

   const vec3 sdr_colour_0 = ToLinear(texture(Source, source_tex_coord_0).xyz);
   const vec3 sdr_colour_1 = ToLinear(texture(Source, source_tex_coord_1).xyz);

   const vec3 hdr_colour_0 = InverseTonemap(sdr_colour_0, params.MaxNits, params.PaperWhiteNits, kLumaRatio);
   const vec3 hdr_colour_1 = InverseTonemap(sdr_colour_1, params.MaxNits, params.PaperWhiteNits, kLumaRatio);

   /* Horizontal interpolation between pixels */ 

   const vec3 horiz_interp = vec3(Bezier(narrowed_source_pixel_offset, HorizControlPoints(sdr_colour_0.x > sdr_colour_1.x)), 
                                  Bezier(narrowed_source_pixel_offset, HorizControlPoints(sdr_colour_0.y > sdr_colour_1.y)), 
                                  Bezier(narrowed_source_pixel_offset, HorizControlPoints(sdr_colour_0.z > sdr_colour_1.z)));  

   const vec3 hdr_colour  = mix(hdr_colour_0, hdr_colour_1, horiz_interp);
   const vec3 sdr_colour  = mix(sdr_colour_0, sdr_colour_1, horiz_interp);

   //const vec3 scanline_width = mix(vec3(0.2f), vec3(0.4f), sdr_colour) * params.ScanlineWidth;
   //const vec3 luminance = pow(vec3(kEuler), vec3(-0.5f) * pow(scanline_distance / scanline_width, vec3(2.0f))); /* Gaussian distribution */

   const vec3 narrowed_scanline_distance = clamp(scanline_distance / (sdr_colour * vec3(params.ScanlineMax - params.ScanlineMin) + vec3(params.ScanlineMin)), vec3(0.0f), vec3(1.0f));

   const vec4 scanline_control_points = vec4(1.0f, 1.0f, params.VerticalAttack, 0.0f);

   const vec3 luminance = vec3(Bezier(narrowed_scanline_distance.x, scanline_control_points),
                               Bezier(narrowed_scanline_distance.y, scanline_control_points),
                               Bezier(narrowed_scanline_distance.z, scanline_control_points));

   return luminance * hdr_colour;
}

void main()
{
   uint resolution_pattern = uint(params.ResolutionPattern);

   const vec2 current_position = vTexCoord * params.OutputSize.xy;
   const float current_center  = floor(current_position.y) + 0.5f;

   const float current_source_position_x  = (vTexCoord.x * params.SourceSize.x) /* / PatternSize[resolution_pattern] */;
   const float current_source_center_x    = floor(current_source_position_x) + 0.5f; 
   
   const float source_tex_coord_x         = (current_source_center_x /* * PatternSize[resolution_pattern]*/) / params.SourceSize.x; 

   const float source_pixel_offset          = current_source_position_x - floor(current_source_position_x);
   const float narrowed_source_pixel_offset = clamp(((source_pixel_offset - 0.5f) * params.HorizontalSharpness) + 0.5f, 0.0f, 1.0f);

   float next_prev = 0.0f;

   const vec3 scanline_colour0 = ScanlineColour(current_position.y, current_center, source_tex_coord_x, narrowed_source_pixel_offset, next_prev);
   const vec3 scanline_colour1 = ScanlineColour(current_position.y, current_center, source_tex_coord_x, narrowed_source_pixel_offset, next_prev);

   vec3 scanline_colour = scanline_colour0 + scanline_colour1;

   /* Various resolution patterns - remember your LCD 4K screen will likely be 16:9 whereas
   the CRT TV will likely be 4:3 and so higher TVL values will be required on your 16:9 screen
   to get an equivalent TVL seen on a 4:3 CRT TV. 
   Pattern 1's 960TVL at 16:9 is about right for a 800TVL at 4:3.
   */

   switch(resolution_pattern)
   {
      case 0:  /* 2 pattern - 1440TVL (16:9) horiz resolution (too high?) on a 4K screen */
      {
         const vec3 mask[2] = vec3[]( kYellow, kCyan );
      
         uint pattern_x = uint(ModInteger(floor(current_position.x), PatternSize[0]));
         scanline_colour *= mask[pattern_x];
         
         break;
      }
      case 1:  /* 3 pattern - 960TVL (16:9) horiz resolution on a 4K screen */
      {  
         const vec3 mask[3] = vec3[]( kRed, kGreen, kBlue );
      
         uint pattern_x = uint(ModInteger(floor(current_position.x), PatternSize[1]));
         scanline_colour *= mask[pattern_x];
      
         break;
      }
      case 2:  /* 4 pattern - 720TVL (16:9) horiz resolution on a 4K screen */
      {
         const vec3 mask[4] = vec3[]( kRed, kYellow, kCyan, kBlue );
      
         uint pattern_x = uint(ModInteger(floor(current_position.x), PatternSize[2]));
         scanline_colour *= mask[pattern_x];
         
         break;
      }
      case 3:  /* 4 pattern - 720TVL (16:9) horiz resolution on a 4K screen */
      {
         const vec3 mask[4] = vec3[]( kRed, kGreen, kBlue, kBlack );
      
         uint pattern_x = uint(ModInteger(floor(current_position.x), PatternSize[3]));
         scanline_colour *= mask[pattern_x];
         
         break;
      }
      case 4:  /* 5 BRG pattern - 576TVL (16:9) horiz resolution on a 4K screen */
      {       
         const vec3 mask[5] = vec3[]( kRed, kMagenta, kBlue, kGreen, kGreen );
      
         uint pattern_x = uint(ModInteger(floor(current_position.x), PatternSize[4]));
         scanline_colour *= mask[pattern_x];
         
         break;
      }
      case 5:  /* 5 pattern - 576TVL (16:9) horiz resolution on a 4K screen */
      {      
         const vec3 mask[5] = vec3[]( kRed, kYellow, kGreen, kCyan, kBlue );
      
         uint pattern_x = uint(ModInteger(floor(current_position.x), PatternSize[5]));
         scanline_colour *= mask[pattern_x];
         
         break;
      }
      case 6:  /* 6 pattern - 480TVL (16:9) horiz resolution on a 4K screen */
      {
         const vec3 mask[6] = vec3[]( kRed, kRed, kGreen, kGreen, kBlue, kBlue );
      
         uint pattern_x = uint(ModInteger(floor(current_position.x), PatternSize[6]));
         scanline_colour *= mask[pattern_x];
         
         break;
      }
      case 7:  /* 7 pattern - 410TVL (16:9) horiz resolution on a 4K screen */
      {
         const vec3 mask[7] = vec3[]( kRed, kRed, kYellow, kGreen, kCyan, kBlue, kBlue );
      
         uint pattern_x = uint(ModInteger(floor(current_position.x), PatternSize[7]));
         scanline_colour *= mask[pattern_x];
         
         break;
      }
      case 8:  /* 9 pattern - 640TVL (16:9) horiz resolution on a *8K* screen */
      {
         const vec3 mask[9] = vec3[]( kBlack, kRed, kRed, kBlack, kGreen, kGreen, kBlack, kBlue, kBlue );
      
         uint pattern_x = uint(ModInteger(floor(current_position.x), PatternSize[8]));
         scanline_colour *= mask[pattern_x];
         
         break;
      }
      case 9:  /* 12 pattern - 480TVL (16:9) horiz resolution on a *8K* screen */
      {
         const vec3 mask[12] = vec3[]( kBlack, kRed, kRed, kRed, kBlack, kGreen, kGreen, kGreen, kBlack, kBlue, kBlue, kBlue );
      
         uint pattern_x = uint(ModInteger(floor(current_position.x), PatternSize[9]));
         scanline_colour *= mask[pattern_x];
         
         break;
      }
      default:
      {
         scanline_colour = vec3(0.0);
         
         break;
      }
   }

   const vec3 hdr10 = Hdr10(scanline_colour, params.PaperWhiteNits, params.ExpandGamut);

   //FragColor = vec4(scanline_colour, 1.0);
   FragColor = vec4(hdr10, 1.0);
}
