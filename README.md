<div align="center">

# ⚔️ Dungeon Stomp (Godot 4.7.2 for Windows & Three.js)

### A classic first-person dungeon crawler, now powered by Godot 4.7.2 for Windows & Three.js.

**Procedural dungeons · Real-time spells · 30 monster families · Godot 4.7.2 Forward+ · Pure GDScript + WebGL**

![Godot Engine](https://img.shields.io/badge/Godot-4.7.2-478CBF?logo=godotengine&logoColor=white)
![Windows Desktop](https://img.shields.io/badge/Platform-Windows%20x86__64-0078D7?logo=windows&logoColor=white)
![Three.js](https://img.shields.io/badge/Three.js-r160-black?logo=three.js)
![License](https://img.shields.io/badge/license-MIT-blue)

<img src="verification/screenshots/s6.png" alt="Dungeon Stomp gameplay: first-person view down a glowing dungeon corridor with a minimap and HUD" width="860">

## 🎮 [**Play it live in your browser →**](https://moonwho101.github.io/DungeonStompThreejs/)

</div>

---

## What is this?

**Dungeon Stomp** is a classic first-person 3D dungeon crawler available as a native **Godot 4.7.2 Windows Engine** and a browser-based **Three.js WebGL port**. It is a modern revival of **Dungeon Stomp**, the original Direct3D dungeon crawler by [Mark Longo (moonwho101)](https://github.com/moonwho101), with the classic levels, models, textures and sounds brought to modern game engines.

Swing a flaming sword, hurl fireballs, cast lightning, and stomp through endless **procedurally generated dungeons** crawling with monsters, treasure and traps.

---

## 🚀 Godot 4.7.2 Windows Engine

The project features a full native Godot 4.7.2 port of the Three.js game targeting **Windows Desktop (x86_64)**. It loads the same data files at runtime and plays the same way:

- **Same levels and data:** `bin/level1.map`, `Objects.dat`, `modellist.dat` and `textures.dat` are parsed at runtime (`scripts/parsers.gd`); MD2 monsters/weapons (`scripts/md2.gd`, GPU vertex-animation blending) and 3DS models (`scripts/tds.gd`) are loaded directly from `Assets/`.
- **Identical dungeon generator:** `scripts/generator.gd` is a port of `generator.js` using the same seeded RNG, so a seed produces the same dungeon in both versions.
- **Same physics and combat:** capsule collision, monster AI/spells, weapons, projectiles, pickups, doors, chests, exit portals and depth scaling (`scripts/collision.gd`, `scripts/monster.gd`, `scripts/game.gd`).
- **Same look:** Lambert/Phong materials matching three.js lighting, normal maps, flickering lamp glare, particles, blood, fog (`scripts/materials.gd`, `scripts/effects.gd`).
- **Same UI:** HUD, minimap, menus (New Game / Resume / Generator / Options), gamepad support and saved runs in `user://` (`scripts/ui.gd`, `scripts/minimap.gd`, `scripts/gamepad.gd`).

### Running in Godot 4.7.2

1. Install **Godot 4.7.2** on Windows or Linux.
2. Open Godot and import `project.godot`.
3. Press **F5** (Play) to run `res://scenes/main.tscn`.

### Building the Windows Executable

Using the command line with Godot 4.7.2:

```bash
mkdir -p build/windows
godot --headless --path . --export-debug "Windows Desktop" build/windows/DungeonStomp.exe
```

The game data folders (`Assets/`, `bin/`, `Sounds/`, `Midi/`) are excluded from Godot's importer (`.gdignore`) and read at runtime, so copy them next to the exported `DungeonStomp.exe`.

### Running Automated Godot Tests

Run the built-in headless test runner:

```bash
godot --headless --path . -s res://tests/test_runner.gd
```

---

## ✨ Features

- 🏰 **Infinite procedural dungeons.** Configure rooms and seed in the Dungeon Generator, or press `G` any time to regenerate a new level. Find the glowing exit portal to descend &mdash; every depth is tougher than the last.
- 💾 **Persistent adventures.** Slain monsters stay dead, collected items stay collected, and opened doors and chests stay open.
- 🧟 **30 monster families.** Ogres, hydras, dragons, necromancers, demonesses, faeries, mummies, wraiths, goblins, skeletons, wolves, tentacle horrors and more.
- 🔮 **Spellcasters that fight back.** Enemies cast Magic Missile, Fireball and Lightning with line-of-sight checks.
- ⚔️ **A full arsenal.** Axe, Flamesword, Bastard Sword, Battle Axe, Ice Sword, Lightning Sword, Morning Star, Spiked Flail, Split Sword and Super Flamesword, plus Magic Missile, Fireball, Lightning and Healing.
- 📈 **RPG progression.** Gain XP, level up, collect potions, scrolls, spellbooks and coins, and track your stats on the HUD.
- 💡 **Dynamic lighting.** Dynamic omni lights with ambient environment lighting.
- 🧭 **Circular minimap.** See walls, monsters and loot around you at a glance.

---

## 🎮 Controls

| Key | Action |
|-----|--------|
| `W` `A` `S` `D` / Arrow keys | Move |
| Mouse | Look around (click to capture the pointer) |
| Left click | Attack / cast spell |
| `Space` | Jump |
| `Shift` | Sprint |
| `Q` / `Z` | Next / previous weapon or spell |
| `E` | Open nearby door / interact |
| `G` | Generate a new procedural dungeon |
| `I` | Cheat: toggle god mode |
| `Esc` | Pause / release the mouse |

---

## 🌐 Three.js Web Version

To run the web version locally:

```bash
python -m http.server 8000
```

Then open **http://localhost:8000** in any modern desktop browser.

---

## 📜 License

Released under the [MIT License](LICENSE). © Mark Longo.
