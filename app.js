/*
 * Copyright 2026 Mark Longo
 */

import * as THREE from 'three';
import { PointerLockControls } from 'three/addons/controls/PointerLockControls.js';
import {
    initRenderer, scene, camera, renderer, controls, setControls,
    hudEl, updateLighting, updateDistanceCulling, onWindowResize,
    normalMapsEnabled, setNormalMapsEnabled, textureManager,
    createPickupFloatingText, updateAdaptiveResolution
} from './render.js';
import {
    velocity, CAPSULE_RADIUS, GRAVITY, JUMP_SPEED, modelBoxes,
    resolveCapsuleCollisions, resolveMonsterCapsuleCollisions
} from './collision.js';
import { MonsterState, monsters, doors } from './gameState.js';
import {
    direction, cameraQuaternion, worldDir, isFlyMode,
    toggleFlyMode, isGrounded, setIsGrounded,
    jumpRequested, setJumpRequested, footstepTimer, setFootstepTimer,
    updateDoors, updatePickups, updateProjectiles, updateTeleporters, updatePlayerWeaponAnimation
} from './update.js';
import {
    MD2_ANIMATIONS, DEFAULT_MONSTER_CONFIG, MONSTER_CONFIGS,
    getMonsterConfig, Monster, TREASURE_DROPS, PICKUP_DEFINITIONS,
    getPickupDefinition, playerStats, damagePlayer, healPlayer, addPlayerXp,
    awardPlayerXp, updatePlayerHud, isInvincible, setIsInvincible,
    playerDead, playerDeathTimer, setPlayerDeathTimer, respawnPlayer,
    PLAYER_GUNS, unlockedWeapons, spellCounts,
    getCurrentGunIndex, setCurrentGunIndex,
    cycleWeapon, updateWeaponMesh, triggerWeaponAttack,
    openNearbyDoor, SWISH_SOUNDS, IMPACT_SOUNDS, PLAYER_IMPACT_SOUNDS,
    playSound, getRandomSound, preloadSounds, resumeAudio, getAudioContext,
    loadGameWorld, levelObjects, activePickups,
    playerWeaponCurrentAnim, generateAndLoadNewLevel,
    toggleMusic, isMusicOn, startNextMusicTrack, updateMusic,
    dungeonDepth, setDungeonDepth, dungeonGenerationOptions, setDungeonGenerationOptions,
    currentMapText, setRunSaveHandler, setPlayerDead,
    isLevelLoading, captureWorldState, restoreWorldState, isWorldStateValid
} from './logic.js';
import { updateMinimap } from './minimap.js';

// Re-export public interfaces for backwards compatibility and external modules
export {
    MonsterState, MD2_ANIMATIONS, DEFAULT_MONSTER_CONFIG, MONSTER_CONFIGS,
    getMonsterConfig, Monster, TREASURE_DROPS, PICKUP_DEFINITIONS,
    getPickupDefinition, playerStats, damagePlayer, healPlayer,
    addPlayerXp, awardPlayerXp, updatePlayerHud, PLAYER_GUNS,
    unlockedWeapons, spellCounts, SWISH_SOUNDS, IMPACT_SOUNDS,
    PLAYER_IMPACT_SOUNDS, playSound, getRandomSound
};

let moveForward = false;
let moveBackward = false;
let moveLeft = false;
let moveRight = false;
let moveUp = false;
let moveDown = false;
let isSprinting = false;

let prevTime = performance.now();
const forwardVector = new THREE.Vector3();
const rightVector = new THREE.Vector3();
let lastPosDisplayTime = 0;

// The simulation only runs while the pointer is locked, so opening the menu (Esc),
// switching tabs, or sitting on the title screen can't get the player killed.
// Add ?run=1 to the URL to keep the simulation running without pointer lock (automated tests).
const alwaysRun = new URLSearchParams(window.location.search).has('run');
const PAUSED_RENDER_INTERVAL_MS = 250;
let gameStarted = false;
let lastPausedRender = 0;
let lastAutosaveTime = 0;

const SAVE_KEY = 'dungeonRunState';
const GEN_OPTS_KEY = 'dungeonGenerationOptions';
const GAME_OPTS_KEY = 'dungeonGameOptions';

function getStoredJson(key) {
    try {
        const val = localStorage.getItem(key);
        return val ? JSON.parse(val) : null;
    } catch (e) {
        return null;
    }
}

function setStoredJson(key, obj) {
    try {
        localStorage.setItem(key, JSON.stringify(obj));
    } catch (e) {}
}

let worldReady = false;

function saveCurrentRun() {
    // Never save before the saved world has been restored or while a level is being built:
    // that would overwrite the run with a half-loaded state.
    if (!worldReady || isLevelLoading()) return;
    if (!controls || !controls.getObject()) return;
    const pos = controls.getObject().position;
    if (!Number.isFinite(pos.x) || !Number.isFinite(pos.y) || !Number.isFinite(pos.z)) return;
    const state = {
        version: 1,
        mapSource: currentMapText ? 'generated' : 'bundled',
        position: { x: pos.x, y: pos.y, z: pos.z },
        yaw: controls.getObject().rotation.y,
        pitch: camera ? camera.rotation.x : 0,
        depth: dungeonDepth,
        playerStats: {
            health: Math.max(1, playerStats.health),
            maxHealth: playerStats.maxHealth || 100,
            level: playerStats.level || 1,
            xp: playerStats.xp || 0,
            nextXp: playerStats.nextXp || 500,
            kills: playerStats.kills || 0
        },
        unlockedWeapons: Array.from(unlockedWeapons),
        spellCounts: { ...spellCounts },
        currentGunIndex: getCurrentGunIndex(),
        dungeonGenerationOptions: { ...dungeonGenerationOptions },
        normalMaps: normalMapsEnabled,
        music: isMusicOn(),
        world: captureWorldState(),
        timestamp: Date.now()
    };
    setStoredJson(SAVE_KEY, state);
}

async function init() {
    const container = document.getElementById('canvas-container');

    initRenderer(container);

    const newControls = new PointerLockControls(camera, document.body);
    setControls(newControls);

    const loadingOverlay = document.getElementById('loading-overlay');
    const instructions = document.getElementById('instructions');
    const menuViewMain = document.getElementById('menu-view-main');
    const menuViewGenerator = document.getElementById('menu-view-generator');
    const menuViewOptions = document.getElementById('menu-view-options');

    const menuPrompt = document.getElementById('instructions-prompt');
    const menuStatus = document.getElementById('menu-status');

    const menuBtnNewGame = document.getElementById('menu-btn-new-game');
    const menuBtnResume = document.getElementById('menu-btn-resume');
    const menuBtnGenerator = document.getElementById('menu-btn-generator');
    const menuBtnOptions = document.getElementById('menu-btn-options');

    const menuBtnGenerateAction = document.getElementById('menu-btn-generate-action');
    const menuBtnGeneratorBack = document.getElementById('menu-btn-generator-back');
    const genSizeInput = document.getElementById('gen-size');
    const genSizeVal = document.getElementById('gen-size-val');
    const genSeedInput = document.getElementById('gen-seed');

    const menuBtnOptionsBack = document.getElementById('menu-btn-options-back');
    const optNormalMaps = document.getElementById('opt-normal-maps');
    const optMusic = document.getElementById('opt-music');

    // Check saved state immediately so Resume is never falsely greyed out on page boot
    const initialSavedRun = getStoredJson(SAVE_KEY);
    if (initialSavedRun && initialSavedRun.version === 1) {
        if (menuBtnResume) menuBtnResume.disabled = false;
        if (menuPrompt) menuPrompt.textContent = `Saved run at Depth ${initialSavedRun.depth || 1} (Hero LVL ${initialSavedRun.playerStats?.level || 1}). Loading...`;
        if (Number.isFinite(initialSavedRun.depth)) {
            setDungeonDepth(initialSavedRun.depth);
        }
        if (initialSavedRun.dungeonGenerationOptions) {
            setDungeonGenerationOptions(initialSavedRun.dungeonGenerationOptions);
        }
    } else {
        if (menuBtnResume) menuBtnResume.disabled = true;
        if (menuPrompt) menuPrompt.textContent = 'Loading dungeon...';
    }

    function showMenuView(view) {
        if (menuViewMain) menuViewMain.style.display = (view === 'main') ? 'block' : 'none';
        if (menuViewGenerator) menuViewGenerator.style.display = (view === 'generator') ? 'block' : 'none';
        if (menuViewOptions) menuViewOptions.style.display = (view === 'options') ? 'block' : 'none';
        if (menuStatus) menuStatus.textContent = '';
    }

    // Pointer lock must be requested straight from the click handler, so it comes before anything
    // else (audio, sounds) that could throw or delay it.
    const startGameSession = () => {
        try {
            newControls.lock();
        } catch (e) {
            console.warn('Pointer lock request failed:', e);
        }
        resumeAudio();
        if (!gameStarted && isMusicOn()) {
            startNextMusicTrack();
        }
    };

    newControls.addEventListener('lock', () => {
        gameStarted = true;
        instructions.style.display = 'none';
        if (loadingOverlay) loadingOverlay.style.display = worldReady ? 'none' : 'flex';
        resumeAudio();
    });

    const releaseInputs = () => {
        moveForward = moveBackward = moveLeft = moveRight = moveUp = moveDown = false;
        isSprinting = false;
    };

    newControls.addEventListener('unlock', () => {
        instructions.style.display = 'block';
        if (loadingOverlay) loadingOverlay.style.display = 'none';
        showMenuView('main');
        if (menuPrompt) menuPrompt.textContent = 'Paused - Resume or choose an option:';
        if (menuBtnResume) menuBtnResume.disabled = false;
        saveCurrentRun();
        releaseInputs();
        const audio = getAudioContext();
        if (audio && audio.state === 'running') audio.suspend().catch(() => {});
    });
    window.addEventListener('blur', releaseInputs);

    // Save reliably across all page exit / hide events
    window.addEventListener('beforeunload', () => {
        if (gameStarted) saveCurrentRun();
    });
    window.addEventListener('pagehide', () => {
        if (gameStarted) saveCurrentRun();
    });
    document.addEventListener('visibilitychange', () => {
        if (document.hidden && gameStarted) saveCurrentRun();
    });

    // Periodic autosave interval every 5 seconds
    setInterval(() => {
        if (gameStarted && !playerDead) {
            saveCurrentRun();
        }
    }, 5000);

    setRunSaveHandler(saveCurrentRun);

    // A Resume click that happened before this script loaded already requested pointer lock; adopt it.
    window.__menuReady = true;
    if (window.__earlyResume && document.pointerLockElement === document.body) {
        newControls.isLocked = true;
        newControls.dispatchEvent({ type: 'lock' });
    }

    // Load saved dungeon generator options
    const savedGenOpts = getStoredJson(GEN_OPTS_KEY);
    if (savedGenOpts) {
        setDungeonGenerationOptions(savedGenOpts);
    }
    if (genSizeInput) {
        genSizeInput.value = String(dungeonGenerationOptions.numObjectsToPlace || 225);
        if (genSizeVal) genSizeVal.textContent = genSizeInput.value;
        genSizeInput.addEventListener('input', () => {
            if (genSizeVal) genSizeVal.textContent = genSizeInput.value;
        });
    }
    if (genSeedInput) {
        genSeedInput.value = dungeonGenerationOptions.seed || '';
    }

    // Load saved game settings
    const savedGameOpts = getStoredJson(GAME_OPTS_KEY);
    if (savedGameOpts) {
        if (typeof savedGameOpts.normalMaps === 'boolean') {
            setNormalMapsEnabled(savedGameOpts.normalMaps);
        }
        if (typeof savedGameOpts.music === 'boolean' && savedGameOpts.music !== isMusicOn()) {
            toggleMusic();
        }
    }
    if (optNormalMaps) optNormalMaps.checked = normalMapsEnabled;
    if (optMusic) optMusic.checked = isMusicOn();
    const musicDisplay = hudEl('music-display');
    if (musicDisplay) {
        musicDisplay.textContent = isMusicOn() ? 'ON' : 'OFF';
        musicDisplay.style.color = isMusicOn() ? '#00ff88' : '#ef4444';
    }

    // Menu button event listeners
    if (menuBtnResume) {
        menuBtnResume.addEventListener('click', (e) => {
            e.stopPropagation();
            if (menuBtnResume.disabled) return;
            startGameSession();
            playSound('buttonselect111.wav', 0.5);
        });
    }

    instructions.addEventListener('click', (e) => {
        if (e.target.closest('button, input, select, textarea')) return;
        if (worldReady || (menuBtnResume && !menuBtnResume.disabled)) {
            startGameSession();
        }
    });

    if (menuBtnNewGame) {
        menuBtnNewGame.addEventListener('click', async (e) => {
            e.stopPropagation();
            playSound('buttonselect111.wav', 0.5);
            menuBtnNewGame.disabled = true;
            if (menuStatus) menuStatus.textContent = 'Forging new dungeon...';
            try {
                // Reset player
                playerStats.health = 100;
                playerStats.maxHealth = 100;
                playerStats.level = 1;
                playerStats.xp = 0;
                playerStats.nextXp = 500;
                playerStats.kills = 0;
                unlockedWeapons.clear();
                ['AXE', 'MAGIC MISSILE', 'FIREBALL', 'LIGHTNING', 'HEALING'].forEach(w => unlockedWeapons.add(w));
                for (const s in spellCounts) spellCounts[s] = 5;
                setCurrentGunIndex(0);
                setDungeonDepth(1);
                setIsInvincible(false);
                setPlayerDead(false);
                toggleFlyMode(false);

                await generateAndLoadNewLevel(textureManager, false);

                updatePlayerHud();
                await updateWeaponMesh();

                gameStarted = true;
                saveCurrentRun();
                if (menuBtnResume) menuBtnResume.disabled = false;
                if (menuStatus) menuStatus.textContent = '';
                startGameSession();
                if (!newControls.isLocked) {
                    if (menuPrompt) menuPrompt.textContent = 'Dungeon ready! Click Resume or anywhere to enter.';
                }
            } catch (err) {
                console.error('Failed to create new game:', err);
                if (menuStatus) menuStatus.textContent = 'Failed to generate dungeon.';
            } finally {
                menuBtnNewGame.disabled = false;
            }
        });
    }

    if (menuBtnGenerator) {
        menuBtnGenerator.addEventListener('click', (e) => {
            e.stopPropagation();
            playSound('buttonselect111.wav', 0.5);
            showMenuView('generator');
            if (genSizeInput) {
                genSizeInput.value = String(dungeonGenerationOptions.numObjectsToPlace || 225);
                if (genSizeVal) genSizeVal.textContent = genSizeInput.value;
            }
            if (genSeedInput) {
                genSeedInput.value = dungeonGenerationOptions.seed || '';
            }
        });
    }

    if (menuBtnGeneratorBack) {
        menuBtnGeneratorBack.addEventListener('click', (e) => {
            e.stopPropagation();
            playSound('buttonselect111.wav', 0.5);
            showMenuView('main');
        });
    }

    if (menuBtnGenerateAction) {
        menuBtnGenerateAction.addEventListener('click', async (e) => {
            e.stopPropagation();
            playSound('buttonselect111.wav', 0.5);
            const size = parseInt(genSizeInput?.value, 10) || 225;
            const seed = genSeedInput?.value.trim() || null;
            const options = { numObjectsToPlace: size, seed };

            setDungeonGenerationOptions(options);
            setStoredJson(GEN_OPTS_KEY, options);

            menuBtnGenerateAction.disabled = true;
            if (menuStatus) menuStatus.textContent = `Generating dungeon (Depth ${dungeonDepth})...`;
            try {
                await generateAndLoadNewLevel(textureManager, false, options);
                gameStarted = true;
                saveCurrentRun();
                if (menuBtnResume) menuBtnResume.disabled = false;
                if (menuStatus) menuStatus.textContent = '';
                showMenuView('main');
                startGameSession();
                if (!newControls.isLocked) {
                    if (menuPrompt) menuPrompt.textContent = 'Dungeon ready! Click Resume or anywhere to enter.';
                }
            } catch (err) {
                console.error('Failed to generate dungeon:', err);
                if (menuStatus) menuStatus.textContent = 'Failed to generate dungeon.';
            } finally {
                menuBtnGenerateAction.disabled = false;
            }
        });
    }

    if (menuBtnOptions) {
        menuBtnOptions.addEventListener('click', (e) => {
            e.stopPropagation();
            playSound('buttonselect111.wav', 0.5);
            showMenuView('options');
            if (optNormalMaps) optNormalMaps.checked = normalMapsEnabled;
            if (optMusic) optMusic.checked = isMusicOn();
        });
    }

    if (menuBtnOptionsBack) {
        menuBtnOptionsBack.addEventListener('click', (e) => {
            e.stopPropagation();
            playSound('buttonselect111.wav', 0.5);
            showMenuView('main');
        });
    }

    if (optNormalMaps) {
        optNormalMaps.addEventListener('change', () => {
            setNormalMapsEnabled(optNormalMaps.checked);
            setStoredJson(GAME_OPTS_KEY, { normalMaps: normalMapsEnabled, music: isMusicOn() });
        });
    }

    if (optMusic) {
        optMusic.addEventListener('change', () => {
            if (isMusicOn() !== optMusic.checked) {
                const enabled = toggleMusic();
                const musicEl = hudEl('music-display');
                if (musicEl) {
                    musicEl.textContent = enabled ? 'ON' : 'OFF';
                    musicEl.style.color = enabled ? '#00ff88' : '#ef4444';
                }
                if (enabled) {
                    resumeAudio();
                    startNextMusicTrack();
                }
            }
            setStoredJson(GAME_OPTS_KEY, { normalMaps: normalMapsEnabled, music: isMusicOn() });
        });
    }

    scene.add(newControls.getObject());

    const onKeyDown = function (event) {
        if (event.repeat || playerDead || !worldReady) return;
        switch (event.code) {
            case 'ArrowUp':
            case 'KeyW':
                moveForward = true;
                break;
            case 'ArrowLeft':
            case 'KeyA':
                moveLeft = true;
                break;
            case 'ArrowDown':
            case 'KeyS':
                moveBackward = true;
                break;
            case 'ArrowRight':
            case 'KeyD':
                moveRight = true;
                break;
            case 'Space':
                if (isFlyMode) {
                    moveUp = true;
                } else {
                    setJumpRequested(true);
                }
                break;
            case 'KeyC':
            case 'ControlLeft':
            case 'ControlRight':
                if (isFlyMode) {
                    moveDown = true;
                }
                break;
            case 'KeyF':
            case 'KeyV':
                toggleFlyMode();
                break;
            case 'ShiftLeft':
            case 'ShiftRight':
                isSprinting = true;
                break;
            case 'KeyQ':
                cycleWeapon(1);
                break;
            case 'KeyZ':
                cycleWeapon(-1);
                break;
            case 'KeyE':
                openNearbyDoor();
                break;
            case 'KeyN':
                setNormalMapsEnabled(!normalMapsEnabled);
                if (optNormalMaps) optNormalMaps.checked = normalMapsEnabled;
                setStoredJson(GAME_OPTS_KEY, { normalMaps: normalMapsEnabled, music: isMusicOn() });
                break;
            case 'KeyK':
                PLAYER_GUNS.forEach(g => unlockedWeapons.add(g));
                for (const spell in spellCounts) {
                    spellCounts[spell] = Math.max(99, spellCounts[spell] + 50);
                }
                updatePlayerHud();
                if (newControls && newControls.getObject()) {
                    createPickupFloatingText('ALL WEAPONS & SPELLS UNLOCKED', newControls.getObject().position, '#facc15');
                }
                playSound('treasure.wav', 0.8);
                break;
            case 'KeyI':
                setIsInvincible(!isInvincible);
                if (newControls && newControls.getObject()) {
                    const statusText = isInvincible ? 'GOD MODE: ON (INVINCIBLE)' : 'GOD MODE: OFF';
                    const statusColor = isInvincible ? '#22c55e' : '#ef4444';
                    createPickupFloatingText(statusText, newControls.getObject().position, statusColor);
                }
                playSound('treasure.wav', 0.8);
                break;
            case 'KeyG':
                generateAndLoadNewLevel(textureManager);
                break;
            case 'KeyP':
            case 'KeyM': {
                const enabled = toggleMusic();
                if (optMusic) optMusic.checked = enabled;
                setStoredJson(GAME_OPTS_KEY, { normalMaps: normalMapsEnabled, music: enabled });
                const musicEl = hudEl('music-display');
                if (musicEl) {
                    musicEl.textContent = enabled ? 'ON' : 'OFF';
                    musicEl.style.color = enabled ? '#00ff88' : '#ef4444';
                }
                if (newControls && newControls.getObject()) {
                    const text = enabled ? 'MUSIC: ON' : 'MUSIC: OFF';
                    const color = enabled ? '#22c55e' : '#ef4444';
                    createPickupFloatingText(text, newControls.getObject().position, color);
                }
                if (enabled) {
                    startNextMusicTrack();
                }
                playSound('buttonselect111.wav', 0.5);
                break;
            }
        }
    };

    const onKeyUp = function (event) {
        switch (event.code) {
            case 'ArrowUp':
            case 'KeyW':
                moveForward = false;
                break;
            case 'ArrowLeft':
            case 'KeyA':
                moveLeft = false;
                break;
            case 'ArrowDown':
            case 'KeyS':
                moveBackward = false;
                break;
            case 'ArrowRight':
            case 'KeyD':
                moveRight = false;
                break;
            case 'Space':
                moveUp = false;
                break;
            case 'KeyC':
            case 'ControlLeft':
            case 'ControlRight':
                moveDown = false;
                break;
            case 'ShiftLeft':
            case 'ShiftRight':
                isSprinting = false;
                break;
        }
    };

    document.addEventListener('keydown', onKeyDown);
    document.addEventListener('keyup', onKeyUp);

    document.addEventListener('mousedown', (event) => {
        if (event.button === 0 && newControls && newControls.isLocked) {
            triggerWeaponAttack();
        }
    });

    window.addEventListener('resize', onWindowResize);

    const savedRun = getStoredJson(SAVE_KEY);
    if (savedRun && savedRun.version === 1) {
        if (Number.isFinite(savedRun.depth)) {
            setDungeonDepth(savedRun.depth);
        }
        if (savedRun.dungeonGenerationOptions) {
            setDungeonGenerationOptions(savedRun.dungeonGenerationOptions);
        }
    }

    try {
        await loadGameWorld(textureManager);
    } catch (e) {
        console.error('Failed to load the dungeon:', e);
        if (loadingOverlay) loadingOverlay.style.display = 'none';
        if (menuPrompt) menuPrompt.textContent = 'Failed to load the dungeon. Check the console for details.';
        return;
    }

    if (savedRun && savedRun.version === 1) {
        try {
            if (savedRun.playerStats) {
                for (const k in savedRun.playerStats) {
                    if (Number.isFinite(savedRun.playerStats[k])) playerStats[k] = savedRun.playerStats[k];
                }
            }
            if (Array.isArray(savedRun.unlockedWeapons)) {
                unlockedWeapons.clear();
                savedRun.unlockedWeapons.filter(w => PLAYER_GUNS.includes(w)).forEach(w => unlockedWeapons.add(w));
            }
            if (savedRun.spellCounts) {
                for (const s in spellCounts) {
                    if (Number.isFinite(savedRun.spellCounts[s])) spellCounts[s] = Math.max(0, savedRun.spellCounts[s]);
                }
            }
            if (Number.isInteger(savedRun.currentGunIndex)) {
                setCurrentGunIndex(Math.max(0, Math.min(PLAYER_GUNS.length - 1, savedRun.currentGunIndex)));
            }

            // Position and world state belong to one specific map; if it is not the one that was
            // saved, the player starts at the entrance of what actually loaded.
            if (isWorldStateValid(savedRun.world)) {
                await restoreWorldState(savedRun.world);
                const p = savedRun.position;
                if (p && Number.isFinite(p.x) && Number.isFinite(p.y) && Number.isFinite(p.z)) {
                    newControls.getObject().position.set(p.x, p.y, p.z);
                }
                if (Number.isFinite(savedRun.yaw)) newControls.getObject().rotation.y = savedRun.yaw;
                if (Number.isFinite(savedRun.pitch)) camera.rotation.x = savedRun.pitch;
            } else {
                console.warn('Saved world does not match the loaded dungeon; starting at its entrance.');
            }

            playerStats.health = Math.max(0, Math.min(playerStats.maxHealth, playerStats.health));
            setPlayerDead(false);
            if (playerStats.health <= 0) respawnPlayer();
            else updatePlayerHud();
        } catch (error) {
            console.warn('Could not fully restore the saved run:', error);
        }

        if (menuBtnResume) menuBtnResume.disabled = false;
        if (menuPrompt) menuPrompt.textContent = `Ready! Saved run at Depth ${dungeonDepth} (Hero LVL ${playerStats.level}).`;
    } else {
        if (menuBtnResume) menuBtnResume.disabled = true;
        if (menuPrompt) menuPrompt.textContent = 'Welcome! Choose New Game to enter the dungeon:';
    }

    await updateWeaponMesh();
    worldReady = true;
    if (loadingOverlay) loadingOverlay.style.display = 'none';

    const monsterSounds = new Set();
    monsters.forEach(m => {
        if (m.config.painSound) monsterSounds.add(m.config.painSound);
        if (m.config.deathSound) monsterSounds.add(m.config.deathSound);
        if (m.config.weaponSound) monsterSounds.add(m.config.weaponSound);
        if (m.config.yellSound) monsterSounds.add(m.config.yellSound);
        if (m.config.sound) monsterSounds.add(m.config.sound);
    });

    preloadSounds([
        ...SWISH_SOUNDS, ...IMPACT_SOUNDS, ...PLAYER_IMPACT_SOUNDS,
        'spell1.wav', 'spell2.wav', 'spell3.wav', 'fireball.wav', 'explod1.wav', 'explod2.wav',
        'walk.wav', 'die.wav', 'death1.wav', 'death2.wav', 'death3.wav', 'death4.wav',
        'Midi/d1.wav', 'Midi/d2.wav', 'Midi/d3.wav', 'Midi/d4.wav',
        ...monsterSounds
    ]);

    window.camera = camera;
    window.renderer = renderer;
    window.controls = newControls;
    window.scene = scene;
    window.monsters = monsters;
    window.modelBoxes = modelBoxes;
    window.resolveMonsterCapsuleCollisions = resolveMonsterCapsuleCollisions;
    window.doors = doors;
    window.openNearbyDoor = openNearbyDoor;
    window.activePickups = activePickups;
    window.playerStats = playerStats;
    window.damagePlayer = damagePlayer;
    window.playSound = playSound;
    window.SWISH_SOUNDS = SWISH_SOUNDS;
    window.IMPACT_SOUNDS = IMPACT_SOUNDS;
    window.PLAYER_IMPACT_SOUNDS = PLAYER_IMPACT_SOUNDS;
    window.PLAYER_GUNS = PLAYER_GUNS;
    window.unlockedWeapons = unlockedWeapons;
    window.spellCounts = spellCounts;
    window.updatePickups = updatePickups;
    window.setCurrentGunIndex = setCurrentGunIndex;
    window.setDungeonDepth = setDungeonDepth;
    window.textureManager = textureManager;
    window.saveCurrentRun = saveCurrentRun;
    window.generateAndLoadNewLevel = (descend, options) => generateAndLoadNewLevel(textureManager, descend, options);
    Object.defineProperty(window, 'dungeonDepth', {
        get: () => dungeonDepth,
        set: (v) => setDungeonDepth(v)
    });
    Object.defineProperty(window, 'currentGunIndex', {
        get: () => getCurrentGunIndex(),
        set: (v) => setCurrentGunIndex(v)
    });
    Object.defineProperty(window, 'playerWeaponCurrentAnim', {
        get: () => playerWeaponCurrentAnim
    });

    prevTime = performance.now();
    lastAutosaveTime = performance.now();
    animate();
}

function animate() {
    requestAnimationFrame(animate);

    const time = performance.now();
    const rawDelta = (time - prevTime) / 1000;
    prevTime = time;

    if (!alwaysRun && (!gameStarted || !controls.isLocked || document.hidden)) {
        if (time - lastPausedRender >= PAUSED_RENDER_INTERVAL_MS) {
            lastPausedRender = time;
            renderer.render(scene, camera);
        }
        return;
    }

    updateAdaptiveResolution(rawDelta * 1000);

    let delta = rawDelta;
    if (delta > 0.1) delta = 0.1;

    const moveSpeed = isSprinting ? 400.0 : 200.0;

    if (isFlyMode) {
        velocity.x *= Math.pow(0.01, delta);
        velocity.y *= Math.pow(0.01, delta);
        velocity.z *= Math.pow(0.01, delta);

        direction.set(
            Number(moveRight) - Number(moveLeft),
            0,
            Number(moveBackward) - Number(moveForward)
        );

        if (direction.lengthSq() > 0) {
            direction.normalize();
            camera.getWorldQuaternion(cameraQuaternion);
            worldDir.copy(direction).applyQuaternion(cameraQuaternion);
            velocity.x += worldDir.x * moveSpeed * 8.0 * delta;
            velocity.y += worldDir.y * moveSpeed * 8.0 * delta;
            velocity.z += worldDir.z * moveSpeed * 8.0 * delta;
        }

        if (moveUp) {
            velocity.y += moveSpeed * 8.0 * delta;
        }
        if (moveDown) {
            velocity.y -= moveSpeed * 8.0 * delta;
        }

        controls.getObject().position.x += velocity.x * delta;
        controls.getObject().position.y += velocity.y * delta;
        controls.getObject().position.z += velocity.z * delta;
    } else {
        velocity.x *= Math.pow(0.001, delta);
        velocity.z *= Math.pow(0.001, delta);

        velocity.y -= GRAVITY * delta;

        if (jumpRequested) {
            if (isGrounded) {
                velocity.y = JUMP_SPEED;
                setIsGrounded(false);
            }
            setJumpRequested(false);
        }

        camera.getWorldQuaternion(cameraQuaternion);
        forwardVector.set(0, 0, -1).applyQuaternion(cameraQuaternion);
        forwardVector.y = 0;
        if (forwardVector.lengthSq() > 1e-6) {
            forwardVector.normalize();
        } else {
            forwardVector.set(0, 0, -1);
        }

        rightVector.set(1, 0, 0).applyQuaternion(cameraQuaternion);
        rightVector.y = 0;
        if (rightVector.lengthSq() > 1e-6) {
            rightVector.normalize();
        } else {
            rightVector.set(1, 0, 0);
        }

        const inputForward = Number(moveForward) - Number(moveBackward);
        const inputRight = Number(moveRight) - Number(moveLeft);

        worldDir.set(0, 0, 0);
        if (inputForward !== 0) {
            worldDir.addScaledVector(forwardVector, inputForward);
        }
        if (inputRight !== 0) {
            worldDir.addScaledVector(rightVector, inputRight);
        }

        if (worldDir.lengthSq() > 0) {
            worldDir.normalize();
            velocity.x += worldDir.x * moveSpeed * 10.0 * delta;
            velocity.z += worldDir.z * moveSpeed * 10.0 * delta;
        }

        const camPos = controls.getObject().position;

        const maxStep = CAPSULE_RADIUS * 0.5;
        const travel = Math.max(Math.abs(velocity.x), Math.abs(velocity.y), Math.abs(velocity.z)) * delta;
        const steps = Math.min(16, Math.max(1, Math.ceil(travel / maxStep)));
        const stepDt = delta / steps;
        let grounded = false;
        for (let s = 0; s < steps; s++) {
            camPos.x += velocity.x * stepDt;
            camPos.y += velocity.y * stepDt;
            camPos.z += velocity.z * stepDt;

            grounded = resolveCapsuleCollisions(camPos) || grounded;
        }
        setIsGrounded(grounded);

        if (isGrounded && (moveForward || moveBackward || moveLeft || moveRight)) {
            const speedSq = velocity.x * velocity.x + velocity.z * velocity.z;
            if (speedSq > 400.0) {
                let curFootstepTimer = footstepTimer + delta * (isSprinting ? 1.5 : 1.0);
                if (curFootstepTimer >= 0.38) {
                    curFootstepTimer = 0.0;
                    playSound('walk.wav', 0.18);
                }
                setFootstepTimer(curFootstepTimer);
            } else {
                setFootstepTimer(0.3);
            }
        } else {
            setFootstepTimer(0.3);
        }
    }

    const pos = controls.getObject().position;
    if (time - lastPosDisplayTime >= 100) {
        lastPosDisplayTime = time;
        hudEl('pos-display').textContent = `${Math.round(pos.x)}, ${Math.round(pos.y)}, ${Math.round(pos.z)}`;
    }

    if (time - lastAutosaveTime >= 5000) {
        lastAutosaveTime = time;
        if (gameStarted && !playerDead) {
            saveCurrentRun();
        }
    }

    if (playerDead) {
        setPlayerDeathTimer(playerDeathTimer - delta);
        if (playerDeathTimer <= 0) respawnPlayer();
    }

    const playerPos = pos;
    for (let i = 0; i < monsters.length; i++) {
        monsters[i].update(delta, playerPos, monsters);
    }

    updatePlayerWeaponAnimation(delta, { moveForward, moveBackward, moveLeft, moveRight });

    updateProjectiles(delta);

    updatePickups(delta, pos);

    updateTeleporters(delta, pos);

    updateDoors(delta);

    updateMusic(delta);

    updateLighting(time / 1000, delta, pos);

    updateDistanceCulling(levelObjects, pos);

    updateMinimap(pos, camera);

    renderer.render(scene, camera);
}

if (document.readyState === 'loading') {
    window.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
