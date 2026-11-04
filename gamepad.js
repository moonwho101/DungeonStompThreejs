/*
 * Copyright 2026 Mark Longo
 * Gamepad & Controller Support for Dungeon Stomp Three.js
 */

import * as THREE from 'three';

export const GP_BUTTONS = Object.freeze({
    A: 0,              // Bottom face button (Xbox A, PS Cross, Switch B) - Jump / Confirm
    B: 1,              // Right face button (Xbox B, PS Circle, Switch A) - Crouch / Cancel / Back
    X: 2,              // Left face button (Xbox X, PS Square, Switch Y) - Interact / Open Door / Chest
    Y: 3,              // Top face button (Xbox Y, PS Triangle, Switch X) - Next Weapon / Toggle
    LB: 4,             // Left bumper / shoulder (L1) - Prev Weapon / Fly Down
    RB: 5,             // Right bumper / shoulder (R1) - Next Weapon / Fly Up
    LT: 6,             // Left trigger (L2) - Sprint (analog) / Fly Down
    RT: 7,             // Right trigger (R2) - Primary Attack / Cast Spell (analog)
    BACK: 8,           // Back / View / Select - God Mode Cheat / Options
    START: 9,          // Start / Menu / Options - Pause / Resume Menu
    L3: 10,            // Left stick press - Sprint toggle
    R3: 11,            // Right stick press - Center camera pitch / Fly mode
    DPAD_UP: 12,       // D-pad Up - Toggle Music / Menu Up
    DPAD_DOWN: 13,     // D-pad Down - Toggle Normal Maps / Menu Down
    DPAD_LEFT: 14,     // D-pad Left - Prev Weapon / Menu Left
    DPAD_RIGHT: 15     // D-pad Right - Next Weapon / Menu Right
});

export const GP_AXES = Object.freeze({
    LEFT_X: 0,
    LEFT_Y: 1,
    RIGHT_X: 2,
    RIGHT_Y: 3
});

// Tuned controller configuration
const DEFAULT_LOOK_SENSITIVITY = 2.8;
const DEFAULT_DEADZONE = 0.15;
const DEFAULT_LOOK_EXPONENT = 1.8;
const MAX_PITCH = Math.PI * 0.47; // ~85 degrees up or down

const _euler = new THREE.Euler(0, 0, 0, 'YXZ');

let lookSensitivity = DEFAULT_LOOK_SENSITIVITY;
let invertY = false;
let vibrationEnabled = true;

// Active gamepad state
let activeGamepadIndex = -1;
let lastActiveGamepadName = '';
const prevButtons = new Map(); // buttonIndex -> boolean
let l3SprintToggled = false;

// Menu navigation state
let menuNavTimer = 0;
let menuNavLastDir = 0; // -1 = up, 1 = down
let menuHorizTimer = 0;
let menuHorizLastDir = 0; // -1 = left, 1 = right
const MENU_REPEAT_DELAY = 0.32;
const MENU_REPEAT_INTERVAL = 0.14;

let currentFocusElement = null;

// Helpers to get connected gamepads
export function getConnectedGamepads() {
    if (!navigator.getGamepads) return [];
    try {
        const raw = navigator.getGamepads();
        const list = [];
        for (let i = 0; i < raw.length; i++) {
            if (raw[i] && raw[i].connected) {
                list.push(raw[i]);
            }
        }
        return list;
    } catch {
        return [];
    }
}

export function getPrimaryGamepad() {
    const gamepads = getConnectedGamepads();
    if (gamepads.length === 0) return null;

    if (activeGamepadIndex !== -1) {
        const found = gamepads.find(g => g.index === activeGamepadIndex);
        if (found) return found;
    }

    // Default to the first connected gamepad
    return gamepads[0];
}

export function formatGamepadName(rawId) {
    if (!rawId) return 'Controller';
    const lower = rawId.toLowerCase();
    if (lower.includes('xbox') || lower.includes('xinput')) {
        return 'Xbox Controller';
    }
    if (lower.includes('dualsense') || lower.includes('ps5')) {
        return 'PlayStation DualSense';
    }
    if (lower.includes('dualshock') || lower.includes('wireless controller') || lower.includes('054c')) {
        return 'PlayStation Controller';
    }
    if (lower.includes('pro controller') || lower.includes('switch') || lower.includes('joy-con')) {
        return 'Nintendo Switch Controller';
    }
    // Clean up generic vendor IDs like "(STANDARD GAMEPAD Vendor: 045e Product: 028e)"
    const clean = rawId.split('(')[0].trim();
    return clean || 'Gamepad';
}

function showControllerToast(message) {
    let toast = document.getElementById('controller-toast');
    if (!toast) {
        toast = document.createElement('div');
        toast.id = 'controller-toast';
        document.body.appendChild(toast);
    }
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(toast.__timer);
    toast.__timer = setTimeout(() => {
        toast.classList.remove('show');
    }, 3200);
}

function updateGamepadDisplay() {
    const el = document.getElementById('gamepad-display');
    const gp = getPrimaryGamepad();
    if (!el) return;
    if (gp) {
        const name = formatGamepadName(gp.id);
        el.textContent = name;
        el.style.color = '#00ff88';
    } else {
        el.textContent = 'None';
        el.style.color = '#64748b';
    }
}

// Analog deadzone and response curve calculation
export function applyStickDeadzoneAndCurve(rawX, rawY, deadzone = DEFAULT_DEADZONE, exponent = DEFAULT_LOOK_EXPONENT) {
    const mag = Math.hypot(rawX, rawY);
    if (mag <= deadzone) {
        return { x: 0, y: 0, mag: 0 };
    }
    const normalizedMag = Math.min(1.0, (mag - deadzone) / (1.0 - deadzone));
    const curvedMag = Math.pow(normalizedMag, exponent);
    const scale = curvedMag / mag;
    return {
        x: rawX * scale,
        y: rawY * scale,
        mag: curvedMag
    };
}

function isButtonPressed(gp, index, threshold = 0.5) {
    if (!gp || !gp.buttons || !gp.buttons[index]) return false;
    const btn = gp.buttons[index];
    if (typeof btn === 'number') return btn > threshold;
    return Boolean(btn.pressed || btn.value > threshold);
}

function getButtonValue(gp, index) {
    if (!gp || !gp.buttons || !gp.buttons[index]) return 0;
    const btn = gp.buttons[index];
    if (typeof btn === 'number') return btn;
    return typeof btn.value === 'number' ? btn.value : (btn.pressed ? 1.0 : 0.0);
}

// Haptic feedback / Rumble
export function triggerGamepadVibration(duration = 100, weakMagnitude = 0.5, strongMagnitude = 0.5) {
    if (!vibrationEnabled) return;
    const gamepads = getConnectedGamepads();
    for (const gp of gamepads) {
        if (!gp || !gp.connected) continue;
        const actuator = gp.vibrationActuator || (gp.hapticActuators && gp.hapticActuators[0]);
        if (actuator) {
            if (typeof actuator.playEffect === 'function') {
                actuator.playEffect('dual-rumble', {
                    startDelay: 0,
                    duration: Math.max(10, Math.min(2000, duration)),
                    weakMagnitude: Math.max(0, Math.min(1, weakMagnitude)),
                    strongMagnitude: Math.max(0, Math.min(1, strongMagnitude))
                }).catch(() => {});
            } else if (typeof actuator.pulse === 'function') {
                actuator.pulse(Math.max(0, Math.min(1, (weakMagnitude + strongMagnitude) / 2)), duration).catch(() => {});
            }
        }
    }
}

// Camera look logic for Three.js camera
export function applyGamepadLook(camera, delta, lookX, lookY) {
    if (!camera || (Math.abs(lookX) < 1e-4 && Math.abs(lookY) < 1e-4)) return;

    _euler.setFromQuaternion(camera.quaternion);

    // Yaw: lookX > 0 (pushing right) turns view right (decreasing Euler Y)
    _euler.y -= lookX * lookSensitivity * delta;

    // Pitch: lookY > 0 (pushing down) tilts view down
    const pitchDelta = (invertY ? lookY : -lookY) * lookSensitivity * delta;
    _euler.x += pitchDelta;

    // Clamp pitch between -MAX_PITCH and +MAX_PITCH to avoid inverted camera
    _euler.x = Math.max(-MAX_PITCH, Math.min(MAX_PITCH, _euler.x));

    camera.quaternion.setFromEuler(_euler);
}

export function recenterCameraPitch(camera) {
    if (!camera) return;
    _euler.setFromQuaternion(camera.quaternion);
    _euler.x = 0;
    camera.quaternion.setFromEuler(_euler);
}

// Settings getters & setters
export function setGamepadSensitivity(val) {
    if (Number.isFinite(val) && val > 0.1 && val <= 10.0) {
        lookSensitivity = val;
    }
}
export function getGamepadSensitivity() {
    return lookSensitivity;
}

export function setGamepadInvertY(val) {
    invertY = Boolean(val);
}
export function getGamepadInvertY() {
    return invertY;
}

export function setGamepadVibrationEnabled(val) {
    vibrationEnabled = Boolean(val);
}
export function isGamepadVibrationEnabled() {
    return vibrationEnabled;
}

// Menu Navigation via Controller
function getActiveMenuView() {
    const gen = document.getElementById('menu-view-generator');
    if (gen && gen.style.display !== 'none') return gen;
    const opt = document.getElementById('menu-view-options');
    if (opt && opt.style.display !== 'none') return opt;
    return document.getElementById('menu-view-main');
}

function getFocusableElements(container) {
    if (!container) return [];
    const elements = Array.from(
        container.querySelectorAll('button:not(:disabled), input:not(:disabled), select:not(:disabled)')
    );
    return elements.filter(el => el.offsetParent !== null && !el.disabled);
}

export function clearMenuFocus() {
    if (currentFocusElement) {
        currentFocusElement.classList.remove('gamepad-focused');
        const parentLabel = currentFocusElement.closest('.menu-checkbox-label');
        if (parentLabel) parentLabel.classList.remove('gamepad-focused');
        currentFocusElement = null;
    }
}

function setMenuFocus(el, playSoundFn) {
    clearMenuFocus();
    if (!el) return;
    currentFocusElement = el;
    el.classList.add('gamepad-focused');
    const parentLabel = el.closest('.menu-checkbox-label');
    if (parentLabel) parentLabel.classList.add('gamepad-focused');
    try {
        el.focus({ preventScroll: true });
    } catch {}
    if (playSoundFn) playSoundFn('buttonselect111.wav', 0.35);
}

export function updateGamepadMenuNavigation(delta, gp, playSoundFn) {
    if (!gp) return;
    const activeView = getActiveMenuView();
    if (!activeView || activeView.style.display === 'none') {
        clearMenuFocus();
        return;
    }

    const items = getFocusableElements(activeView);
    if (items.length === 0) {
        clearMenuFocus();
        return;
    }

    let currentIndex = currentFocusElement ? items.indexOf(currentFocusElement) : -1;
    if (currentIndex === -1) {
        // Prioritize Resume button if present and enabled
        const resumeBtn = activeView.querySelector('#menu-btn-resume:not(:disabled)');
        if (resumeBtn && items.includes(resumeBtn)) {
            currentIndex = items.indexOf(resumeBtn);
        } else {
            currentIndex = 0;
        }
        setMenuFocus(items[currentIndex], null);
    }

    // Read Left Stick and D-Pad for navigation
    const stickY = gp.axes && gp.axes[1] ? gp.axes[1] : 0;
    const stickX = gp.axes && gp.axes[0] ? gp.axes[0] : 0;
    const dpadUp = isButtonPressed(gp, GP_BUTTONS.DPAD_UP);
    const dpadDown = isButtonPressed(gp, GP_BUTTONS.DPAD_DOWN);
    const dpadLeft = isButtonPressed(gp, GP_BUTTONS.DPAD_LEFT);
    const dpadRight = isButtonPressed(gp, GP_BUTTONS.DPAD_RIGHT);

    // Vertical navigation (Up / Down)
    let vertDir = 0;
    if (dpadUp || stickY < -0.45) vertDir = -1;
    else if (dpadDown || stickY > 0.45) vertDir = 1;

    if (vertDir !== 0) {
        if (menuNavLastDir !== vertDir) {
            menuNavLastDir = vertDir;
            menuNavTimer = MENU_REPEAT_DELAY;
            currentIndex = (currentIndex + vertDir + items.length) % items.length;
            setMenuFocus(items[currentIndex], playSoundFn);
        } else {
            menuNavTimer -= delta;
            if (menuNavTimer <= 0) {
                menuNavTimer = MENU_REPEAT_INTERVAL;
                currentIndex = (currentIndex + vertDir + items.length) % items.length;
                setMenuFocus(items[currentIndex], playSoundFn);
            }
        }
    } else {
        menuNavLastDir = 0;
        menuNavTimer = 0;
    }

    // Horizontal adjustment (Left / Right for sliders and checkboxes)
    let horizDir = 0;
    if (dpadLeft || stickX < -0.45) horizDir = -1;
    else if (dpadRight || stickX > 0.45) horizDir = 1;

    if (horizDir !== 0) {
        if (menuHorizLastDir !== horizDir) {
            menuHorizLastDir = horizDir;
            menuHorizTimer = MENU_REPEAT_DELAY;
            adjustFocusedItem(currentFocusElement, horizDir, playSoundFn);
        } else {
            menuHorizTimer -= delta;
            if (menuHorizTimer <= 0) {
                menuHorizTimer = MENU_REPEAT_INTERVAL;
                adjustFocusedItem(currentFocusElement, horizDir, playSoundFn);
            }
        }
    } else {
        menuHorizLastDir = 0;
        menuHorizTimer = 0;
    }

    // A Button (Select / Confirm)
    const justA = isButtonJustPressed(gp, GP_BUTTONS.A);
    if (justA && currentFocusElement) {
        triggerGamepadVibration(60, 0.3, 0.1);
        if (currentFocusElement.type === 'checkbox') {
            currentFocusElement.checked = !currentFocusElement.checked;
            currentFocusElement.dispatchEvent(new Event('change', { bubbles: true }));
            if (playSoundFn) playSoundFn('buttonselect111.wav', 0.4);
        } else if (currentFocusElement.tagName === 'BUTTON') {
            currentFocusElement.click();
        } else {
            currentFocusElement.click();
        }
    }

    // B Button (Back / Cancel / Resume)
    const justB = isButtonJustPressed(gp, GP_BUTTONS.B);
    if (justB) {
        triggerGamepadVibration(50, 0.2, 0.1);
        const backBtn = activeView.querySelector('button[id$="-back"]');
        if (backBtn) {
            backBtn.click();
        } else {
            const resumeBtn = document.getElementById('menu-btn-resume');
            if (resumeBtn && !resumeBtn.disabled) {
                resumeBtn.click();
            }
        }
    }

    // Start / Menu Button (Resume from main menu)
    const justStart = isButtonJustPressed(gp, GP_BUTTONS.START);
    if (justStart) {
        const resumeBtn = document.getElementById('menu-btn-resume');
        if (resumeBtn && !resumeBtn.disabled) {
            triggerGamepadVibration(50, 0.2, 0.1);
            resumeBtn.click();
        }
    }
}

function adjustFocusedItem(el, dir, playSoundFn) {
    if (!el) return;
    if (el.type === 'range') {
        const min = parseFloat(el.min) || 0;
        const max = parseFloat(el.max) || 100;
        const step = parseFloat(el.step) || 1;
        let val = parseFloat(el.value) || 0;
        val = Math.max(min, Math.min(max, val + dir * step));
        // Avoid precision floating artifacts
        const decimals = (el.step && el.step.includes('.')) ? el.step.split('.')[1].length : 0;
        el.value = decimals > 0 ? val.toFixed(decimals) : String(Math.round(val));
        el.dispatchEvent(new Event('input', { bubbles: true }));
        el.dispatchEvent(new Event('change', { bubbles: true }));
        if (playSoundFn) playSoundFn('buttonselect111.wav', 0.25);
    } else if (el.type === 'checkbox') {
        el.checked = !el.checked;
        el.dispatchEvent(new Event('change', { bubbles: true }));
        if (playSoundFn) playSoundFn('buttonselect111.wav', 0.35);
    }
}

function isButtonJustPressed(gp, buttonIndex) {
    const isDown = isButtonPressed(gp, buttonIndex);
    const wasDown = prevButtons.get(buttonIndex) || false;
    return isDown && !wasDown;
}

// Main Gamepad update loop (called each frame)
export function pollGamepad(delta, isPaused, isFlyMode, playSoundFn) {
    const gp = getPrimaryGamepad();

    // Check for auto-switching to newly active gamepad
    const allGps = getConnectedGamepads();
    if (allGps.length > 0) {
        for (const candidate of allGps) {
            // Check if user is touching buttons or sticks on another controller
            let active = false;
            for (let i = 0; i < candidate.buttons.length; i++) {
                if (isButtonPressed(candidate, i)) { active = true; break; }
            }
            if (!active && candidate.axes) {
                for (let a = 0; a < candidate.axes.length; a++) {
                    if (Math.abs(candidate.axes[a]) > 0.35) { active = true; break; }
                }
            }
            if (active && candidate.index !== activeGamepadIndex) {
                activeGamepadIndex = candidate.index;
                const newName = formatGamepadName(candidate.id);
                if (newName !== lastActiveGamepadName) {
                    lastActiveGamepadName = newName;
                    showControllerToast(`🎮 ${newName} Active`);
                }
                updateGamepadDisplay();
                break;
            }
        }
    }

    if (gp) {
        const currentName = formatGamepadName(gp.id);
        if (currentName !== lastActiveGamepadName) {
            lastActiveGamepadName = currentName;
            updateGamepadDisplay();
            showControllerToast(`🎮 ${currentName} Connected`);
        }
    }

    if (!gp) {
        prevButtons.clear();
        updateGamepadDisplay();
        return {
            connected: false,
            moveX: 0,
            moveY: 0,
            lookX: 0,
            lookY: 0,
            hasLook: false,
            sprint: false,
            jumpJustPressed: false,
            flyUp: false,
            flyDown: false,
            attack: false,
            interact: false,
            cycleWeapon: 0,
            toggleFlyMode: false,
            toggleGodMode: false,
            toggleMusic: false,
            toggleNormalMaps: false,
            pauseToggle: false,
            recenterPitch: false
        };
    }

    // In menu / paused: delegate to menu navigation
    if (isPaused) {
        updateGamepadMenuNavigation(delta, gp, playSoundFn);
        // Record buttons for edge detection
        for (let i = 0; i < 16; i++) {
            prevButtons.set(i, isButtonPressed(gp, i));
        }
        return { connected: true, inMenu: true };
    }

    // Clear menu focus when entering gameplay
    clearMenuFocus();

    // 1. Left Stick (Movement) - Analog with 360 degree radial deadzone
    const rawLeftX = gp.axes && gp.axes[GP_AXES.LEFT_X] !== undefined ? gp.axes[GP_AXES.LEFT_X] : 0;
    const rawLeftY = gp.axes && gp.axes[GP_AXES.LEFT_Y] !== undefined ? gp.axes[GP_AXES.LEFT_Y] : 0;
    const leftStick = applyStickDeadzoneAndCurve(rawLeftX, rawLeftY, DEFAULT_DEADZONE, 1.1);

    // 2. Right Stick (Camera Look / Aim) - Non-linear response curve for precise aiming & fast spins
    const rawRightX = gp.axes && gp.axes[GP_AXES.RIGHT_X] !== undefined ? gp.axes[GP_AXES.RIGHT_X] : 0;
    const rawRightY = gp.axes && gp.axes[GP_AXES.RIGHT_Y] !== undefined ? gp.axes[GP_AXES.RIGHT_Y] : 0;
    const rightStick = applyStickDeadzoneAndCurve(rawRightX, rawRightY, 0.12, DEFAULT_LOOK_EXPONENT);

    // 3. Triggers
    const ltValue = getButtonValue(gp, GP_BUTTONS.LT);
    const rtValue = getButtonValue(gp, GP_BUTTONS.RT);

    // Sprint: Hold LT (> 0.2) or click L3 (toggle)
    const justL3 = isButtonJustPressed(gp, GP_BUTTONS.L3);
    if (justL3) {
        l3SprintToggled = !l3SprintToggled;
        triggerGamepadVibration(40, 0.2, 0.05);
    }
    // Cancel L3 sprint toggle if player stops moving
    if (l3SprintToggled && leftStick.mag < 0.05) {
        l3SprintToggled = false;
    }
    const isSprinting = ltValue > 0.25 || l3SprintToggled;

    // Jump: A button (just pressed)
    const justA = isButtonJustPressed(gp, GP_BUTTONS.A);
    if (justA && !isFlyMode) {
        triggerGamepadVibration(40, 0.2, 0.05);
    }

    // Fly Mode controls
    const flyUp = isFlyMode && (isButtonPressed(gp, GP_BUTTONS.A) || isButtonPressed(gp, GP_BUTTONS.RB));
    const flyDown = isFlyMode && (isButtonPressed(gp, GP_BUTTONS.B) || isButtonPressed(gp, GP_BUTTONS.LB) || ltValue > 0.25);

    // Primary Attack / Cast: RT (analog threshold > 0.4)
    const isRTDown = rtValue > 0.4 || isButtonPressed(gp, GP_BUTTONS.RT);
    const wasRTDown = prevButtons.get(GP_BUTTONS.RT) || false;
    const justAttack = isRTDown && !wasRTDown;

    // Interact (Open Door / Chest): X button (just pressed)
    const justInteract = isButtonJustPressed(gp, GP_BUTTONS.X);

    // Cycle Weapon: RB or D-Pad Right = Next (+1); LB or D-Pad Left = Prev (-1); Y = Next (+1)
    let cycleWeapon = 0;
    if (isButtonJustPressed(gp, GP_BUTTONS.RB) || isButtonJustPressed(gp, GP_BUTTONS.DPAD_RIGHT) || isButtonJustPressed(gp, GP_BUTTONS.Y)) {
        cycleWeapon = 1;
        triggerGamepadVibration(45, 0.25, 0.05);
    } else if (isButtonJustPressed(gp, GP_BUTTONS.LB) || isButtonJustPressed(gp, GP_BUTTONS.DPAD_LEFT)) {
        cycleWeapon = -1;
        triggerGamepadVibration(45, 0.25, 0.05);
    }

    // Toggle Fly Mode: R3 click + held LT or B in cheat mode
    const justR3 = isButtonJustPressed(gp, GP_BUTTONS.R3);

    // D-Pad Up: Toggle Music
    const justDpadUp = isButtonJustPressed(gp, GP_BUTTONS.DPAD_UP);

    // D-Pad Down: Toggle Normal Maps
    const justDpadDown = isButtonJustPressed(gp, GP_BUTTONS.DPAD_DOWN);

    // Back / View Button: God Mode toggle
    const justBack = isButtonJustPressed(gp, GP_BUTTONS.BACK);

    // Start / Menu Button: Pause
    const justStart = isButtonJustPressed(gp, GP_BUTTONS.START);

    // Record button states for next frame edge detection
    for (let i = 0; i < 16; i++) {
        prevButtons.set(i, isButtonPressed(gp, i));
    }
    prevButtons.set(GP_BUTTONS.RT, isRTDown);

    return {
        connected: true,
        inMenu: false,
        // Movement analog values (-1 to +1)
        moveX: leftStick.x,
        moveY: leftStick.y,
        moveMag: leftStick.mag,
        // Camera look analog values (-1 to +1)
        lookX: rightStick.x,
        lookY: rightStick.y,
        hasLook: rightStick.mag > 0,
        // Action triggers
        sprint: isSprinting,
        jumpJustPressed: justA,
        flyUp,
        flyDown,
        attack: justAttack,
        interact: justInteract,
        cycleWeapon,
        toggleFlyMode: false, // Handled separately or with R3
        recenterPitch: justR3,
        toggleGodMode: justBack,
        toggleMusic: justDpadUp,
        toggleNormalMaps: justDpadDown,
        pauseToggle: justStart
    };
}

// Lifecycle listeners
export function initGamepadSystem() {
    window.addEventListener('gamepadconnected', (e) => {
        const gp = e.gamepad;
        activeGamepadIndex = gp.index;
        const name = formatGamepadName(gp.id);
        lastActiveGamepadName = name;
        showControllerToast(`🎮 ${name} Connected`);
        updateGamepadDisplay();
        triggerGamepadVibration(80, 0.4, 0.2);
    });

    window.addEventListener('gamepaddisconnected', (e) => {
        const gp = e.gamepad;
        if (activeGamepadIndex === gp.index) {
            activeGamepadIndex = -1;
            lastActiveGamepadName = '';
        }
        showControllerToast(`🎮 Controller Disconnected`);
        updateGamepadDisplay();
        prevButtons.clear();
    });

    // Initial check
    setTimeout(updateGamepadDisplay, 100);
}
