#version 450

/* 
A shader that tries to emulate a slot mask screens but with full brightness.

The novel thing about this shader is that it relies on the HDR shaders to brighten up the image so that when 
we apply this shader which emulates the slot mask the resulting screen isn't left too dark.  

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
#include "include\developer_properties.h"
} params;

#include "include\user_parameters.h"
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
#define kMaxMaskSize       8
#define kMaxSlotSizeX      2
#define kMaxSlotSizeY      4

#define kXXXX     { kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kMG       { kMagenta, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kGM       { kGreen, kMagenta, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kBGR      { kBlue, kGreen, kRed, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kRGB      { kRed, kGreen, kBlue, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kRGBX     { kRed, kGreen, kBlue, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kBGRX     { kBlue, kGreen, kRed, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kRYCBX    { kRed, kYellow, kCyan, kBlue, kBlack, kBlack, kBlack, kBlack }
#define kBCYRX    { kBlue, kCyan, kYellow, kRed, kBlack, kBlack, kBlack, kBlack }

#define kRRGGBBX  { kRed, kRed, kGreen, kGreen, kBlue, kBlue, kBlack, kBlack }
#define kBBGGRRX  { kBlue, kBlue, kGreen, kGreen, kRed, kRed, kBlack, kBlack }

#define kMGMG_MGXX_MGMG_XXMG   { { kMG, kMG }, { kMG, kXXXX }, { kMG, kMG }, { kXXXX, kMG } }
#define kGMGM_GMXX_GMGM_XXGM   { { kGM, kGM }, { kGM, kXXXX }, { kGM, kGM }, { kXXXX, kGM } }

#define kBGRBGR_BGRXXX_BGRBGR_XXXBGR   { { kBGR, kBGR }, { kBGR, kXXXX }, { kBGR, kBGR }, { kXXXX, kBGR } }
#define kRGBRGB_RGBXXX_RGBRGB_XXXRGB   { { kRGB, kRGB }, { kRGB, kXXXX }, { kRGB, kRGB }, { kXXXX, kRGB } }

#define kRGBXRGBX_RGBXXXXX_RGBXRGBX_XXXXRGBX   { { kRGBX, kRGBX }, { kRGBX, kXXXX }, { kRGBX, kRGBX }, { kXXXX, kRGBX } }
#define kBGRXBGRX_BGRXXXXX_BGRXBGRX_XXXXBGRX   { { kBGRX, kBGRX }, { kBGRX, kXXXX }, { kBGRX, kBGRX }, { kXXXX, kBGRX } }

#define kRYCBXRYCBX_RYCBXXXXX_RYCBXRYCBX_XXXXRYCBX   { { kRYCBX, kRYCBX }, { kRYCBX, kXXXX }, { kRYCBX, kRYCBX }, { kXXXX, kRYCBX } }
#define kBCYRXBCYRX_BCYRXXXXX_BCYRXBCYRX_XXXXBCYRX   { { kBCYRX, kBCYRX }, { kBCYRX, kXXXX }, { kBCYRX, kBCYRX }, { kXXXX, kBCYRX } }

#define kRRGGBBXRRGGBBX_RRGGBBXXXXX_RRGGBBXRRGGBBX_XXXXRRGGBBX   { { kRRGGBBX, kRRGGBBX }, { kRRGGBBX, kXXXX }, { kRRGGBBX, kRRGGBBX }, { kXXXX, kRRGGBBX } }
#define kBBGGRRXBBGGRRX_BBGGRRXXXXX_BBGGRRXBBGGRRX_XXXXBBGGRRX   { { kBBGGRRX, kBBGGRRX }, { kBBGGRRX, kXXXX }, { kBBGGRRX, kBBGGRRX }, { kXXXX, kBBGGRRX } }

const uint kPhosphorMaskSize[kResolutionAxis][kTVLAxis] = { { 4, 3, 2 }, { 7, 5, 4 } }; //4K: 600 TVL, 800 TVL, 1000 TVL   8K: 600 TVL, 800 TVL, 1000 TVL

const vec3 kPhosphorMasks[kResolutionAxis][kTVLAxis][kBGRAxis][kMaxSlotSizeY][kMaxSlotSizeX][kMaxMaskSize] = {
   { // 4K
      { kRGBXRGBX_RGBXXXXX_RGBXRGBX_XXXXRGBX, kBGRXBGRX_BGRXXXXX_BGRXBGRX_XXXXBGRX },   // 600 TVL
      { kBGRBGR_BGRXXX_BGRBGR_XXXBGR, kRGBRGB_RGBXXX_RGBRGB_XXXRGB },                   // 800 TVL
      { kMGMG_MGXX_MGMG_XXMG, kGMGM_GMXX_GMGM_XXGM }                                    // 1000 TVL
   },
   { // 8K
      { kRRGGBBXRRGGBBX_RRGGBBXXXXX_RRGGBBXRRGGBBX_XXXXRRGGBBX, kBBGGRRXBBGGRRX_BBGGRRXXXXX_BBGGRRXBBGGRRX_XXXXBBGGRRX },   // 600 TVL
      { kRYCBXRYCBX_RYCBXXXXX_RYCBXRYCBX_XXXXRYCBX, kBCYRXBCYRX_BCYRXXXXX_BCYRXBCYRX_XXXXBCYRX },                           // 800 TVL
      { kRGBXRGBX_RGBXXXXX_RGBXRGBX_XXXXRGBX, kBGRXBGRX_BGRXXXXX_BGRXBGRX_XXXXBGRX }                                        // 1000 TVL
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

      uint slot_x = uint(ModInteger(floor(current_position.x / float(kPhosphorMaskSize[lcd_resolution][crt_resolution])), kMaxSlotSizeX));
      uint slot_y = uint(ModInteger(floor(current_position.y), kMaxSlotSizeY));

      uint mask = uint(ModInteger(floor(current_position.x), kPhosphorMaskSize[lcd_resolution][crt_resolution]));

      scanline_colour *= kPhosphorMasks[lcd_resolution][crt_resolution][lcd_subpixel_layout][slot_x][slot_y][mask];      
   }

   // HACK: To get maximum brightness we just set paper white luminance to max luminance
   const vec3 hdr10 = Hdr10(scanline_colour, params.PaperWhiteNits, params.ExpandGamut);

   //FragColor = vec4(scanline_colour, 1.0);
   FragColor = vec4(hdr10, 1.0);
}
