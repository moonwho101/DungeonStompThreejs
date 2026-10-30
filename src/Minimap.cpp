#include "Minimap.h"

namespace DungeonStomp
{
    Minimap::Minimap()
    {
    }

    void Minimap::Update(const DirectX::XMFLOAT3& playerPos, const std::vector<DirectX::XMFLOAT3>& monsterPositions)
    {
        m_points.clear();
        m_points.push_back({ playerPos.x, playerPos.z, 3 });

        for (const auto& monsterPos : monsterPositions)
        {
            m_points.push_back({ monsterPos.x, monsterPos.z, 2 });
        }
    }
}
