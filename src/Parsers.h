#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include <DirectXMath.h>

namespace DungeonStomp
{
    struct MapTile
    {
        uint16_t tileType = 0;
        uint16_t objectId = 0;
        float x = 0.0f;
        float y = 0.0f;
        float z = 0.0f;
    };

    struct DungeonMapData
    {
        uint32_t width = 0;
        uint32_t height = 0;
        std::vector<MapTile> tiles;
        DirectX::XMFLOAT3 startPosition{ 0.0f, 0.0f, 0.0f };
        DirectX::XMFLOAT3 exitPosition{ 0.0f, 0.0f, 0.0f };
    };

    struct Model3DS
    {
        std::string name;
        std::vector<DirectX::XMFLOAT3> vertices;
        std::vector<uint32_t> indices;
        std::vector<DirectX::XMFLOAT2> uvs;
    };

    class Parsers
    {
    public:
        static bool LoadMapFile(const std::string& filepath, DungeonMapData& outMapData);
        static bool Load3DSFile(const std::string& filepath, Model3DS& outModel);
        static bool LoadSndListFile(const std::string& filepath, std::vector<std::string>& outSoundList);
    };
}
