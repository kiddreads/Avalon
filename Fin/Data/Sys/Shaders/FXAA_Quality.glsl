// FXAA Quality - Enhanced Fast Approximate Anti-Aliasing
// Higher quality version with configurable edge detection and subpixel smoothing.
// Based on FXAA 3.11 by Timothy Lottes (NVIDIA).

/*
[configuration]

[OptionRangeFloat]
GUIName = Subpixel Quality
OptionName = FXAA_SUBPIX
MinValue = 0.0
MaxValue = 1.0
StepAmount = 0.05
DefaultValue = 0.75

[OptionRangeFloat]
GUIName = Edge Threshold
OptionName = FXAA_EDGE_THRESHOLD
MinValue = 0.063
MaxValue = 0.333
StepAmount = 0.01
DefaultValue = 0.125

[OptionRangeFloat]
GUIName = Edge Threshold Min
OptionName = FXAA_EDGE_THRESHOLD_MIN
MinValue = 0.0
MaxValue = 0.1
StepAmount = 0.005
DefaultValue = 0.0312

[/configuration]
*/

float FxaaLuma(float4 rgba)
{
  return dot(rgba.rgb, float3(0.299, 0.587, 0.114));
}

void main()
{
  float2 uv = GetCoordinates();
  float2 invRes = GetInvResolution();

  float subpix = GetOption(FXAA_SUBPIX);
  float edgeThreshold = GetOption(FXAA_EDGE_THRESHOLD);
  float edgeThresholdMin = GetOption(FXAA_EDGE_THRESHOLD_MIN);

  // Sample center and neighbors
  float4 rgbM = Sample();
  float lumaM = FxaaLuma(rgbM);

  float lumaN  = FxaaLuma(SampleLocation(uv + float2( 0.0, -1.0) * invRes));
  float lumaS  = FxaaLuma(SampleLocation(uv + float2( 0.0,  1.0) * invRes));
  float lumaE  = FxaaLuma(SampleLocation(uv + float2( 1.0,  0.0) * invRes));
  float lumaW  = FxaaLuma(SampleLocation(uv + float2(-1.0,  0.0) * invRes));

  float lumaMin = min(lumaM, min(min(lumaN, lumaS), min(lumaE, lumaW)));
  float lumaMax = max(lumaM, max(max(lumaN, lumaS), max(lumaE, lumaW)));
  float lumaRange = lumaMax - lumaMin;

  // Early exit for low contrast areas
  if (lumaRange < max(edgeThresholdMin, lumaMax * edgeThreshold))
  {
    SetOutput(rgbM);
    return;
  }

  // Sample corners
  float lumaNW = FxaaLuma(SampleLocation(uv + float2(-1.0, -1.0) * invRes));
  float lumaNE = FxaaLuma(SampleLocation(uv + float2( 1.0, -1.0) * invRes));
  float lumaSW = FxaaLuma(SampleLocation(uv + float2(-1.0,  1.0) * invRes));
  float lumaSE = FxaaLuma(SampleLocation(uv + float2( 1.0,  1.0) * invRes));

  float lumaNS = lumaN + lumaS;
  float lumaEW = lumaE + lumaW;

  float lumaNWSW = lumaNW + lumaSW;
  float lumaNENE2 = lumaNE + lumaSE;

  // Compute subpixel blend
  float subpixNSEW = lumaNS + lumaEW;
  float subpixA = subpixNSEW * 2.0 + lumaNWSW + lumaNENE2;
  float subpixB = (subpixA * (1.0 / 12.0)) - lumaM;
  float subpixC = clamp(abs(subpixB) / lumaRange, 0.0, 1.0);
  float subpixD = (-2.0 * subpixC + 3.0) * subpixC * subpixC;
  float subpixF = subpixD * subpixD * subpix;

  // Determine edge direction
  float edgeH = abs(lumaNWSW - 2.0 * lumaW) + abs(lumaNS - 2.0 * lumaM) * 2.0 + abs(lumaNENE2 - 2.0 * lumaE);
  float edgeV = abs(lumaNW + lumaNE - 2.0 * lumaN) + abs(lumaEW - 2.0 * lumaM) * 2.0 + abs(lumaSW + lumaSE - 2.0 * lumaS);
  bool horzSpan = edgeH >= edgeV;

  float lengthSign = horzSpan ? invRes.y : invRes.x;
  if (!horzSpan) { lumaN = lumaW; lumaS = lumaE; }

  float gradientN = abs(lumaN - lumaM);
  float gradientS = abs(lumaS - lumaM);

  if (gradientN < gradientS) lengthSign = -lengthSign;

  float2 posN;
  posN.x = uv.x + (horzSpan ? 0.0 : lengthSign * 0.5);
  posN.y = uv.y + (horzSpan ? lengthSign * 0.5 : 0.0);

  // Search along edge
  float2 offNP = horzSpan ? float2(invRes.x, 0.0) : float2(0.0, invRes.y);

  float lumaEndN = FxaaLuma(SampleLocation(posN - offNP * 1.5));
  float lumaEndP = FxaaLuma(SampleLocation(posN + offNP * 1.5));

  float gradientScaled = max(gradientN, gradientS) * 0.25;
  float lumaMM = lumaM - (lumaN + lumaS) * 0.5;
  bool lumaMLTZero = lumaMM < 0.0;

  lumaEndN -= (lumaN + lumaS) * 0.5;
  lumaEndP -= (lumaN + lumaS) * 0.5;

  bool doneN = abs(lumaEndN) >= gradientScaled;
  bool doneP = abs(lumaEndP) >= gradientScaled;

  float dstN = 1.5;
  float dstP = 1.5;

  // Extended search (up to 5 steps)
  for (int i = 0; i < 5; i++)
  {
    if (!doneN)
    {
      dstN += 1.0;
      lumaEndN = FxaaLuma(SampleLocation(posN - offNP * dstN));
      lumaEndN -= (lumaN + lumaS) * 0.5;
      doneN = abs(lumaEndN) >= gradientScaled;
    }
    if (!doneP)
    {
      dstP += 1.0;
      lumaEndP = FxaaLuma(SampleLocation(posN + offNP * dstP));
      lumaEndP -= (lumaN + lumaS) * 0.5;
      doneP = abs(lumaEndP) >= gradientScaled;
    }
    if (doneN && doneP) break;
  }

  float dst = min(dstN, dstP);
  float spanLength = dstN + dstP;
  float pixelOffset = (-dst / spanLength + 0.5) * lengthSign;

  bool goodSpan = ((dstN < dstP) ? (lumaEndN < 0.0) : (lumaEndP < 0.0)) != lumaMLTZero;
  float pixelOffsetGood = goodSpan ? pixelOffset : 0.0;
  float pixelOffsetSubpix = max(pixelOffsetGood, subpixF * lengthSign);

  float2 posF;
  posF.x = uv.x + (horzSpan ? 0.0 : pixelOffsetSubpix);
  posF.y = uv.y + (horzSpan ? pixelOffsetSubpix : 0.0);

  SetOutput(SampleLocation(posF));
}
