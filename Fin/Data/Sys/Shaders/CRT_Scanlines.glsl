// CRT Scanline Shader
// Simulates CRT display scanlines with configurable intensity and curvature.

/*
[configuration]

[OptionRangeFloat]
GUIName = Scanline Intensity
OptionName = CRT_SCANLINE_INTENSITY
MinValue = 0.0
MaxValue = 1.0
StepAmount = 0.05
DefaultValue = 0.4

[OptionRangeFloat]
GUIName = Scanline Width
OptionName = CRT_SCANLINE_WIDTH
MinValue = 0.5
MaxValue = 4.0
StepAmount = 0.1
DefaultValue = 1.0

[OptionRangeFloat]
GUIName = Curvature
OptionName = CRT_CURVATURE
MinValue = 0.0
MaxValue = 0.5
StepAmount = 0.01
DefaultValue = 0.0

[OptionRangeFloat]
GUIName = Corner Darkening
OptionName = CRT_CORNER
MinValue = 0.0
MaxValue = 1.0
StepAmount = 0.05
DefaultValue = 0.0

[OptionRangeFloat]
GUIName = Brightness Boost
OptionName = CRT_BRIGHTNESS
MinValue = 0.8
MaxValue = 1.5
StepAmount = 0.05
DefaultValue = 1.1

[/configuration]
*/

float2 applyCurvature(float2 uv, float curvature)
{
  float2 cc = uv - 0.5;
  float dist = dot(cc, cc) * curvature;
  return uv + cc * dist;
}

void main()
{
  float2 uv = GetCoordinates();
  float curvature = GetOption(CRT_CURVATURE);

  // Apply barrel distortion
  if (curvature > 0.001)
    uv = applyCurvature(uv, curvature);

  // Out of bounds check
  if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
  {
    SetOutput(float4(0.0, 0.0, 0.0, 1.0));
    return;
  }

  float4 color = SampleLocation(uv);
  float2 res = GetResolution();

  // Scanline effect
  float scanlineWidth = GetOption(CRT_SCANLINE_WIDTH);
  float scanline = sin(uv.y * res.y * 3.14159265 / scanlineWidth);
  scanline = scanline * scanline;
  float intensity = GetOption(CRT_SCANLINE_INTENSITY);
  color.rgb *= 1.0 - intensity * (1.0 - scanline);

  // Corner darkening (vignette-like)
  float corner = GetOption(CRT_CORNER);
  if (corner > 0.001)
  {
    float2 cc = uv - 0.5;
    float vignette = 1.0 - dot(cc, cc) * corner * 4.0;
    color.rgb *= clamp(vignette, 0.0, 1.0);
  }

  // Brightness compensation
  color.rgb *= GetOption(CRT_BRIGHTNESS);

  color.rgb = clamp(color.rgb, 0.0, 1.0);

  SetOutput(color);
}
