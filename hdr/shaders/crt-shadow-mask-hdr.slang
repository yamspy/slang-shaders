#version 450

/* 
A shader that tries to emulate a shadow mask screens but with full brightness.

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

   float ShadowMaskPattern;

#include "include\developer_properties.h"
} params;

#include "include\user_parameters.h"

#pragma parameter Space3                  " "                                                   0.0      0.0   0.0      0.0
#pragma parameter DeveloperSettings       "DEVELOPER SETTINGS:"                                 0.0      0.0   0.0      0.0
#pragma parameter ShadowMaskPattern           "    Shadow Mask: Fine/2x1/1x2/Diagonal/Coarse/8K Coarse"  0.0      0.0   5.0      1.0

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
#define kPatternAxis       6
#define kResolutionAxis    2
#define kMaxMaskSize       12
#define kMaxShadowSize     8
#define kMaxGridSize       2

#define kXXXX           { kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kMG             { kMagenta, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kGM             { kGreen, kMagenta, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kMGCRYB         { kMagenta, kGreen, kCyan, kRed, kYellow, kBlue, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kRYBMGC         { kRed, kYellow, kBlue, kMagenta, kGreen, kCyan, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kRYCB            { kRed, kYellow, kCyan, kBlue, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kCBRY            { kCyan, kBlue, kRed, kYellow, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kBGR            { kBlue, kGreen, kRed, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kRBG            { kRed, kBlue, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kGRB            { kGreen, kRed, kBlue, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kYCM            { kCyan, kYellow, kMagenta, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kMYC            { kMagenta, kCyan, kYellow, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kCMY            { kYellow, kMagenta, kCyan, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kGBRGBR         { kGreen, kBlue, kRed, kGreen, kBlue, kRed, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
// TODO: #define kGBRGBR         { kGreen, kBlue, kRed, kGreen, kBlue, kRed, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kGYRMBC         { kGreen, kYellow, kRed, kMagenta, kBlue, kCyan, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
// TODO: #define kGYRMBC         { kGreen, kYellow, kRed, kMagenta, kBlue, kCyan, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kMBCGYR         { kMagenta, kBlue, kCyan, kGreen, kYellow, kRed, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
// TODO: #define kMBCGYR         { kMagenta, kBlue, kCyan, kGreen, kYellow, kRed, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kGRRBBG         { kGreen, kRed, kRed, kBlue, kBlue, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kBBGGRR         { kBlue, kBlue, kGreen, kGreen, kRed, kRed, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kGBBRRG         { kGreen, kBlue, kBlue, kRed, kRed, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kRRGGBB         { kRed, kRed, kGreen, kGreen, kBlue, kBlue, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kGGRRRRBBBBGG   { kGreen, kGreen, kRed, kRed, kRed, kRed, kBlue, kBlue, kBlue, kBlue, kGreen, kGreen }
#define kBBBBGGGGRRRR   { kBlue, kBlue, kBlue, kBlue, kGreen, kGreen, kGreen, kGreen, kRed, kRed, kRed, kRed }

#define kGGBBBBRRRRGG   { kGreen, kGreen, kBlue, kBlue, kBlue, kBlue, kRed, kRed, kRed, kRed, kGreen, kGreen }
#define kRRRRGGGGBBBB   { kRed, kRed, kRed, kRed, kGreen, kGreen, kGreen, kGreen, kBlue, kBlue, kBlue, kBlue }

#define kMG_GM             { kMG, kGM, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }
#define kGM_MG             { kGM, kMG, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }

#define kBGR_RBG_GRB       { kBGR, kRBG, kGRB, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }
// TODO: #define kBGR_RBG  { kBGR, kRBG, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }

#define kYCM_MYC_CMY       { kYCM, kMYC, kCMY, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }
// TODO: #define kBGR_RBG  { kYCM, kMYC, kCMY, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }

#define kMGMG_GMGM         { kMG, kMG, kGM, kGM, kXXXX, kXXXX, kXXXX, kXXXX }
// TODO: #define kMG_GM    { kMG, kGM, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }

#define kGRRBBG_GRRBBG_BBGGRR_BBGGRR  { kGRRBBG, kGRRBBG, kBBGGRR, kBBGGRR, kXXXX, kXXXX, kXXXX, kXXXX }
#define kGBBRRG_GBBRRG_RRGGBB_RRGGBB  { kGBBRRG, kGBBRRG, kRRGGBB, kRRGGBB, kXXXX, kXXXX, kXXXX, kXXXX }

#define kGGRRRRBBBBGG_GGRRRRBBBBGG_GGRRRRBBBBGG_GGRRRRBBBBGG_BBBBGGGGRRRR_BBBBGGGGRRRR_BBBBGGGGRRRR_BBBBGGGGRRRR  { kGGRRRRBBBBGG, kGGRRRRBBBBGG, kGGRRRRBBBBGG, kGGRRRRBBBBGG, kBBBBGGGGRRRR, kBBBBGGGGRRRR, kBBBBGGGGRRRR, kBBBBGGGGRRRR }
#define kGGBBBBRRRRGG_GGBBBBRRRRGG_GGBBBBRRRRGG_GGBBBBRRRRGG_RRRRGGGGBBBB_RRRRGGGGBBBB_RRRRGGGGBBBB_RRRRGGGGBBBB  { kGGBBBBRRRRGG, kGGBBBBRRRRGG, kGGBBBBRRRRGG, kGGBBBBRRRRGG, kRRRRGGGGBBBB, kRRRRGGGGBBBB, kRRRRGGGGBBBB, kRRRRGGGGBBBB }

#define kRYCB_kCBRY  { kRYCB, kCBRY, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }
// TODO: #define kRYCB_kCBRY  { kRYCB, kCBRY, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }

//#define kMGCRYB_RYBMGC  { kMGCRYB, kRYBMGC, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }
// TODO: #define kMGCRYB_RYBMGC  { kMGCRYB, kRYBMGC, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }

//#define kMGCRYB_MGCRYB_RYBMGC_RYBMGC  { kMGCRYB, kMGCRYB, kRYBMGC, kRYBMGC, kXXXX, kXXXX, kXXXX, kXXXX }
// TODO: #define kMGCRYB_MGCRYB_RYBMGC_RYBMGC  { kMGCRYB, kMGCRYB, kRYBMGC, kRYBMGC, kXXXX, kXXXX, kXXXX, kXXXX }

#define kGBRGBR_GYRMBC_GBRGBR_MBCGYR  { kGBRGBR, kGYRMBC, kGBRGBR, kMBCGYR, kXXXX, kXXXX, kXXXX, kXXXX }
// TODO: #define kGBRGBR_GYRMBC_GBRGBR_MBCGYR  { kGBRGBR, kGYRMBC, kGBRGBR, kMBCGYR, kXXXX, kXXXX, kXXXX, kXXXX }

const uint kPhosphorMaskSize[kPatternAxis] = { 2, 2, 4, 3, 6, 12 }; // , 6, 6, 6 
const uint kShadowMaskSize[kPatternAxis] =   { 2, 4, 2, 3, 4, 8, };  // , 2, 4, 4 

const vec3 kPhosphorMasks[kPatternAxis][kBGRAxis][kMaxShadowSize][kMaxMaskSize]  = {
   { kMG_GM, kGM_MG },  // Fine
   { kMGMG_GMGM, kMGMG_GMGM },  
   { kRYCB_kCBRY, kRYCB_kCBRY },
   { kBGR_RBG_GRB, kBGR_RBG_GRB },            // Coarse0
   //{ kYCM_MYC_CMY, kYCM_MYC_CMY },
   { kGRRBBG_GRRBBG_BBGGRR_BBGGRR, kGBBRRG_GBBRRG_RRGGBB_RRGGBB },            // Coarse1
   { kGGRRRRBBBBGG_GGRRRRBBBBGG_GGRRRRBBBBGG_GGRRRRBBBBGG_BBBBGGGGRRRR_BBBBGGGGRRRR_BBBBGGGGRRRR_BBBBGGGGRRRR, kGGBBBBRRRRGG_GGBBBBRRRRGG_GGBBBBRRRRGG_GGBBBBRRRRGG_RRRRGGGGBBBB_RRRRGGGGBBBB_RRRRGGGGBBBB_RRRRGGGGBBBB },   // 8K  
//   { kMGCRYB_RYBMGC, kMGCRYB_RYBMGC },   // Tile0                                                                                                          
//   { kMGCRYB_MGCRYB_RYBMGC_RYBMGC, kMGCRYB_MGCRYB_RYBMGC_RYBMGC },      // Tile1                                                                                                     
//   { kGBRGBR_GYRMBC_GBRGBR_MBCGYR, kGBRGBR_GYRMBC_GBRGBR_MBCGYR }       // Tile2
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
      uint lcd_subpixel_layout   = uint(params.LCDSubpixel);
      uint shadow_mask           = uint(params.ShadowMaskPattern);
      
      uint shadow_y = uint(ModInteger(floor(current_position.y), kShadowMaskSize[shadow_mask]));

      uint mask = uint(ModInteger(floor(current_position.x), kPhosphorMaskSize[shadow_mask]));

      scanline_colour *= kPhosphorMasks[shadow_mask][lcd_subpixel_layout][shadow_y][mask];      
   }

   // HACK: To get maximum brightness we just set paper white luminance to max luminance
   const vec3 hdr10 = Hdr10(scanline_colour, params.PaperWhiteNits, params.ExpandGamut);

   //FragColor = vec4(scanline_colour, 1.0);
   FragColor = vec4(hdr10, 1.0);
}
