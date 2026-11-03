cmake_minimum_required(VERSION 3.20)
project(DungeonStomp CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(MSVC)
    add_compile_options(/W4 /EHsc /utf-8)
else()
    add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(Vulkan REQUIRED)
find_package(glfw3 REQUIRED)
find_package(glm REQUIRED)

find_program(GLSLANG_VALIDATOR NAMES glslangValidator glslc)

set(VERT_SHADER "${CMAKE_SOURCE_DIR}/src/Shaders/shader.vert")
set(FRAG_SHADER "${CMAKE_SOURCE_DIR}/src/Shaders/shader.frag")
set(VERT_SPV "${CMAKE_SOURCE_DIR}/src/Shaders/shader.vert.spv")
set(FRAG_SPV "${CMAKE_SOURCE_DIR}/src/Shaders/shader.frag.spv")

if(GLSLANG_VALIDATOR)
    add_custom_command(
        OUTPUT ${VERT_SPV} ${FRAG_SPV}
        COMMAND ${GLSLANG_VALIDATOR} -V ${VERT_SHADER} -o ${VERT_SPV}
        COMMAND ${GLSLANG_VALIDATOR} -V ${FRAG_SHADER} -o ${FRAG_SPV}
        DEPENDS ${VERT_SHADER} ${FRAG_SHADER}
        COMMENT "Compiling GLSL shaders to SPIR-V..."
    )
    add_custom_target(CompileShaders ALL DEPENDS ${VERT_SPV} ${FRAG_SPV})
endif()

include_directories(
    ${Vulkan_INCLUDE_DIRS}
    ${CMAKE_SOURCE_DIR}/src
)

file(GLOB_RECURSE SOURCES "src/*.cpp")
file(GLOB_RECURSE HEADERS "src/*.h")

add_executable(DungeonStomp ${SOURCES} ${HEADERS})

if(GLSLANG_VALIDATOR)
    add_dependencies(DungeonStomp CompileShaders)
endif()

target_link_libraries(DungeonStomp PRIVATE
    Vulkan::Vulkan
    glfw
    glm::glm
)
