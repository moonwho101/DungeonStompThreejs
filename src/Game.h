#pragma once

#include "D3D12Renderer.h"
#include "DungeonGenerator.h"
#include "Player.h"
#include "Monster.h"
#include "Minimap.h"
#include "Audio.h"

namespace DungeonStomp
{
    class Game
    {
    public:
        Game();
        ~Game();

        bool Initialize(HWND hwnd, uint32_t width, uint32_t height);
        void Update(float deltaTime);
        void Render();
        void Shutdown();

        bool IsRunning() const { return m_isRunning; }

    private:
        bool m_isRunning = false;
        D3D12Renderer m_renderer;
        DungeonGenerator m_dungeonGenerator;
        DungeonMapData m_currentMap;
        Player m_player;
        std::vector<Monster> m_monsters;
        Minimap m_minimap;
        Audio m_audio;
    };
}
