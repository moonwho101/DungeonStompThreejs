#include "Parsers.h"
#include <iostream>
#include <cassert>

int main()
{
    DungeonStomp::DungeonMapData map;
    bool loaded = DungeonStomp::Parsers::LoadMapFile("bin/level1.map", map);
    assert(loaded);
    assert(map.width > 0);

    DungeonStomp::Model3DS model;
    bool modelLoaded = DungeonStomp::Parsers::Load3DSFile("Assets/pew.3DS", model);
    assert(modelLoaded);
    assert(!model.vertices.empty());

    std::cout << "[TestParsers] Passed!" << std::endl;
    return 0;
}
