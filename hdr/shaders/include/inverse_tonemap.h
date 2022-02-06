
#define kMaxNitsFor2084     10000.0f
#define kEpsilon            0.0001f

vec3 InverseTonemap(vec3 sdr_linear, float max_nits, float paper_white_nits, float luma_ratio)
{
   float luma                 = dot(sdr_linear, vec3(0.2126, 0.7152, 0.0722));  /* Rec BT.709 luma coefficients - https://en.wikipedia.org/wiki/Luma_(video) */

   /* Inverse reinhard tonemap */
   float max_value            = (max_nits / paper_white_nits) + kEpsilon;
   float elbow                = max_value / (max_value - 1.0f);                          
   float offset               = 1.0f - ((0.5f * elbow) / (elbow - 0.5f));              
   
   float hdr_luma_inv_tonemap = offset + ((luma * elbow) / (elbow - luma));
   float sdr_luma_inv_tonemap = luma / ((1.0f + kEpsilon) - luma);                     /* Convert the srd < 0.5 to 0.0 -> 1.0 range */

   float luma_inv_tonemap       = (luma > 0.5f) ? hdr_luma_inv_tonemap : sdr_luma_inv_tonemap;
   vec3 per_luma              = sdr_linear / (luma + kEpsilon) * luma_inv_tonemap;

   vec3 hdr_inv_tonemap       = offset + ((sdr_linear * elbow) / (elbow - sdr_linear));         
   vec3 sdr_inv_tonemap       = sdr_linear / ((1.0f + kEpsilon) - sdr_linear);                       /* Convert the srd < 0.5 to 0.0 -> 1.0 range */

   vec3 per_channel           = vec3(sdr_linear.x > 0.5f ? hdr_inv_tonemap.x : sdr_inv_tonemap.x,
                                     sdr_linear.y > 0.5f ? hdr_inv_tonemap.y : sdr_inv_tonemap.y,
                                     sdr_linear.z > 0.5f ? hdr_inv_tonemap.z : sdr_inv_tonemap.z);

   vec3 hdr = mix(per_luma, per_channel, vec3(luma_ratio));

   return hdr;
}
