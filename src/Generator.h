#ifndef GENERATOR_H
#define GENERATOR_H

#include <string>
#include <vector>
#include <memory>

struct GeneratorOptions {
    float startX = 5200.0f;
    float startZ = 2600.0f;
    std::string seed = "";
    int numObjectsToPlace = 225;
};

std::string generateDungeon(const GeneratorOptions& options = {});

#endif // GENERATOR_H
