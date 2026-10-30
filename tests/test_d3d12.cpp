#include "D3D12Renderer.h"
#include <iostream>
#include <cassert>

int main()
{
    DungeonStomp::D3D12Renderer renderer;
    bool init = renderer.Initialize((HWND)0, 1280, 720);
    assert(init);

    const auto& caps = renderer.GetCapabilities();
    assert(caps.supportsRaytracingDXR1_1);
    assert(caps.supportsMeshShaders);
    assert(caps.supportsVariableRateShading);
    assert(caps.supportsSamplerFeedback);

    std::cout << "[TestD3D12] DirectX 12 Ultimate Capabilities Verified! Passed!" << std::endl;
    return 0;
}
