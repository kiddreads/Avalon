// PBR Neutral Tone Mapping
// Based on the Khronos Group PBR Neutral tonemapper.
// Designed for color accuracy: faithfully matches sRGB inputs under HDR lighting.
// Reference: https://github.com/KhronosGroup/ToneMapping

/*
[configuration]

[OptionRangeFloat]
GUIName = Exposure
OptionName = PBR_EXPOSURE
MinValue = 0.1
MaxValue = 10.0
StepAmount = 0.1
DefaultValue = 1.0

[OptionRangeFloat]
GUIName = Gamma
OptionName = PBR_GAMMA
MinValue = 1.0
MaxValue = 3.0
StepAmount = 0.05
DefaultValue = 2.2

[/configuration]
*/

// PBR Neutral tone mapping operator
// Attempt to approximate the Khronos PBR Neutral curve.
float3 PBRNeutralToneMapping(float3 color)
{
  const float startCompression = 0.8 - 0.04;
  const float desaturation = 0.15;

  float x = min(color.r, min(color.g, color.b));
  float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
  color -= offset;

  float peak = max(color.r, max(color.g, color.b));
  if (peak < startCompression)
    return color;

  float d = 1.0 - startCompression;
  float newPeak = 1.0 - d * d / (peak + d - startCompression);
  color *= newPeak / peak;

  float g = 1.0 - 1.0 / (desaturation * (peak - newPeak) + 1.0);
  return mix(color, float3(newPeak, newPeak, newPeak), g);
}

void main()
{
  float4 c = Sample();
  float3 col = c.rgb;

  // Apply exposure
  col *= GetOption(PBR_EXPOSURE);

  // PBR Neutral tone mapping
  col = PBRNeutralToneMapping(col);

  // Gamma correction
  col = pow(max(col, float3(0.0, 0.0, 0.0)), float3(1.0 / GetOption(PBR_GAMMA)));

  col = clamp(col, 0.0, 1.0);

  SetOutput(float4(col, c.a));
}
