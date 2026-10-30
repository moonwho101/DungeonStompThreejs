cmake_minimum_required(VERSION 3.20)

include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/../include/stubs
    ${CMAKE_CURRENT_SOURCE_DIR}/../external/DirectX-Headers/include/wsl/stubs
    ${CMAKE_CURRENT_SOURCE_DIR}/../external/DirectX-Headers/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../external/DirectXMath/Inc
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

set(TEST_SOURCES
    ../src/D3D12Renderer.cpp
    ../src/Parsers.cpp
    ../src/DungeonGenerator.cpp
    ../src/Collision.cpp
    ../src/Monster.cpp
    ../src/Player.cpp
    ../src/Minimap.cpp
    ../src/Audio.cpp
    ../src/Game.cpp
)

add_executable(test_dungeon test_dungeon.cpp ${TEST_SOURCES})
add_executable(test_parsers test_parsers.cpp ${TEST_SOURCES})
add_executable(test_d3d12 test_d3d12.cpp ${TEST_SOURCES})

add_test(NAME TestDungeon COMMAND test_dungeon)
add_test(NAME TestParsers COMMAND test_parsers)
add_test(NAME TestD3D12 COMMAND test_d3d12)
