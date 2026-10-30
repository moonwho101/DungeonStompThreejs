#include "Generator.h"
#include <iostream>
#include <random>
#include <cmath>
#include <algorithm>
#include <sstream>
#include <iomanip>
#include <unordered_set>
#include <glm/glm.hpp>

struct Dir { int dx, dz; };

class SimpleRNG {
    uint32_t state;
public:
    SimpleRNG(uint32_t seed) : state(seed ^ 0xDEADBEEFU) {}
    float nextFloat() {
        state += 0x6D2B79F5U;
        uint32_t t = state;
        t = (t ^ (t >> 15)) * (t | 1U);
        t ^= t + (t ^ (t >> 7)) * (t | 61U);
        return static_cast<float>((t ^ (t >> 14))) / 4294967296.0f;
    }
    int randint(int a, int b) {
        return a + static_cast<int>(nextFloat() * (b - a + 1));
    }
};

std::string generateDungeon(const GeneratorOptions& options) {
    uint32_t seedVal = 1337;
    if (!options.seed.empty()) {
        uint32_t hash = 2166136261U;
        for (char c : options.seed) hash = (hash ^ static_cast<uint8_t>(c)) * 16777619U;
        seedVal = hash;
    }
    SimpleRNG rng(seedVal);

    std::stringstream ss;
    ss << "OBJECT startpos\n";
    ss << "CO_ORDINATES " << std::fixed << std::setprecision(6) << options.startX << " 0.000000 " << options.startZ << "\n";
    ss << "ROT_ANGLE 90\n";
    ss << "OBJECT CORRIDOR01\n";
    ss << "CO_ORDINATES " << std::fixed << std::setprecision(6) << options.startX << " 0.000000 " << options.startZ << "\n";
    ss << "ROT_ANGLE 0\n";
    ss << "OBJECT text\n";
    ss << "CO_ORDINATES 2020.000000 0.000000 1020.000000\n";
    ss << "ROT_ANGLE 0 largedungeon\n";
    ss << "LINK " << options.startX << " " << options.startZ << " 90 0\n";
    ss << "END_FILE\n";

    return ss.str();
}
