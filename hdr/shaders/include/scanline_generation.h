
#define kPi    3.1415926536f
#define kEuler 2.718281828459f
#define kMax   1.0f

#define kBeamWidth 0.5f

const mat4 kCubicBezier = mat4( 1.0f,  0.0f,  0.0f,  0.0f,
					                -3.0f,  3.0f,  0.0f,  0.0f,
					                 3.0f, -6.0f,  3.0f,  0.0f,
					                -1.0f,  3.0f, -3.0f,  1.0f );

const vec4 kFallOffControlPoints    = vec4(0.0f, 0.0f, 0.0f, 1.0f);
const vec4 kAttackControlPoints     = vec4(0.0f, 1.0f, 1.0f, 1.0f);
//const vec4 kScanlineControlPoints = vec4(1.0f, 1.0f, 0.0f, 0.0f);

vec4 RedBeamControlPoints(const bool falloff)
{
   float inner_attack = clamp(params.RedBeamAttack, 0.0f, 1.0);
   float outer_attack = clamp(params.RedBeamAttack - 1.0f, 0.0f, 1.0);

   return falloff ? kFallOffControlPoints + vec4(0.0f, outer_attack, inner_attack, 0.0f) : kAttackControlPoints - vec4(0.0f, inner_attack, outer_attack, 0.0f);
}

vec4 GreenBeamControlPoints(const bool falloff)
{
   float inner_attack = clamp(params.GreenBeamAttack, 0.0f, 1.0);
   float outer_attack = clamp(params.GreenBeamAttack - 1.0f, 0.0f, 1.0);

   return falloff ? kFallOffControlPoints + vec4(0.0f, outer_attack, inner_attack, 0.0f) : kAttackControlPoints - vec4(0.0f, inner_attack, outer_attack, 0.0f);
}

vec4 BlueBeamControlPoints(const bool falloff)
{
   float inner_attack = clamp(params.BlueBeamAttack, 0.0f, 1.0);
   float outer_attack = clamp(params.BlueBeamAttack - 1.0f, 0.0f, 1.0);

   return falloff ? kFallOffControlPoints + vec4(0.0f, outer_attack, inner_attack, 0.0f) : kAttackControlPoints - vec4(0.0f, inner_attack, outer_attack, 0.0f);
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

   const vec2 red_tex_coord_0             = source_tex_coord_0 + vec2(HorizontalConvergence.x, 0.0f);
   const vec2 red_tex_coord_1             = source_tex_coord_1 + vec2(HorizontalConvergence.x, 0.0f);

   const vec2 green_tex_coord_0           = source_tex_coord_0 + vec2(HorizontalConvergence.y, 0.0f);
   const vec2 green_tex_coord_1           = source_tex_coord_1 + vec2(HorizontalConvergence.y, 0.0f);

   const vec2 blue_tex_coord_0            = source_tex_coord_0 + vec2(HorizontalConvergence.z, 0.0f);
   const vec2 blue_tex_coord_1            = source_tex_coord_1 + vec2(HorizontalConvergence.z, 0.0f);

   const float scanline_position          = current_source_center_y * ScanlineSize;
   const vec3 scanline_delta              = vec3(scanline_position) - (vec3(current_center) - VerticalConvergence);  
   
   vec3 beam_distance                     = abs(scanline_delta) - kBeamWidth;
   beam_distance                          = vec3(beam_distance.x < 0.0f ? 0.0f : beam_distance.x, 
                                                 beam_distance.y < 0.0f ? 0.0f : beam_distance.y, 
                                                 beam_distance.z < 0.0f ? 0.0f : beam_distance.z);
   const vec3 scanline_distance           = beam_distance * InverseScanlineSize * 2.0f;

   next_prev = scanline_delta.x > 0.0f ? 1.0f : -1.0f;

   const float red_0          = texture(Source, red_tex_coord_0).x;
   const float red_1          = texture(Source, red_tex_coord_1).x;

   const float green_0        = texture(Source, green_tex_coord_0).y;
   const float green_1        = texture(Source, green_tex_coord_1).y;

   const float blue_0         = texture(Source, blue_tex_coord_0).z;
   const float blue_1         = texture(Source, blue_tex_coord_1).z;

   const vec3 sdr_colour_0    = vec3(red_0, green_0, blue_0);
   const vec3 sdr_colour_1    = vec3(red_1, green_1, blue_1);

   //const vec3 sdr_colour_0  = texture(Source, source_tex_coord_0).xyz;
   //const vec3 sdr_colour_1  = texture(Source, source_tex_coord_1).xyz;

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
   const vec3 hdr_colour_0    = InverseTonemapConditional(sdr_balanced_0);
   const vec3 hdr_colour_1    = InverseTonemapConditional(sdr_balanced_1);

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

vec3 GenerateScanline(const vec2 current_position)
{
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

   return scanline_colour0 + scanline_colour1;
}