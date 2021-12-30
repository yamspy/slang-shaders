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
   float ResolutionPattern;
   float Sharpness;
} params;

#pragma parameter ScanlineWidth     "Scanline Width"     0.95   0.0 1.0    0.01 
#pragma parameter ResolutionPattern "Resolution Pattern" 2.0    0.0 8.0    1.0
#pragma parameter Sharpness         "Sharpness"          1.8    0.0 5.0    0.1

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
layout(set = 0, binding = 3) uniform sampler2D StockPass;

float ModInteger(float a, float b) 
{
    float m = a - floor((a + 0.5) / b) * b;
    return floor(m + 0.5);
}

#define kPi    3.1415926536
#define kEuler 2.718281828459
#define kMax   1.0

#define kGuassianMin   vec3(1.1)
#define kGuassianMax   vec3(3.0)

#define kRed     vec3(1.0, 0.0, 0.0)
#define kGreen   vec3(0.0, 1.0, 0.0)
#define kBlue    vec3(0.0, 0.0, 1.0)
#define kMagenta vec3(1.0, 0.0, 1.0)
#define kYellow  vec3(1.0, 1.0, 0.0)
#define kCyan    vec3(0.0, 1.0, 1.0)
#define kBlack   vec3(0.0, 0.0, 0.0)
#define kWhite   vec3(1.0, 1.0, 1.0)

float Ramp(const float gaussian, float colour)
{
    return clamp(gaussian * colour, 0.0, 1.0); 
}

vec3 Ramp3(const vec3 gaussian, vec3 colour)
{
    return clamp(gaussian * colour, vec3(0.0), vec3(1.0)); 
}

void main()
{
   float ScanlineSize = params.OutputSize.y / params.SourceSize.y; 

   const vec2 InPixels = (vTexCoord * params.OutputSize.xy);

   const float ScanlinePosition = (floor(vTexCoord.y * params.SourceSize.y) * ScanlineSize) + (ScanlineSize * 0.5);

   float ScanlineDistance = ScanlinePosition - (floor(InPixels.y) + 0.5);

   ScanlineDistance /= ScanlineSize * params.ScanlineWidth;
   ScanlineDistance = clamp(abs(ScanlineDistance * 2.0), 0.0, 1.0);

   const float Gaussian = pow(kEuler, -0.5 * pow(ScanlineDistance/0.3, 2.0)); /* Gaussian distribution */

   float HorizInterp = (vTexCoord.x * params.SourceSize.x) - (floor(vTexCoord.x * params.SourceSize.x)); 
   HorizInterp = clamp(((HorizInterp - 0.5) * params.Sharpness) + 0.5, 0.0f, 1.0);

   const vec2 SourceTexCoord0 = vec2(vTexCoord.x, ScanlinePosition / params.OutputSize.y);

   vec3 HDRColour0 = texture(Source, SourceTexCoord0).xyz;
   vec3 SDRColour0 = texture(StockPass, SourceTexCoord0).xyz;

   const vec2 SourceTexCoord1 = vec2(vTexCoord.x + (1.0 / params.SourceSize.x), ScanlinePosition / params.OutputSize.y);

   const vec3 HDRColour1 = texture(Source, SourceTexCoord1).xyz;
   const vec3 SDRColour1 = texture(StockPass, SourceTexCoord1).xyz;
   
   const vec3 HDRColour  = mix(HDRColour0, HDRColour1, vec3(HorizInterp));
   const vec3 SDRColour  = mix(SDRColour0, SDRColour1, vec3(HorizInterp));
   
   vec3 Luminance = Ramp3(vec3(Gaussian), (SDRColour * kGuassianMax) + kGuassianMin); 

   vec3 OutputColour;

   /* Various resolution patterns - remember your LCD 4K screen will likely be 16:9 whereas
   the CRT TV will likely be 4:3 and so higher TVL values will be required on your 16:9 screen
   to get an equivalent TVL seen on a 4:3 CRT TV. 
   Pattern 1's 960TVL at 16:9 is about right for a 800TVL at 4:3.
   */

   uint ResolutionPattern = uint(params.ResolutionPattern);

   switch(ResolutionPattern)
   {
      case 0:  /* 2 pattern - 1440TVL (16:9) horiz resolution (too high?) on a 4K screen */
      {
         const uint PatternSize = 2;
         const vec3 Mask[2] = vec3[]( kYellow, kCyan );
      
         uint PatternX = uint(ModInteger(floor(InPixels.x), PatternSize));
         OutputColour = Luminance * HDRColour * Mask[PatternX];
         
         break;
      }
      case 1:  /* 3 pattern - 960TVL (16:9) horiz resolution on a 4K screen */
      {  
         const uint PatternSize = 3;
         const vec3 Mask[3] = vec3[]( kRed, kGreen, kBlue );
      
         uint PatternX = uint(ModInteger(floor(InPixels.x), PatternSize));
         OutputColour = Luminance * HDRColour * Mask[PatternX];
      
         break;
      }
      case 2:  /* 4 pattern - 720TVL (16:9) horiz resolution on a 4K screen */
      {
         const uint PatternSize = 4;
         const vec3 Mask[4] = vec3[]( kRed, kYellow, kCyan, kBlue );
      
         uint PatternX = uint(ModInteger(floor(InPixels.x), PatternSize));
         OutputColour = Luminance * HDRColour * Mask[PatternX];
         
         break;
      }
      case 3:  /* 5 BRG pattern - 576TVL (16:9) horiz resolution on a 4K screen */
      {
         const uint PatternSize = 5;         
         const vec3 Mask[5] = vec3[]( kRed, kMagenta, kBlue, kGreen, kGreen );
      
         uint PatternX = uint(ModInteger(floor(InPixels.x), PatternSize));
         OutputColour = Luminance * HDRColour * Mask[PatternX];
         
         break;
      }
      case 4:  /* 5 pattern - 576TVL (16:9) horiz resolution on a 4K screen */
      {
         const uint PatternSize = 5;         
         const vec3 Mask[5] = vec3[]( kRed, kYellow, kGreen, kCyan, kBlue );
      
         uint PatternX = uint(ModInteger(floor(InPixels.x), PatternSize));
         OutputColour = Luminance * HDRColour * Mask[PatternX];
         
         break;
      }
      case 5:  /* 6 pattern - 480TVL (16:9) horiz resolution on a 4K screen */
      {
         const uint PatternSize = 6;
         const vec3 Mask[6] = vec3[]( kRed, kRed, kGreen, kGreen, kBlue, kBlue );
      
         uint PatternX = uint(ModInteger(floor(InPixels.x), PatternSize));
         OutputColour = Luminance * HDRColour * Mask[PatternX];
         
         break;
      }
      case 6:  /* 7 pattern - 410TVL (16:9) horiz resolution on a 4K screen */
      {
         const uint PatternSize = 7;
         const vec3 Mask[7] = vec3[]( kRed, kRed, kYellow, kGreen, kCyan, kBlue, kBlue );
      
         uint PatternX = uint(ModInteger(floor(InPixels.x), PatternSize));
         OutputColour = Luminance * HDRColour * Mask[PatternX];
         
         break;
      }
      case 7:  /* 9 pattern - 640TVL (16:9) horiz resolution on a *8K* screen */
      {
         const uint PatternSize = 9;
         const vec3 Mask[9] = vec3[]( kBlack, kRed, kRed, kBlack, kGreen, kGreen, kBlack, kBlue, kBlue );
      
         uint PatternX = uint(ModInteger(floor(InPixels.x), PatternSize));
         OutputColour = Luminance * HDRColour * Mask[PatternX];
         
         break;
      }
      case 8:  /* 12 pattern - 480TVL (16:9) horiz resolution on a *8K* screen */
      {
         const uint PatternSize = 12;
         const vec3 Mask[12] = vec3[]( kBlack, kRed, kRed, kRed, kBlack, kGreen, kGreen, kGreen, kBlack, kBlue, kBlue, kBlue );
      
         uint PatternX = uint(ModInteger(floor(InPixels.x), PatternSize));
         OutputColour = Luminance * HDRColour * Mask[PatternX];
         
         break;
      }
      default:
      {
         OutputColour = vec3(0.0);
         
         break;
      }
   }

   FragColor = vec4(OutputColour, 1.0);
}
