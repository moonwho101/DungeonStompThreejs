#pragma once

#include "win_stubs.h"
#include <directx/dxgiformat.h>
#include <directx/d3d12.h>
#include <directx/d3dx12.h>
#include <DirectXMath.h>
#include <vector>
#include <string>
#include <memory>

namespace DungeonStomp
{
    struct Vertex
    {
        DirectX::XMFLOAT3 position;
        DirectX::XMFLOAT3 normal;
        DirectX::XMFLOAT2 texCoord;
        DirectX::XMFLOAT3 tangent;
    };

    struct LightData
    {
        DirectX::XMFLOAT3 position;
        DirectX::XMFLOAT3 color;
        DirectX::XMFLOAT4 params; // x: intensity, y: range, z: enabled
    };

    struct SceneCB
    {
        DirectX::XMMATRIX viewProjectionMatrix;
        DirectX::XMMATRIX modelMatrix;
        DirectX::XMFLOAT3 cameraPosition;
        float time;
    };

    struct DirectX12UltimateCapabilities
    {
        bool supportsRaytracingDXR1_1 = false;
        bool supportsMeshShaders = false;
        bool supportsVariableRateShading = false;
        bool supportsSamplerFeedback = false;
        D3D_FEATURE_LEVEL maxFeatureLevel = D3D_FEATURE_LEVEL_11_0;
    };

    class D3D12Renderer
    {
    public:
        D3D12Renderer();
        ~D3D12Renderer();

        bool Initialize(HWND hwnd, uint32_t width, uint32_t height);
        void Shutdown();

        void BeginFrame();
        void EndFrame();

        void SetCamera(const DirectX::XMFLOAT3& position, const DirectX::XMMATRIX& viewProjection);
        void RenderMesh(const std::vector<Vertex>& vertices, const std::vector<uint32_t>& indices, const DirectX::XMMATRIX& worldMatrix);

        const DirectX12UltimateCapabilities& GetCapabilities() const { return m_capabilities; }
        bool IsInitialized() const { return m_isInitialized; }

        ID3D12Device* GetDevice() const { return m_device; }
        ID3D12GraphicsCommandList* GetCommandList() const { return m_commandList; }

    private:
        bool CheckDirectX12UltimateSupport();
        bool CreateD3D12Device();
        bool CreateCommandObjects();
        bool CreateSwapChain(HWND hwnd);
        bool CreateDescriptorHeaps();
        bool CreateRootSignature();
        bool CreatePipelineStates();
        bool CreateRenderTargets();

        bool m_isInitialized = false;
        uint32_t m_width = 1280;
        uint32_t m_height = 720;
        uint32_t m_frameIndex = 0;
        HWND m_hwnd = (HWND)0;

        DirectX12UltimateCapabilities m_capabilities;
        SceneCB m_sceneCBData;

        // Direct3D 12 Core API Objects
        ID3D12Device* m_device = nullptr;
        ID3D12CommandQueue* m_commandQueue = nullptr;
        ID3D12CommandAllocator* m_commandAllocator = nullptr;
        ID3D12GraphicsCommandList* m_commandList = nullptr;
        ID3D12DescriptorHeap* m_rtvHeap = nullptr;
        ID3D12DescriptorHeap* m_dsvHeap = nullptr;
        ID3D12RootSignature* m_rootSignature = nullptr;
        ID3D12PipelineState* m_pipelineState = nullptr;
        ID3D12PipelineState* m_meshShaderPipelineState = nullptr;
        ID3D12StateObject* m_raytracingStateObject = nullptr;

        ID3D12Resource* m_renderTargets[2] = { nullptr, nullptr };
        ID3D12Resource* m_depthStencil = nullptr;
        ID3D12Fence* m_fence = nullptr;
        uint64_t m_fenceValue = 0;
        HANDLE m_fenceEvent = nullptr;

        uint32_t m_rtvDescriptorSize = 0;
    };
}
