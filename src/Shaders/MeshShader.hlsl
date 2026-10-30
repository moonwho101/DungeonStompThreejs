// MeshShader.hlsl - DirectX 12 Ultimate Mesh Shader Pipeline (Shader Model 6.5)

#define MAX_MS_VERTS 64
#define MAX_MS_PRIMS 126

struct MeshVertexOutput
{
    float4 position : SV_POSITION;
    float3 worldPos : TEXCOORD1;
    float3 normal   : NORMAL;
    float2 texCoord : TEXCOORD0;
};

struct MeshPayload
{
    uint meshletIndices[32];
};

cbuffer SceneConstantBuffer : register(b0)
{
    matrix viewProjectionMatrix;
    matrix modelMatrix;
    float3 cameraPosition;
    float time;
};

[NumThreads(32, 1, 1)]
[OutputTopology("triangle")]
void main(
    uint gtid : SV_GroupIndex,
    uint gid : SV_GroupID,
    in payload MeshPayload payload,
    out vertices MeshVertexOutput verts[MAX_MS_VERTS],
    out indices uint3 prims[MAX_MS_PRIMS])
{
    SetMeshOutputCounts(MAX_MS_VERTS, MAX_MS_PRIMS);

    if (gtid < MAX_MS_VERTS)
    {
        float3 pos = float3(gtid % 8, 0, gtid / 8);
        float4 worldPos = mul(modelMatrix, float4(pos, 1.0f));
        verts[gtid].position = mul(viewProjectionMatrix, worldPos);
        verts[gtid].worldPos = worldPos.xyz;
        verts[gtid].normal = float3(0, 1, 0);
        verts[gtid].texCoord = float2(pos.x / 8.0f, pos.z / 8.0f);
    }

    if (gtid < MAX_MS_PRIMS)
    {
        prims[gtid] = uint3(gtid % 8, (gtid + 1) % 8, (gtid + 2) % 8);
    }
}
