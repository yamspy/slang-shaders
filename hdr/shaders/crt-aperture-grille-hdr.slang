#version 450

/* 
A shader that tries to emulate a sony PVM type aperture grille screen but with full brightness.

The novel thing about this shader is that it relies on the HDR shaders to brighten up the image so that when 
we apply this shader which emulates the apperture grille the resulting screen isn't left too dark.  

I think you need at least a DisplayHDR 600 monitor but to get close to CRT levels of brightness I think DisplayHDR 1000.

Please Enable HDR in RetroArch 1.10+

NOTE: when this shader is envoked the Contrast, Peak Luminance and Paper White Luminance in the HDR menu do nothing instead set those values through the shader parameters 

For this shader set Paper White Luminance to above 700 and Peak Luminance to the peak luminance of your monitor.  

Also try to use a integer scaling - its just better - overscaling is fine.

This shader doesn't do any geometry warping or bouncing of light around inside the screen etc - I think these effects just add unwanted noise, I know people disagree. Please feel free to make you own and add them

Dont use this shader directly - use the hdr\crt-make-model-hdr.slangp where make and model are the make and model of the CRT you want.

THIS SHADER DOES NOT SUPPORT WRGB OLED (Due to the sub pixel layout of WRGB - RGB QD-OLED or LCD (and variants thereof screens are fine)
*/

#pragma format A2B10G10R10_UNORM_PACK32

#define WHITE_BALANCE_CONTROL 0

#include "include\hdr10.h"

#if WHITE_BALANCE_CONTROL
//#include "include\white_balance.h"
#endif // WHITE_BALANCE_CONTROL

layout(push_constant) uniform Push
{
#include "include\user_properties.h"

   float CRTResolution;
   
#include "include\developer_properties.h"
} params;

#include "include\user_parameters.h"

#pragma parameter Space3                  " "                                                 0.0      0.0   0.0      0.0
#pragma parameter DeveloperSettings       "DEVELOPER SETTINGS:"                               0.0      0.0   0.0      0.0
#pragma parameter CRTResolution           "    CRT Resolution: 600TVL/800TVL/1000TVL"         0.0      0.0   2.0      1.0

#include "include\developer_parameters.h"

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

#define kMG             { kMagenta, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kGM             { kGreen, kMagenta, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kBGR            { kBlue, kGreen, kRed, kBlack, kBlack, kBlack, kBlack }
#define kRGB            { kRed, kGreen, kBlue, kBlack, kBlack, kBlack, kBlack }

#define kRGBX           { kRed, kGreen, kBlue, kBlack, kBlack, kBlack, kBlack }
#define kBGRX           { kBlue, kGreen, kRed, kBlack, kBlack, kBlack, kBlack }

#define kRYCBX          { kRed, kYellow, kCyan, kBlue, kBlack, kBlack, kBlack }
#define kBCYRX          { kBlue, kCyan, kYellow, kRed, kBlack, kBlack, kBlack }

#define kRRGGBBX        { kRed, kRed, kGreen, kGreen, kBlue, kBlue, kBlack }
#define kBBGGRRX        { kBlue, kBlue, kGreen, kGreen, kRed, kRed, kBlack }

const uint kPhosphorMaskSize[kResolutionAxis][kTVLAxis] = { { 4, 3, 2 }, { 7, 5, 4 } }; //4K: 600 TVL, 800 TVL, 1000 TVL   8K: 600 TVL, 800 TVL, 1000 TVL

const vec3 kPhosphorMasks[kResolutionAxis][kTVLAxis][kBGRAxis][kMaxMaskSize] = {
   { // 4K
      { kRGBX, kBGRX },            // 600 TVL
      { kBGR, kRGB },              // 800 TVL
      { kMG, kGM }                 // 1000 TVL
   },
   { // 8K
      { kRRGGBBX, kBBGGRRX },      // 600 TVL
      { kRYCBX, kRYCBX },          // 800 TVL
      { kRGBX, kBGRX }             // 1000 TVL
   }
};

float ModInteger(float a, float b) 
{
    float m = a - floor((a + 0.5) / b) * b;
    return floor(m + 0.5);
}

#include "include\scanline_generation.h"

void main()
{
   const vec2 current_position = vTexCoord * global.OutputSize.xy;

   vec3 scanline_colour = GenerateScanline(current_position);

   {
      uint lcd_subpixel_layout = uint(params.LCDSubpixel);
      uint crt_resolution      = uint(params.CRTResolution);
      uint lcd_resolution      = uint(params.LCDResolution);

      uint mask = uint(ModInteger(floor(current_position.x), kPhosphorMaskSize[lcd_resolution][crt_resolution]));

      scanline_colour *= kPhosphorMasks[lcd_resolution][crt_resolution][lcd_subpixel_layout][mask];      
   }

   // HACK: To get maximum brightness we just set paper white luminance to max luminance
   const vec3 hdr10 = Hdr10(scanline_colour, params.PaperWhiteNits, params.ExpandGamut);

   //FragColor = vec4(scanline_colour, 1.0);
   FragColor = vec4(hdr10, 1.0);
}
