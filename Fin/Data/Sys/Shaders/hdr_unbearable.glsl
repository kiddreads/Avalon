/*
[configuration]

[OptionRangeFloat]
GUIName = Exposure
OptionName = HDR_UNBEARABLE_EXPOSURE
MinValue = 0.0
MaxValue = 8.0
StepAmount = 0.1
DefaultValue = 4.0

[OptionRangeFloat]
GUIName = Contrast
OptionName = HDR_UNBEARABLE_CONTRAST
MinValue = 0.5
MaxValue = 5.0
StepAmount = 0.1
DefaultValue = 3.5

[OptionRangeFloat]
GUIName = Saturation
OptionName = HDR_UNBEARABLE_SATURATION
MinValue = 0.0
MaxValue = 6.0
StepAmount = 0.1
DefaultValue = 5.0

[/configuration]
*/

void main()
{
  float4 c = Sample();

  // User parameters
  float exposure = GetOption(HDR_UNBEARABLE_EXPOSURE);
  float contrast = GetOption(HDR_UNBEARABLE_CONTRAST);
  float saturation = GetOption(HDR_UNBEARABLE_SATURATION);

  float3 col = c.rgb;

  // Nuclear exposure
  col *= exposure * 8.0;

  // Aggressive tone map (crushed mids, blown highs)
  col = col / max(col + float3(0.15, 0.15, 0.15), float3(0.0001, 0.0001, 0.0001));

  // Extreme contrast
  col = (col - 0.5) * contrast + 0.5;

  // Oversaturate to hell
  float luma = dot(col, float3(0.2126, 0.7152, 0.0722));
  col = mix(float3(luma, luma, luma), col, saturation);

  // Eye-searing gamma abuse
  col = pow(abs(col), float3(0.35, 0.35, 0.35));

  // Clamp AFTER damage
  col = clamp(col, 0.0, 1.0);

  SetOutput(float4(col, c.a));
}

