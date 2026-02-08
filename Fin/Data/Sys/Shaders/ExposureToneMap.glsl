// Simple HDR tone mapping using the built-in exposure uniform.
// When HDR Output is on, Sample() can return values > 1.0; this shader
// applies exposure-based tone mapping and gamma correction.
// The Settings → Graphics → Exposure slider controls the 'exposure' uniform.

void main()
{
  float3 hdrColor = Sample().rgb;

  // When HDR is active, tone map then gamma correct for display
  if (OptionEnabled(hdr_output))
  {
    float3 mapped = ToneMapExposure(hdrColor, exposure);
    mapped = GammaCorrect(mapped, 2.2);
    SetOutput(float4(mapped, 1.0));
  }
  else
  {
    // SDR: optional brightness from exposure (1.0 = no change)
    float3 mapped = hdrColor * exposure;
    mapped = clamp(mapped, float3(0.0), float3(1.0));
    mapped = GammaCorrect(mapped, 2.2);
    SetOutput(float4(mapped, 1.0));
  }
}
