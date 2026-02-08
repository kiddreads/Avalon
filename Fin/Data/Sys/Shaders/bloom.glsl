// Quality Bloom Shader
// Multi-sample Gaussian-weighted bloom with configurable threshold and intensity.

/*
[configuration]

[OptionRangeFloat]
GUIName = Bloom Intensity
OptionName = BLOOM_INTENSITY
MinValue = 0.0
MaxValue = 2.0
StepAmount = 0.05
DefaultValue = 0.5

[OptionRangeFloat]
GUIName = Bloom Threshold
OptionName = BLOOM_THRESHOLD
MinValue = 0.0
MaxValue = 1.5
StepAmount = 0.05
DefaultValue = 0.7

[OptionRangeFloat]
GUIName = Bloom Radius
OptionName = BLOOM_RADIUS
MinValue = 1.0
MaxValue = 8.0
StepAmount = 0.5
DefaultValue = 3.0

[/configuration]
*/

float luminance(float3 c)
{
  return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float4 sampleBloom(float2 uv, float2 offset)
{
  float4 c = SampleLocation(uv + offset);
  float lum = luminance(c.rgb);
  float threshold = GetOption(BLOOM_THRESHOLD);
  float contrib = max(lum - threshold, 0.0) / max(lum, 0.001);
  return c * contrib;
}

void main()
{
  float4 center = Sample();
  float2 uv = GetCoordinates();
  float2 px = GetInvResolution() * GetOption(BLOOM_RADIUS);

  // 13-tap Gaussian-weighted bloom kernel
  float4 bloom = float4(0.0, 0.0, 0.0, 0.0);

  // Center weight
  bloom += sampleBloom(uv, float2(0.0, 0.0)) * 0.1964825501511404;

  // Ring 1 (4 samples)
  bloom += sampleBloom(uv, float2( 1.0,  0.0) * px) * 0.2969069646728344;
  bloom += sampleBloom(uv, float2(-1.0,  0.0) * px) * 0.2969069646728344;
  bloom += sampleBloom(uv, float2( 0.0,  1.0) * px) * 0.2969069646728344;
  bloom += sampleBloom(uv, float2( 0.0, -1.0) * px) * 0.2969069646728344;

  // Ring 2 (4 diagonal samples)
  bloom += sampleBloom(uv, float2( 1.0,  1.0) * px) * 0.09447039785044732;
  bloom += sampleBloom(uv, float2(-1.0,  1.0) * px) * 0.09447039785044732;
  bloom += sampleBloom(uv, float2( 1.0, -1.0) * px) * 0.09447039785044732;
  bloom += sampleBloom(uv, float2(-1.0, -1.0) * px) * 0.09447039785044732;

  // Ring 3 (4 far samples)
  bloom += sampleBloom(uv, float2( 2.0,  0.0) * px) * 0.01038349049640964;
  bloom += sampleBloom(uv, float2(-2.0,  0.0) * px) * 0.01038349049640964;
  bloom += sampleBloom(uv, float2( 0.0,  2.0) * px) * 0.01038349049640964;
  bloom += sampleBloom(uv, float2( 0.0, -2.0) * px) * 0.01038349049640964;

  bloom /= 2.0; // Normalize

  float3 result = center.rgb + bloom.rgb * GetOption(BLOOM_INTENSITY);

  SetOutput(float4(result, center.a));
}
