#include "Collision.h"
#include <cmath>
#include <algorithm>
#include <limits>
#include <glm/gtx/norm.hpp>

std::vector<CollisionTriangle> levelTriangles;
std::vector<BoundingBox> modelBoxes;
std::unordered_map<long long, std::vector<CollisionTriangle*>> collisionGrid;
std::vector<DoorCollisionData> doorCollisions;

static unsigned int g_queryStamp = 0;

CollisionTriangle makeCollisionTriangle(float ax, float ay, float az, float bx, float by, float bz, float cx, float cy, float cz) {
    CollisionTriangle tri;
    tri.a = glm::vec3(ax, ay, az);
    tri.b = glm::vec3(bx, by, bz);
    tri.c = glm::vec3(cx, cy, cz);
    glm::vec3 e1 = tri.b - tri.a;
    glm::vec3 e2 = tri.c - tri.a;
    tri.n = glm::cross(e1, e2);
    float lenSq = glm::length2(tri.n);
    tri.planar = lenSq > 1e-10f;
    if (tri.planar) tri.n = glm::normalize(tri.n);

    tri.minX = std::min({ax, bx, cx});
    tri.maxX = std::max({ax, bx, cx});
    tri.minY = std::min({ay, by, cy});
    tri.maxY = std::max({ay, by, cy});
    tri.minZ = std::min({az, bz, cz});
    tri.maxZ = std::max({az, bz, cz});

    return tri;
}

long long getGridKey(int cx, int cy, int cz) {
    return ((static_cast<long long>(cx) + 512LL) * 1024LL + (static_cast<long long>(cy) + 512LL)) * 1024LL + (static_cast<long long>(cz) + 512LL);
}

void buildCollisionGrid() {
    collisionGrid.clear();
    for (size_t i = 0; i < levelTriangles.size(); i++) {
        CollisionTriangle* tri = &levelTriangles[i];
        int minCx = static_cast<int>(std::floor(tri->minX / GRID_CELL_SIZE));
        int maxCx = static_cast<int>(std::floor(tri->maxX / GRID_CELL_SIZE));
        int minCy = static_cast<int>(std::floor(tri->minY / GRID_CELL_SIZE));
        int maxCy = static_cast<int>(std::floor(tri->maxY / GRID_CELL_SIZE));
        int minCz = static_cast<int>(std::floor(tri->minZ / GRID_CELL_SIZE));
        int maxCz = static_cast<int>(std::floor(tri->maxZ / GRID_CELL_SIZE));

        for (int cx = minCx; cx <= maxCx; cx++) {
            for (int cy = minCy; cy <= maxCy; cy++) {
                for (int cz = minCz; cz <= maxCz; cz++) {
                    long long key = getGridKey(cx, cy, cz);
                    collisionGrid[key].push_back(tri);
                }
            }
        }
    }
}

std::vector<CollisionTriangle*> gatherNearbyTriangles(float minX, float maxX, float minY, float maxY, float minZ, float maxZ) {
    std::vector<CollisionTriangle*> nearby;
    unsigned int stamp = ++g_queryStamp;

    int minCx = static_cast<int>(std::floor(minX / GRID_CELL_SIZE));
    int maxCx = static_cast<int>(std::floor(maxX / GRID_CELL_SIZE));
    int minCy = static_cast<int>(std::floor(minY / GRID_CELL_SIZE));
    int maxCy = static_cast<int>(std::floor(maxY / GRID_CELL_SIZE));
    int minCz = static_cast<int>(std::floor(minZ / GRID_CELL_SIZE));
    int maxCz = static_cast<int>(std::floor(maxZ / GRID_CELL_SIZE));

    for (int cx = minCx; cx <= maxCx; cx++) {
        for (int cy = minCy; cy <= maxCy; cy++) {
            for (int cz = minCz; cz <= maxCz; cz++) {
                auto it = collisionGrid.find(getGridKey(cx, cy, cz));
                if (it == collisionGrid.end()) continue;
                for (CollisionTriangle* tri : it->second) {
                    if (tri->stamp == stamp) continue;
                    tri->stamp = stamp;
                    if (tri->maxX < minX || tri->minX > maxX ||
                        tri->maxY < minY || tri->minY > maxY ||
                        tri->maxZ < minZ || tri->minZ > maxZ) {
                        continue;
                    }
                    nearby.push_back(tri);
                }
            }
        }
    }

    for (const auto& door : doorCollisions) {
        if (door.bounds.max.x < minX || door.bounds.min.x > maxX ||
            door.bounds.max.y < minY || door.bounds.min.y > maxY ||
            door.bounds.max.z < minZ || door.bounds.min.z > maxZ) {
            continue;
        }
        for (const auto& tri : door.triangles) {
            if (tri.maxX < minX || tri.minX > maxX ||
                tri.maxY < minY || tri.minY > maxY ||
                tri.maxZ < minZ || tri.minZ > maxZ) {
                continue;
            }
            nearby.push_back(const_cast<CollisionTriangle*>(&tri));
        }
    }
    return nearby;
}

std::vector<BoundingBox> gatherNearbyBoxes(float minX, float maxX, float minY, float maxY, float minZ, float maxZ) {
    std::vector<BoundingBox> nearby;
    for (const auto& box : modelBoxes) {
        if (box.isEmpty()) continue;
        if (box.max.x < minX || box.min.x > maxX ||
            box.max.y < minY || box.min.y > maxY ||
            box.max.z < minZ || box.min.z > maxZ) {
            continue;
        }
        nearby.push_back(box);
    }
    return nearby;
}

glm::vec3 closestPointSegmentPoint(const glm::vec3& a, const glm::vec3& b, const glm::vec3& p) {
    glm::vec3 ab = b - a;
    float abLenSq = glm::length2(ab);
    if (abLenSq < 1e-8f) return a;
    float t = std::clamp(glm::dot(p - a, ab) / abLenSq, 0.0f, 1.0f);
    return a + ab * t;
}

glm::vec3 closestPointTrianglePoint(const glm::vec3& v0, const glm::vec3& v1, const glm::vec3& v2, const glm::vec3& p) {
    glm::vec3 v10 = v1 - v0;
    glm::vec3 v20 = v2 - v0;
    glm::vec3 vp0 = p - v0;

    float d1 = glm::dot(v10, vp0);
    float d2 = glm::dot(v20, vp0);
    if (d1 <= 0 && d2 <= 0) return v0;

    glm::vec3 vp1 = p - v1;
    float d3 = glm::dot(v10, vp1);
    float d4 = glm::dot(v20, vp1);
    if (d3 >= 0 && d4 <= d3) return v1;

    float vc = d1 * d4 - d3 * d2;
    if (vc <= 0 && d1 >= 0 && d3 <= 0) {
        float v = d1 / (d1 - d3);
        return v0 + v10 * v;
    }

    glm::vec3 vp2 = p - v2;
    float d5 = glm::dot(v10, vp2);
    float d6 = glm::dot(v20, vp2);
    if (d6 >= 0 && d5 <= d6) return v2;

    float vb = d5 * d2 - d1 * d6;
    if (vb <= 0 && d2 >= 0 && d6 <= 0) {
        float w = d2 / (d2 - d6);
        return v0 + v20 * w;
    }

    float va = d3 * d6 - d5 * d4;
    if (va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0) {
        float w = (d4 - d3) / ((d4 - d3) + (d5 - d6));
        return v1 + (v2 - v1) * w;
    }

    float denom = 1.0f / (va + vb + vc);
    float v = vb * denom;
    float w = vc * denom;
    return v0 + v10 * v + v20 * w;
}

void closestPointsSegmentSegment(const glm::vec3& a, const glm::vec3& b, const glm::vec3& c, const glm::vec3& d, glm::vec3& target1, glm::vec3& target2) {
    glm::vec3 u = b - a;
    glm::vec3 v = d - c;
    glm::vec3 w = a - c;

    float aDot = glm::dot(u, u);
    float bDot = glm::dot(u, v);
    float cDot = glm::dot(v, v);
    float dDot = glm::dot(u, w);
    float eDot = glm::dot(v, w);
    float D = aDot * cDot - bDot * bDot;

    float sN, sD = D;
    float tN, tD = D;

    if (D < 1e-8f) {
        sN = 0.0f; sD = 1.0f; tN = eDot; tD = cDot;
    } else {
        sN = (bDot * eDot - cDot * dDot);
        tN = (aDot * eDot - bDot * dDot);
        if (sN < 0.0f) { sN = 0.0f; tN = eDot; tD = cDot; }
        else if (sN > sD) { sN = sD; tN = eDot + bDot; tD = cDot; }
    }

    if (tN < 0.0f) {
        tN = 0.0f;
        if (-dDot < 0.0f) sN = 0.0f;
        else if (-dDot > aDot) sN = sD;
        else { sN = -dDot; sD = aDot; }
    } else if (tN > tD) {
        tN = tD;
        if ((-dDot + bDot) < 0.0f) sN = 0.0f;
        else if ((-dDot + bDot) > aDot) sN = sD;
        else { sN = (-dDot + bDot); sD = aDot; }
    }

    float sc = std::abs(sN) < 1e-8f ? 0.0f : sN / sD;
    float tc = std::abs(tN) < 1e-8f ? 0.0f : tN / tD;

    target1 = a + u * sc;
    target2 = c + v * tc;
}

CapsuleTriangleResult closestPointsCapsuleTriangle(const glm::vec3& capA, const glm::vec3& capB, const CollisionTriangle& tri) {
    CapsuleTriangleResult res;
    res.pierced = false;

    if (tri.planar) {
        res.normal = tri.n;
        float dA = glm::dot(res.normal, capA - tri.a);
        float dB = glm::dot(res.normal, capB - tri.a);
        if (dA * dB < 0) {
            float t = dA / (dA - dB);
            glm::vec3 pierceP = glm::mix(capA, capB, t);
            glm::vec3 triP = closestPointTrianglePoint(tri.a, tri.b, tri.c, pierceP);
            if (glm::distance2(triP, pierceP) < 1e-6f) {
                bool aNear = std::abs(dA) <= std::abs(dB);
                if ((aNear ? dA : dB) > 0) res.normal = -res.normal;
                res.capP = pierceP;
                res.triP = pierceP;
                res.dist = -std::min(std::abs(dA), std::abs(dB));
                res.pierced = true;
                return res;
            }
        }
    }

    float minDistSq = std::numeric_limits<float>::infinity();

    glm::vec3 pTriA = closestPointTrianglePoint(tri.a, tri.b, tri.c, capA);
    glm::vec3 pCapA = closestPointSegmentPoint(capA, capB, pTriA);
    float dSq = glm::distance2(pCapA, pTriA);
    if (dSq < minDistSq) {
        minDistSq = dSq; res.capP = pCapA; res.triP = pTriA;
    }

    glm::vec3 pTriB = closestPointTrianglePoint(tri.a, tri.b, tri.c, capB);
    glm::vec3 pCapB = closestPointSegmentPoint(capA, capB, pTriB);
    dSq = glm::distance2(pCapB, pTriB);
    if (dSq < minDistSq) {
        minDistSq = dSq; res.capP = pCapB; res.triP = pTriB;
    }

    for (int i = 0; i < 3; i++) {
        glm::vec3 e0 = i == 0 ? tri.a : (i == 1 ? tri.b : tri.c);
        glm::vec3 e1 = i == 0 ? tri.b : (i == 1 ? tri.c : tri.a);
        glm::vec3 seg1, seg2;
        closestPointsSegmentSegment(capA, capB, e0, e1, seg1, seg2);
        dSq = glm::distance2(seg1, seg2);
        if (dSq < minDistSq) {
            minDistSq = dSq; res.capP = seg1; res.triP = seg2;
        }
    }

    res.dist = std::sqrt(minDistSq);
    return res;
}

CapsuleBoxResult closestPointsCapsuleBox(const glm::vec3& capA, const glm::vec3& capB, const BoundingBox& box) {
    CapsuleBoxResult res;
    float bx = std::clamp(capA.x, box.min.x, box.max.x);
    float bz = std::clamp(capA.z, box.min.z, box.max.z);

    float lo = std::max(capA.y, box.min.y);
    float hi = std::min(capB.y, box.max.y);
    float capY, boxY;
    if (lo <= hi) {
        capY = boxY = (lo + hi) * 0.5f;
    } else if (capB.y < box.min.y) {
        capY = capB.y; boxY = box.min.y;
    } else {
        capY = capA.y; boxY = box.max.y;
    }

    res.capP = glm::vec3(capA.x, capY, capA.z);
    res.boxP = glm::vec3(bx, boxY, bz);
    res.dist = glm::distance(res.capP, res.boxP);
    return res;
}

bool hasLineOfSight(const glm::vec3& fromPos, const glm::vec3& toPos) {
    float dist = glm::distance(fromPos, toPos);
    if (dist <= 1.0f) return true;

    float stepSize = 35.0f;
    int steps = std::max(1, static_cast<int>(std::floor(dist / stepSize)));

    auto boxes = gatherNearbyBoxes(
        std::min(fromPos.x, toPos.x) - 25, std::max(fromPos.x, toPos.x) + 25,
        std::min(fromPos.y, toPos.y) - 25, std::max(fromPos.y, toPos.y) + 25,
        std::min(fromPos.z, toPos.z) - 25, std::max(fromPos.z, toPos.z) + 25
    );

    for (int i = 1; i < steps; i++) {
        glm::vec3 sample = glm::mix(fromPos, toPos, static_cast<float>(i) / steps);
        auto tris = gatherNearbyTriangles(
            sample.x - 25, sample.x + 25,
            sample.y - 25, sample.y + 25,
            sample.z - 25, sample.z + 25
        );
        for (CollisionTriangle* tri : tris) {
            glm::vec3 closest = closestPointTrianglePoint(tri->a, tri->b, tri->c, sample);
            if (glm::distance2(sample, closest) <= 20.0f * 20.0f) return false;
        }
        for (const auto& box : boxes) {
            if (sample.x >= box.min.x && sample.x <= box.max.x &&
                sample.y >= box.min.y && sample.y <= box.max.y &&
                sample.z >= box.min.z && sample.z <= box.max.z) return false;
        }
    }
    return true;
}

bool resolveCapsuleWorld(glm::vec3& pos, float footOffset, float radius, float height, glm::vec3* vel) {
    float baseY = pos.y - footOffset;
    float velYPadding = vel ? std::abs(vel->y * 0.2f) : 0.0f;
    auto tris = gatherNearbyTriangles(pos.x - radius - 30, pos.x + radius + 30, baseY - 50 - velYPadding, baseY + height + 50 + velYPadding, pos.z - radius - 30, pos.z + radius + 30);
    auto boxes = gatherNearbyBoxes(pos.x - radius - 30, pos.x + radius + 30, baseY - 50 - velYPadding, baseY + height + 50 + velYPadding, pos.z - radius - 30, pos.z + radius + 30);

    bool grounded = false;
    constexpr int MAX_ITERATIONS = 6;

    for (int iter = 0; iter < MAX_ITERATIONS; iter++) {
        float curBaseY = pos.y - footOffset;
        glm::vec3 capA(pos.x, curBaseY + radius, pos.z);
        glm::vec3 capB(pos.x, curBaseY + height - radius, pos.z);

        float maxPenetration = 0.0f;
        glm::vec3 bestNormal(0);

        for (CollisionTriangle* tri : tris) {
            auto res = closestPointsCapsuleTriangle(capA, capB, *tri);
            if (res.dist >= radius) continue;
            float pen = radius - res.dist;
            if (pen <= maxPenetration) continue;

            glm::vec3 normal;
            if (res.pierced) {
                normal = res.normal;
            } else {
                normal = res.capP - res.triP;
                if (glm::length2(normal) > 1e-8f) {
                    normal = glm::normalize(normal);
                } else {
                    normal = tri->n;
                }
                if (std::abs(tri->n.y) > 0.7f && std::abs(normal.y) > 0.5f) {
                    normal = glm::vec3(0, normal.y > 0 ? 1.0f : -1.0f, 0);
                }
            }
            maxPenetration = pen;
            bestNormal = normal;
        }

        for (const auto& box : boxes) {
            auto res = closestPointsCapsuleBox(capA, capB, box);
            if (res.dist >= radius) continue;

            float pen;
            glm::vec3 normal;
            if (res.dist > 1e-4f) {
                pen = radius - res.dist;
                normal = glm::normalize(res.capP - res.boxP);
            } else {
                float outMinX = capA.x + radius - box.min.x;
                float outMaxX = box.max.x - (capA.x - radius);
                float outMinZ = capA.z + radius - box.min.z;
                float outMaxZ = box.max.z - (capA.z - radius);
                pen = box.max.y - curBaseY;
                normal = glm::vec3(0, 1, 0);
                if (outMinX < pen) { pen = outMinX; normal = glm::vec3(-1, 0, 0); }
                if (outMaxX < pen) { pen = outMaxX; normal = glm::vec3(1, 0, 0); }
                if (outMinZ < pen) { pen = outMinZ; normal = glm::vec3(0, 0, -1); }
                if (outMaxZ < pen) { pen = outMaxZ; normal = glm::vec3(0, 0, 1); }
            }

            if (pen > maxPenetration) {
                maxPenetration = pen;
                bestNormal = normal;
            }
        }

        if (maxPenetration <= 0) break;
        pos += bestNormal * (maxPenetration + 0.01f);
        if (bestNormal.y > 0.5f) grounded = true;

        if (vel) {
            float dotVel = glm::dot(*vel, bestNormal);
            if (dotVel < 0) *vel -= bestNormal * dotVel;
        }
    }
    return grounded;
}

bool resolveCapsuleCollisions(glm::vec3& camPos, glm::vec3& vel) {
    return resolveCapsuleWorld(camPos, EYE_HEIGHT, CAPSULE_RADIUS, CAPSULE_HEIGHT, &vel);
}
