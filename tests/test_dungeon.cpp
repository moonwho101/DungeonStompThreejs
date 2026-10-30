#include "DungeonGenerator.h"
#include <iostream>
#include <cassert>

int main()
{
    DungeonStomp::DungeonGenerator generator;
    DungeonStomp::DungeonGeneratorOptions options;
    options.seed = 12345;
    options.depth = 1;

    DungeonStomp::DungeonMapData map = generator.Generate(options);
    assert(map.width == 32);
    assert(map.height == 32);
    assert(!map.tiles.empty());

    std::cout << "[TestDungeon] Passed!" << std::endl;
    return 0;
}
