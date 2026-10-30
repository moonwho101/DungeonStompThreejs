// PixelShader.hlsl - DirectX 12 Ultimate Normal-Mapped Dynamic Light Pixel Shader

Texture2D albedoTexture : register(t0);
Texture2D normalMapTexture : register(t1);
SamplerState defaultSampler : register(s0);

cbuffer LightConstantBuffer : register(b1)
{
    float3 lightPositions[16];
    float3 lightColors[16];
    float4 lightParams[16]; // x: intensity, y: range, z: enabled
    uint numLights;
    float3 ambientColor;
};

struct PSInput
{
    float4 position : SV_POSITION;
    float3 worldPos : TEXCOORD1;
    float3 normal   : NORMAL;
    float2 texCoord : TEXCOORD0;
    float3 tangent  : TANGENT;
};

float4 main(PSInput input) : SV_TARGET
{
    float4 albedo = albedoTexture.Sample(defaultSampler, input.texCoord);
    if (albedo.a < 0.1f)
    {
        discard;
    }

    // Normal mapping setup
    float3 N = normalize(input.normal);
    float3 T = normalize(input.tangent);
    float3 B = cross(N, T);
    float3x3 TBN = float3x3(T, B, N);

    float3 sampledNormal = normalMapTexture.Sample(defaultSampler, input.texCoord).rgb * 2.0f - 1.0f;
    float3 worldNormal = normalize(mul(sampledNormal, TBN));

    float3 finalLighting = ambientColor;

    for (uint i = 0; i < numLights; ++i)
    {
        if (lightParams[i].z > 0.5f)
        {
            float3 lightVec = lightPositions[i] - input.worldPos;
            float distance = length(lightVec);
            float range = lightParams[i].y;

            if (distance < range)
            {
                float3 lightDir = lightVec / distance;
                float diff = max(dot(worldNormal, lightDir), 0.0f);
                float attenuation = 1.0f - saturate(distance / range);
                attenuation *= attenuation; // Quadratic roll-off

                finalLighting += lightColors[i] * lightParams[i].x * diff * attenuation;
            }
        }
    }

    return float4(albedo.rgb * finalLighting, albedo.a);
}
