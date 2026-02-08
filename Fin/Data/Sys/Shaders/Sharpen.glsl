// Adaptive Sharpening Shader
// Unsharp mask with luminance-aware edge detection to avoid sharpening noise.

/*
[configuration]

[OptionRangeFloat]
GUIName = Sharpness
OptionName = SHARPEN_STRENGTH
MinValue = 0.0
MaxValue = 3.0
StepAmount = 0.1
DefaultValue = 1.0

[OptionRangeFloat]
GUIName = Clamp (Haloing Limit)
OptionName = SHARPEN_CLAMP
MinValue = 0.0
MaxValue = 1.0
StepAmount = 0.01
DefaultValue = 0.12

[/configuration]
*/

float getLuma(float3 c)
{
  return dot(c, float3(0.2126, 0.7152, 0.0722));
}

void main()
{
  float2 uv = GetCoordinates();
  float2 px = GetInvResolution();
  float strength = GetOption(SHARPEN_STRENGTH);
  float clampVal = GetOption(SHARPEN_CLAMP);

  if (strength < 0.01)
  {
    SetOutput(Sample());
    return;
  }

  // 3x3 neighborhood sampling
  float4 center = Sample();
  float4 n  = SampleLocation(uv + float2( 0.0, -1.0) * px);
  float4 s  = SampleLocation(uv + float2( 0.0,  1.0) * px);
  float4 e  = SampleLocation(uv + float2( 1.0,  0.0) * px);
  float4 w  = SampleLocation(uv + float2(-1.0,  0.0) * px);
  float4 nw = SampleLocation(uv + float2(-1.0, -1.0) * px);
  float4 ne = SampleLocation(uv + float2( 1.0, -1.0) * px);
  float4 sw = SampleLocation(uv + float2(-1.0,  1.0) * px);
  float4 se = SampleLocation(uv + float2( 1.0,  1.0) * px);

  // Weighted blur (3x3 Gaussian-ish)
  float4 blur = (n + s + e + w) * 0.15 + (nw + ne + sw + se) * 0.1 + center * 0.2;

  // Unsharp mask: detail = original - blur
  float4 detail = center - blur;

  // Luminance-based clamping to reduce haloing
  float luma = getLuma(center.rgb);
  float detailLuma = getLuma(abs(detail.rgb));
  float clampAmount = clampVal * luma;
  detail = clamp(detail, -clampAmount, clampAmount);

  float3 result = center.rgb + detail.rgb * strength;
  result = clamp(result, 0.0, 1.0);

  SetOutput(float4(result, center.a));
}
