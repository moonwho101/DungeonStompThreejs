#include "Parsers.h"
#include <fstream>
#include <sstream>
#include <iostream>
#include <algorithm>
#include <cctype>

static std::string toLower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c){ return std::tolower(c); });
    return s;
}

static std::string replaceAll(std::string str, const std::string& from, const std::string& to) {
    size_t start_pos = 0;
    while((start_pos = str.find(from, start_pos)) != std::string::npos) {
        str.replace(start_pos, from.length(), to);
        start_pos += to.length();
    }
    return str;
}

bool TextureManager::loadTexturesDat(const std::string& filepath) {
    std::ifstream file(filepath);
    if (!file.is_open()) return false;

    std::string line;
    std::string currentTexPath = "";

    while (std::getline(file, line)) {
        if (line.empty() || line.rfind("//", 0) == 0) continue;
        std::stringstream ss(line);
        std::string token;
        ss >> token;
        if (token == "AddTexture") {
            ss >> currentTexPath;
            currentTexPath = replaceAll(currentTexPath, "\\", "/");
            std::string lowerPath = toLower(currentTexPath);
            if (lowerPath.rfind("../assets/", 0) == 0) {
                currentTexPath = currentTexPath.substr(10);
            } else if (lowerPath.rfind("assets/", 0) == 0) {
                currentTexPath = currentTexPath.substr(7);
            }
        } else if (token == "Alias") {
            std::string id, aliasName;
            ss >> id >> aliasName;
            if (!aliasName.empty()) {
                aliases[toLower(aliasName)] = currentTexPath;
            }
        }
    }
    return true;
}

std::string TextureManager::getTexturePath(const std::string& alias) const {
    if (alias.empty()) return "";
    std::string clean = toLower(alias);
    auto it = aliases.find(clean);
    if (it != aliases.end()) return it->second;
    return clean + ".bmp";
}

bool ObjectsDatParser::parse(const std::string& filepath) {
    std::ifstream file(filepath);
    if (!file.is_open()) return false;

    std::vector<std::string> tokens;
    std::string tok;
    while (file >> tok) {
        tokens.push_back(tok);
    }

    objects.clear();
    size_t i = 0;
    size_t count = tokens.size();
    ObjectData* currentObject = nullptr;
    std::string currentTexture = "wall1";

    const float TRI_UVS[6] = {0, 0, 0, 1, 1, 0};
    const float QUAD_UVS[8] = {0, 0, 0, 1, 1, 1, 1, 0};
    (void)QUAD_UVS;

    auto parseFloatSafe = [&](size_t idx) -> float {
        if (idx >= tokens.size()) return 0.0f;
        try {
            return std::stof(tokens[idx]);
        } catch (...) {
            return 0.0f;
        }
    };

    auto readCorners = [&](int n, bool textured, const float* presetUvs) {
        std::vector<float> corners(n * 5);
        for (int v = 0; v < n; v++) {
            int o = v * 5;
            corners[o + 0] = parseFloatSafe(i++);
            corners[o + 1] = parseFloatSafe(i++);
            corners[o + 2] = parseFloatSafe(i++);
            if (textured) {
                corners[o + 3] = parseFloatSafe(i++);
                corners[o + 4] = 1.0f - parseFloatSafe(i++);
            } else {
                corners[o + 3] = presetUvs[v * 2 + 0];
                corners[o + 4] = presetUvs[v * 2 + 1];
            }
        }
        return corners;
    };

    auto addPoly = [&](const std::vector<float>& corners, const std::vector<int>& order) {
        Poly poly;
        poly.texture = currentTexture;
        poly.verts.resize(order.size() * 5);
        for (size_t k = 0; k < order.size(); k++) {
            int src = order[k] * 5;
            size_t dst = k * 5;
            for (int c = 0; c < 5; c++) poly.verts[dst + c] = corners[src + c];
        }
        if (currentObject) currentObject->polys.push_back(poly);
    };

    while (i < count) {
        std::string t = tokens[i];
        if (t == "OBJECT" || t == "Q2M_OBJECT") {
            i++;
            int objId = std::stoi(tokens[i++]);
            std::string objName = tokens[i++];
            objects[objId] = ObjectData{ objId, objName, {} };
            currentObject = &objects[objId];
            continue;
        }

        if (!currentObject) {
            i++;
            continue;
        }

        if (t == "TEXTURE") {
            i++;
            currentTexture = tokens[i++];
            continue;
        } else if (t == "TYPE" || t == "SCALE" || t == "SHADOW" || t == "CONNECTION") {
            i += 2;
            continue;
        } else if (t == "TRI") {
            i++;
            addPoly(readCorners(3, false, TRI_UVS), {0, 1, 2});
            continue;
        } else if (t == "QUAD") {
            i++;
            addPoly(readCorners(4, false, QUAD_UVS), {0, 1, 3, 2, 3, 1});
            continue;
        } else if (t == "TRITEX") {
            i++;
            addPoly(readCorners(3, true, nullptr), {0, 1, 2});
            continue;
        } else if (t == "QUADTEX") {
            i++;
            addPoly(readCorners(4, true, nullptr), {0, 1, 3, 2, 3, 1});
            continue;
        } else {
            i++;
        }
    }
    return true;
}

bool LevelMapParser::parseFile(const std::string& filepath) {
    std::ifstream file(filepath);
    if (!file.is_open()) return false;
    std::stringstream ss;
    ss << file.rdbuf();
    return parseText(ss.str());
}

bool LevelMapParser::parseText(const std::string& text) {
    instances.clear();
    lights.clear();
    std::stringstream ss(text);
    std::string line;
    LevelInstance* currentObj = nullptr;

    while (std::getline(ss, line)) {
        if (line.empty() || line.rfind("//", 0) == 0) continue;
        std::stringstream ls(line);
        std::string cmd;
        ls >> cmd;

        if (cmd == "OBJECT") {
            std::string name = "";
            ls >> name;
            LevelInstance inst;
            inst.name = name;
            instances.push_back(inst);
            currentObj = &instances.back();

            std::string lowerName = toLower(name);
            if (lowerName == "startpos") currentObj->isStartPos = true;
            if (lowerName.find("light") != std::string::npos) currentObj->isLight = true;
        } else if (currentObj && cmd == "CO_ORDINATES") {
            ls >> currentObj->x >> currentObj->y >> currentObj->z;
            currentObj->y += 28.0f;
            if (currentObj->isStartPos) {
                startPos.x = currentObj->x;
                startPos.y = currentObj->y + 100.0f;
                startPos.z = currentObj->z;
            }
        } else if (currentObj && cmd == "ROT_ANGLE") {
            ls >> currentObj->rot;
            if (currentObj->isStartPos) startPos.rot = currentObj->rot;
            if (ls >> currentObj->modelName) {
                if (ls >> currentObj->textureAlias) {
                    if (ls >> currentObj->monsterId) {
                        ls >> currentObj->ability;
                    }
                }
            }
        } else if (currentObj && cmd == "LIGHT_SOURCE") {
            std::string typeStr;
            ls >> typeStr;
            LightSource light;
            light.type = (toLower(typeStr) == "spotlight") ? "spotlight" : "flicker";
            light.x = currentObj->x;
            light.y = currentObj->y + 28.0f;
            light.z = currentObj->z;

            std::string sub;
            while (ls >> sub) {
                if (sub == "POS") ls >> light.x >> light.y >> light.z, light.y += 28.0f;
                else if (sub == "DIR") ls >> light.dx >> light.dy >> light.dz;
                else if (sub == "COLOUR") ls >> light.r >> light.g >> light.b;
            }
            currentObj->hasLight = true;
            currentObj->light = light;
            lights.push_back(light);
        } else if (currentObj && cmd == "SHADOW") {
            ls >> currentObj->shadow;
        }
    }
    return true;
}
