#pragma once

#include <DirectXMath.h>
#include <vector>

namespace DungeonStomp
{
    struct MinimapPoint
    {
        float x = 0.0f;
        float z = 0.0f;
        uint32_t type = 0; // 0: floor, 1: wall, 2: monster, 3: player
    };

    class Minimap
    {
    public:
        Minimap();

        void Update(const DirectX::XMFLOAT3& playerPos, const std::vector<DirectX::XMFLOAT3>& monsterPositions);
        const std::vector<MinimapPoint>& GetPoints() const { return m_points; }

    private:
        std::vector<MinimapPoint> m_points;
    };
}
