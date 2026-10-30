#pragma once

#include <string>
#include <vector>
#include <DirectXMath.h>

namespace DungeonStomp
{
    enum class MonsterState
    {
        IDLE,
        ALERT,
        CHASE,
        ATTACK,
        HURT,
        DEATH
    };

    struct MonsterConfig
    {
        std::string name;
        float maxHealth = 100.0f;
        float moveSpeed = 40.0f;
        float attackDamage = 15.0f;
        float attackRange = 25.0f;
        float aggroRange = 150.0f;
        bool castsSpells = false;
        std::string spellType;
    };

    class Monster
    {
    public:
        Monster(const std::string& type, const DirectX::XMFLOAT3& position);

        void Update(float deltaTime, const DirectX::XMFLOAT3& playerPos);
        void TakeDamage(float amount);

        MonsterState GetState() const { return m_state; }
        const DirectX::XMFLOAT3& GetPosition() const { return m_position; }
        float GetHealth() const { return m_health; }
        bool IsDead() const { return m_state == MonsterState::DEATH; }

    private:
        std::string m_type;
        MonsterConfig m_config;
        MonsterState m_state = MonsterState::IDLE;
        DirectX::XMFLOAT3 m_position{ 0.0f, 0.0f, 0.0f };
        float m_health = 100.0f;
        float m_attackCooldown = 0.0f;
    };
}
