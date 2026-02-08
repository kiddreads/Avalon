// Vignette Shader
// Darkens the edges of the screen for a cinematic look.

/*
[configuration]

[OptionRangeFloat]
GUIName = Vignette Strength
OptionName = VIGNETTE_STRENGTH
MinValue = 0.0
MaxValue = 2.0
StepAmount = 0.05
DefaultValue = 0.8

[OptionRangeFloat]
GUIName = Vignette Radius
OptionName = VIGNETTE_RADIUS
MinValue = 0.1
MaxValue = 2.0
StepAmount = 0.05
DefaultValue = 0.8

[OptionRangeFloat]
GUIName = Vignette Softness
OptionName = VIGNETTE_SOFTNESS
MinValue = 0.01
MaxValue = 1.0
StepAmount = 0.01
DefaultValue = 0.45

[/configuration]
*/

void main()
{
  float4 color = Sample();
  float2 uv = GetCoordinates();

  float2 center = uv - 0.5;
  float dist = length(center);

  float radius = GetOption(VIGNETTE_RADIUS);
  float softness = GetOption(VIGNETTE_SOFTNESS);
  float strength = GetOption(VIGNETTE_STRENGTH);

  float vignette = smoothstep(radius, radius - softness, dist);
  vignette = mix(1.0, vignette, strength);

  color.rgb *= vignette;

  SetOutput(color);
}
