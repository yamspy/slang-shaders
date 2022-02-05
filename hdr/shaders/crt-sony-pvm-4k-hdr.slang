#version 450

/* 
A shader that tries to emulate a sony PVM type aperture grille screen but with full brightness.

The novel thing about this shader is that it relies on the HDR shaders to brighten up the image so that when 
we apply this shader which emulates the apperture grille the resulting screen isn't left too dark.  

I think you need at least a DisplayHDR 600 monitor but to get close to CRT levels of brightness I think DisplayHDR 1000.

Please Enable HDR in RetroArch 1.10+

NOTE: when this shader is envoked the Contrast, Peak Luminance and Paper White Luminance in the HDR menu do nothing instead set those values through the shader parameters 

For this shader set Peak Luminance AND Paper White Luminance to the peak luminance of your monitor.   

Also try to use a integer scaling - its just better - overscaling is fine.

This shader doesn't do any geometry warping or bouncing of light around inside the screen etc - I think these effects just add unwanted noise, I know people disagree. Please feel free to make you own and add them

Dont use this shader directly - use the hdr\crt-sony-pvm-4k-hdr.slangp and variants to have the proper chain of effects.

THIS SHADER DOES NOT SUPPORT WRGB OLED (Due to the sub pixel layout of WRGB - QD-OLED or LCD (and variants thereof screens are fine) 
*/

#pragma format A2B10G10R10_UNORM_PACK32

#define WHITE_BALANCE_CONTROL 0

#include "inverse_tonemap.h"
#include "hdr10.h"

#if WHITE_BALANCE_CONTROL
//#include "white_balance.h"
#endif // WHITE_BALANCE_CONTROL

layout(push_constant) uniform Push
{
   // User Settings
   float MaxNits;
   float LCDResolution;
   float LCDSubpixel;
   float ExpandGamut;
   float RedConvergence;
   float GreenConvergence;
   float BlueConvergence;

   // Developer Settings
   float CRTResolution;
   float Contrast;

   // Vertical Settings
   float RedScanlineMin;
   float RedScanlineMax;
   float RedScanlineAttack;
   float GreenScanlineMin;
   float GreenScanlineMax;
   float GreenScanlineAttack;
   float BlueScanlineMin;
   float BlueScanlineMax;
   float BlueScanlineAttack;

   // Horizontal Settings
   float RedBeamSharpness;
   float RedBeamAttack;
   float GreenBeamSharpness;
   float GreenBeamAttack;
   float BlueBeamSharpness;
   float BlueBeamAttack;

#if WHITE_BALANCE_CONTROL
   float WhiteTemperature;
   float WhiteTint;
#endif // WHITE_BALANCE_CONTROL
} params;


#pragma parameter Title                   "SONY PVM/BVM HDR SHADER"                           0.0      0.0   0.0      0.0
#pragma parameter Space0                  " "                                                 0.0      0.0   0.0      0.0
#pragma parameter Support0                "SUPPORTED: RGB/BGR LCD, QD-OLED Displays"          0.0      0.0   0.0      0.0
#pragma parameter Support1                "NOT SUPPORTED: WRGB OLED Displays"                 0.0      0.0   0.0      0.0
#pragma parameter Support2                "MIN SPEC: DisplayHDR 600, 4K"                      0.0      0.0   0.0      0.0
#pragma parameter Support3                "REC SPEC: DisplayHDR 1000, 4K+"                    0.0      0.0   0.0      0.0
#pragma parameter Space1                  " "                                                 0.0      0.0   0.0      0.0
#pragma parameter Instructions0           "HDR: Enable HDR: On"                               0.0      0.0   0.0      0.0
#pragma parameter Instructions1           "SCALING: Integer Scale: ON"                        0.0      0.0   0.0      0.0
#pragma parameter Instructions2           "SCALING: Integer Overscale: ON"                    0.0      0.0   0.0      0.0
#pragma parameter Instructions3           "SCALING: Apect Ratio: Core Provided"               0.0      0.0   0.0      0.0
#pragma parameter Space2                  " "                                                 0.0      0.0   0.0      0.0
#pragma parameter UserSettings            "USER SETTINGS:"                                    0.0      0.0   0.0      0.0
#pragma parameter MaxNits                 "    Display's Peak Luminance"                      700.0    0.0   10000.0  10.0
#pragma parameter LCDResolution           "    Display's Resolution: 4K/8K"                   0.0      0.0   1.0      1.0
#pragma parameter LCDSubpixel             "    Display's Subpixel Layout: RGB/BGR"            0.0      0.0   1.0      1.0
#pragma parameter ExpandGamut             "    Original/Vivid"                                0.0      0.0   1.0      1.0
#pragma parameter RedConvergence          "    Red Convergence"                               -0.50    -10.0 10.0     0.05
#pragma parameter GreenConvergence        "    Green Convergence"                             0.00     -10.0 10.0     0.05
#pragma parameter BlueConvergence         "    Blue Convergence"                              0.00     -10.0 10.0     0.05
#pragma parameter Space3                  " "                                                 0.0      0.0   0.0      0.0
#pragma parameter DeveloperSettings       "DEVELOPER SETTINGS:"                               0.0      0.0   0.0      0.0
#pragma parameter CRTResolution           "    CRT Resolution: 600TVL/800TVL/1000TVL"         0.0      0.0   2.0      1.0
#pragma parameter Contrast                "    Contrast"                                      -0.3     -3.0  3.0      0.05
#pragma parameter DeveloperSettings0      "    VERTICAL SETTINGS:"                            0.0      0.0   0.0      0.0
#pragma parameter RedScanlineMin          "        Red Scanline Min"                          0.55     0.0   2.0      0.01 
#pragma parameter RedScanlineMax          "        Red Scanline Max"                          0.82     0.0   2.0      0.01 
#pragma parameter RedScanlineAttack       "        Red Scanline Attack"                       0.65     0.0   1.0      0.01
#pragma parameter GreenScanlineMin        "        Green Scanline Min"                        0.55     0.0   2.0      0.01 
#pragma parameter GreenScanlineMax        "        Green Scanline Max"                        0.90     0.0   2.0      0.01 
#pragma parameter GreenScanlineAttack     "        Green Scanline Attack"                     0.13     0.0   1.0      0.01
#pragma parameter BlueScanlineMin         "        Blue Scanline Min"                         0.72     0.0   2.0      0.01 
#pragma parameter BlueScanlineMax         "        Blue Scanline Max"                         1.00     0.0   2.0      0.01 
#pragma parameter BlueScanlineAttack      "        Blue Scanline Attack"                      0.65     0.0   1.0      0.01
#pragma parameter DeveloperSettings1      "    HORIZONTAL SETTINGS:"                          0.0      0.0   0.0      0.0
#pragma parameter RedBeamSharpness        "        Red Beam Sharpness"                        1.75     0.0   5.0      0.05
#pragma parameter RedBeamAttack           "        Red Beam Attack"                           0.72     0.0   1.0      0.01
#pragma parameter GreenBeamSharpness      "        Green Beam Sharpness"                      1.60     0.0   5.0      0.05
#pragma parameter GreenBeamAttack         "        Green Beam Attack"                         0.80     0.0   1.0      0.01
#pragma parameter BlueBeamSharpness       "        Blue Beam Sharpness"                       1.90     0.0   5.0      0.05
#pragma parameter BlueBeamAttack          "        Blue Beam Attack"                          0.45     0.0   1.0      0.01

#if WHITE_BALANCE_CONTROL
//#pragma parameter WhiteTemperature     "White Temperature"                             6500.0   0.0   13000.0  50.0
//#pragma parameter WhiteTint            "White Tint"                                    0.0      -1.0   1.0      0.01
#endif // WHITE_BALANCE_CONTROL

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
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

   ScanlineSize         = global.OutputSize.y / global.SourceSize.y; 
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
#define kBeamWidth 0.5f

#define kRed     vec3(1.0, 0.0, 0.0)
#define kGreen   vec3(0.0, 1.0, 0.0)
#define kBlue    vec3(0.0, 0.0, 1.0)
#define kMagenta vec3(1.0, 0.0, 1.0)
#define kYellow  vec3(1.0, 1.0, 0.0)
#define kCyan    vec3(0.0, 1.0, 1.0)
#define kBlack   vec3(0.0, 0.0, 0.0)
#define kWhite   vec3(1.0, 1.0, 1.0)

#define kBGRAxis           2
#define kTVLAxis           3
#define kResolutionAxis    2
#define kMaxMaskSize       7

#define kNotSupported   { kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kRGBX           { kRed, kGreen, kBlue, kBlack, kBlack, kBlack, kBlack }
#define kBGRX           { kBlue, kGreen, kRed, kBlack, kBlack, kBlack, kBlack }

#define kRYCBX          { kRed, kYellow, kCyan, kBlue, kBlack, kBlack, kBlack }
#define kBCYRX          { kBlue, kCyan, kYellow, kRed, kBlack, kBlack, kBlack }

#define kRRGGBBX        { kRed, kRed, kGreen, kGreen, kBlue, kBlue, kBlack }
#define kBBGGRRX        { kBlue, kBlue, kGreen, kGreen, kRed, kRed, kBlack }

const uint kPhosphorMaskSize  [kResolutionAxis][kTVLAxis][kBGRAxis] = { 
   {  // 4K
      { 4, 4 },   // 600 TVL
      { 1, 1 },   // 800 TVL
      { 1, 1 }    // 1000 TVL
   },
   { // 8K
      { 7, 7 },   // 600 TVL
      { 5, 5 },   // 800 TVL
      { 4, 4 }    // 1000 TVL
   }
};

const vec3 kPhosphorMasks[kResolutionAxis][kTVLAxis][kBGRAxis][kMaxMaskSize] = {
   { // 4K
      { kRGBX, kBGRX },                   // 600 TVL
      { kNotSupported, kNotSupported },   // 800 TVL
      { kNotSupported, kNotSupported }    // 1000 TVL
   },
   { // 8K
      { kRRGGBBX, kBBGGRRX },             // 600 TVL
      { kRYCBX, kRYCBX },                 // 800 TVL
      { kRGBX, kBGRX }                    // 1000 TVL
   }
};

const mat4 kCubicBezier = mat4( 1.0f,  0.0f,  0.0f,  0.0f,
					                -3.0f,  3.0f,  0.0f,  0.0f,
					                 3.0f, -6.0f,  3.0f,  0.0f,
					                -1.0f,  3.0f, -3.0f,  1.0f );

const vec4 kFallOffControlPoints    = vec4(0.0f, 0.0f, 0.0f, 1.0f);
const vec4 kAttackControlPoints     = vec4(0.0f, 1.0f, 1.0f, 1.0f);
//const vec4 kScanlineControlPoints = vec4(1.0f, 1.0f, 0.0f, 0.0f);

vec4 RedBeamControlPoints(const bool falloff)
{
   return falloff ? kFallOffControlPoints + vec4(0.0f, 0.0f, params.RedBeamAttack, 0.0f) : kAttackControlPoints - vec4(0.0f, params.RedBeamAttack, 0.0f, 0.0f);
}

vec4 GreenBeamControlPoints(const bool falloff)
{
   return falloff ? kFallOffControlPoints + vec4(0.0f, 0.0f, params.GreenBeamAttack, 0.0f) : kAttackControlPoints - vec4(0.0f, params.GreenBeamAttack, 0.0f, 0.0f);
}

vec4 BlueBeamControlPoints(const bool falloff)
{
   return falloff ? kFallOffControlPoints + vec4(0.0f, 0.0f, params.BlueBeamAttack, 0.0f) : kAttackControlPoints - vec4(0.0f, params.BlueBeamAttack, 0.0f, 0.0f);
}

float Bezier(const float t0, const vec4 control_points)
{
   vec4 t = vec4(1.0, t0, t0*t0, t0*t0*t0);
   return dot(t, control_points * kCubicBezier);
}

float ToLinear1(float channel)
{
	return (channel > 0.04045f) ? pow(abs(channel) * (1.0f / 1.055f) + (0.055f / 1.055f), 2.4f) : channel * (1.0f / 12.92f);
}

vec3 ToLinear(vec3 colour)
{
	return vec3(ToLinear1(colour.r), ToLinear1(colour.g), ToLinear1(colour.b));
}

float Contrast1(float linear, float channel)
{
	return (channel > 0.04045f) ? linear * pow(abs(channel) * (1.0f / 1.055f) + (0.055f / 1.055f), params.Contrast) : channel * (1.0f / 12.92f);
}

vec3 Contrast(vec3 linear, vec3 colour)
{
	return vec3(Contrast1(linear.r, colour.r), Contrast1(linear.g, colour.g), Contrast1(linear.b, colour.b));
}

vec3 Ramp(const vec3 luminance, const vec3 colour)
{
    return clamp(luminance * colour, 0.0, 1.0); 
}

vec3 ScanlineColour(const float current_position, const float current_center, const float source_tex_coord_x, const vec3 narrowed_source_pixel_offset, inout float next_prev )
{
   const float current_source_position_y  = (vTexCoord.y * global.SourceSize.y) - next_prev;
   const float current_source_center_y    = floor(current_source_position_y) + 0.5f; 
   
   const float source_tex_coord_y         = current_source_center_y / global.SourceSize.y; 

   const vec2 source_tex_coord_0          = vec2(source_tex_coord_x, source_tex_coord_y);
   const vec2 source_tex_coord_1          = vec2(source_tex_coord_x + (1.0f / global.SourceSize.x), source_tex_coord_y);

   const float scanline_position          = current_source_center_y * ScanlineSize;
   const vec3 scanline_delta              = vec3(scanline_position) - (vec3(current_center) - Convergence);  
   
   vec3 beam_distance                     = abs(scanline_delta) - kBeamWidth;
   beam_distance                          = vec3(beam_distance.x < 0.0f ? 0.0f : beam_distance.x, 
                                                 beam_distance.y < 0.0f ? 0.0f : beam_distance.y, 
                                                 beam_distance.z < 0.0f ? 0.0f : beam_distance.z);
   const vec3 scanline_distance           = beam_distance * InverseScanlineSize * 2.0f;

   next_prev = scanline_delta.x > 0.0f ? 1.0f : -1.0f;

   const vec3 sdr_colour_0    = texture(Source, source_tex_coord_0).xyz;
   const vec3 sdr_colour_1    = texture(Source, source_tex_coord_1).xyz;

   const vec3 sdr_linear_0    = ToLinear(sdr_colour_0);
   const vec3 sdr_linear_1    = ToLinear(sdr_colour_1);

   const vec3 sdr_constrast_0 = Contrast(sdr_linear_0, sdr_colour_0);
   const vec3 sdr_constrast_1 = Contrast(sdr_linear_1, sdr_colour_1);

#if WHITE_BALANCE_CONTROL
   //const vec3 sdr_balanced_0  = WhiteBalance(sdr_constrast_0, params.WhiteTemperature, params.WhiteTint); 
   //const vec3 sdr_balanced_1  = WhiteBalance(sdr_constrast_1, params.WhiteTemperature, params.WhiteTint);
#else
   const vec3 sdr_balanced_0  = sdr_constrast_0;
   const vec3 sdr_balanced_1  = sdr_constrast_1;
#endif // WHITE_BALANCE_CONTROL

   // HACK: To get maximum brightness we just set paper white luminance to max luminance
   const vec3 hdr_colour_0    = InverseTonemap(sdr_balanced_0, params.MaxNits, params.MaxNits, kLumaRatio);
   const vec3 hdr_colour_1    = InverseTonemap(sdr_balanced_1, params.MaxNits, params.MaxNits, kLumaRatio);

   /* Horizontal interpolation between pixels */ 
   const vec3 horiz_interp = vec3(Bezier(narrowed_source_pixel_offset.x, RedBeamControlPoints(sdr_linear_0.x > sdr_linear_1.x)), 
                                  Bezier(narrowed_source_pixel_offset.y, GreenBeamControlPoints(sdr_linear_0.y > sdr_linear_1.y)), 
                                  Bezier(narrowed_source_pixel_offset.z, BlueBeamControlPoints(sdr_linear_0.z > sdr_linear_1.z)));  

   const vec3 hdr_colour  = mix(hdr_colour_0, hdr_colour_1, horiz_interp);
   const vec3 sdr_colour  = mix(sdr_linear_0, sdr_linear_1, horiz_interp);

   const float red_scanline_distance   = clamp(scanline_distance.x / ((sdr_colour.r * (params.RedScanlineMax - params.RedScanlineMin)) + params.RedScanlineMin),       0.0f, 1.0f);
   const float green_scanline_distance = clamp(scanline_distance.y / ((sdr_colour.g * (params.GreenScanlineMax - params.GreenScanlineMin)) + params.GreenScanlineMin), 0.0f, 1.0f);
   const float blue_scanline_distance  = clamp(scanline_distance.z / ((sdr_colour.b * (params.BlueScanlineMax - params.BlueScanlineMin)) + params.BlueScanlineMin),    0.0f, 1.0f);

   const vec4 red_control_points    = vec4(1.0f, 1.0f, sdr_colour.r * params.RedScanlineAttack,    0.0f);
   const vec4 green_control_points  = vec4(1.0f, 1.0f, sdr_colour.g * params.GreenScanlineAttack,  0.0f);
   const vec4 blue_control_points   = vec4(1.0f, 1.0f, sdr_colour.b * params.BlueScanlineAttack,   0.0f);

   const vec3 luminance = vec3(Bezier(red_scanline_distance, red_control_points),
                               Bezier(green_scanline_distance, green_control_points),
                               Bezier(blue_scanline_distance, blue_control_points));

   return luminance * hdr_colour;
}

void main()
{
   const vec2 current_position               = vTexCoord * global.OutputSize.xy;
   const float current_center                = floor(current_position.y) + 0.5f;

   const float current_source_position_x     = vTexCoord.x * global.SourceSize.x;
   const float current_source_center_x       = floor(current_source_position_x) + 0.5f; 
   
   const float source_tex_coord_x            = current_source_center_x / global.SourceSize.x; 

   const float source_pixel_offset           = current_source_position_x - floor(current_source_position_x);

   const vec3 beam_sharpness                 = vec3(params.RedBeamSharpness, params.GreenBeamSharpness, params.BlueBeamSharpness);
   const vec3 narrowed_source_pixel_offset   = clamp(((vec3(source_pixel_offset) - vec3(0.5f)) * beam_sharpness) + vec3(0.5f), vec3(0.0f), vec3(1.0f));

   float next_prev = 0.0f;

   const vec3 scanline_colour0 = ScanlineColour(current_position.y, current_center, source_tex_coord_x, narrowed_source_pixel_offset, next_prev);
   const vec3 scanline_colour1 = ScanlineColour(current_position.y, current_center, source_tex_coord_x, narrowed_source_pixel_offset, next_prev);

   vec3 scanline_colour = scanline_colour0 + scanline_colour1;

   {
      uint lcd_subpixel_layout = uint(params.LCDSubpixel);
      uint crt_resolution      = uint(params.CRTResolution);
      uint lcd_resolution      = uint(params.LCDResolution);

      uint pattern_x = uint(ModInteger(floor(current_position.x), kPhosphorMaskSize[lcd_resolution][crt_resolution][lcd_subpixel_layout]));

      scanline_colour *= kPhosphorMasks[lcd_resolution][crt_resolution][lcd_subpixel_layout][pattern_x];      
   }

   // HACK: To get maximum brightness we just set paper white luminance to max luminance
   const vec3 hdr10 = Hdr10(scanline_colour, params.MaxNits, params.ExpandGamut);

   //FragColor = vec4(scanline_colour, 1.0);
   FragColor = vec4(hdr10, 1.0);
}
