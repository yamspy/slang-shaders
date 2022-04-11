// SDR Colour output spaces
float sRGBToLinear_1(const float channel)
{
	return (channel > 0.04045f) ? pow((channel + 0.055f) * (1.0f / 1.055f), 2.4f + HCRT_GAMMA) : channel * (1.0f / 12.92f);
}

vec3 sRGBToLinear(const vec3 colour)
{
	return vec3(sRGBToLinear_1(colour.r), sRGBToLinear_1(colour.g), sRGBToLinear_1(colour.b));
}

float LinearTosRGB_1(const float channel)
{
	return (channel > 0.0031308f) ? (1.055f * pow(channel, 1.0f / 2.4f)) - 0.055f : channel * 12.92f;
}

vec3 LinearTosRGB(const vec3 colour)
{
	return vec3(LinearTosRGB_1(colour.r), LinearTosRGB_1(colour.g), LinearTosRGB_1(colour.b));
}

vec3 LinearToDCIP3(const vec3 colour)
{
	return pow(colour, vec3(1.0f / 2.6f));
}

vec3 GammaCorrect(const vec3 scanline_colour)
{
   if(HCRT_HDR < 1.0f)
   {
      return HCRT_OUTPUT_COLOUR_SPACE == 0.0f ? LinearTosRGB(scanline_colour) : LinearToDCIP3(scanline_colour);
   }
   else
   {
      return Hdr10(scanline_colour, HCRT_PAPER_WHITE_NITS, HCRT_EXPAND_GAMUT);
   }
}