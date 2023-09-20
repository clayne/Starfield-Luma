#define ENABLE_HDR 1
#define HDR_GAME_PAPER_WHITE 2.5f
#define HDR_USE_GAMMA_2_2 1

Texture2D<float> _8 : register(t0, space8);
Texture2D<float> _9 : register(t1, space8);
Texture2D<float> _10 : register(t2, space8);
SamplerState _13 : register(s0, space8);

struct PSInputs
{
    float4 pos : SV_Position;
    float2 TEXCOORD : TEXCOORD0;
};

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

float4 PS(PSInputs inputs) : SV_Target
{
    float Y = _8.Sample(_13, inputs.TEXCOORD.xy).x * 1.16412353515625f;
    float Cb = _9.Sample(_13, inputs.TEXCOORD.xy).x;
    float Cr = _10.Sample(_13, inputs.TEXCOORD.xy).x;
    float3 color;
    //TODO: fix matrices???
    color.x = (Y - 0.870655059814453125f) + (Cb * 1.595794677734375f);
    color.y = ((Y + 0.529705047607421875f) - (Cb * 0.8134765625f)) - (Cr * 0.391448974609375f);
    color.z = (Y - 1.081668853759765625f) + (Cr * 2.017822265625f);
    
#if ENABLE_HDR
#if HDR_USE_GAMMA_2_2
    color = pow(color, 2.2f);
#else
    color = gamma_sRGB_to_linear(color);
#endif
    color *= HDR_GAME_PAPER_WHITE;
#endif // ENABLE_HDR

    return float4(color, 1.0f);
}