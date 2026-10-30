#ifndef PARSERS_H
#define PARSERS_H

#include <string>
#include <vector>
#include <unordered_map>
#include <map>
#include <memory>
#include <glm/glm.hpp>

struct Poly {
    std::string texture;
    std::vector<float> verts; // x, y, z, u, v
};

struct ObjectData {
    int id = 0;
    std::string name;
    std::vector<Poly> polys;
};

struct LightSource {
    std::string type; // "flicker" or "spotlight"
    float x = 0, y = 0, z = 0;
    float dx = 0, dy = -1, dz = 0;
    float r = 1, g = 1, b = 1;
};

struct LevelInstance {
    std::string name;
    float x = 0, y = 0, z = 0;
    float rot = 0;
    int shadow = 1;
    std::string modelName;
    std::string textureAlias;
    int monsterId = 0;
    int ability = 0;
    bool isStartPos = false;
    bool isLight = false;
    bool hasLight = false;
    LightSource light;
};

struct StartPos {
    float x = 0, y = 100, z = 0, rot = 0;
};

class TextureManager {
public:
    std::unordered_map<std::string, std::string> aliases;
    bool loadTexturesDat(const std::string& filepath);
    std::string getTexturePath(const std::string& alias) const;
};

class ObjectsDatParser {
public:
    std::unordered_map<int, ObjectData> objects;
    bool parse(const std::string& filepath);
};

class LevelMapParser {
public:
    std::vector<LevelInstance> instances;
    StartPos startPos;
    std::vector<LightSource> lights;
    bool parseFile(const std::string& filepath);
    bool parseText(const std::string& text);
};

#endif // PARSERS_H
