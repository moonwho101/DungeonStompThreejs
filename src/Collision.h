#ifndef COLLISION_H
#define COLLISION_H

#include <vector>
#include <unordered_map>
#include <memory>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

constexpr float CAPSULE_RADIUS = 28.0f;
constexpr float CAPSULE_HEIGHT = 105.0f;
constexpr float EYE_HEIGHT = 100.0f;
constexpr float GRAVITY = 1600.0f;
constexpr float JUMP_SPEED = 520.0f;

constexpr float MONSTER_CAPSULE_RADIUS = 24.0f;
constexpr float MONSTER_CAPSULE_HEIGHT = 80.0f;
constexpr float MONSTER_FOOT_OFFSET = 50.0f;
constexpr float STAND_ON_MAX_LIFT = 20.0f;

constexpr float GRID_CELL_SIZE = 256.0f;

struct CollisionTriangle {
    glm::vec3 a{0}, b{0}, c{0}, n{0};
    bool planar = false;
    unsigned int stamp = 0;
    float minX = 0, maxX = 0, minY = 0, maxY = 0, minZ = 0, maxZ = 0;
};

struct BoundingBox {
    glm::vec3 min{0};
    glm::vec3 max{0};
    bool isEmpty() const {
        return min.x >= max.x || min.y >= max.y || min.z >= max.z;
    }
};

struct DoorCollisionData {
    BoundingBox bounds;
    std::vector<CollisionTriangle> triangles;
};

CollisionTriangle makeCollisionTriangle(float ax, float ay, float az, float bx, float by, float bz, float cx, float cy, float cz);
long long getGridKey(int cx, int cy, int cz);

extern std::vector<CollisionTriangle> levelTriangles;
extern std::vector<BoundingBox> modelBoxes;
extern std::unordered_map<long long, std::vector<CollisionTriangle*>> collisionGrid;
extern std::vector<DoorCollisionData> doorCollisions;

void buildCollisionGrid();
std::vector<CollisionTriangle*> gatherNearbyTriangles(float minX, float maxX, float minY, float maxY, float minZ, float maxZ);
std::vector<BoundingBox> gatherNearbyBoxes(float minX, float maxX, float minY, float maxY, float minZ, float maxZ);

bool hasLineOfSight(const glm::vec3& fromPos, const glm::vec3& toPos);

glm::vec3 closestPointSegmentPoint(const glm::vec3& a, const glm::vec3& b, const glm::vec3& p);
glm::vec3 closestPointTrianglePoint(const glm::vec3& v0, const glm::vec3& v1, const glm::vec3& v2, const glm::vec3& p);
void closestPointsSegmentSegment(const glm::vec3& a, const glm::vec3& b, const glm::vec3& c, const glm::vec3& d, glm::vec3& target1, glm::vec3& target2);

struct CapsuleTriangleResult {
    glm::vec3 capP{0};
    glm::vec3 triP{0};
    float dist = 0;
    bool pierced = false;
    glm::vec3 normal{0};
};

CapsuleTriangleResult closestPointsCapsuleTriangle(const glm::vec3& capA, const glm::vec3& capB, const CollisionTriangle& tri);

struct CapsuleBoxResult {
    glm::vec3 capP{0};
    glm::vec3 boxP{0};
    float dist = 0;
};

CapsuleBoxResult closestPointsCapsuleBox(const glm::vec3& capA, const glm::vec3& capB, const BoundingBox& box);

bool resolveCapsuleWorld(glm::vec3& pos, float footOffset, float radius, float height, glm::vec3* vel);
bool resolveCapsuleCollisions(glm::vec3& camPos, glm::vec3& vel);

#endif // COLLISION_H
