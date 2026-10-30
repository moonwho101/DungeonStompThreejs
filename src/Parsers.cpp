#include "Parsers.h"
#include <fstream>
#include <iostream>

namespace DungeonStomp
{
    // 3DS Chunk Identifiers
    constexpr uint16_t CHUNK_MAIN3DS       = 0x4D4D;
    constexpr uint16_t CHUNK_EDIT3DS       = 0x3D3D;
    constexpr uint16_t CHUNK_EDIT_OBJECT   = 0x4000;
    constexpr uint16_t CHUNK_OBJ_TRIMESH   = 0x4100;
    constexpr uint16_t CHUNK_TRI_VERTEXL   = 0x4110;
    constexpr uint16_t CHUNK_TRI_FACEL1    = 0x4120;
    constexpr uint16_t CHUNK_TRI_MAPPING   = 0x4140;

    struct ChunkHeader
    {
        uint16_t id;
        uint32_t length;
    };

    bool Parsers::LoadMapFile(const std::string& filepath, DungeonMapData& outMapData)
    {
        std::ifstream file(filepath, std::ios::binary);
        if (!file.is_open())
        {
            std::string altPath = "../" + filepath;
            file.open(altPath, std::ios::binary);
            if (!file.is_open())
            {
                altPath = "../../" + filepath;
                file.open(altPath, std::ios::binary);
            }
        }

        if (file.is_open())
        {
            file.seekg(0, std::ios::end);
            size_t fileSize = file.tellg();
            file.seekg(0, std::ios::beg);

            outMapData.width = 32;
            outMapData.height = 32;
            outMapData.startPosition = { 100.0f, 0.0f, 100.0f };
            outMapData.exitPosition = { 500.0f, 0.0f, 500.0f };
            outMapData.tiles.resize(outMapData.width * outMapData.height);

            if (fileSize >= outMapData.tiles.size() * sizeof(uint16_t))
            {
                for (size_t i = 0; i < outMapData.tiles.size(); ++i)
                {
                    file.read(reinterpret_cast<char*>(&outMapData.tiles[i].tileType), sizeof(uint16_t));
                    outMapData.tiles[i].x = static_cast<float>(i % outMapData.width) * 10.0f;
                    outMapData.tiles[i].z = static_cast<float>(i / outMapData.width) * 10.0f;
                }
            }
            else
            {
                for (size_t i = 0; i < outMapData.tiles.size(); ++i)
                {
                    outMapData.tiles[i].tileType = 1;
                    outMapData.tiles[i].x = static_cast<float>(i % outMapData.width) * 10.0f;
                    outMapData.tiles[i].z = static_cast<float>(i / outMapData.width) * 10.0f;
                }
            }
            std::cout << "[Parsers] Loaded binary dungeon map file: " << filepath << " (" << fileSize << " bytes)" << std::endl;
            return true;
        }

        outMapData.width = 32;
        outMapData.height = 32;
        outMapData.startPosition = { 100.0f, 0.0f, 100.0f };
        outMapData.exitPosition = { 500.0f, 0.0f, 500.0f };
        outMapData.tiles.resize(outMapData.width * outMapData.height);
        for (size_t i = 0; i < outMapData.tiles.size(); ++i)
        {
            outMapData.tiles[i].tileType = 1;
            outMapData.tiles[i].x = static_cast<float>(i % outMapData.width) * 10.0f;
            outMapData.tiles[i].z = static_cast<float>(i / outMapData.width) * 10.0f;
        }
        return true;
    }

    bool Parsers::Load3DSFile(const std::string& filepath, Model3DS& outModel)
    {
        outModel.name = filepath;
        outModel.vertices.clear();
        outModel.indices.clear();
        outModel.uvs.clear();

        std::ifstream file(filepath, std::ios::binary);
        if (!file.is_open())
        {
            std::string altPath = "../" + filepath;
            file.open(altPath, std::ios::binary);
            if (!file.is_open())
            {
                altPath = "../../" + filepath;
                file.open(altPath, std::ios::binary);
            }
        }

        if (file.is_open())
        {
            while (file.good() && !file.eof())
            {
                ChunkHeader chunk;
                file.read(reinterpret_cast<char*>(&chunk.id), sizeof(uint16_t));
                file.read(reinterpret_cast<char*>(&chunk.length), sizeof(uint32_t));

                if (file.gcount() < sizeof(uint32_t)) break;

                if (chunk.id == CHUNK_TRI_VERTEXL)
                {
                    uint16_t numVertices = 0;
                    file.read(reinterpret_cast<char*>(&numVertices), sizeof(uint16_t));
                    outModel.vertices.resize(numVertices);
                    for (uint16_t i = 0; i < numVertices; ++i)
                    {
                        float vx, vy, vz;
                        file.read(reinterpret_cast<char*>(&vx), sizeof(float));
                        file.read(reinterpret_cast<char*>(&vy), sizeof(float));
                        file.read(reinterpret_cast<char*>(&vz), sizeof(float));
                        outModel.vertices[i] = { vx, vy, vz };
                    }
                }
                else if (chunk.id == CHUNK_TRI_FACEL1)
                {
                    uint16_t numFaces = 0;
                    file.read(reinterpret_cast<char*>(&numFaces), sizeof(uint16_t));
                    outModel.indices.reserve(numFaces * 3);
                    for (uint16_t i = 0; i < numFaces; ++i)
                    {
                        uint16_t a, b, c, flags;
                        file.read(reinterpret_cast<char*>(&a), sizeof(uint16_t));
                        file.read(reinterpret_cast<char*>(&b), sizeof(uint16_t));
                        file.read(reinterpret_cast<char*>(&c), sizeof(uint16_t));
                        file.read(reinterpret_cast<char*>(&flags), sizeof(uint16_t));
                        outModel.indices.push_back(a);
                        outModel.indices.push_back(b);
                        outModel.indices.push_back(c);
                    }
                }
                else if (chunk.id == CHUNK_MAIN3DS || chunk.id == CHUNK_EDIT3DS || chunk.id == CHUNK_OBJ_TRIMESH)
                {
                    continue; // Read child sub-chunks
                }
                else
                {
                    if (chunk.length > 6)
                    {
                        file.seekg(chunk.length - 6, std::ios::cur);
                    }
                }
            }
            std::cout << "[Parsers] Parsed 3DS binary mesh file: " << filepath << " (" << outModel.vertices.size() << " vertices, " << outModel.indices.size() / 3 << " triangles)" << std::endl;
        }

        if (outModel.vertices.empty())
        {
            outModel.vertices = {
                { -1.0f, -1.0f, -1.0f }, { 1.0f, -1.0f, -1.0f },
                { 1.0f,  1.0f, -1.0f }, { -1.0f,  1.0f, -1.0f },
                { -1.0f, -1.0f,  1.0f }, { 1.0f, -1.0f,  1.0f },
                { 1.0f,  1.0f,  1.0f }, { -1.0f,  1.0f,  1.0f }
            };
            outModel.indices = {
                0, 1, 2, 2, 3, 0,
                4, 5, 6, 6, 7, 4,
                0, 1, 5, 5, 4, 0,
                2, 3, 7, 7, 6, 2,
                0, 3, 7, 7, 4, 0,
                1, 2, 6, 6, 5, 1
            };
        }
        return true;
    }

    bool Parsers::LoadSndListFile(const std::string& filepath, std::vector<std::string>& outSoundList)
    {
        std::ifstream file(filepath);
        if (!file.is_open())
        {
            std::string altPath = "../" + filepath;
            file.open(altPath);
            if (!file.is_open())
            {
                altPath = "../../" + filepath;
                file.open(altPath);
            }
        }
        if (!file.is_open()) return false;

        std::string line;
        while (std::getline(file, line))
        {
            if (!line.empty())
            {
                outSoundList.push_back(line);
            }
        }
        return true;
    }
}
