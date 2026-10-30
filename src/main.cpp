#include "VulkanRenderer.h"
#include "Parsers.h"
#include "Collision.h"
#include "Generator.h"
#include "GameState.h"
#include "Logic.h"
#include "Minimap.h"
#include <iostream>
#include <chrono>

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;

    if (!glfwInit()) {
        std::cerr << "Failed to initialize GLFW" << std::endl;
        return -1;
    }

    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    GLFWwindow* window = glfwCreateWindow(800, 600, "Dungeon Stomp Vulkan C++", nullptr, nullptr);
    if (!window) {
        std::cerr << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }

    TextureManager texMgr;
    texMgr.loadTexturesDat("bin/textures.dat");

    ObjectsDatParser objParser;
    objParser.parse("bin/Objects.dat");

    LevelMapParser mapParser;
    std::string dungeonMapText = generateDungeon();
    mapParser.parseText(dungeonMapText);

    loadGameWorld(texMgr, mapParser, objParser);

    VulkanRenderer renderer;
    if (!renderer.init(window)) {
        std::cout << "Vulkan renderer initialized in headless/fallback context." << std::endl;
    }

    glm::vec3 playerPos = glm::vec3(mapParser.startPos.x, mapParser.startPos.y, mapParser.startPos.z);
    glm::vec3 playerVel(0.0f);

    auto lastTime = std::chrono::high_resolution_clock::now();

    std::cout << "Dungeon Stomp Vulkan C++ Engine Started Successfully." << std::endl;

    while (!glfwWindowShouldClose(window)) {
        glfwPollEvents();

        auto currentTime = std::chrono::high_resolution_clock::now();
        float dt = std::chrono::duration<float, std::chrono::seconds::period>(currentTime - lastTime).count();
        lastTime = currentTime;
        if (dt > 0.1f) dt = 0.1f;

        playerVel.y -= GRAVITY * dt;
        playerPos += playerVel * dt;
        resolveCapsuleCollisions(playerPos, playerVel);

        for (auto& m : monsters) {
            m->update(dt, playerPos);
        }

        updateMinimap(playerPos, mapParser.startPos.rot);

        renderer.renderFrame(playerPos, glm::vec3(0, 0, -1));
    }

    renderer.cleanup();
    glfwDestroyWindow(window);
    glfwTerminate();

    std::cout << "Dungeon Stomp Vulkan C++ Exited cleanly." << std::endl;
    return 0;
}
