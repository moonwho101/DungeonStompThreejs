// Raytracing.hlsl - DirectX 12 Ultimate Raytracing DXR 1.1 Shaders

RaytracingAccelerationStructure Scene : register(t0, space0);
RWTexture2D<float4> RenderTarget : register(u0, space0);

cbuffer RaytracingConstantBuffer : register(b0)
{
    matrix viewProjectionInverse;
    float3 cameraPosition;
    float time;
};

struct RayPayload
{
    float4 color;
};

[shader("raygeneration")]
void RayGenShader()
{
    uint2 launchIndex = DispatchRaysIndex().xy;
    uint2 launchDimensions = DispatchRaysDimensions().xy;

    float2 clipPos = (float2(launchIndex) + 0.5f) / float2(launchDimensions) * 2.0f - 1.0f;
    clipPos.y = -clipPos.y;

    float4 worldPos = mul(viewProjectionInverse, float4(clipPos, 0.0f, 1.0f));
    worldPos.xyz /= worldPos.w;

    RayDesc ray;
    ray.Origin = cameraPosition;
    ray.Direction = normalize(worldPos.xyz - cameraPosition);
    ray.MinT = 0.001f;
    ray.MaxT = 10000.0f;

    RayPayload payload = { float4(0, 0, 0, 0) };
    TraceRay(Scene, RAY_FLAG_NONE, 0xFF, 0, 0, 0, ray, payload);

    RenderTarget[launchIndex] = payload.color;
}

[shader("miss")]
void MissShader(inout RayPayload payload)
{
    payload.color = float4(0.05f, 0.05f, 0.1f, 1.0f); // Ambient sky/dungeon darkness
}

[shader("closesthit")]
void ClosestHitShader(inout RayPayload payload, in BuiltInTriangleIntersectionAttributes attribs)
{
    float3 barycentricCoords = float3(1.0f - attribs.barycentrics.x - attribs.barycentrics.y, attribs.barycentrics.x, attribs.barycentrics.y);
    payload.color = float4(barycentricCoords, 1.0f);
}
