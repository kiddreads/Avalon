// Color Grading / LUT-style Shader
// Provides lift/gamma/gain color wheels, color temperature, and tint adjustments.
// A software-based alternative to hardware LUT textures.

/*
[configuration]

[OptionRangeFloat]
GUIName = Brightness
OptionName = CG_BRIGHTNESS
MinValue = -0.5
MaxValue = 0.5
StepAmount = 0.01
DefaultValue = 0.0

[OptionRangeFloat]
GUIName = Contrast
OptionName = CG_CONTRAST
MinValue = 0.5
MaxValue = 2.0
StepAmount = 0.05
DefaultValue = 1.0

[OptionRangeFloat]
GUIName = Saturation
OptionName = CG_SATURATION
MinValue = 0.0
MaxValue = 3.0
StepAmount = 0.05
DefaultValue = 1.0

[OptionRangeFloat]
GUIName = Color Temperature
OptionName = CG_TEMPERATURE
MinValue = -1.0
MaxValue = 1.0
StepAmount = 0.05
DefaultValue = 0.0

[OptionRangeFloat]
GUIName = Tint (Green-Magenta)
OptionName = CG_TINT
MinValue = -1.0
MaxValue = 1.0
StepAmount = 0.05
DefaultValue = 0.0

[OptionRangeFloat]
GUIName = Gamma
OptionName = CG_GAMMA
MinValue = 0.5
MaxValue = 3.0
StepAmount = 0.05
DefaultValue = 1.0

[OptionRangeFloat]
GUIName = Lift (Shadows)
OptionName = CG_LIFT
MinValue = -0.5
MaxValue = 0.5
StepAmount = 0.01
DefaultValue = 0.0

[OptionRangeFloat]
GUIName = Gain (Highlights)
OptionName = CG_GAIN
MinValue = 0.5
MaxValue = 2.0
StepAmount = 0.05
DefaultValue = 1.0

[/configuration]
*/

float3 applyTemperature(float3 col, float temp, float tint)
{
  // Attempt to approximate white balance shift
  // Warm (positive temp) adds red/yellow, cool (negative) adds blue
  col.r += temp * 0.1;
  col.b -= temp * 0.1;
  // Tint shifts green-magenta axis
  col.g += tint * 0.1;
  return col;
}

float3 applyLiftGammaGain(float3 col, float lift, float gamma, float gain)
{
  // Lift: shifts shadows
  col = col + float3(lift, lift, lift);
  // Gain: scales highlights
  col = col * gain;
  // Gamma: midtone adjustment
  col = pow(max(col, float3(0.0, 0.0, 0.0)), float3(1.0 / gamma, 1.0 / gamma, 1.0 / gamma));
  return col;
}

void main()
{
  float4 c = Sample();
  float3 col = c.rgb;

  // Brightness
  col += GetOption(CG_BRIGHTNESS);

  // Contrast (around midpoint 0.5)
  col = (col - 0.5) * GetOption(CG_CONTRAST) + 0.5;

  // Temperature and tint
  col = applyTemperature(col, GetOption(CG_TEMPERATURE), GetOption(CG_TINT));

  // Lift / Gamma / Gain
  col = applyLiftGammaGain(col, GetOption(CG_LIFT), GetOption(CG_GAMMA), GetOption(CG_GAIN));

  // Saturation
  float luma = dot(col, float3(0.2126, 0.7152, 0.0722));
  col = mix(float3(luma, luma, luma), col, GetOption(CG_SATURATION));

  col = clamp(col, 0.0, 1.0);

  SetOutput(float4(col, c.a));
}
