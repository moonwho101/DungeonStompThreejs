cmake_minimum_required(VERSION 3.20)
project(DungeonStompDX12 VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include/stubs
    ${CMAKE_CURRENT_SOURCE_DIR}/external/DirectX-Headers/include/wsl/stubs
    ${CMAKE_CURRENT_SOURCE_DIR}/external/DirectX-Headers/include
    ${CMAKE_CURRENT_SOURCE_DIR}/external/DirectXMath/Inc
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Shaders
set(SHADER_FILES
    src/Shaders/VertexShader.hlsl
    src/Shaders/PixelShader.hlsl
    src/Shaders/MeshShader.hlsl
    src/Shaders/Raytracing.hlsl
)

# Source files
set(SOURCE_FILES
    src/Main.cpp
    src/D3D12Renderer.cpp
    src/Parsers.cpp
    src/DungeonGenerator.cpp
    src/Collision.cpp
    src/Monster.cpp
    src/Player.cpp
    src/Minimap.cpp
    src/Audio.cpp
    src/Game.cpp
)

add_executable(DungeonStompDX12 ${SOURCE_FILES} ${SHADER_FILES})

if(WIN32)
    target_link_libraries(DungeonStompDX12 PRIVATE d3d12 dxgi dxguid d3dcompiler user32 gdi32)
endif()

enable_testing()
add_subdirectory(tests)
