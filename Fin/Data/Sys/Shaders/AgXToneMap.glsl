// AgX Tone Mapping
// Modern filmic tonemapper popularized by Blender 3.x+.
// Attempt to approximate the AgX look with a single-pass shader.
// Attempt based on the work by Troy Sobotka and Blender's AgX implementation.

/*
[configuration]

[OptionRangeFloat]
GUIName = Exposure
OptionName = AGX_EXPOSURE
MinValue = 0.1
MaxValue = 10.0
StepAmount = 0.1
DefaultValue = 1.0

[OptionRangeFloat]
GUIName = Saturation
OptionName = AGX_SATURATION
MinValue = 0.0
MaxValue = 2.0
StepAmount = 0.05
DefaultValue = 1.0

[OptionRangeFloat]
GUIName = Look Intensity
OptionName = AGX_LOOK
MinValue = 0.0
MaxValue = 1.0
StepAmount = 0.05
DefaultValue = 0.5

[/configuration]
*/

// AgX log2 encoding range
const float AGX_MIN_EV = -12.47393;
const float AGX_MAX_EV = 4.026069;

float3 agxDefaultContrastApprox(float3 x)
{
  // 6th order polynomial approximation of the AgX default contrast curve
  float3 x2 = x * x;
  float3 x4 = x2 * x2;
  return + 15.5     * x4 * x2
         - 40.14    * x4 * x
         + 31.96    * x4
         - 6.868    * x2 * x
         + 0.4298   * x2
         + 0.1191   * x
         - 0.00232;
}

float3 agx(float3 val)
{
  // Input transform (sRGB to AgX log space)
  const mat3 agx_mat = mat3(
    0.842479062253094,  0.0423282422610123, 0.0423756549057051,
    0.0784335999999992, 0.878468636469772,  0.0784336,
    0.0792237451477643, 0.0791661274605434, 0.879142973793104
  );

  val = agx_mat * val;
  val = max(val, float3(1e-10, 1e-10, 1e-10));
  val = log2(val);
  val = (val - AGX_MIN_EV) / (AGX_MAX_EV - AGX_MIN_EV);
  val = clamp(val, 0.0, 1.0);

  val = agxDefaultContrastApprox(val);

  return val;
}

float3 agxEotf(float3 val)
{
  // Inverse output transform (AgX to sRGB)
  const mat3 agx_mat_inv = mat3(
     1.19687900512017,  -0.0528968517574562, -0.0529716355144438,
    -0.0980208811401368,  1.15190312990417,  -0.0980434501171241,
    -0.0990297440797205, -0.0989611768448433, 1.15107367264116
  );

  val = agx_mat_inv * val;
  val = pow(max(val, float3(0.0, 0.0, 0.0)), float3(2.2, 2.2, 2.2));
  return val;
}

float3 agxLook(float3 val, float intensity)
{
  float luma = dot(val, float3(0.2126, 0.7152, 0.0722));
  float3 offset = float3(0.0, 0.0, 0.0);

  // Punchy look: slight saturation boost + contrast
  float3 slope = float3(1.0, 1.0, 1.0);
  float3 power = float3(1.35, 1.35, 1.35);
  float sat = 1.4;

  val = pow(max(val * slope + offset, float3(0.0, 0.0, 0.0)), power);
  float3 saturated = luma + sat * (val - luma);

  return mix(val, saturated, intensity);
}

void main()
{
  float4 c = Sample();
  float3 col = c.rgb;

  // Apply exposure
  col *= GetOption(AGX_EXPOSURE);

  // AgX tone mapping
  col = agx(col);

  // Apply look
  col = agxLook(col, GetOption(AGX_LOOK));

  // AgX EOTF (output transform)
  col = agxEotf(col);

  // Saturation adjustment
  float luma = dot(col, float3(0.2126, 0.7152, 0.0722));
  col = mix(float3(luma, luma, luma), col, GetOption(AGX_SATURATION));

  col = clamp(col, 0.0, 1.0);

  SetOutput(float4(col, c.a));
}
