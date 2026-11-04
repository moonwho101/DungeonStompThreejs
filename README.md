<div align="center">

# ⚔️ Dungeon Stomp Three.js

### A classic first-person dungeon crawler, reborn in your browser.

**Procedural dungeons · Real-time spells · Dozens of monsters · Zero installs · Pure JavaScript + WebGL**

![Three.js](https://img.shields.io/badge/Three.js-r160-black?logo=three.js)
![JavaScript](https://img.shields.io/badge/JavaScript-ES%20Modules-F7DF1E?logo=javascript&logoColor=black)
![WebGL](https://img.shields.io/badge/WebGL-3D-990000?logo=webgl)
![No Build Step](https://img.shields.io/badge/build%20step-none-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)

<img src="verification/screenshots/s6.png" alt="Dungeon Stomp Three.js gameplay: first-person view down a glowing teal dungeon corridor with a minimap and HUD" width="860">

## 🎮 [**Play it live in your browser →**](https://moonwho101.github.io/DungeonStompThreejs/)

</div>

---

## What is this?

**Dungeon Stomp Three.js** is a browser-based, first-person 3D dungeon crawler built with [Three.js](https://threejs.org/). It is a ground-up JavaScript port of **Dungeon Stomp**, the original Direct3D dungeon crawler by [Mark Longo (moonwho101)](https://github.com/moonwho101), with the classic levels, models, textures and sounds brought to the web.

Swing a flaming sword, hurl fireballs, cast lightning, and stomp through endless **procedurally generated dungeons** crawling with monsters, treasure and traps. Just open it in a browser and play.

### 👉 [**Play it live: moonwho101.github.io/DungeonStompThreejs**](https://moonwho101.github.io/DungeonStompThreejs/)

> If you grew up on Doom, Quake, Hexen, Eye of the Beholder or Diablo, this one is for you.

## ✨ Features

- 🏰 **Infinite procedural dungeons.** Configure rooms and seed in the Dungeon Generator, or press `G` any time to regenerate a new level. Find the glowing exit portal to descend &mdash; every depth is tougher than the last.
- 💾 **Persistent adventures.** The game saves periodically and after each portal. Resume restores your position, stats, weapons and depth, plus the world exactly as you left it: slain monsters stay dead, collected items stay collected, and opened doors and chests stay open.
- 📜 **In-game menu system.** Simple and clean opening and pause menu with New Game, Resume, Dungeon Generator settings, and visual/audio Options.
- 🧟 **30 monster families.** Ogres, hydras, dragons, necromancers, demonesses, faeries, mummies, wraiths, goblins, skeletons, wolves, tentacle horrors and more. Each has its own AI, aggro range, pain and death sounds, and attack style.
- 🔮 **Spellcasters that fight back.** Many enemies cast **Magic Missile**, **Fireball** and **Lightning** at you with line-of-sight checks and cooldowns.
- ⚔️ **A full arsenal.** Axe, Flamesword, Bastard Sword, Battle Axe, Ice Sword, Lightning Sword, Morning Star, Spiked Flail, Split Sword and Super Flamesword, plus the spells **Magic Missile**, **Fireball**, **Lightning** and **Healing**.
- 📈 **RPG progression.** Gain XP, level up, collect potions, scrolls, spellbooks and coins, and track your kill count on a modern HUD.
- 💡 **Dynamic lighting and normal mapping.** Hundreds of lights per level, with toggleable normal maps (`N`) for a gritty, tactile look.
- 🧭 **Circular minimap.** See walls, monsters and loot around you at a glance.
- 🚪 **Interactive world.** Open doors and crack open treasure chests.
- 🔊 **Atmospheric audio.** More than 150 original sound effects, plus a rolling music soundtrack (`P` / `M` to toggle).
- 🕹️ **Full controller & Xbox gamepad support.** Plug and play with any standard gamepad (Xbox, PlayStation DualSense/DualShock, Switch Pro, etc.) with modern dual-analog crawler controls, haptic vibration rumble feedback, and in-game menu navigation.
- 🕹️ **Fly mode and god mode** for exploring, level design and debugging.
- 🪶 **No bundler, no npm, no build.** It's plain ES modules plus an import map. Read it, hack it, mod it.

## 🎮 Controls

| Key | Action |
|-----|--------|
| `W` `A` `S` `D` / Arrow keys | Move |
| Mouse | Look around (click to capture the pointer) |
| Left click | Attack / cast |
| `Space` | Jump (fly up in fly mode) |
| `Shift` | Sprint |
| `Q` / `Z` | Next / previous weapon or spell |
| `E` | Open nearby door |
| `G` | Generate a new dungeon |
| `F` / `V` | Toggle fly mode (`C` / `Ctrl` to descend) |
| `N` | Toggle normal maps |
| `P` / `M` | Toggle music |
| `K` | Cheat: unlock all weapons and spells |
| `I` | Cheat: toggle god mode |
| `Esc` | Pause / release the mouse |

### 🎮 Controller Controls (Xbox / Modern Gamepad)

| Control | Action |
|---------|--------|
| **Left Stick** | 360° Analog Move (analog speed scaling: sneak / walk / run) |
| **Right Stick** | 360° Camera Look / Aim (curved response for fine aiming + quick turns) |
| **Right Trigger (`RT`)** | Attack / Swing Weapon / Cast Spell |
| **Left Trigger (`LT`)** | Hold to Sprint |
| **Left Stick Press (`L3`)** | Toggle Sprint |
| **Right Stick Press (`R3`)** | Re-center Camera Pitch (instant level horizon) |
| **Button `X`** (Xbox `X` / PS `Square`) | Interact / Open nearby Door & Chest |
| **Button `A`** (Xbox `A` / PS `Cross`) | Jump (fly up in fly mode) / Select in menus |
| **Button `B`** (Xbox `B` / PS `Circle`) | Crouch / Descend (in fly mode) / Back in menus |
| **Button `Y`** (Xbox `Y` / PS `Triangle`) | Next Weapon |
| **Right Bumper (`RB`)** / **D-Pad Right** | Next Weapon or Spell |
| **Left Bumper (`LB`)** / **D-Pad Left** | Previous Weapon or Spell |
| **D-Pad Up** | Toggle Music |
| **D-Pad Down** | Toggle Normal Maps |
| **Start / Menu** | Pause / Resume Game |
| **Back / View** | Cheat: Toggle God Mode (invincible) |
| **D-Pad / Left Stick in Menus** | Full menu navigation (navigate buttons, adjust sliders, toggle options) |
| **Dual Rumble Haptics** | Dynamic vibration on attack, monster hits, player damage, pickups & doors |

## 🌐 Play it live

**[▶ Play Dungeon Stomp Three.js now](https://moonwho101.github.io/DungeonStompThreejs/)**

No install needed. Open the link in a modern desktop browser (Chrome, Edge, Firefox or Safari) and click to start.

## 🚀 Play it locally

The game loads levels, models and textures with `fetch`, so it has to be served over HTTP. Opening `index.html` directly from disk won't work.

```bash
git clone https://github.com/moonwho101/DungeonStompThreejs.git
cd DungeonStompThreejs

# pick any static server:
python -m http.server 8000
# or
npx serve .
```

Then open **http://localhost:8000** in a modern browser (Chrome, Edge, Firefox or Safari) and click to start.

Three.js is loaded from a CDN (unpkg) through an import map, so you need an internet connection on first load.

### Host it for free
It's a fully static site, so you can publish it with **GitHub Pages**, Netlify, Vercel or Cloudflare Pages. Point them at the repo root, with no build command and no output directory.

## 🧱 Project layout

| Path | Purpose |
|------|---------|
| [`index.html`](index.html) | Entry point, HUD and styles |
| [`app.js`](app.js) | Startup, input handling, pointer lock |
| [`logic.js`](logic.js) | Monsters, AI, combat, items, spells, level loading |
| [`generator.js`](generator.js) | Procedural dungeon generator |
| [`render.js`](render.js) | Three.js renderer, lights, materials, effects |
| [`update.js`](update.js) | Per-frame game loop |
| [`collision.js`](collision.js) | Player and monster collision |
| [`minimap.js`](minimap.js) | Circular minimap |
| [`parsers.js`](parsers.js) | Parsers for the original Dungeon Stomp `.map`, `.mod` and `.cmp` data |
| [`bin/`](bin) | Original level, model-list and collision data |
| [`Assets/`](Assets) | Flat directory of 3DS/MD2 models, textures and normal maps |
| [`Sounds/`](Sounds), [`Midi/`](Midi) | Sound effects and music |
| [`tools/`](tools), [`verification/`](verification) | Asset analysis scripts and automated Playwright checks |

After adding or renaming assets, run `python tools/generate_asset_index.py` to refresh the case-insensitive filename index used by the game.

## 🛠️ Built with

- [Three.js](https://threejs.org/) for rendering, `PointerLockControls` and the 3DS loader
- Vanilla JavaScript (ES modules), with no framework and no bundler
- Web Audio / HTML5 audio for sound and music

## 🤝 Contributing

Bug reports, new monsters, level ideas, performance tweaks and pull requests are all welcome. Fork it, break it, make it better.

1. Fork the repo
2. Create a branch: `git checkout -b feature/my-awesome-feature`
3. Commit and push
4. Open a pull request

If you enjoy the project, **⭐ star the repo**. It helps other dungeon crawlers find it.

## 📜 License

Released under the [MIT License](LICENSE). © Mark Longo.

---

<div align="center">

**Dungeon Stomp Three.js**: descend, fight, loot, repeat. 🗡️🔥⚡

</div>
