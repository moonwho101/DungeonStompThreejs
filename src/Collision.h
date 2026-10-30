#pragma once

#include <DirectXMath.h>
#include <vector>

namespace DungeonStomp
{
    struct Capsule
    {
        DirectX::XMFLOAT3 basePosition{ 0.0f, 0.0f, 0.0f };
        float radius = 10.0f;
        float height = 30.0f;
    };

    struct BoundingBox
    {
        DirectX::XMFLOAT3 minBounds{ -5.0f, 0.0f, -5.0f };
        DirectX::XMFLOAT3 maxBounds{ 5.0f, 20.0f, 5.0f };
    };

    class Collision
    {
    public:
        static bool ResolveCapsuleCollision(DirectX::XMFLOAT3& position, float radius, float height, const std::vector<BoundingBox>& worldObstacles);
        static bool CheckCapsuleOverlap(const Capsule& a, const Capsule& b);
    };
}
