#include "GameState.h"
#include <cmath>
#include <glm/gtx/norm.hpp>

std::vector<std::shared_ptr<Monster>> monsters;
std::vector<DoorState> doors;
PlayerStats playerStats;
std::unordered_set<std::string> unlockedWeapons = {"AXE", "MAGIC MISSILE", "FIREBALL", "LIGHTNING", "HEALING"};
std::unordered_map<std::string, int> spellCounts = {
    {"MAGIC MISSILE", 5},
    {"FIREBALL", 5},
    {"LIGHTNING", 5},
    {"HEALING", 5}
};
int currentGunIndex = 0;

void Monster::update(float dt, const glm::vec3& playerPos) {
    if (state == MonsterState::DEATH) return;

    float distToPlayer = glm::distance(position, playerPos);
    if (distToPlayer < config.aggroDist) {
        state = MonsterState::CHASE;
    }

    if (state == MonsterState::CHASE) {
        glm::vec3 dir = playerPos - position;
        dir.y = 0;
        if (glm::length2(dir) > 1e-4f) {
            dir = glm::normalize(dir);
            velocity.x = dir.x * config.speed;
            velocity.z = dir.z * config.speed;
            rotation = std::atan2(-dir.x, -dir.z) * 180.0f / 3.14159265f;
        }
        if (distToPlayer <= config.attackDist) {
            state = MonsterState::ATTACK;
        }
    }

    velocity.y -= GRAVITY * dt;

    position += velocity * dt;
    isGrounded = resolveCapsuleWorld(position, MONSTER_FOOT_OFFSET, MONSTER_CAPSULE_RADIUS, MONSTER_CAPSULE_HEIGHT, &velocity);
}
