// Also in "tonemap" shaders.
// This currently shifts colors too much, even if it's mathematically correct.
#define FIX_LUT_GAMMA_MAPPING 1
#define LUT_SIZE 16.f

static float additionalNeutralLUTPercentage = 0.5f;
static float LUTLuminancePreservationPercentage = 0.5f;

struct PushConstantWrapper_ColorGradingMerge
{
    float LUT1Percentage;
    float LUT2Percentage;
    float LUT3Percentage;
    float LUT4Percentage;
    float neutralLUTPercentage;
};

cbuffer PushConstantWrapper_ColorGradingMerge : register(b0, space0)
{
    PushConstantWrapper_ColorGradingMerge PcwColorGradingMerge : packoffset(c0);
};

Texture2D<float3> LUT1 : register(t0, space8);
Texture2D<float3> LUT2 : register(t1, space8);
Texture2D<float3> LUT3 : register(t2, space8);
Texture2D<float3> LUT4 : register(t3, space8);
RWTexture3D<float4> outMixedLUT : register(u0, space8);

static uint3 gl_GlobalInvocationID;
struct SPIRV_Cross_Input
{
    uint3 gl_GlobalInvocationID : SV_DispatchThreadID;
};

float gamma_linear_to_sRGB(float channel)
{
    [flatten]
    if (channel <= 0.0031308f)
    {
        channel = channel * 12.92f;
    }
    else
    {
        channel = 1.055f * pow(channel, 1.0f / 2.4f) - 0.055f;
    }
    return channel;
}

float3 gamma_linear_to_sRGB(float3 Color)
{
    return float3(gamma_linear_to_sRGB(Color.r),
                  gamma_linear_to_sRGB(Color.g),
                  gamma_linear_to_sRGB(Color.b));
}

float gamma_sRGB_to_linear(float channel)
{
    [flatten]
    if (channel <= 0.04045f)
    {
        channel = channel / 12.92f;
    }
    else
    {
        channel = pow((channel + 0.055f) / 1.055f, 2.4f);
    }
    return channel;
}

float3 gamma_sRGB_to_linear(float3 Color)
{
    return float3(gamma_sRGB_to_linear(Color.r),
                  gamma_sRGB_to_linear(Color.g),
                  gamma_sRGB_to_linear(Color.b));
}

float Luminance(float3 color)
{
    // Fixed from "wrong" values: 0.2125 0.7154 0.0721f
    return dot(color, float3(0.2126f, 0.7152f, 0.0722f));
}

void CS()
{
    const uint3 outUVW = uint3(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y, gl_GlobalInvocationID.z); // In pixels
    const uint inU = (gl_GlobalInvocationID.z << 4u) + gl_GlobalInvocationID.x;
    const int3 inUVW = int3(inU, gl_GlobalInvocationID.y, 0u); // In pixels
    const float UVWScale = 1.f / (LUT_SIZE - 1.f); // Was "0.066666670143604278564453125", pixel coordinates 0-15 for a resolution of 16, which is half of LUTs size of 16x16x16
    
    float3 neutralLUTColor = float3(outUVW) * UVWScale; // The neutral LUT is automatically generated by the coordinates, but it's baked with sRGB gamma
    neutralLUTColor = gamma_sRGB_to_linear(neutralLUTColor);
    
    float3 LUT1Color = LUT1.Load(inUVW);
    float3 LUT2Color = LUT2.Load(inUVW);
    float3 LUT3Color = LUT3.Load(inUVW);
    float3 LUT4Color = LUT4.Load(inUVW);
    LUT1Color = gamma_sRGB_to_linear(LUT1Color);
    LUT2Color = gamma_sRGB_to_linear(LUT2Color);
    LUT3Color = gamma_sRGB_to_linear(LUT3Color);
    LUT4Color = gamma_sRGB_to_linear(LUT4Color);
    
    float neutralLUTLuminance = Luminance(neutralLUTColor);
    float LUT1Luminance = Luminance(LUT1Color);
    float LUT2Luminance = Luminance(LUT2Color);
    float LUT3Luminance = Luminance(LUT3Color);
    float LUT4Luminance = Luminance(LUT4Color);
    
    if (LUT1Luminance != 0.f)
        LUT1Color *= lerp(1.f, neutralLUTLuminance / LUT1Luminance, LUTLuminancePreservationPercentage);
    if (LUT2Luminance != 0.f)
        LUT2Color *= lerp(1.f, neutralLUTLuminance / LUT2Luminance, LUTLuminancePreservationPercentage);
    if (LUT3Luminance != 0.f)
        LUT3Color *= lerp(1.f, neutralLUTLuminance / LUT3Luminance, LUTLuminancePreservationPercentage);
    if (LUT4Luminance != 0.f)
        LUT4Color *= lerp(1.f, neutralLUTLuminance / LUT4Luminance, LUTLuminancePreservationPercentage);
    
#if !FIX_LUT_GAMMA_MAPPING && 0 // Disabled as it's still preferable to do LUT blends in linear space
    neutralLUTColor = gamma_linear_to_sRGB(neutralLUTColor);
    LUT1Color = gamma_linear_to_sRGB(LUT1Color);
    LUT2Color = gamma_linear_to_sRGB(LUT2Color);
    LUT3Color = gamma_linear_to_sRGB(LUT3Color);
    LUT4Color = gamma_linear_to_sRGB(LUT4Color);
#endif // FIX_LUT_GAMMA_MAPPING
    
    PushConstantWrapper_ColorGradingMerge adjustedPcwColorGradingMerge = PcwColorGradingMerge;
    adjustedPcwColorGradingMerge.neutralLUTPercentage = lerp(adjustedPcwColorGradingMerge.neutralLUTPercentage, 1.f, additionalNeutralLUTPercentage);
    adjustedPcwColorGradingMerge.LUT1Percentage = lerp(adjustedPcwColorGradingMerge.LUT1Percentage, 0.f, additionalNeutralLUTPercentage);
    adjustedPcwColorGradingMerge.LUT2Percentage = lerp(adjustedPcwColorGradingMerge.LUT2Percentage, 0.f, additionalNeutralLUTPercentage);
    adjustedPcwColorGradingMerge.LUT3Percentage = lerp(adjustedPcwColorGradingMerge.LUT3Percentage, 0.f, additionalNeutralLUTPercentage);
    adjustedPcwColorGradingMerge.LUT4Percentage = lerp(adjustedPcwColorGradingMerge.LUT4Percentage, 0.f, additionalNeutralLUTPercentage);
    
    float3 mixedLUT = (adjustedPcwColorGradingMerge.neutralLUTPercentage * neutralLUTColor)
                          + (adjustedPcwColorGradingMerge.LUT1Percentage * LUT1Color)
                          + (adjustedPcwColorGradingMerge.LUT2Percentage * LUT2Color)
                          + (adjustedPcwColorGradingMerge.LUT3Percentage * LUT3Color)
                          + (adjustedPcwColorGradingMerge.LUT4Percentage * LUT4Color);
#if !FIX_LUT_GAMMA_MAPPING // Convert to linear after blending between LUTs, so the blends are done in linear space
    mixedLUT = gamma_linear_to_sRGB(mixedLUT);
#endif // FIX_LUT_GAMMA_MAPPING
    outMixedLUT[outUVW] = float4(mixedLUT, 1.f);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    CS();
}