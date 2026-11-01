import asyncio
import os
from pathlib import Path

from playwright.async_api import async_playwright


async def verify_emission_rates(page):
    results = await page.evaluate("""async () => {
        const THREE = await import('three');
        const logic = await import('./logic.js');
        const update = await import('./update.js');
        const render = await import('./render.js');
        const savedProjectiles = logic.activeProjectiles.splice(0);
        const savedPortals = logic.activeTeleporters.splice(0);
        const random = Math.random;
        const results = [];
        const remote = new THREE.Vector3(1000000, 1000000, 1000000);
        const resetParticles = () => {
            render.particles.lifetimes.fill(0);
            render.particles.sizes.fill(0);
            render.particles.next = render.particles.highWater = render.particles.alive = 0;
            render.updateParticles(0);
        };
        try {
            Math.random = () => 0.5;
            for (const fps of [30, 60, 144, 240]) {
                resetParticles();
                const portal = {
                    group: new THREE.Group(), position: remote.clone(),
                    timer: 0, particleTimer: 0
                };
                logic.activeTeleporters.push(portal);
                const player = remote.clone().add(new THREE.Vector3(500, 0, 0));
                for (let i = 0; i < fps; i++) update.updateTeleporters(1 / fps, player);
                const portalCount = render.particles.alive;
                logic.activeTeleporters.length = 0;
                update.updateTeleporters(1, player);

                for (const owner of ['player', 'monster']) {
                    resetParticles();
                    if (owner === 'player') logic.launchProjectile('FIREBALL');
                    else logic.launchMonsterProjectile(
                        { position: remote, config: { damage: 10 } }, 'FIREBALL', player
                    );
                    const projectile = logic.activeProjectiles[0];
                    projectile.position.copy(remote);
                    projectile.velocity.set(0, 0, 0);
                    projectile.gravity = 0;
                    projectile.maxLife = 10;
                    for (let i = 0; i < fps; i++) update.updateProjectiles(1 / fps);
                    results.push({ fps, owner, portalCount, trailCount: render.particles.alive });
                    update.removeProjectile(0);
                }

                resetParticles();
                const anim = { start: 0, end: 100, fps: 1, loop: false };
                const caster = Object.assign(Object.create(logic.Monster.prototype), {
                    position: remote.clone(), velocity: new THREE.Vector3(),
                    mesh: new THREE.Group(), isGrounded: true, state: 'ATTACK',
                    stateTimer: 0, attackCooldown: 0, hasDealtDamageThisAttack: false,
                    particleTimer: 0, losTimer: 1000, hasLOS: true,
                    currentAnim: anim, animTimer: 0, animComplete: false,
                    isMeleeAttack: false, pendingSpell: 'FIREBALL',
                    config: { canCastSpells: true, attackRange: 1000, animations: { ATTACK: anim } },
                    tickAmbientNoise() {}, smoothTurn() {},
                    updateMorphTargets() {}, updateBoundingBox() {}
                });
                for (let i = 0; i < fps; i++) caster.update(1 / fps, player, []);
                results.push({ fps, casterCount: render.particles.alive });
            }
            resetParticles();
            const distantPortal = {
                group: new THREE.Group(), position: remote.clone(), timer: 0, particleTimer: 0
            };
            logic.activeTeleporters.push(distantPortal);
            update.updateTeleporters(0.1, new THREE.Vector3());
            if (render.particles.alive !== 0 || distantPortal.particleTimer !== 0) {
                throw new Error('Distant portals must not accumulate particle work');
            }
        } finally {
            Math.random = random;
            while (logic.activeProjectiles.length) update.removeProjectile(0);
            logic.activeProjectiles.push(...savedProjectiles);
            logic.activeTeleporters.splice(0, logic.activeTeleporters.length, ...savedPortals);
            resetParticles();
        }
        return results;
    }""")
    for result in results:
        if "casterCount" in result:
            assert abs(result["casterCount"] - 180) <= 3, result
        else:
            assert abs(result["portalCount"] - 180) <= 3, result
            assert abs(result["trailCount"] - 240) <= 4, result
    print("Particle emission stable at 30, 60, 144, and 240 FPS:", results)


async def verify_hidden_tab(page):
    result = await page.evaluate("""async () => {
        const render = await import('./render.js');
        const originalRender = render.renderer.render;
        const originalHidden = Object.getOwnPropertyDescriptor(document, 'hidden');
        const position = window.controls.getObject().position.clone();
        let draws = 0;
        render.renderer.render = () => { draws++; };
        Object.defineProperty(document, 'hidden', { configurable: true, get: () => true });
        try {
            document.dispatchEvent(new Event('visibilitychange'));
            await new Promise(resolve => setTimeout(resolve, 250));
            return { draws, moved: !position.equals(window.controls.getObject().position) };
        } finally {
            if (originalHidden) Object.defineProperty(document, 'hidden', originalHidden);
            else delete document.hidden;
            document.dispatchEvent(new Event('visibilitychange'));
            render.renderer.render = originalRender;
        }
    }""")
    assert result == {"draws": 0, "moved": False}, result
    print("Hidden tab performs no rendering or movement (including ?run=1).")


async def verify_world_cleanup(page):
    result = await page.evaluate("""async () => {
        const logic = await import('./logic.js');
        const materials = new Set(window.monsters.map(m => m.hpSprite.material));
        const geometry = window.monsters[0].mesh.geometry;
        let materialDisposals = 0, textureDisposals = 0, geometryDisposals = 0;
        for (const material of materials) {
            material.addEventListener('dispose', () => materialDisposals++);
            material.map.addEventListener('dispose', () => textureDisposals++);
        }
        geometry.addEventListener('dispose', () => geometryDisposals++);
        logic.clearCurrentWorld();
        return {
            expected: materials.size, materialDisposals, textureDisposals,
            geometryDisposals, monsters: window.monsters.length
        };
    }""")
    assert result["expected"] > 0, result
    assert result["materialDisposals"] == result["expected"], result
    assert result["textureDisposals"] == result["expected"], result
    assert result["geometryDisposals"] == 0, result
    assert result["monsters"] == 0, result
    print("Health bars released exactly once; shared model geometry retained:", result)
    await page.evaluate("""async () => {
        await window.generateAndLoadNewLevel(false, { numRooms: 4, numObjectsToPlace: 100, seed: 42 });
        if (!window.monsters.length) throw new Error('Generated world has no monsters');
        if (!window.monsters.every(m => m.hpSprite.material.map)) {
            throw new Error('Health bars did not rebuild');
        }
        window.saveCurrentRun();
        const logic = await import('./logic.js');
        const snapshot = logic.captureWorldState();
        if (!logic.isWorldStateValid(snapshot)) throw new Error('Invalid world snapshot');
        await logic.restoreWorldState(snapshot);
    }""")
    print("Dungeon regeneration and world snapshot restore passed.")


async def run():
    async with async_playwright() as p:
        launch_options = {
            "headless": True,
            "args": ["--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
        }
        if os.environ.get("CHROMIUM_EXECUTABLE"):
            launch_options["executable_path"] = os.environ["CHROMIUM_EXECUTABLE"]
        browser = await p.chromium.launch(**launch_options)
        try:
            page = await browser.new_page()
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            # Optional local copy of the pinned Three.js package for offline verification.
            if os.environ.get("THREE_TEST_DIR"):
                root = Path(os.environ["THREE_TEST_DIR"]).resolve()

                async def serve_three(route):
                    path = (root / route.request.url.split("three@0.160.0/")[1]).resolve()
                    assert path.is_relative_to(root)
                    await route.fulfill(path=str(path), content_type="application/javascript")

                await page.route("https://unpkg.com/three@0.160.0/**", serve_three)
            await page.goto(os.environ.get("GAME_URL", "http://localhost:8000/?run=1"))
            await page.wait_for_function(
                "() => window.monsters && window.monsters.length > 0", timeout=120000
            )
            await verify_emission_rates(page)
            await verify_hidden_tab(page)
            await verify_world_cleanup(page)
            assert not errors, errors
            print("Performance regression verification PASSED.")
        finally:
            await browser.close()


if __name__ == "__main__":
    asyncio.run(run())
