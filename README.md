<div align="center">

# ⚔️ Dungeon Stomp DirectX 12 Ultimate & Three.js

### A classic first-person dungeon crawler, powered by Microsoft C++ DirectX 12 Ultimate & Three.js.

**Procedural dungeons · Real-time spells · DirectX 12 Ultimate (DXR 1.1 Raytracing, Mesh Shaders, VRS, Sampler Feedback) · C++20 & JavaScript**

![DirectX 12 Ultimate](https://img.shields.io/badge/DirectX%2012-Ultimate%20(FL%2012__2)-0078D4?logo=windows)
![C++20](https://img.shields.io/badge/C%2B%2B-20-blue?logo=cplusplus)
![Three.js](https://img.shields.io/badge/Three.js-r160-black?logo=three.js)
![JavaScript](https://img.shields.io/badge/JavaScript-ES%20Modules-F7DF1E?logo=javascript&logoColor=black)
![License](https://img.shields.io/badge/license-MIT-blue)

<img src="verification/screenshots/generated_level.png" alt="Dungeon Stomp gameplay: first-person view down a glowing teal dungeon corridor with a minimap and HUD" width="860">

</div>

---

## What is this?

**Dungeon Stomp** is a classic first-person 3D dungeon crawler available as a native **Microsoft C++ DirectX 12 Ultimate engine** and a browser-based **Three.js WebGL port**.

Swing a flaming sword, hurl fireballs, cast lightning, and stomp through endless **procedurally generated dungeons** crawling with monsters, treasure and traps.

## 🚀 Microsoft C++ DirectX 12 Ultimate Engine

The project features a full native C++20 implementation targeting **Microsoft DirectX 12 Ultimate (Feature Level 12_2)**:

- 🎮 **DirectX 12 Ultimate Rendering Pipeline (`src/D3D12Renderer.cpp`)**:
  - **DXR 1.1 Raytracing (`src/Shaders/Raytracing.hlsl`)**: Hardware raytraced ambient occlusion and reflection passes.
  - **Mesh Shaders (`src/Shaders/MeshShader.hlsl`)**: Shader Model 6.5 geometry amplification and per-meshlet culling.
  - **Variable Rate Shading (VRS)** & **Sampler Feedback**.
  - **Normal Mapping & Dynamic Point Lighting (`src/Shaders/PixelShader.hlsl`)**.
- 🛠️ **Visual Studio 2022 & CMake Support**:
  - Open `DungeonStompDX12.sln` directly in Visual Studio 2022.
  - Build with CMake: `cmake -B build && cmake --build build`.
- 🏰 **Procedural Dungeon Generator & Binary Asset Parsers**:
  - Ported C++ dungeon generator and parsers for original `.map`, `.mod`, `.cmp`, and `.3ds` models.

### 🛠️ Building the C++ DirectX 12 Ultimate Engine

#### Visual Studio 2022
1. Open `DungeonStompDX12.sln` in Visual Studio 2022.
2. Select **x64** and **Release** (or **Debug**).
3. Build and Run (`F5` or `Ctrl+F5`).

#### CMake (Windows & Linux / WSL)
```bash
cmake -B build
cmake --build build
ctest --test-dir build --output-on-failure
./build/DungeonStompDX12
```

---

## 🎮 WebGL / Three.js Engine

To run the browser version locally:

```bash
python -m http.server 8000
```
Then open **http://localhost:8000** in your browser.

---

## 🧱 Project Layout

| Path | Purpose |
|------|---------|
| `DungeonStompDX12.sln` / `.vcxproj` | Microsoft Visual Studio 2022 C++ Solution & Project |
| `CMakeLists.txt` | CMake C++20 build configuration |
| `src/Main.cpp` | Application entry point and game loop |
| `src/D3D12Renderer.h/.cpp` | DirectX 12 Ultimate rendering engine |
| `src/Shaders/` | HLSL Shaders (Vertex, Pixel, MeshShader Model 6.5, DXR Raytracing) |
| `src/DungeonGenerator.h/.cpp` | Procedural dungeon generation engine |
| `src/Parsers.h/.cpp` | Parsers for binary `.map`, `.mod`, `.cmp`, and `.3ds` assets |
| `src/Player.h/.cpp`, `src/Monster.h/.cpp` | Player stats/weapons/spells and Monster AI state machine |
| `src/Collision.h/.cpp`, `src/Minimap.h/.cpp` | Capsule collision resolution and circular minimap |
| `src/Audio.h/.cpp` | Positional 3D audio engine |
| `tests/` | C++ unit & integration tests (`test_dungeon`, `test_parsers`, `test_d3d12`) |
| `app.js`, `logic.js`, `render.js` | WebGL / Three.js JavaScript codebase |
| `Assets/`, `bin/`, `Sounds/` | Texture maps, binary dungeon levels, and sound assets |

---

## 📜 License

Released under the [MIT License](LICENSE). © Mark Longo.
