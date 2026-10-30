// VertexShader.hlsl - DirectX 12 Ultimate Standard & Dynamic Lighting Vertex Shader

cbuffer SceneConstantBuffer : register(b0)
{
    matrix viewProjectionMatrix;
    matrix modelMatrix;
    float3 cameraPosition;
    float time;
};

struct VSInput
{
    float3 position : POSITION;
    float3 normal   : NORMAL;
    float2 texCoord : TEXCOORD0;
    float3 tangent  : TANGENT;
};

struct VSOutput
{
    float4 position : SV_POSITION;
    float3 worldPos : TEXCOORD1;
    float3 normal   : NORMAL;
    float2 texCoord : TEXCOORD0;
    float3 tangent  : TANGENT;
};

VSOutput main(VSInput input)
{
    VSOutput output;
    float4 worldPosition = mul(modelMatrix, float4(input.position, 1.0f));
    output.worldPos = worldPosition.xyz;
    output.position = mul(viewProjectionMatrix, worldPosition);
    output.normal = normalize(mul((float3x3)modelMatrix, input.normal));
    output.tangent = normalize(mul((float3x3)modelMatrix, input.tangent));
    output.texCoord = input.texCoord;
    return output;
}
