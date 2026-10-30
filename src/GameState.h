#ifndef GAMESTATE_H
#define GAMESTATE_H

#include <string>
#include <vector>
#include <unordered_set>
#include <unordered_map>
#include <memory>
#include <glm/glm.hpp>
#include "Collision.h"

enum class MonsterState {
    IDLE,
    ALERT,
    CHASE,
    ATTACK,
    HURT,
    DEATH
};

struct MonsterConfig {
    std::string name;
    float scale = 1.0f;
    std::string format;
    std::string filepath;
    std::string textureAlias;
    float maxHealth = 100.0f;
    float speed = 100.0f;
    float aggroDist = 800.0f;
    float attackDist = 120.0f;
    float attackDamage = 15.0f;
    std::string painSound;
    std::string deathSound;
    std::string weaponSound;
    std::string yellSound;
    std::string sound;
};

class Monster {
public:
    int id = 0;
    MonsterConfig config;
    glm::vec3 position{0};
    glm::vec3 velocity{0};
    float rotation = 0.0f;
    float health = 100.0f;
    MonsterState state = MonsterState::IDLE;
    bool isGrounded = false;

    void update(float dt, const glm::vec3& playerPos);
};

struct DoorState {
    int id = 0;
    glm::vec3 position{0};
    float rotation = 0.0f;
    bool isOpen = false;
    float currentUp = 0.0f;
};

struct PlayerStats {
    float health = 100.0f;
    float maxHealth = 100.0f;
    int level = 1;
    int xp = 0;
    int nextXp = 500;
    int kills = 0;
};

extern std::vector<std::shared_ptr<Monster>> monsters;
extern std::vector<DoorState> doors;
extern PlayerStats playerStats;
extern std::unordered_set<std::string> unlockedWeapons;
extern std::unordered_map<std::string, int> spellCounts;
extern int currentGunIndex;

#endif // GAMESTATE_H
