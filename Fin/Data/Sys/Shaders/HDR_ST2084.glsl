// HDR ST2084 (PQ) Tone Mapping
// Attempt to implement the SMPTE ST 2084 Perceptual Quantizer (PQ) transfer function
// used in HDR10 displays. Maps HDR linear light to PQ curve for HDR output,
// or applies inverse PQ for SDR display.

/*
[configuration]

[OptionRangeFloat]
GUIName = Display Max Nits
OptionName = PQ_DISPLAY_MAX_NITS
MinValue = 100
MaxValue = 4000
StepAmount = 50
DefaultValue = 1000

[OptionRangeFloat]
GUIName = Paper White Nits
OptionName = PQ_PAPER_WHITE
MinValue = 80
MaxValue = 500
StepAmount = 10
DefaultValue = 203

[OptionRangeFloat]
GUIName = Exposure
OptionName = PQ_EXPOSURE
MinValue = 0.1
MaxValue = 5.0
StepAmount = 0.1
DefaultValue = 1.0

[OptionRangeFloat]
GUIName = Saturation
OptionName = PQ_SATURATION
MinValue = 0.0
MaxValue = 2.0
StepAmount = 0.05
DefaultValue = 1.0

[/configuration]
*/

// ST 2084 PQ constants
const float m1 = 0.1593017578125;
const float m2 = 78.84375;
const float c1 = 0.8359375;
const float c2 = 18.8515625;
const float c3 = 18.6875;

// Linear to PQ (encode)
float3 linearToPQ(float3 L)
{
  // Normalize to 10000 nits reference
  L = max(L, float3(0.0, 0.0, 0.0));
  float3 Lp = pow(L, float3(m1, m1, m1));
  float3 N = pow((c1 + c2 * Lp) / (1.0 + c3 * Lp), float3(m2, m2, m2));
  return N;
}

// PQ to linear (decode)
float3 pqToLinear(float3 N)
{
  N = max(N, float3(0.0, 0.0, 0.0));
  float3 Np = pow(N, float3(1.0 / m2, 1.0 / m2, 1.0 / m2));
  float3 L = pow(max(Np - c1, float3(0.0, 0.0, 0.0)) / (c2 - c3 * Np), float3(1.0 / m1, 1.0 / m1, 1.0 / m1));
  return L;
}

// Simple Reinhard-based HDR compression for display
float3 compressHDR(float3 hdr, float maxNits, float paperWhite)
{
  float scale = paperWhite / 10000.0;
  hdr *= scale;

  // Soft knee compression
  float peak = maxNits / 10000.0;
  float3 compressed = hdr * (1.0 + hdr / (peak * peak)) / (1.0 + hdr);
  return compressed;
}

void main()
{
  float4 c = Sample();
  float3 col = c.rgb;

  float displayMax = GetOption(PQ_DISPLAY_MAX_NITS);
  float paperWhite = GetOption(PQ_PAPER_WHITE);
  float exposureVal = GetOption(PQ_EXPOSURE);
  float saturation = GetOption(PQ_SATURATION);

  // Apply exposure
  col *= exposureVal;

  if (OptionEnabled(hdr_output))
  {
    // HDR path: compress and encode to PQ
    col = compressHDR(col, displayMax, paperWhite);
    col = linearToPQ(col);
  }
  else
  {
    // SDR path: simple tone mapping
    col = col / (col + float3(1.0, 1.0, 1.0));
    col = pow(max(col, float3(0.0, 0.0, 0.0)), float3(1.0 / 2.2, 1.0 / 2.2, 1.0 / 2.2));
  }

  // Saturation
  float luma = dot(col, float3(0.2126, 0.7152, 0.0722));
  col = mix(float3(luma, luma, luma), col, saturation);

  col = clamp(col, 0.0, 1.0);

  SetOutput(float4(col, c.a));
}
