#include "Game.h"
#include <iostream>

namespace DungeonStomp
{
    Game::Game()
    {
    }

    Game::~Game()
    {
        Shutdown();
    }

    bool Game::Initialize(HWND hwnd, uint32_t width, uint32_t height)
    {
        std::cout << "============================================" << std::endl;
        std::cout << "  Dungeon Stomp DirectX 12 Ultimate Engine  " << std::endl;
        std::cout << "============================================" << std::endl;

        if (!m_renderer.Initialize(hwnd, width, height))
        {
            return false;
        }

        m_audio.Initialize();

        DungeonGeneratorOptions genOpts;
        genOpts.depth = 1;
        genOpts.seed = 42;
        m_currentMap = m_dungeonGenerator.Generate(genOpts);

        m_player.SetPosition(m_currentMap.startPosition);

        m_monsters.emplace_back("OGRE", DirectX::XMFLOAT3{ 50.0f, 0.0f, 50.0f });
        m_monsters.emplace_back("GOBLIN", DirectX::XMFLOAT3{ 120.0f, 0.0f, 80.0f });
        m_monsters.emplace_back("DRAGON", DirectX::XMFLOAT3{ 250.0f, 0.0f, 250.0f });

        m_isRunning = true;
        return true;
    }

    void Game::Update(float deltaTime)
    {
        if (!m_isRunning) return;

        m_player.Update(deltaTime);

        std::vector<DirectX::XMFLOAT3> monsterPositions;
        for (auto& monster : m_monsters)
        {
            monster.Update(deltaTime, m_player.GetPosition());
            monsterPositions.push_back(monster.GetPosition());
        }

        m_minimap.Update(m_player.GetPosition(), monsterPositions);
    }

    void Game::Render()
    {
        if (!m_isRunning) return;

        m_renderer.BeginFrame();
        // Render game scene
        m_renderer.EndFrame();
    }

    void Game::Shutdown()
    {
        if (m_isRunning)
        {
            m_audio.Shutdown();
            m_renderer.Shutdown();
            m_isRunning = false;
        }
    }
}
