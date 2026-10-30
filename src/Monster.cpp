#include "Monster.h"
#include <cmath>

namespace DungeonStomp
{
    Monster::Monster(const std::string& type, const DirectX::XMFLOAT3& position)
        : m_type(type), m_position(position)
    {
        m_config.name = type;
        m_config.maxHealth = 100.0f;
        m_config.moveSpeed = 45.0f;
        m_config.attackDamage = 12.0f;
        m_config.attackRange = 20.0f;
        m_config.aggroRange = 200.0f;
        m_health = m_config.maxHealth;
    }

    void Monster::Update(float deltaTime, const DirectX::XMFLOAT3& playerPos)
    {
        if (m_state == MonsterState::DEATH) return;

        float dx = playerPos.x - m_position.x;
        float dz = playerPos.z - m_position.z;
        float distSq = dx * dx + dz * dz;
        float dist = std::sqrt(distSq);

        if (m_attackCooldown > 0.0f)
        {
            m_attackCooldown -= deltaTime;
        }

        if (dist < m_config.attackRange)
        {
            m_state = MonsterState::ATTACK;
            if (m_attackCooldown <= 0.0f)
            {
                m_attackCooldown = 1.2f;
            }
        }
        else if (dist < m_config.aggroRange)
        {
            m_state = MonsterState::CHASE;
            m_position.x += (dx / dist) * m_config.moveSpeed * deltaTime;
            m_position.z += (dz / dist) * m_config.moveSpeed * deltaTime;
        }
        else
        {
            m_state = MonsterState::IDLE;
        }
    }

    void Monster::TakeDamage(float amount)
    {
        if (m_state == MonsterState::DEATH) return;

        m_health -= amount;
        if (m_health <= 0.0f)
        {
            m_health = 0.0f;
            m_state = MonsterState::DEATH;
        }
        else
        {
            m_state = MonsterState::HURT;
        }
    }
}
