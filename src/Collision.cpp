#include "Collision.h"
#include <algorithm>
#include <cmath>

namespace DungeonStomp
{
    bool Collision::ResolveCapsuleCollision(DirectX::XMFLOAT3& position, float radius, float height, const std::vector<BoundingBox>& worldObstacles)
    {
        bool hit = false;
        for (const auto& box : worldObstacles)
        {
            float closestX = std::max(box.minBounds.x, std::min(position.x, box.maxBounds.x));
            float closestZ = std::max(box.minBounds.z, std::min(position.z, box.maxBounds.z));

            float dx = position.x - closestX;
            float dz = position.z - closestZ;
            float distSq = dx * dx + dz * dz;

            if (distSq < radius * radius && distSq > 1e-6f)
            {
                float dist = std::sqrt(distSq);
                float overlap = radius - dist;
                position.x += (dx / dist) * overlap;
                position.z += (dz / dist) * overlap;
                hit = true;
            }
        }
        return hit;
    }

    bool Collision::CheckCapsuleOverlap(const Capsule& a, const Capsule& b)
    {
        float dx = a.basePosition.x - b.basePosition.x;
        float dz = a.basePosition.z - b.basePosition.z;
        float minDist = a.radius + b.radius;
        return (dx * dx + dz * dz) < (minDist * minDist);
    }
}
