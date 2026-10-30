#include "Player.h"
#include <algorithm>

namespace DungeonStomp
{
    Player::Player()
    {
        m_unlockedWeapons = { "AXE", "FLAMESWORD", "BASTARD SWORD", "ICE SWORD", "LIGHTNING SWORD", "FIREBALL", "MAGIC MISSILE", "LIGHTNING", "HEALING" };
        m_spellCounts["FIREBALL"] = 10;
        m_spellCounts["MAGIC MISSILE"] = 20;
        m_spellCounts["LIGHTNING"] = 10;
        m_spellCounts["HEALING"] = 5;
    }

    void Player::Update(float deltaTime)
    {
        m_position.x += m_velocity.x * deltaTime;
        m_position.y += m_velocity.y * deltaTime;
        m_position.z += m_velocity.z * deltaTime;
    }

    void Player::TakeDamage(float amount)
    {
        m_stats.health = std::max(0.0f, m_stats.health - amount);
    }

    void Player::Heal(float amount)
    {
        m_stats.health = std::min(m_stats.maxHealth, m_stats.health + amount);
    }

    void Player::AddXp(uint32_t amount)
    {
        m_stats.xp += amount;
        if (m_stats.xp >= m_stats.nextXp)
        {
            m_stats.level++;
            m_stats.xp -= m_stats.nextXp;
            m_stats.nextXp += 500;
            m_stats.maxHealth += 20.0f;
            m_stats.health = m_stats.maxHealth;
        }
    }

    void Player::CycleWeapon(int direction)
    {
        if (m_unlockedWeapons.empty()) return;
        if (direction > 0)
        {
            m_currentWeaponIndex = (m_currentWeaponIndex + 1) % m_unlockedWeapons.size();
        }
        else
        {
            m_currentWeaponIndex = (m_currentWeaponIndex + m_unlockedWeapons.size() - 1) % m_unlockedWeapons.size();
        }
        m_currentWeapon = m_unlockedWeapons[m_currentWeaponIndex];
    }

    void Player::TriggerAttack()
    {
        if (m_currentWeapon == "HEALING" && m_spellCounts["HEALING"] > 0)
        {
            m_spellCounts["HEALING"]--;
            Heal(40.0f);
        }
    }
}
