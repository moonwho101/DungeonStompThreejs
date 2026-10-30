#include "Logic.h"
#include <iostream>
#include <algorithm>
#include <cmath>

std::vector<Pickup> activePickups;
int dungeonDepth = 1;

void damagePlayer(float amount) {
    playerStats.health = std::max(0.0f, playerStats.health - amount);
}

void healPlayer(float amount) {
    playerStats.health = std::min(playerStats.maxHealth, playerStats.health + amount);
}

void addPlayerXp(int amount) {
    playerStats.xp += amount;
    if (playerStats.xp >= playerStats.nextXp) {
        playerStats.level++;
        playerStats.nextXp += 500 * playerStats.level;
        playerStats.maxHealth += 20;
        playerStats.health = playerStats.maxHealth;
    }
}

void cycleWeapon(int dir) {
    (void)dir;
}

void triggerWeaponAttack() {
}

void openNearbyDoor() {
    for (auto& door : doors) {
        if (!door.isOpen) {
            door.isOpen = true;
            door.currentUp = 200.0f;
            break;
        }
    }
}

void playSound(const std::string& soundFile, float volume) {
    (void)soundFile;
    (void)volume;
}

static glm::vec3 rotateY(const glm::vec3& v, float angleDegrees) {
    float rad = angleDegrees * 3.14159265f / 180.0f;
    float cosA = std::cos(rad);
    float sinA = std::sin(rad);
    return glm::vec3(
        v.x * cosA + v.z * sinA,
        v.y,
        -v.x * sinA + v.z * cosA
    );
}

bool loadGameWorld(TextureManager& texMgr, LevelMapParser& mapParser, ObjectsDatParser& objParser) {
    (void)texMgr;
    levelTriangles.clear();
    monsters.clear();
    doors.clear();

    for (const auto& inst : mapParser.instances) {
        if (inst.name.rfind("door", 0) == 0) {
            DoorState d;
            d.id = inst.monsterId;
            d.position = glm::vec3(inst.x, inst.y, inst.z);
            d.rotation = inst.rot;
            doors.push_back(d);
        } else if (inst.name == "!monster1" || inst.monsterId > 0) {
            auto m = std::make_shared<Monster>();
            m->id = inst.monsterId;
            m->position = glm::vec3(inst.x, inst.y, inst.z);
            m->rotation = inst.rot;
            m->config.name = inst.modelName.empty() ? "Monster" : inst.modelName;
            monsters.push_back(m);
        }

        for (const auto& pair : objParser.objects) {
            const ObjectData& obj = pair.second;
            if (obj.name == inst.name) {
                for (const auto& poly : obj.polys) {
                    const auto& v = poly.verts;
                    for (size_t k = 0; k + 14 < v.size(); k += 15) {
                        glm::vec3 p0 = rotateY(glm::vec3(v[k + 0], v[k + 1], v[k + 2]), inst.rot) + glm::vec3(inst.x, inst.y, inst.z);
                        glm::vec3 p1 = rotateY(glm::vec3(v[k + 5], v[k + 6], v[k + 7]), inst.rot) + glm::vec3(inst.x, inst.y, inst.z);
                        glm::vec3 p2 = rotateY(glm::vec3(v[k + 10], v[k + 11], v[k + 12]), inst.rot) + glm::vec3(inst.x, inst.y, inst.z);

                        levelTriangles.push_back(makeCollisionTriangle(
                            p0.x, p0.y, p0.z,
                            p1.x, p1.y, p1.z,
                            p2.x, p2.y, p2.z
                        ));
                    }
                }
            }
        }
    }

    buildCollisionGrid();
    std::cout << "Loaded game world: " << levelTriangles.size() << " collision triangles, "
              << monsters.size() << " monsters, " << doors.size() << " doors." << std::endl;
    return true;
}
