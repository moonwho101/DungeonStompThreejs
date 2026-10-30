#pragma once

#include "win_stubs.h"
#include <string>
#include <vector>
#include <unordered_map>
#include <DirectXMath.h>

namespace DungeonStomp
{
    struct SoundBuffer
    {
        std::vector<uint8_t> audioData;
        uint32_t audioLength = 0;
        uint16_t channels = 1;
        uint32_t sampleRate = 22050;
        uint16_t bitsPerSample = 16;
    };

    class Audio
    {
    public:
        Audio();
        ~Audio();

        bool Initialize();
        bool LoadWavFile(const std::string& filepath, SoundBuffer& outBuffer);
        void PlaySoundEffect(const std::string& soundName, float volume = 1.0f);
        void Play3DSound(const std::string& soundName, const DirectX::XMFLOAT3& position, float volume = 1.0f);
        void Shutdown();

    private:
        bool m_isInitialized = false;
        std::unordered_map<std::string, SoundBuffer> m_soundCache;
    };
}
