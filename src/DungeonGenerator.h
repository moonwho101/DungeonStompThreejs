#pragma once

#include "Parsers.h"
#include <string>
#include <random>

namespace DungeonStomp
{
    struct DungeonGeneratorOptions
    {
        uint32_t numObjectsToPlace = 225;
        uint32_t seed = 12345;
        uint32_t depth = 1;
    };

    class DungeonGenerator
    {
    public:
        DungeonGenerator();

        DungeonMapData Generate(const DungeonGeneratorOptions& options);

    private:
        void GenerateRoomsAndCorridors(DungeonMapData& map, std::mt19937& rng);
    };
}
