#include "DungeonGenerator.h"
#include <iostream>

namespace DungeonStomp
{
    DungeonGenerator::DungeonGenerator()
    {
    }

    DungeonMapData DungeonGenerator::Generate(const DungeonGeneratorOptions& options)
    {
        DungeonMapData map;
        map.width = 32;
        map.height = 32;

        std::mt19937 rng(options.seed + options.depth);
        GenerateRoomsAndCorridors(map, rng);

        std::cout << "[DungeonGenerator] Procedural level generated (Seed: " << options.seed
                  << ", Depth: " << options.depth << ", Objects: " << options.numObjectsToPlace << ")" << std::endl;

        return map;
    }

    void DungeonGenerator::GenerateRoomsAndCorridors(DungeonMapData& map, std::mt19937& rng)
    {
        map.tiles.resize(map.width * map.height);
        map.startPosition = { 20.0f, 0.0f, 20.0f };
        map.exitPosition = { 300.0f, 0.0f, 300.0f };

        for (uint32_t z = 0; z < map.height; ++z)
        {
            for (uint32_t x = 0; x < map.width; ++x)
            {
                size_t index = z * map.width + x;
                map.tiles[index].x = static_cast<float>(x) * 10.0f;
                map.tiles[index].z = static_cast<float>(z) * 10.0f;
                if (x == 0 || x == map.width - 1 || z == 0 || z == map.height - 1)
                {
                    map.tiles[index].tileType = 2; // Wall
                }
                else
                {
                    map.tiles[index].tileType = 1; // Floor
                }
            }
        }
    }
}
