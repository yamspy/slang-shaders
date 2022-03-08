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

layout(push_constant) uniform Push
{
   // User Settings
   float hcrt_hdr;
   float hcrt_max_nits;
   float hcrt_paper_white_nits;
   float hcrt_lcd_resolution;
   float hcrt_lcd_subpixel;
   float hcrt_brightness;
   float hcrt_contrast;
   float hcrt_expand_gamut;
   float hcrt_red_vertical_convergence;
   float hcrt_green_vertical_convergence;
   float hcrt_blue_vertical_convergence;
   float hcrt_red_horizontal_convergence;
   float hcrt_green_horizontal_convergence;
   float hcrt_blue_horizontal_convergence;

   // Developer Settings
   float hcrt_crt_screen_type;
   float hcrt_crt_resolution;

   // Vertical Settings
   float hcrt_red_scanline_min;
   float hcrt_red_scanline_max;
   float hcrt_red_scanline_attack;
   float hcrt_green_scanline_min;
   float hcrt_green_scanline_max;
   float hcrt_green_scanline_attack;
   float hcrt_blue_scanline_min;
   float hcrt_blue_scanline_max;
   float hcrt_blue_scanline_attack;

   // Horizontal Settings
   float hcrt_red_beam_sharpness;
   float hcrt_red_beam_attack;
   float hcrt_green_beam_sharpness;
   float hcrt_green_beam_attack;
   float hcrt_blue_beam_sharpness;
   float hcrt_blue_beam_attack;

} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;

   float hcrt_colour_system;
   float hcrt_colour_space;
   float hcrt_white_temperature;
   float hcrt_gamma;
} global;


#pragma parameter hcrt_title                         "SONY PVM/BVM HDR SHADER"                                   0.0      0.0   0.0001   0.0
#pragma parameter hcrt_space0                        " "                                                         0.0      0.0   0.0001   0.0
#pragma parameter hcrt_support0                      "SUPPORTED: RGB/BGR LCD, QD-OLED Displays"                  0.0      0.0   0.0001   0.0
#pragma parameter hcrt_support1                      "NOT SUPPORTED: WRGB OLED Displays"                         0.0      0.0   0.0001   0.0
#pragma parameter hcrt_support2                      "MIN SPEC: DisplayHDR 600, 4K, RetroArch v1.10"             0.0      0.0   0.0001   0.0
#pragma parameter hcrt_support3                      "REC SPEC: DisplayHDR 1000, 4K+, RetroArch v1.10"           0.0      0.0   0.0001   0.0
#pragma parameter hcrt_space1                        " "                                                         0.0      0.0   0.0001   0.0
#pragma parameter hcrt_instructions0                 "HDR: Enable HDR: On"                                       0.0      0.0   0.0001   0.0
#pragma parameter hcrt_instructions1                 "SCALING: Integer Scale: ON"                                0.0      0.0   0.0001   0.0
#pragma parameter hcrt_instructions2                 "SCALING: Integer Overscale: ON"                            0.0      0.0   0.0001   0.0
#pragma parameter hcrt_instructions3                 "SCALING: Apect Ratio: Core Provided"                       0.0      0.0   0.0001   0.0
#pragma parameter hcrt_space2                        " "                                                         0.0      0.0   0.0001   0.0
#pragma parameter hcrt_user_settings                 "USER SETTINGS:"                                            0.0      0.0   0.0001   0.0
#pragma parameter hcrt_hdr                           "    SDR | HDR"                                             1.0      0.0   1.0      1.0
#pragma parameter hcrt_max_nits                      "    Display's Peak Luminance"                              700.0    0.0   10000.0  10.0
#pragma parameter hcrt_paper_white_nits              "    Display's Paper White Luminance"                       700.0    0.0   10000.0  10.0
#pragma parameter hcrt_lcd_resolution                "    Display's Resolution: 4K | 8K"                         0.0      0.0   1.0      1.0
#pragma parameter hcrt_lcd_subpixel                  "    Display's Subpixel Layout: RGB | BGR"                  0.0      0.0   1.0      1.0
#pragma parameter hcrt_brightness                    "    Brightness"                                            0.0      -1.0  1.0      0.01
#pragma parameter hcrt_contrast                      "    Contrast"                                              0.0      -1.0  1.0      0.01
#pragma parameter hcrt_gamma                         "    Gamma"                                                 0.0      -1.0   1.0     0.01
#pragma parameter hcrt_red_vertical_convergence      "    Red Vertical Convergence"                              0.00     -10.0 10.0     0.01
#pragma parameter hcrt_green_vertical_convergence    "    Green Vertical Convergence"                            0.00     -10.0 10.0     0.01
#pragma parameter hcrt_blue_vertical_convergence     "    Blue Vertical Convergence"                             0.00     -10.0 10.0     0.01
#pragma parameter hcrt_red_horizontal_convergence    "    Red Horizontal Convergence"                            0.00     -10.0 10.0     0.01
#pragma parameter hcrt_green_horizontal_convergence  "    Green Horizontal Convergence"                          0.00     -10.0 10.0     0.01
#pragma parameter hcrt_blue_horizontal_convergence   "    Blue Horizontal Convergence"                           0.00     -10.0 10.0     0.01

#pragma parameter hcrt_space3                        " "                                                         0.0      0.0   0.0001   0.0
#pragma parameter hcrt_developer_settings            "DEVELOPER SETTINGS:"                                       0.0      0.0   0.0001   0.0
#pragma parameter hcrt_crt_screen_type               "    CRT Type: APERTURE GRILLE | SHADOW MASK | SLOT MASK"   0.0      0.0   2.0      1.0
#pragma parameter hcrt_crt_resolution                "    CRT Resolution: 600TVL | 800TVL | 1000TVL"             0.0      0.0   2.0      1.0
#pragma parameter hcrt_colour_system                 "    CRT Colour System: PAL | NTSC-U | NTSC-J"              1.0      0.0   2.0      1.0
#pragma parameter hcrt_colour_space                  "    Colour Space: Rec.601/Rec.709 | sRGB"                  0.0      0.0   1.0      1.0
#pragma parameter hcrt_white_temperature             "    White Point: (PAL:D65, NTSC-U:D65, NTSC-J:D93)"        0.0      -5000.0  12000.0      100.0
#pragma parameter hcrt_expand_gamut                  "    Original/Vivid"                                        0.0      0.0   1.0      1.0

#pragma parameter hcrt_developer_settings0           "    VERTICAL SETTINGS:"                                    0.0      0.0   0.0001   0.0
#pragma parameter hcrt_red_scanline_min              "        Red Scanline Min"                                  0.50     0.0   2.0      0.01 
#pragma parameter hcrt_red_scanline_max              "        Red Scanline Max"                                  1.00     0.0   2.0      0.01 
#pragma parameter hcrt_red_scanline_attack           "        Red Scanline Attack"                               0.20     0.0   1.0      0.01
#pragma parameter hcrt_green_scanline_min            "        Green Scanline Min"                                0.50     0.0   2.0      0.01 
#pragma parameter hcrt_green_scanline_max            "        Green Scanline Max"                                1.00     0.0   2.0      0.01 
#pragma parameter hcrt_green_scanline_attack         "        Green Scanline Attack"                             0.20     0.0   1.0      0.01
#pragma parameter hcrt_blue_scanline_min             "        Blue Scanline Min"                                 0.50     0.0   2.0      0.01 
#pragma parameter hcrt_blue_scanline_max             "        Blue Scanline Max"                                 1.00     0.0   2.0      0.01 
#pragma parameter hcrt_blue_scanline_attack          "        Blue Scanline Attack"                              0.20     0.0   1.0      0.01
#pragma parameter hcrt_developer_settings1           "    HORIZONTAL SETTINGS:"                                  0.0      0.0   0.0001   0.0
#pragma parameter hcrt_red_beam_sharpness            "        Red Beam Sharpness"                                1.75     0.0   5.0      0.05
#pragma parameter hcrt_red_beam_attack               "        Red Beam Attack"                                   0.50     0.0   2.0      0.01
#pragma parameter hcrt_green_beam_sharpness          "        Green Beam Sharpness"                              1.75     0.0   5.0      0.05
#pragma parameter hcrt_green_beam_attack             "        Green Beam Attack"                                 0.50     0.0   2.0      0.01
#pragma parameter hcrt_blue_beam_sharpness           "        Blue Beam Sharpness"                               1.75     0.0   5.0      0.05
#pragma parameter hcrt_blue_beam_attack              "        Blue Beam Attack"                                  0.50     0.0   2.0      0.01


#define HCRT_HDR                            params.hcrt_hdr
#define HCRT_MAX_NITS                       params.hcrt_max_nits
#define HCRT_PAPER_WHITE_NITS               params.hcrt_paper_white_nits
#define HCRT_LCD_RESOLUTION                 params.hcrt_lcd_resolution 
#define HCRT_LCD_SUBPIXEL                   params.hcrt_lcd_subpixel
#define HCRT_BRIGHTNESS                     params.hcrt_brightness
#define HCRT_CONTRAST                       params.hcrt_contrast
#define HCRT_EXPAND_GAMUT                   params.hcrt_expand_gamut
#define HCRT_RED_VERTICAL_CONVERGENCE       params.hcrt_red_vertical_convergence
#define HCRT_GREEN_VERTICAL_CONVERGENCE     params.hcrt_green_vertical_convergence
#define HCRT_BLUE_VERTICAL_CONVERGENCE      params.hcrt_blue_vertical_convergence
#define HCRT_RED_HORIZONTAL_CONVERGENCE     params.hcrt_red_horizontal_convergence
#define HCRT_GREEN_HORIZONTAL_CONVERGENCE   params.hcrt_green_horizontal_convergence
#define HCRT_BLUE_HORIZONTAL_CONVERGENCE    params.hcrt_blue_horizontal_convergence

#define HCRT_CRT_SCREEN_TYPE                params.hcrt_crt_screen_type
#define HCRT_CRT_RESOLUTION                 params.hcrt_crt_resolution
#define HCRT_CRT_COLOUR_SPACE               global.hcrt_colour_space
#define HCRT_CRT_COLOUR_SYSTEM              global.hcrt_colour_system
#define HCRT_WHITE_TEMPERATURE              global.hcrt_white_temperature
#define HCRT_GAMMA                          global.hcrt_gamma

#define HCRT_RED_SCANLINE_MIN               params.hcrt_red_scanline_min
#define HCRT_RED_SCANLINE_MAX               params.hcrt_red_scanline_max
#define HCRT_RED_SCANLINE_ATTACK            params.hcrt_red_scanline_attack
#define HCRT_GREEN_SCANLINE_MIN             params.hcrt_green_scanline_min
#define HCRT_GREEN_SCANLINE_MAX             params.hcrt_green_scanline_max
#define HCRT_GREEN_SCANLINE_ATTACK          params.hcrt_green_scanline_attack
#define HCRT_BLUE_SCANLINE_MIN              params.hcrt_blue_scanline_min
#define HCRT_BLUE_SCANLINE_MAX              params.hcrt_blue_scanline_max
#define HCRT_BLUE_SCANLINE_ATTACK           params.hcrt_blue_scanline_attack

#define HCRT_RED_BEAM_SHARPNESS             params.hcrt_red_beam_sharpness
#define HCRT_RED_BEAM_ATTACK                params.hcrt_red_beam_attack
#define HCRT_GREEN_BEAM_SHARPNESS           params.hcrt_green_beam_sharpness
#define HCRT_GREEN_BEAM_ATTACK              params.hcrt_green_beam_attack
#define HCRT_BLUE_BEAM_SHARPNESS            params.hcrt_blue_beam_sharpness
#define HCRT_BLUE_BEAM_ATTACK               params.hcrt_blue_beam_attack

#define COMPAT_TEXTURE(c, d) texture(c, d)

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord * vec2(1.00001);  // To resolve rounding issues when sampling
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
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

#define kApertureGrille    0
#define kShadowMask        1
#define kSlotMask          2

#define kBGRAxis           2
#define kTVLAxis           3
#define kResolutionAxis    2

// APERTURE GRILLE MASKS

#define kMaxApertureGrilleSize       7

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

const uint kApertureGrilleMaskSize[kResolutionAxis][kTVLAxis] = { { 4, 3, 2 }, { 7, 5, 4 } }; //4K: 600 TVL, 800 TVL, 1000 TVL   8K: 600 TVL, 800 TVL, 1000 TVL

const vec3 kApertureGrilleMasks[kResolutionAxis][kTVLAxis][kBGRAxis][kMaxApertureGrilleSize] = {
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

#undef kXXXX
#undef kMG
#undef kGM
#undef kBGR
#undef kRGB
#undef kRGBX
#undef kBGRX
#undef kRYCBX
#undef kBCYRX
#undef kRRGGBBX
#undef kBBGGRRX

// SHADOW MASKS

#define kMaxShadowMaskSizeX     12
#define kMaxShadowMaskSizeY     8

#define kXXXX              { kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kMG                { kMagenta, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kGM                { kGreen, kMagenta, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kGRRBBG            { kGreen, kRed, kRed, kBlue, kBlue, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kBBGGRR            { kBlue, kBlue, kGreen, kGreen, kRed, kRed, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kGBBRRG            { kGreen, kBlue, kBlue, kRed, kRed, kGreen, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }
#define kRRGGBB            { kRed, kRed, kGreen, kGreen, kBlue, kBlue, kBlack, kBlack, kBlack, kBlack, kBlack, kBlack }

#define kGGRRRRBBBBGG      { kGreen, kGreen, kRed, kRed, kRed, kRed, kBlue, kBlue, kBlue, kBlue, kGreen, kGreen }
#define kBBBBGGGGRRRR      { kBlue, kBlue, kBlue, kBlue, kGreen, kGreen, kGreen, kGreen, kRed, kRed, kRed, kRed }

#define kGGBBBBRRRRGG      { kGreen, kGreen, kBlue, kBlue, kBlue, kBlue, kRed, kRed, kRed, kRed, kGreen, kGreen }
#define kRRRRGGGGBBBB      { kRed, kRed, kRed, kRed, kGreen, kGreen, kGreen, kGreen, kBlue, kBlue, kBlue, kBlue }

#define kMG_GM             { kMG, kGM, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }
#define kGM_MG             { kGM, kMG, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX, kXXXX }

#define kGRRBBG_GRRBBG_BBGGRR_BBGGRR  { kGRRBBG, kGRRBBG, kBBGGRR, kBBGGRR, kXXXX, kXXXX, kXXXX, kXXXX }
#define kGBBRRG_GBBRRG_RRGGBB_RRGGBB  { kGBBRRG, kGBBRRG, kRRGGBB, kRRGGBB, kXXXX, kXXXX, kXXXX, kXXXX }

#define kGGRRRRBBBBGG_GGRRRRBBBBGG_GGRRRRBBBBGG_GGRRRRBBBBGG_BBBBGGGGRRRR_BBBBGGGGRRRR_BBBBGGGGRRRR_BBBBGGGGRRRR  { kGGRRRRBBBBGG, kGGRRRRBBBBGG, kGGRRRRBBBBGG, kGGRRRRBBBBGG, kBBBBGGGGRRRR, kBBBBGGGGRRRR, kBBBBGGGGRRRR, kBBBBGGGGRRRR }
#define kGGBBBBRRRRGG_GGBBBBRRRRGG_GGBBBBRRRRGG_GGBBBBRRRRGG_RRRRGGGGBBBB_RRRRGGGGBBBB_RRRRGGGGBBBB_RRRRGGGGBBBB  { kGGBBBBRRRRGG, kGGBBBBRRRRGG, kGGBBBBRRRRGG, kGGBBBBRRRRGG, kRRRRGGGGBBBB, kRRRRGGGGBBBB, kRRRRGGGGBBBB, kRRRRGGGGBBBB }

const uint kShadowMaskSizeX[kResolutionAxis][kTVLAxis] = { { 6, 2, 2 }, { 12, 6, 6 } }; 
const uint kShadowMaskSizeY[kResolutionAxis][kTVLAxis] = { { 4, 2, 2 }, {  8, 4, 4 } }; 

const vec3 kShadowMasks[kResolutionAxis][kTVLAxis][kBGRAxis][kMaxShadowMaskSizeY][kMaxShadowMaskSizeX]  = {
   { // 4K
      { kGRRBBG_GRRBBG_BBGGRR_BBGGRR, kGBBRRG_GBBRRG_RRGGBB_RRGGBB },                                                      // 600 TVL
      { kMG_GM, kGM_MG },                                                                                                  // 800 TVL
      { kMG_GM, kGM_MG }                                                                                                   // 1000 TVL
   },
   { // 8K
      { kGGRRRRBBBBGG_GGRRRRBBBBGG_GGRRRRBBBBGG_GGRRRRBBBBGG_BBBBGGGGRRRR_BBBBGGGGRRRR_BBBBGGGGRRRR_BBBBGGGGRRRR, 
        kGGBBBBRRRRGG_GGBBBBRRRRGG_GGBBBBRRRRGG_GGBBBBRRRRGG_RRRRGGGGBBBB_RRRRGGGGBBBB_RRRRGGGGBBBB_RRRRGGGGBBBB },        // 600 TVL
      { kGRRBBG_GRRBBG_BBGGRR_BBGGRR, kGBBRRG_GBBRRG_RRGGBB_RRGGBB },                                                      // 800 TVL
      { kGRRBBG_GRRBBG_BBGGRR_BBGGRR, kGBBRRG_GBBRRG_RRGGBB_RRGGBB }                                                       // 1000 TVL
   }
};

#undef kXXXX
#undef kMG
#undef kGM
#undef kBGR
#undef kRGB
#undef kRGBX
#undef kBGRX
#undef kRYCBX
#undef kBCYRX
#undef kRRGGBBX
#undef kBBGGRRX

// SLOT MASKS

#define kMaxSlotMaskSize   8
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

const uint kSlotMaskSize[kResolutionAxis][kTVLAxis] = { { 4, 3, 2 }, { 7, 5, 4 } }; //4K: 600 TVL, 800 TVL, 1000 TVL   8K: 600 TVL, 800 TVL, 1000 TVL

const vec3 kSlotMasks[kResolutionAxis][kTVLAxis][kBGRAxis][kMaxSlotSizeY][kMaxSlotSizeX][kMaxSlotMaskSize] = {
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

#undef kXXXX
#undef kMG
#undef kGM
#undef kBGR
#undef kRGB
#undef kRGBX
#undef kBGRX
#undef kRYCBX
#undef kBCYRX
#undef kRRGGBBX
#undef kBBGGRRX

float ModInteger(float a, float b) 
{
    float m = a - floor((a + 0.5) / b) * b;
    return floor(m + 0.5);
}

const mat4 kCubicBezier = mat4( 1.0f,  0.0f,  0.0f,  0.0f,
                               -3.0f,  3.0f,  0.0f,  0.0f,
                                3.0f, -6.0f,  3.0f,  0.0f,
                               -1.0f,  3.0f, -3.0f,  1.0f );

float Bezier(const float t0, const vec4 control_points)
{
   vec4 t = vec4(1.0, t0, t0*t0, t0*t0*t0);
   return dot(t, control_points * kCubicBezier);
}

#include "include\hdr10.h"
#include "include\inverse_tonemap.h"
#include "include\colour_grade.h"
#include "include\scanline_generation.h"

vec3 Hdr10Conditional(const vec3 scanline_colour)
{
   if(HCRT_HDR > 0.0f)
   {
      return Hdr10(scanline_colour, HCRT_PAPER_WHITE_NITS, HCRT_EXPAND_GAMUT);
   }
   else
   {
      return scanline_colour;
   }
}

void main()
{
   const float scanline_size        = global.OutputSize.y / global.SourceSize.y;
   vec3 scanline_colour             = GenerateScanline(global.SourceSize.xy, scanline_size);

   const uint screen_type           = uint(HCRT_CRT_SCREEN_TYPE);
   const uint crt_resolution        = uint(HCRT_CRT_RESOLUTION);
   const uint lcd_resolution        = uint(HCRT_LCD_RESOLUTION);
   const uint lcd_subpixel_layout   = uint(HCRT_LCD_SUBPIXEL);

   const vec2 current_position      = vTexCoord * global.OutputSize.xy;

   switch(screen_type)
   {
      case kApertureGrille:
      {
         uint mask = uint(ModInteger(floor(current_position.x), kApertureGrilleMaskSize[lcd_resolution][crt_resolution]));

         scanline_colour *= kApertureGrilleMasks[lcd_resolution][crt_resolution][lcd_subpixel_layout][mask];      

         break;
      }
      case kShadowMask:
      {
         uint shadow_y = uint(ModInteger(floor(current_position.y), kShadowMaskSizeY[lcd_resolution][crt_resolution]));

         uint mask = uint(ModInteger(floor(current_position.x), kShadowMaskSizeX[lcd_resolution][crt_resolution]));

         scanline_colour *= kShadowMasks[lcd_resolution][crt_resolution][lcd_subpixel_layout][shadow_y][mask];    

         break;
      }
      case kSlotMask:
      {
         uint slot_x = uint(ModInteger(floor(current_position.x / float(kSlotMaskSize[lcd_resolution][crt_resolution])), kMaxSlotSizeX));
         uint slot_y = uint(ModInteger(floor(current_position.y), kMaxSlotSizeY));

         uint mask = uint(ModInteger(floor(current_position.x), kSlotMaskSize[lcd_resolution][crt_resolution]));

         scanline_colour *= kSlotMasks[lcd_resolution][crt_resolution][lcd_subpixel_layout][slot_x][slot_y][mask];

         break;
      }
      default:
      {
         break;
      }
   }

   const vec3 hdr10 = Hdr10Conditional(scanline_colour);

   //FragColor = vec4(scanline_colour, 1.0);
   FragColor = vec4(hdr10, 1.0);
}
