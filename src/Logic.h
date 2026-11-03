#ifndef LOGIC_H
#define LOGIC_H

#include "GameState.h"
#include "Parsers.h"
#include <string>

struct Pickup {
    std::string type;
    glm::vec3 position{0};
    bool active = true;
};

extern std::vector<Pickup> activePickups;
extern int dungeonDepth;

void damagePlayer(float amount);
void healPlayer(float amount);
void addPlayerXp(int amount);
void cycleWeapon(int dir);
void triggerWeaponAttack();
void openNearbyDoor();
void playSound(const std::string& soundFile, float volume = 1.0f);
bool loadGameWorld(TextureManager& texMgr, LevelMapParser& mapParser, ObjectsDatParser& objParser);

#endif // LOGIC_H
