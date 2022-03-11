
#define kPi    3.1415926536f
#define kEuler 2.718281828459f
#define kMax   1.0f

#define kBeamWidth 0.5f
#define kLumaRatio 0.5f

const vec4 kFallOffControlPoints    = vec4(0.0f, 0.0f, 0.0f, 1.0f);
const vec4 kAttackControlPoints     = vec4(0.0f, 1.0f, 1.0f, 1.0f);
//const vec4 kScanlineControlPoints = vec4(1.0f, 1.0f, 0.0f, 0.0f);

vec4 RedBeamControlPoints(const bool falloff)
{
   float inner_attack = clamp(HCRT_RED_BEAM_ATTACK, 0.0f, 1.0);
   float outer_attack = clamp(HCRT_RED_BEAM_ATTACK - 1.0f, 0.0f, 1.0);

   return falloff ? kFallOffControlPoints + vec4(0.0f, outer_attack, inner_attack, 0.0f) : kAttackControlPoints - vec4(0.0f, inner_attack, outer_attack, 0.0f);
}

vec4 GreenBeamControlPoints(const bool falloff)
{
   float inner_attack = clamp(HCRT_GREEN_BEAM_ATTACK, 0.0f, 1.0);
   float outer_attack = clamp(HCRT_GREEN_BEAM_ATTACK - 1.0f, 0.0f, 1.0);

   return falloff ? kFallOffControlPoints + vec4(0.0f, outer_attack, inner_attack, 0.0f) : kAttackControlPoints - vec4(0.0f, inner_attack, outer_attack, 0.0f);
}

vec4 BlueBeamControlPoints(const bool falloff)
{
   float inner_attack = clamp(HCRT_BLUE_BEAM_ATTACK, 0.0f, 1.0);
   float outer_attack = clamp(HCRT_BLUE_BEAM_ATTACK - 1.0f, 0.0f, 1.0);

   return falloff ? kFallOffControlPoints + vec4(0.0f, outer_attack, inner_attack, 0.0f) : kAttackControlPoints - vec4(0.0f, inner_attack, outer_attack, 0.0f);
}

vec3 InverseTonemapConditional(const vec3 linear)
{
   if(HCRT_HDR > 0.0f)
   {
      return linear;
   }
   else
   {
      return InverseTonemap(linear, HCRT_MAX_NITS, HCRT_PAPER_WHITE_NITS, kLumaRatio);
   }
}

vec3 ScanlineColour(const vec2 source_size, const float scanline_size, const vec3 source_tex_coord_x, const vec3 narrowed_source_pixel_offset, inout vec3 next_prev)
{
   const vec3 current_source_position_y   = (vec3(vTexCoord.y * source_size.y) - vec3(HCRT_RED_VERTICAL_CONVERGENCE, HCRT_GREEN_VERTICAL_CONVERGENCE, HCRT_BLUE_VERTICAL_CONVERGENCE)) + next_prev;
   const vec3 current_source_center_y     = floor(current_source_position_y) + 0.5f; 
   
   const vec3 source_tex_coord_y          = current_source_center_y / source_size.y; 

   const vec3 scanline_delta              = fract(current_source_position_y) - 0.5f;

   // Slightly increase the beam width to get maximum brightness
   vec3 beam_distance                     = abs(scanline_delta - next_prev) - (kBeamWidth / scanline_size);
   beam_distance                          = vec3(beam_distance.x < 0.0f ? 0.0f : beam_distance.x, 
                                                 beam_distance.y < 0.0f ? 0.0f : beam_distance.y, 
                                                 beam_distance.z < 0.0f ? 0.0f : beam_distance.z);
   const vec3 scanline_distance           = beam_distance * 2.0f;

   next_prev.x = scanline_delta.x > 0.0f ? 1.0f : -1.0f;
   next_prev.y = scanline_delta.y > 0.0f ? 1.0f : -1.0f;
   next_prev.z = scanline_delta.z > 0.0f ? 1.0f : -1.0f;

   const vec2 red_tex_coord_0             = vec2(source_tex_coord_x.x, source_tex_coord_y.x);
   const vec2 red_tex_coord_1             = vec2(source_tex_coord_x.x + (1.0f / source_size.x), source_tex_coord_y.x);

   const vec2 green_tex_coord_0           = vec2(source_tex_coord_x.y, source_tex_coord_y.y);
   const vec2 green_tex_coord_1           = vec2(source_tex_coord_x.y + (1.0f / source_size.x), source_tex_coord_y.y);

   const vec2 blue_tex_coord_0            = vec2(source_tex_coord_x.z, source_tex_coord_y.z);
   const vec2 blue_tex_coord_1            = vec2(source_tex_coord_x.z + (1.0f / source_size.x), source_tex_coord_y.z);

   const float red_0                      = COMPAT_TEXTURE(Source, red_tex_coord_0).x;
   const float red_1                      = COMPAT_TEXTURE(Source, red_tex_coord_1).x;

   const float green_0                    = COMPAT_TEXTURE(Source, green_tex_coord_0).y;
   const float green_1                    = COMPAT_TEXTURE(Source, green_tex_coord_1).y;

   const float blue_0                     = COMPAT_TEXTURE(Source, blue_tex_coord_0).z;
   const float blue_1                     = COMPAT_TEXTURE(Source, blue_tex_coord_1).z;

   const vec3 sdr_colour_0                = ColourGrade(vec3(red_0, green_0, blue_0));
   const vec3 sdr_colour_1                = ColourGrade(vec3(red_1, green_1, blue_1));

   const vec3 hdr_colour_0                = InverseTonemapConditional(sdr_colour_0);
   const vec3 hdr_colour_1                = InverseTonemapConditional(sdr_colour_1);

   /* Horizontal interpolation between pixels */ 
   const vec3 horiz_interp = vec3(Bezier(narrowed_source_pixel_offset.x, RedBeamControlPoints(sdr_colour_0.x > sdr_colour_1.x)), 
                                  Bezier(narrowed_source_pixel_offset.y, GreenBeamControlPoints(sdr_colour_0.y > sdr_colour_1.y)), 
                                  Bezier(narrowed_source_pixel_offset.z, BlueBeamControlPoints(sdr_colour_0.z > sdr_colour_1.z)));  

   const vec3 hdr_colour  = mix(hdr_colour_0, hdr_colour_1, horiz_interp);
   const vec3 sdr_colour  = mix(sdr_colour_0, sdr_colour_1, horiz_interp);

   const float red_scanline_distance   = clamp(scanline_distance.x / ((sdr_colour.r * (HCRT_RED_SCANLINE_MAX - HCRT_RED_SCANLINE_MIN)) + HCRT_RED_SCANLINE_MIN),       0.0f, 1.0f);
   const float green_scanline_distance = clamp(scanline_distance.y / ((sdr_colour.g * (HCRT_GREEN_SCANLINE_MAX - HCRT_GREEN_SCANLINE_MIN)) + HCRT_GREEN_SCANLINE_MIN), 0.0f, 1.0f);
   const float blue_scanline_distance  = clamp(scanline_distance.z / ((sdr_colour.b * (HCRT_BLUE_SCANLINE_MAX - HCRT_BLUE_SCANLINE_MIN)) + HCRT_BLUE_SCANLINE_MIN),    0.0f, 1.0f);

   const vec4 red_control_points    = vec4(1.0f, 1.0f, sdr_colour.r * HCRT_RED_SCANLINE_ATTACK,    0.0f);
   const vec4 green_control_points  = vec4(1.0f, 1.0f, sdr_colour.g * HCRT_GREEN_SCANLINE_ATTACK,  0.0f);
   const vec4 blue_control_points   = vec4(1.0f, 1.0f, sdr_colour.b * HCRT_BLUE_SCANLINE_ATTACK,   0.0f);

   const vec3 luminance = vec3(Bezier(red_scanline_distance, red_control_points),
                               Bezier(green_scanline_distance, green_control_points),
                               Bezier(blue_scanline_distance, blue_control_points));

   return luminance * hdr_colour;
}
 
vec3 GenerateScanline(const vec2 source_size, const float scanline_size)
{
   const vec3 current_source_position_x      = vec3(vTexCoord.x * source_size.x) - vec3(HCRT_RED_HORIZONTAL_CONVERGENCE, HCRT_GREEN_HORIZONTAL_CONVERGENCE, HCRT_BLUE_HORIZONTAL_CONVERGENCE);
   const vec3 current_source_center_x        = floor(current_source_position_x) + 0.5f; 
   
   const vec3 source_tex_coord_x             = current_source_center_x / source_size.x; 

   const vec3 source_pixel_offset            = fract(current_source_position_x);

   const vec3 beam_sharpness                 = vec3(HCRT_RED_BEAM_SHARPNESS, HCRT_GREEN_BEAM_SHARPNESS, HCRT_BLUE_BEAM_SHARPNESS);
   const vec3 narrowed_source_pixel_offset   = clamp(((source_pixel_offset - vec3(0.5f)) * beam_sharpness) + vec3(0.5f), vec3(0.0f), vec3(1.0f));

   vec3 next_prev = vec3(0.0f);

   const vec3 scanline_colour0 = ScanlineColour(source_size, scanline_size, source_tex_coord_x, narrowed_source_pixel_offset, next_prev);

   // Optionally sample the neighbouring scanline
   vec3 scanline_colour1 = vec3(0.0f);
   if(HCRT_RED_SCANLINE_MAX > 1.0f || HCRT_GREEN_SCANLINE_MAX > 1.0f || HCRT_BLUE_SCANLINE_MAX > 1.0f)
   {
      scanline_colour1 = ScanlineColour(source_size, scanline_size, source_tex_coord_x, narrowed_source_pixel_offset, next_prev);
   }

   return scanline_colour0 + scanline_colour1;
}