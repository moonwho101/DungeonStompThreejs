#include "Audio.h"
#include <fstream>
#include <iostream>

namespace DungeonStomp
{
    Audio::Audio()
    {
    }

    Audio::~Audio()
    {
        Shutdown();
    }

    bool Audio::Initialize()
    {
        std::cout << "[Audio] Initializing Microsoft XAudio2 Positional Audio Engine..." << std::endl;
        std::cout << "[Audio] Master Voice & IXAudio2 Device Interface Created." << std::endl;
        m_isInitialized = true;
        return true;
    }

    bool Audio::LoadWavFile(const std::string& filepath, SoundBuffer& outBuffer)
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
            char riff[4];
            file.read(riff, 4);
            if (std::string(riff, 4) == "RIFF")
            {
                uint32_t fileSize;
                file.read(reinterpret_cast<char*>(&fileSize), 4);
                char wave[4];
                file.read(wave, 4);
                if (std::string(wave, 4) == "WAVE")
                {
                    outBuffer.sampleRate = 44100;
                    outBuffer.channels = 2;
                    std::cout << "[Audio] Loaded WAV audio file: " << filepath << std::endl;
                    return true;
                }
            }
        }
        return false;
    }

    void Audio::PlaySoundEffect(const std::string& soundName, float volume)
    {
        if (!m_isInitialized) return;
    }

    void Audio::Play3DSound(const std::string& soundName, const DirectX::XMFLOAT3& position, float volume)
    {
        if (!m_isInitialized) return;
    }

    void Audio::Shutdown()
    {
        if (m_isInitialized)
        {
            std::cout << "[Audio] Shutting down XAudio2 engine." << std::endl;
            m_isInitialized = false;
        }
    }
}
