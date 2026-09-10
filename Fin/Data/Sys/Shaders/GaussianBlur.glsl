// Gaussian Blur Shader
// Configurable radius and strength for a smooth blur effect.

/*
[configuration]

[OptionRangeFloat]
GUIName = Blur Strength
OptionName = BLUR_STRENGTH
MinValue = 0.0
MaxValue = 4.0
StepAmount = 0.1
DefaultValue = 1.0

[OptionRangeFloat]
GUIName = Blur Radius
OptionName = BLUR_RADIUS
MinValue = 0.5
MaxValue = 6.0
StepAmount = 0.5
DefaultValue = 2.0

[/configuration]
*/

void main()
{
  float2 uv = GetCoordinates();
  float2 px = GetInvResolution() * GetOption(BLUR_RADIUS);
  float strength = GetOption(BLUR_STRENGTH);

  if (strength < 0.01)
  {
    SetOutput(Sample());
    return;
  }

  // 9-tap Gaussian kernel (sigma ~1.5)
  // Weights: 0.0162, 0.0540, 0.1218, 0.1872, 0.2416, 0.1872, 0.1218, 0.0540, 0.0162
  // We use a separable 2D approximation via a cross pattern + diagonals

  float4 sum = float4(0.0, 0.0, 0.0, 0.0);
  float total = 0.0;

  // Center
  float w = 0.2416;
  sum += Sample() * w;
  total += w;

  // Cardinal directions (distance 1)
  w = 0.1872;
  sum += SampleLocation(uv + float2( 1.0,  0.0) * px) * w;
  sum += SampleLocation(uv + float2(-1.0,  0.0) * px) * w;
  sum += SampleLocation(uv + float2( 0.0,  1.0) * px) * w;
  sum += SampleLocation(uv + float2( 0.0, -1.0) * px) * w;
  total += w * 4.0;

  // Diagonals (distance 1)
  w = 0.1218;
  sum += SampleLocation(uv + float2( 1.0,  1.0) * px) * w;
  sum += SampleLocation(uv + float2(-1.0,  1.0) * px) * w;
  sum += SampleLocation(uv + float2( 1.0, -1.0) * px) * w;
  sum += SampleLocation(uv + float2(-1.0, -1.0) * px) * w;
  total += w * 4.0;

  // Cardinal directions (distance 2)
  w = 0.0540;
  sum += SampleLocation(uv + float2( 2.0,  0.0) * px) * w;
  sum += SampleLocation(uv + float2(-2.0,  0.0) * px) * w;
  sum += SampleLocation(uv + float2( 0.0,  2.0) * px) * w;
  sum += SampleLocation(uv + float2( 0.0, -2.0) * px) * w;
  total += w * 4.0;

  // Far diagonals (distance 2)
  w = 0.0162;
  sum += SampleLocation(uv + float2( 2.0,  2.0) * px) * w;
  sum += SampleLocation(uv + float2(-2.0,  2.0) * px) * w;
  sum += SampleLocation(uv + float2( 2.0, -2.0) * px) * w;
  sum += SampleLocation(uv + float2(-2.0, -2.0) * px) * w;
  total += w * 4.0;

  float4 blurred = sum / total;
  float4 original = Sample();

  SetOutput(mix(original, blurred, strength));
}
