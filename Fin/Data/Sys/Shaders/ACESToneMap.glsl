// ACES Filmic Tone Mapping
// Based on the Academy Color Encoding System (ACES) fitted curve
// by Stephen Hill (@self_shadow) and Narkowicz.
// Attempt to approximate the ACES filmic tone mapping curve.

/*
[configuration]

[OptionRangeFloat]
GUIName = Exposure
OptionName = ACES_EXPOSURE
MinValue = 0.1
MaxValue = 10.0
StepAmount = 0.1
DefaultValue = 1.0

[OptionRangeFloat]
GUIName = Saturation
OptionName = ACES_SATURATION
MinValue = 0.0
MaxValue = 2.0
StepAmount = 0.05
DefaultValue = 1.0

[OptionRangeFloat]
GUIName = Gamma
OptionName = ACES_GAMMA
MinValue = 1.0
MaxValue = 3.0
StepAmount = 0.05
DefaultValue = 2.2

[/configuration]
*/

// sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
const mat3 ACESInputMat = mat3(
  0.59719, 0.07600, 0.02840,
  0.35458, 0.90834, 0.13383,
  0.04823, 0.01566, 0.83777
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
const mat3 ACESOutputMat = mat3(
   1.60475, -0.10208, -0.00327,
  -0.53108,  1.10813, -0.07276,
  -0.07367, -0.00605,  1.07602
);

float3 RRTAndODTFit(float3 v)
{
  float3 a = v * (v + 0.0245786) - 0.000090537;
  float3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
  return a / b;
}

float3 ACESFitted(float3 color)
{
  color = ACESInputMat * color;
  color = RRTAndODTFit(color);
  color = ACESOutputMat * color;
  return clamp(color, 0.0, 1.0);
}

void main()
{
  float4 c = Sample();
  float3 col = c.rgb;

  // Apply exposure
  col *= GetOption(ACES_EXPOSURE);

  // Saturation adjustment (in luminance space)
  float luma = dot(col, float3(0.2126, 0.7152, 0.0722));
  col = mix(float3(luma, luma, luma), col, GetOption(ACES_SATURATION));

  // ACES filmic tone mapping
  col = ACESFitted(col);

  // Gamma correction
  col = pow(max(col, float3(0.0, 0.0, 0.0)), float3(1.0 / GetOption(ACES_GAMMA)));

  SetOutput(float4(col, c.a));
}
