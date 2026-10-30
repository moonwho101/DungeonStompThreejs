#pragma once

#include <DirectXMath.h>
#include <string>
#include <vector>
#include <unordered_map>

namespace DungeonStomp
{
    struct PlayerStats
    {
        float health = 100.0f;
        float maxHealth = 100.0f;
        uint32_t level = 1;
        uint32_t xp = 0;
        uint32_t nextXp = 500;
        uint32_t kills = 0;
    };

    class Player
    {
    public:
        Player();

        void Update(float deltaTime);
        void TakeDamage(float amount);
        void Heal(float amount);
        void AddXp(uint32_t amount);

        void CycleWeapon(int direction);
        void TriggerAttack();

        const DirectX::XMFLOAT3& GetPosition() const { return m_position; }
        void SetPosition(const DirectX::XMFLOAT3& pos) { m_position = pos; }

        const PlayerStats& GetStats() const { return m_stats; }
        const std::string& GetCurrentWeapon() const { return m_currentWeapon; }

    private:
        DirectX::XMFLOAT3 m_position{ 0.0f, 15.0f, 0.0f };
        DirectX::XMFLOAT3 m_velocity{ 0.0f, 0.0f, 0.0f };
        PlayerStats m_stats;

        std::vector<std::string> m_unlockedWeapons;
        size_t m_currentWeaponIndex = 0;
        std::string m_currentWeapon = "AXE";
        std::unordered_map<std::string, uint32_t> m_spellCounts;
    };
}
