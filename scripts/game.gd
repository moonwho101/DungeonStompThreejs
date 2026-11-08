# Main game controller: world building, player, combat, items, saving and the frame loop
# (port of app.js, logic.js and update.js).
class_name Game
extends Node3D

const PLAYER_GUNS := ["AXE", "FLAMESWORD", "BASTARDSWORD", "BATTLEAXE", "ICESWORD", "LIGHTNINGSWORD",
	"MORNINGSTAR", "SPIKEDFLAIL", "SPLITSWORD", "SUPERFLAMESWORD", "MAGIC MISSILE", "FIREBALL", "LIGHTNING", "HEALING"]
const SPELL_NAMES := ["MAGIC MISSILE", "FIREBALL", "LIGHTNING", "HEALING"]
const DEFAULT_WEAPONS := ["AXE", "MAGIC MISSILE", "FIREBALL", "LIGHTNING", "HEALING"]
const WEAPON_DAMAGE := {
	"AXE": 5, "FLAMESWORD": 5, "BASTARDSWORD": 8, "BATTLEAXE": 10, "ICESWORD": 12, "LIGHTNINGSWORD": 14,
	"MORNINGSTAR": 16, "SPIKEDFLAIL": 18, "SPLITSWORD": 19, "SUPERFLAMESWORD": 20,
	"MAGIC MISSILE": 5, "FIREBALL": 10, "LIGHTNING": 15, "HEALING": 0,
}
const TREASURE_DROPS := ["POTION", "cheese1", "GOBLET", "pot1", "pot2", "pot3", "mushroom", "COIN", "SPELLBOOK",
	"SCROLL-HEALING-", "SCROLL-MAGICMISSLE-", "SCROLL-FIREBALL-", "SCROLL-LIGHTNING-"]
const PICKUP_KEYS := ["POTION", "CHEESE1", "POT1", "POT2", "POT3", "MUSHROOM", "GOBLET", "ARMOUR", "COIN", "SPELLBOOK",
	"SCROLL-HEALING-", "SCROLL-MAGICMISSLE-", "SCROLL-FIREBALL-", "SCROLL-LIGHTNING-"]
const PICKUP_DEFINITIONS := {
	"POTION": {"type": "health", "amount": 10, "label": "+10 HP"},
	"CHEESE1": {"type": "health", "amount": 15, "label": "+15 HP"},
	"POT1": {"type": "health", "amount": 10, "label": "+10 HP"},
	"POT2": {"type": "health", "amount": 15, "label": "+15 HP"},
	"POT3": {"type": "health", "amount": 20, "label": "+20 HP"},
	"MUSHROOM": {"type": "health", "amount": "full", "label": "FULL HP"},
	"GOBLET": {"type": "xp", "amount": 50, "label": "+50 XP"},
	"ARMOUR": {"type": "xp", "amount": 10, "label": "+10 XP"},
	"COIN": {"type": "xp", "amount": 10, "label": "+10 XP"},
	"SPELLBOOK": {"type": "xp", "amount": 50, "label": "+50 XP"},
	"SCROLL-HEALING-": {"type": "xp", "amount": 10, "label": "+10 XP"},
	"SCROLL-MAGICMISSLE-": {"type": "xp", "amount": 20, "label": "+20 XP"},
	"SCROLL-FIREBALL-": {"type": "xp", "amount": 30, "label": "+30 XP"},
	"SCROLL-LIGHTNING-": {"type": "xp", "amount": 40, "label": "+40 XP"},
}
const OPENABLE_CONTAINERS := {"cdoorclosedchest": "cdooropenchest", "cdoorclosedbarrel": "cdooropenbarrel"}
const PROJECTILE_TYPES := {
	"MAGIC MISSILE": {"speed": 1300.0, "gravity": 0.0, "radius": 20.0, "aoeRadius": 80.0, "maxLife": 4.0,
		"coreRadius": 7.0, "coreColor": 0x38bdf8, "coreOpacity": 0.9, "haloColor": 0x00e5ff, "haloOpacity": 0.8, "haloSize": 70.0,
		"lightColor": 0x00e5ff, "lightIntensity": 6000.0, "lightDistance": 350.0, "colorHex": 0x38bdf8},
	"FIREBALL": {"speed": 1050.0, "gravity": -200.0, "radius": 26.0, "aoeRadius": 180.0, "maxLife": 4.5,
		"coreRadius": 7.0, "coreColor": 0xff4500, "coreOpacity": 0.95, "haloColor": 0xffaa00, "haloOpacity": 0.9, "haloSize": 110.0,
		"lightColor": 0xff6600, "lightIntensity": 9000.0, "lightDistance": 450.0, "colorHex": 0xff5500},
	"LIGHTNING": {"speed": 1600.0, "gravity": 0.0, "radius": 22.0, "aoeRadius": 120.0, "maxLife": 3.5,
		"coreRadius": 7.0, "coreColor": 0xffffff, "coreOpacity": 0.95, "haloColor": 0x00ffff, "haloOpacity": 0.9, "haloSize": 90.0,
		"lightColor": 0x00ffff, "lightIntensity": 8000.0, "lightDistance": 400.0, "colorHex": 0x00ffff},
}
const SWISH_SOUNDS := ["swish1.wav", "swish4.wav", "swish5.wav", "swish7.wav", "swish8.wav", "swish9.wav", "swing_02.wav"]
const IMPACT_SOUNDS := ["impact.wav", "impact2.wav", "impact3.wav", "impact4.wav", "impact5.wav", "impact6.wav",
	"impact7.wav", "impact8.wav", "impact10.wav"]
const PLAYER_IMPACT_SOUNDS := ["pimpact.wav", "ouch.wav", "pain1.wav"]
const EXCLUDED_IDS := [6, 35, 131, 120]
const EXCLUDED_NAMES := ["lamp_post", "!monster1", "startpos", "text"]
const STATIC_CHUNK_SIZE := 1024.0
const RENDER_DISTANCE := 3000.0
const PLAYER_RESPAWN_DELAY := 3.0
const PICKUP_DISTANCE := 70.0
const MOUSE_SENSITIVITY := 0.002
const AUTOSAVE_INTERVAL := 5.0

const SAVE_KEY := "dungeonRunState"
const GEN_OPTS_KEY := "dungeonGenerationOptions"
const GAME_OPTS_KEY := "dungeonGameOptions"
const MAP_KEY := "generatedLevel1Map"

# Subsystems
var collision := CollisionWorld.new()
var fx: Effects
var audio: AudioManager
var ui: GameUI
var gamepad: GamepadInput
var world_root: Node3D
var camera: Camera3D
var environment: Environment

var texture_manager := Parsers.TextureManager.new()
var objects_parser := Parsers.ObjectsDatParser.new()
var model_list := Parsers.ModelListParser.new()
var _data_loaded := false

# World state
var monsters: Array = []
var doors: Array = []
var chests: Array = []
var level_objects: Array = []
var active_pickups: Array = []
var active_projectiles: Array = []
var active_teleporters: Array = []
var level_pickup_count := 0
var level_loading := false
var level_load_in_flight := false
var current_map_text := ""
var current_map_key := "bundled"
var built_object_count := 0
var light_count := 0

# Player state
var velocity := Vector3.ZERO
var is_grounded := false
var jump_requested := false
var fly_mode := false
var footstep_timer := 0.0
var player_stats := {"health": 100.0, "maxHealth": 100, "level": 1, "xp": 0, "nextXp": 500, "kills": 0}
var player_dead := false
var player_death_timer := 0.0
var player_start_pos := Vector3.ZERO
var is_invincible := false
var unlocked_weapons: Array = DEFAULT_WEAPONS.duplicate()
var spell_counts := {"MAGIC MISSILE": 5, "FIREBALL": 5, "LIGHTNING": 5, "HEALING": 5}
var current_gun_index := 0
var dungeon_depth := 1
var gen_options := {"numObjectsToPlace": 225, "seed": null}
var normal_maps_enabled := true

# Player weapon view model
var gun_mesh: MeshInstance3D = null
var gun_model: MD2Model = null
var weapon_anim: Dictionary = Monster.ANIMS.STAND
var weapon_anim_timer := 0.0
var is_weapon_attacking := false
var has_weapon_hit := false

# Input / session
var move_forward := false
var move_backward := false
var move_left := false
var move_right := false
var move_up := false
var move_down := false
var is_sprinting := false
var game_started := false
var world_ready := false
var playing := false
var teleporter_cooldown := 0.0
var _autosave_timer := 0.0
var _pos_display_timer := 0.0
var _time := 0.0
var _auto_start := false
var _shot_path := ""
var _shot_delay := 0.0
var _shot_frames := 0
# Debug/verification options (see _parse_cmdline)
var _debug_pos := Vector3.ZERO
var _has_debug_pos := false
var _debug_rot := Vector2.ZERO
var _debug_calm := false


func _ready() -> void:
	_parse_cmdline()
	_setup_scene()
	Materials.texture_manager = texture_manager
	ui.show_menu_view("main")
	ui.show_menu(true)
	ui.show_loading(true)
	call_deferred("_init_game")


func _parse_cmdline() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--autostart":
			_auto_start = true
		elif arg.begins_with("--screenshot="):
			_shot_path = arg.substr(13)
		elif arg.begins_with("--screenshot-delay="):
			_shot_delay = arg.substr(19).to_float()
		elif arg.begins_with("--pos="):
			var v := arg.substr(6).split_floats(",")
			if v.size() == 3:
				_debug_pos = Vector3(v[0], v[1], v[2])
				_has_debug_pos = true
		elif arg.begins_with("--rot="):
			var r := arg.substr(6).split_floats(",")
			if r.size() == 2:
				_debug_rot = Vector2(deg_to_rad(r[0]), deg_to_rad(r[1]))
		elif arg == "--calm":
			_debug_calm = true


func _setup_scene() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color8(0x08, 0x08, 0x0e)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color8(0x7a, 0x82, 0xa8)
	environment.ambient_light_energy = 0.9 / PI
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color8(0x08, 0x08, 0x0e)
	environment.fog_light_energy = 1.0
	environment.fog_sun_scatter = 0.0
	environment.fog_density = 1.0
	environment.fog_sky_affect = 0.0
	environment.fog_depth_begin = 1200.0
	environment.fog_depth_end = 3400.0
	environment.fog_depth_curve = 1.0
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color8(0xaa, 0xb6, 0xff)
	sun.light_energy = 0.9 / PI
	sun.light_specular = 0.0
	add_child(sun)
	sun.look_at_from_position(Vector3(2500, 6000, 1500), Vector3.ZERO, Vector3.UP)

	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.fov = 75.0
	camera.near = 1.0
	camera.far = 3600.0
	camera.rotation_order = EULER_ORDER_YXZ
	add_child(camera)
	camera.current = true

	fx = Effects.new()
	fx.name = "Effects"
	add_child(fx)
	audio = AudioManager.new()
	audio.name = "Audio"
	add_child(audio)
	ui = GameUI.new()
	ui.name = "UI"
	ui.game = self
	add_child(ui)
	gamepad = GamepadInput.new()
	gamepad.game = self
	add_child(gamepad)


func _exit_tree() -> void:
	clear_current_world()
	TDSModel.clear_cache()
	MD2Model.clear_cache()
	Materials.clear_caches()
	Monster.clear_shared()


func player_position() -> Vector3:
	return camera.position


func vibrate(duration_ms: float, weak: float, strong: float) -> void:
	gamepad.vibrate(duration_ms, weak, strong)


# ---------------------------------------------------------------- Storage (localStorage replacement)

static func _storage_path(key: String) -> String:
	return "user://%s.json" % key


func storage_get(key: String) -> Variant:
	var f := FileAccess.open(_storage_path(key), FileAccess.READ)
	if f == null:
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed


func storage_set(key: String, value: Variant) -> void:
	var f := FileAccess.open(_storage_path(key), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(value))

# ---------------------------------------------------------------- Startup and session flow

func _init_game() -> void:
	# Show the loading overlay before the (synchronous) level build starts.
	await get_tree().process_frame
	await get_tree().process_frame

	var saved_gen = storage_get(GEN_OPTS_KEY)
	if saved_gen is Dictionary:
		set_generation_options(saved_gen)
	var saved_opts = storage_get(GAME_OPTS_KEY)
	if saved_opts is Dictionary:
		if saved_opts.get("normalMaps") is bool:
			set_normal_maps_enabled(saved_opts.normalMaps)
		if saved_opts.get("music") is bool and saved_opts.music != audio.is_music_on():
			audio.toggle_music()
		if saved_opts.get("controllerVibration") is bool:
			gamepad.vibration_enabled = saved_opts.controllerVibration
		if saved_opts.get("controllerInvertY") is bool:
			gamepad.invert_y = saved_opts.controllerInvertY
		if saved_opts.get("controllerSens") is float or saved_opts.get("controllerSens") is int:
			gamepad.set_sensitivity(float(saved_opts.controllerSens))
	set_normal_maps_enabled(normal_maps_enabled)
	ui.sync_options()

	var saved_run = storage_get(SAVE_KEY)
	var has_save: bool = saved_run is Dictionary and int(saved_run.get("version", 0)) == 1
	if has_save:
		ui.set_resume_enabled(true)
		ui.set_prompt("Saved run at Depth %d (Hero LVL %d). Loading..." % [int(saved_run.get("depth", 1)),
			int(saved_run.get("playerStats", {}).get("level", 1))])
		if saved_run.get("depth") is float:
			set_dungeon_depth(int(saved_run.depth))
		if saved_run.get("dungeonGenerationOptions") is Dictionary:
			set_generation_options(saved_run.dungeonGenerationOptions)
	else:
		ui.set_resume_enabled(false)
		ui.set_prompt("Loading dungeon...")

	load_game_world()

	if has_save:
		_restore_saved_run(saved_run)
		ui.set_resume_enabled(true)
		ui.set_prompt("Ready! Saved run at Depth %d (Hero LVL %d). Click Resume to continue:" % [dungeon_depth, player_stats.level])
	else:
		ui.set_resume_enabled(false)
		ui.set_prompt("Welcome! Choose New Game to enter the dungeon:")

	update_weapon_mesh()
	world_ready = true
	ui.show_loading(false)

	var sounds: Array = SWISH_SOUNDS + IMPACT_SOUNDS + PLAYER_IMPACT_SOUNDS + ["spell1.wav", "spell2.wav", "spell3.wav",
		"fireball.wav", "explod1.wav", "explod2.wav", "walk.wav", "die.wav", "death1.wav", "death2.wav", "death3.wav", "death4.wav"]
	for m: Monster in monsters:
		for k in ["painSound", "deathSound", "weaponSound", "yellSound", "sound"]:
			if m.config.get(k, "") != "":
				sounds.append(m.config[k])
	audio.preload_sounds(sounds)
	if _debug_calm:
		for m: Monster in monsters:
			m.config.aggroRadius = 0.0
	if _has_debug_pos:
		camera.position = _debug_pos
		camera.rotation = Vector3(_debug_rot.y, _debug_rot.x, 0)
	if _auto_start:
		start_game_session()


func _restore_saved_run(saved: Dictionary) -> void:
	var ps = saved.get("playerStats")
	if ps is Dictionary:
		for k in ps:
			if (ps[k] is float or ps[k] is int) and player_stats.has(k):
				player_stats[k] = ps[k]
	if saved.get("unlockedWeapons") is Array:
		unlocked_weapons.clear()
		for w in saved.unlockedWeapons:
			if w in PLAYER_GUNS and not (w in unlocked_weapons):
				unlocked_weapons.append(w)
	if saved.get("spellCounts") is Dictionary:
		for s in spell_counts:
			var v = saved.spellCounts.get(s)
			if v is float or v is int:
				spell_counts[s] = maxi(0, int(v))
	if saved.get("currentGunIndex") is float or saved.get("currentGunIndex") is int:
		current_gun_index = clampi(int(saved.currentGunIndex), 0, PLAYER_GUNS.size() - 1)
	if is_world_state_valid(saved.get("world")):
		restore_world_state(saved.world)
		var p = saved.get("position")
		if p is Dictionary:
			camera.position = Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
		if saved.get("yaw") is float:
			camera.rotation.y = saved.yaw
		if saved.get("pitch") is float:
			camera.rotation.x = saved.pitch
	else:
		push_warning("Saved world does not match the loaded dungeon; starting at its entrance.")
	player_stats.health = clampf(float(player_stats.health), 0.0, float(player_stats.maxHealth))
	player_dead = false
	if player_stats.health <= 0.0:
		respawn_player()
	else:
		update_player_hud()


func is_paused() -> bool:
	return not game_started or not playing or ui.is_menu_visible()


# Enters gameplay: captures the mouse and hides the menu (startGameSession).
func start_game_session() -> void:
	playing = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ui.show_menu(false)
	ui.show_loading(not world_ready)
	audio.set_paused(false)
	if not game_started and audio.is_music_on():
		audio.start_next_music_track()
	game_started = true


# Leaves gameplay and shows the pause menu (the pointer-lock 'unlock' handler).
func pause_game_session() -> void:
	playing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_menu(true)
	ui.show_loading(false)
	ui.show_menu_view("main")
	ui.set_prompt("Paused - Resume or choose an option:")
	ui.set_resume_enabled(true)
	save_current_run()
	release_inputs()
	audio.set_paused(true)


func release_inputs() -> void:
	move_forward = false
	move_backward = false
	move_left = false
	move_right = false
	move_up = false
	move_down = false
	is_sprinting = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if game_started:
			save_current_run()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_inputs()
		if playing and world_ready:
			pause_game_session()


func new_game() -> void:
	ui.set_status("Forging new dungeon...")
	await get_tree().process_frame
	player_stats = {"health": 100.0, "maxHealth": 100, "level": 1, "xp": 0, "nextXp": 500, "kills": 0}
	unlocked_weapons = DEFAULT_WEAPONS.duplicate()
	for s in spell_counts:
		spell_counts[s] = 5
	current_gun_index = 0
	set_dungeon_depth(1)
	is_invincible = false
	player_dead = false
	toggle_fly_mode(false)
	generate_and_load_new_level(false)
	update_player_hud()
	update_weapon_mesh()
	game_started = true
	save_current_run()
	ui.set_resume_enabled(true)
	ui.set_status("")
	start_game_session()


func generate_from_menu(size: int, seed_text: String) -> void:
	var options := {"numObjectsToPlace": size, "seed": seed_text if seed_text != "" else null}
	set_generation_options(options)
	storage_set(GEN_OPTS_KEY, options)
	ui.set_status("Generating dungeon (Depth %d)..." % dungeon_depth)
	await get_tree().process_frame
	generate_and_load_new_level(false, options)
	game_started = true
	save_current_run()
	ui.set_resume_enabled(true)
	ui.set_status("")
	ui.show_menu_view("main")
	start_game_session()


func set_generation_options(opts: Dictionary) -> void:
	var n = opts.get("numObjectsToPlace")
	if n is float or n is int:
		gen_options.numObjectsToPlace = clampi(int(n), 100, 600)
	if opts.has("seed"):
		var s = opts.seed
		gen_options.seed = null if (s == null or str(s) == "") else str(s)


func set_dungeon_depth(depth: int) -> void:
	dungeon_depth = maxi(1, depth)
	ui.set_info("depth", str(dungeon_depth))


func set_normal_maps_enabled(enabled: bool) -> void:
	normal_maps_enabled = enabled
	Materials.set_normal_maps_enabled(enabled)
	ui.set_toggle_info("normalmap", enabled)


func saved_game_options() -> Dictionary:
	return {
		"normalMaps": normal_maps_enabled,
		"music": audio.is_music_on(),
		"controllerVibration": gamepad.vibration_enabled,
		"controllerInvertY": gamepad.invert_y,
		"controllerSens": gamepad.sensitivity,
	}


func save_game_options() -> void:
	storage_set(GAME_OPTS_KEY, saved_game_options())


func toggle_music_from_input() -> void:
	var enabled := audio.toggle_music()
	ui.sync_options()
	save_game_options()
	ui.set_toggle_info("music", enabled)
	fx.create_floating_text("MUSIC: ON" if enabled else "MUSIC: OFF", camera.position, "#22c55e" if enabled else "#ef4444")
	if enabled:
		audio.start_next_music_track()
	audio.play_sound("buttonselect111.wav", 0.5)


func toggle_normal_maps_from_input() -> void:
	set_normal_maps_enabled(not normal_maps_enabled)
	ui.sync_options()
	save_game_options()
	fx.create_floating_text("NORMAL MAPS: ON" if normal_maps_enabled else "NORMAL MAPS: OFF", camera.position,
		"#22c55e" if normal_maps_enabled else "#ef4444")
	audio.play_sound("buttonselect111.wav", 0.5)


func toggle_god_mode() -> void:
	is_invincible = not is_invincible
	fx.create_floating_text("GOD MODE: ON (INVINCIBLE)" if is_invincible else "GOD MODE: OFF", camera.position,
		"#22c55e" if is_invincible else "#ef4444")
	audio.play_sound("treasure.wav", 0.8)


func unlock_all() -> void:
	for g in PLAYER_GUNS:
		if not (g in unlocked_weapons):
			unlocked_weapons.append(g)
	for s in spell_counts:
		spell_counts[s] = maxi(99, spell_counts[s] + 50)
	update_player_hud()
	fx.create_floating_text("ALL WEAPONS & SPELLS UNLOCKED", camera.position, "#facc15")
	audio.play_sound("treasure.wav", 0.8)


func toggle_fly_mode(force = null) -> void:
	fly_mode = (not fly_mode) if force == null else bool(force)
	velocity = Vector3.ZERO
	ui.set_mode_display(fly_mode)


# ---------------------------------------------------------------- Saving

static func hash_string(text: String) -> String:
	var h := 2166136261
	for i in text.length():
		h = DungeonGenerator.imul(h ^ (text.unicode_at(i) & 0xFFFF), 16777619)
	return _to_base36(h & 0xFFFFFFFF) + ":" + str(text.length())


static func _to_base36(v: int) -> String:
	if v == 0:
		return "0"
	var digits := "0123456789abcdefghijklmnopqrstuvwxyz"
	var s := ""
	while v > 0:
		s = digits[v % 36] + s
		v /= 36
	return s


func save_current_run() -> void:
	# Never save before the saved world has been restored or while a level is being built.
	if not world_ready or level_loading or level_load_in_flight:
		return
	var pos := camera.position
	if not (is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z)):
		return
	var state := {
		"version": 1,
		"mapSource": "generated" if current_map_text != "" else "bundled",
		"position": {"x": pos.x, "y": pos.y, "z": pos.z},
		"yaw": camera.rotation.y,
		"pitch": camera.rotation.x,
		"depth": dungeon_depth,
		"playerStats": {
			"health": maxf(1.0, float(player_stats.health)),
			"maxHealth": player_stats.maxHealth,
			"level": player_stats.level,
			"xp": player_stats.xp,
			"nextXp": player_stats.nextXp,
			"kills": player_stats.kills,
		},
		"unlockedWeapons": unlocked_weapons.duplicate(),
		"spellCounts": spell_counts.duplicate(),
		"currentGunIndex": current_gun_index,
		"dungeonGenerationOptions": gen_options.duplicate(),
		"normalMaps": normal_maps_enabled,
		"music": audio.is_music_on(),
		"world": capture_world_state(),
		"timestamp": Time.get_unix_time_from_system(),
	}
	storage_set(SAVE_KEY, state)


static func _round_coord(v: float) -> float:
	return roundf(v * 10.0) / 10.0


# Snapshot of everything in the level the player can change, so a resumed run keeps the same
# dead monsters, collected items, open doors and opened chests.
func capture_world_state() -> Dictionary:
	var m: Array = []
	for mon: Monster in monsters:
		m.append({"x": _round_coord(mon.position.x), "y": _round_coord(mon.position.y), "z": _round_coord(mon.position.z),
			"r": roundf(mon.rotation_y * 1000.0) / 1000.0, "hp": mon.health, "d": 1 if mon.dead else 0})
	var p: Array = []
	var dr: Array = []
	for pk: Dictionary in active_pickups:
		if pk.state != "ACTIVE":
			continue
		if pk.level_index >= 0:
			p.append(pk.level_index)
		else:
			dr.append({"n": pk.name, "x": _round_coord(pk.position.x), "y": _round_coord(pk.position.y), "z": _round_coord(pk.position.z)})
	var d: Array = []
	for door: Dictionary in doors:
		d.append(1 if (door.is_open or door.is_opening) else 0)
	var c: Array = []
	for chest: Dictionary in chests:
		c.append(1 if chest.is_open else 0)
	return {"v": 1, "k": current_map_key, "mc": monsters.size(), "dc": doors.size(), "cc": chests.size(),
		"pc": level_pickup_count, "m": m, "p": p, "dr": dr, "d": d, "c": c}


func is_world_state_valid(snap) -> bool:
	return snap is Dictionary and int(snap.get("v", 0)) == 1 and str(snap.get("k", "")) == current_map_key \
		and int(snap.get("mc", -1)) == monsters.size() and int(snap.get("dc", -1)) == doors.size() \
		and int(snap.get("cc", -1)) == chests.size() and int(snap.get("pc", -1)) == level_pickup_count


func restore_world_state(snap: Dictionary) -> bool:
	if not is_world_state_valid(snap):
		return false
	var ms: Array = snap.m
	for i in ms.size():
		monsters[i].restore_snapshot(ms[i])
	var remaining := {}
	for idx in snap.p:
		remaining[int(idx)] = true
	for i in range(active_pickups.size() - 1, -1, -1):
		var pk: Dictionary = active_pickups[i]
		if pk.level_index >= 0 and not remaining.has(pk.level_index):
			_remove_pickup(i)
	var ds: Array = snap.d
	for i in ds.size():
		if int(ds[i]) == 1:
			_open_door_instantly(doors[i])
	var cs: Array = snap.c
	for i in cs.size():
		if int(cs[i]) == 1:
			open_chest(chests[i], true)
	for drop: Dictionary in snap.dr:
		drop_treasure(Vector3(drop.x, drop.y, drop.z), true, str(drop.n), true)
	return true

# ---------------------------------------------------------------- World building

func _ensure_data_loaded() -> void:
	if _data_loaded:
		return
	texture_manager.load_textures_dat("bin/textures.dat")
	objects_parser.parse("bin/Objects.dat")
	model_list.parse("bin/modellist.dat")
	_data_loaded = true


func add_level_object(node: Node3D, pos: Vector3, radius: float = 0.0, follow: Monster = null) -> Dictionary:
	var entry := {"node": node, "position": pos, "radius": radius, "follow": follow}
	level_objects.append(entry)
	return entry


func remove_level_object(node: Node3D) -> void:
	for i in level_objects.size():
		if level_objects[i].node == node:
			level_objects.remove_at(i)
			return


func clear_current_world() -> void:
	for m: Monster in monsters:
		m.free_nodes()
	monsters.clear()
	for proj: Dictionary in active_projectiles:
		fx.release_dynamic_light(proj.light_slot)
	active_projectiles.clear()
	for tp: Dictionary in active_teleporters:
		fx.release_dynamic_light(tp.light_slot)
	active_teleporters.clear()
	for child in world_root.get_children():
		world_root.remove_child(child)
		child.queue_free()
	level_objects.clear()
	active_pickups.clear()
	doors.clear()
	chests.clear()
	fx.clear_lamps()
	fx.clear_blood()
	collision.clear()


func load_game_world(override_map_text: String = "") -> void:
	level_loading = true
	level_pickup_count = 0
	_build_game_world(override_map_text)
	level_loading = false


func _build_game_world(override_map_text: String) -> void:
	var t0 := Time.get_ticks_msec()
	clear_current_world()

	var map_text := override_map_text
	if map_text == "":
		# A saved run resumes on the dungeon it was saved in; the bundled bin/level1.map is used when
		# there is no saved run (or the run was played on it); a run whose map is missing gets a new dungeon.
		var saved_run = storage_get(SAVE_KEY)
		var saved_map = storage_get(MAP_KEY)
		if saved_run is Dictionary and saved_run.get("mapSource") == "bundled":
			map_text = ""
		elif saved_map is String and saved_map != "":
			map_text = saved_map
		elif saved_run is Dictionary:
			map_text = DungeonGenerator.generate(gen_options)
			storage_set(MAP_KEY, map_text)

	current_map_text = map_text
	current_map_key = hash_string(map_text) if map_text != "" else "bundled"

	_ensure_data_loaded()
	var level := Parsers.LevelMapParser.new()
	if map_text != "":
		level.parse_text(map_text)
	else:
		level.parse_file("bin/level1.map")
	var instances: Array = level.instances
	print("Loaded %d objects in level map. StartPos: %s" % [instances.size(), str(level.start_pos)])

	player_start_pos = level.start_pos
	camera.position = player_start_pos
	camera.rotation = Vector3(0, deg_to_rad(level.start_rot), 0)

	var object_id_by_name := {}
	for id in objects_parser.objects:
		var od: Parsers.ObjectDef = objects_parser.objects[id]
		var nm := od.name.to_lower().strip_edges()
		if nm != "" and not object_id_by_name.has(nm):
			object_id_by_name[nm] = id

	var static_chunks := {} # chunk key -> {tex alias -> [positions, normals, uvs]}
	var door_builds: Array = [] # [door dict, PackedVector3Array world triangle corners]
	built_object_count = 0
	light_count = 0

	for inst: Parsers.MapInstance in instances:
		if inst.is_start_pos:
			continue
		if inst.light != null or inst.is_light:
			light_count += 1
			var src := inst.light
			if src == null:
				src = Parsers.LightSource.new()
				src.pos = Vector3(inst.x, inst.y, inst.z)
				src.color = Vector3(10, 8, 5)
			fx.register_lamp(src)
			continue

		if inst.model_name != "":
			var clean_model := inst.model_name.to_lower().strip_edges()
			if clean_model == "spiral":
				create_exit_teleporter(Vector3(inst.x, inst.y + 40.0, inst.z))
				continue
			var def := model_list.get_model_by_name(inst.model_name)
			if def != null:
				if def.is_3ds():
					if _place_3ds_instance(inst, def, clean_model):
						continue
				elif def.is_md2():
					if _place_md2_instance(inst, def):
						continue

		if _is_excluded(inst, object_id_by_name):
			continue
		var obj_id: int = object_id_by_name.get(inst.name.to_lower().strip_edges(), -1) if inst.name != "" else -1
		var obj_def: Parsers.ObjectDef = objects_parser.objects.get(obj_id)
		if obj_def == null:
			continue
		built_object_count += 1
		_place_object_instance(inst, obj_def, static_chunks, door_builds)

	# Static level chunks: one mesh per 1024-unit cell with a surface per texture.
	for key in static_chunks:
		var buckets: Dictionary = static_chunks[key]
		var mesh := ArrayMesh.new()
		var aabb := AABB()
		var first := true
		for tex_alias: String in buckets:
			var b: MeshBucket = buckets[tex_alias]
			if b.verts.is_empty():
				continue
			_add_surface(mesh, tex_alias, b)
			aabb = b.aabb() if first else aabb.merge(b.aabb())
			first = false
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world_root.add_child(mi)
		add_level_object(mi, aabb.get_center(), aabb.size.length() * 0.5)

	collision.build_grid()

	# Door triangles stay out of the static grid because doors move.
	for db: Array in door_builds:
		var door: Dictionary = db[0]
		var corners: PackedVector3Array = db[1]
		door.tri_start = collision.triangle_count()
		for k in range(0, corners.size() - 2, 3):
			collision.add_triangle(corners[k], corners[k + 1], corners[k + 2])
		door.tri_count = collision.triangle_count() - door.tri_start
		var mn := Vector3(INF, INF, INF)
		var mx := Vector3(-INF, -INF, -INF)
		for p in corners:
			mn = mn.min(p)
			mx = mx.max(p)
		door.bounds_min = mn
		door.bounds_max = mx
		collision.doors.append(door)

	ui.set_info("obj", str(built_object_count))
	ui.set_info("light", str(light_count))
	ui.set_info("depth", str(dungeon_depth))
	ui.minimap.level_changed()
	print("Level built in %d ms (%d triangles, %d monsters)" % [Time.get_ticks_msec() - t0, collision.triangle_count(), monsters.size()])


class MeshBucket:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()

	# Adds a triangle given in three.js order; it is stored as (0, 2, 1) so three.js front faces
	# stay front faces in Godot (which uses the opposite winding).
	func add(p0: Vector3, p1: Vector3, p2: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2) -> void:
		var n := (p1 - p0).cross(p2 - p0)
		n = n.normalized() if n.length_squared() > 0.0 else Vector3.UP
		verts.append(p0)
		verts.append(p2)
		verts.append(p1)
		normals.append(n)
		normals.append(n)
		normals.append(n)
		uvs.append(uv0)
		uvs.append(uv2)
		uvs.append(uv1)

	func aabb() -> AABB:
		var mn := verts[0]
		var mx := verts[0]
		for p in verts:
			mn = mn.min(p)
			mx = mx.max(p)
		return AABB(mn, mx - mn)


func _add_surface(mesh: ArrayMesh, tex_alias: String, b: MeshBucket) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = b.verts
	arrays[Mesh.ARRAY_NORMAL] = b.normals
	arrays[Mesh.ARRAY_TEX_UV] = b.uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, Materials.get_shared_material(tex_alias))


func _is_excluded(inst: Parsers.MapInstance, ids: Dictionary) -> bool:
	if inst.is_start_pos:
		return true
	var clean := inst.name.to_lower().strip_edges()
	if inst.name != "" and clean in EXCLUDED_NAMES:
		return true
	var id: int = ids.get(clean, -1) if inst.name != "" else -1
	return id in EXCLUDED_IDS


func get_pickup_definition(name: String) -> Dictionary:
	if name == "":
		return {}
	var clean := name.to_upper().strip_edges()
	if PICKUP_DEFINITIONS.has(clean):
		return PICKUP_DEFINITIONS[clean]
	var no_dash := clean.rstrip("-")
	for key: String in PICKUP_KEYS:
		var key_no_dash := key.rstrip("-")
		if clean == key or no_dash == key_no_dash or clean.begins_with(key_no_dash) or key_no_dash.begins_with(no_dash):
			return PICKUP_DEFINITIONS[key]
	return {}


func add_pickup(node: Node3D, pos: Vector3, name: String, def: Dictionary) -> void:
	active_pickups.append({
		"node": node, "position": pos, "original_y": pos.y, "name": name, "def": def,
		"state": "ACTIVE", "float_timer": 0.0, "base_scale": node.scale.x,
		# Pickups placed by the level get a stable index; drops from monsters and chests get -1.
		"level_index": level_pickup_count if level_loading else -1,
	})
	if level_loading:
		level_pickup_count += 1


func _place_3ds_instance(inst: Parsers.MapInstance, def: Parsers.ModelDef, clean_model: String) -> bool:
	var tds := TDSModel.load_for_def(def)
	if tds == null:
		return false
	var model := tds.instantiate()
	var s := def.scale
	model.scale = Vector3(s, s, s)
	model.position = Vector3(inst.x, inst.y + 50.0, inst.z)
	var angle := deg_to_rad(inst.rot)
	# Wall torches use the level-geometry rotation direction, so only they need the angle negated.
	model.rotation.y = (-angle + PI) if clean_model == "torch2" else angle
	world_root.add_child(model)
	add_level_object(model, model.position)
	built_object_count += 1

	var pdef := get_pickup_definition(def.name)
	if pdef.is_empty():
		pdef = get_pickup_definition(inst.model_name)
	if pdef.is_empty():
		pdef = get_pickup_definition(inst.name)
	if pdef.is_empty() and def.filepath != "":
		pdef = get_pickup_definition(def.filepath.get_file().get_basename())
	if pdef.is_empty():
		for mn in tds.mesh_names:
			if mn != "":
				pdef = get_pickup_definition(mn)
				if not pdef.is_empty():
					break
	if not pdef.is_empty():
		add_pickup(model, model.position, def.name if def.name != "" else (inst.model_name if inst.model_name != "" else inst.name), pdef)
		return true

	var cname := (def.name if def.name != "" else inst.model_name).to_lower().strip_edges()
	var box := tds.world_box(model.transform)
	if not box.is_empty() and cname != "circle" and cname != "spiral":
		collision.boxes.append(box)
	var open_name: String = OPENABLE_CONTAINERS.get(cname.trim_suffix(".3ds"), "")
	if open_name != "":
		chests.append({"model": model, "open_model_name": open_name, "position": model.position, "rotation_y": angle,
			"scale": s, "is_open": false, "box": box})
	return true


func _place_md2_instance(inst: Parsers.MapInstance, def: Parsers.ModelDef) -> bool:
	var md2 := MD2Model.load_for_def(def)
	if md2 == null:
		return false
	var s := def.scale
	var tex_alias := inst.texture_alias if (inst.texture_alias != "" and inst.texture_alias != "-1") else def.texture_alias
	var mesh := md2.create_instance(tex_alias)
	mesh.scale = Vector3(s, s, s)
	var pos := Vector3(inst.x, inst.y + 50.0, inst.z)
	mesh.position = pos
	var angle := deg_to_rad(inst.rot)
	mesh.rotation.y = angle - PI / 2.0
	world_root.add_child(mesh)
	var entry := add_level_object(mesh, pos)
	built_object_count += 1

	var pick_name := def.name if def.name != "" else (inst.model_name if inst.model_name != "" else inst.name)
	if def.type == "YOURGUN":
		md2.set_pose(mesh, [87], [1.0])
		var pdef := get_pickup_definition(def.name)
		if pdef.is_empty():
			pdef = get_pickup_definition(inst.model_name)
		if pdef.is_empty():
			pdef = get_pickup_definition(inst.name)
		if pdef.is_empty():
			pdef = {"type": "weapon", "amount": 50, "label": "+" + def.name}
		add_pickup(mesh, pos, pick_name, pdef)
		return true

	var pdef2 := get_pickup_definition(def.name)
	if pdef2.is_empty():
		pdef2 = get_pickup_definition(inst.model_name)
	if pdef2.is_empty():
		pdef2 = get_pickup_definition(inst.name)
	if not pdef2.is_empty():
		add_pickup(mesh, pos, pick_name, pdef2)
		return true

	var weapon_mesh: Node3D = null
	var weapon_model: MD2Model = null
	var weapon_def: Parsers.ModelDef = null
	if def.monster_weapon != "" and def.monster_weapon.to_upper() != "NONE":
		weapon_def = model_list.get_model_by_name(def.monster_weapon)
	if weapon_def != null:
		if weapon_def.is_md2():
			weapon_model = MD2Model.load_for_def(weapon_def)
			if weapon_model != null:
				var ws := weapon_def.scale
				weapon_mesh = weapon_model.create_instance(weapon_def.texture_alias)
				weapon_mesh.scale = Vector3(ws, ws, ws)
		elif weapon_def.is_3ds():
			var wt := TDSModel.load_for_def(weapon_def)
			if wt != null:
				weapon_mesh = wt.instantiate()
				var ws := weapon_def.scale
				weapon_mesh.scale = Vector3(ws, ws, ws)
		if weapon_mesh != null:
			weapon_mesh.position = pos
			weapon_mesh.rotation.y = angle - PI / 2.0
			world_root.add_child(weapon_mesh)

	var cfg := Monster.get_config(def.name)
	cfg["name"] = def.name
	var monster := Monster.new(self, md2, mesh, weapon_model, weapon_mesh, cfg, pos, angle, s)
	monsters.append(monster)
	entry.follow = monster
	if weapon_mesh != null:
		add_level_object(weapon_mesh, pos, 0.0, monster)
	return true


func _place_object_instance(inst: Parsers.MapInstance, obj_def: Parsers.ObjectDef, static_chunks: Dictionary, door_builds: Array) -> void:
	var is_door := inst.name.to_lower().strip_edges() == "door55" or obj_def.name.to_lower().strip_edges() == "door55"
	var pdef := {}
	if not is_door:
		pdef = get_pickup_definition(inst.name)
		if pdef.is_empty():
			pdef = get_pickup_definition(obj_def.name)
	var is_pickup := not pdef.is_empty()
	var angle := deg_to_rad(inst.rot)
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	var is_dynamic := is_door or is_pickup
	var buckets: Dictionary
	if is_dynamic:
		buckets = {}
	else:
		var key := "%d,%d,%d" % [floori(inst.x / STATIC_CHUNK_SIZE), floori(inst.y / STATIC_CHUNK_SIZE), floori(inst.z / STATIC_CHUNK_SIZE)]
		if not static_chunks.has(key):
			static_chunks[key] = {}
		buckets = static_chunks[key]
	var door_corners := PackedVector3Array()

	for poly: Parsers.ObjectPoly in obj_def.polys:
		var tex := poly.texture if poly.texture != "" else "wall1"
		var bucket: MeshBucket = buckets.get(tex)
		if bucket == null:
			bucket = MeshBucket.new()
			buckets[tex] = bucket
		var v: PackedFloat32Array = poly.verts
		var vcount := v.size() / 5
		for k in range(0, vcount - 2, 3):
			var o := k * 5
			var l0 := Vector3(v[o], v[o + 1], v[o + 2])
			var l1 := Vector3(v[o + 5], v[o + 6], v[o + 7])
			var l2 := Vector3(v[o + 10], v[o + 11], v[o + 12])
			var uv0 := Vector2(v[o + 3], v[o + 4])
			var uv1 := Vector2(v[o + 8], v[o + 9])
			var uv2 := Vector2(v[o + 13], v[o + 14])
			if is_pickup:
				bucket.add(l0, l1, l2, uv0, uv1, uv2)
				continue
			var w0 := Vector3(l0.x * cos_a - l0.z * sin_a + inst.x, l0.y + inst.y, l0.x * sin_a + l0.z * cos_a + inst.z)
			var w1 := Vector3(l1.x * cos_a - l1.z * sin_a + inst.x, l1.y + inst.y, l1.x * sin_a + l1.z * cos_a + inst.z)
			var w2 := Vector3(l2.x * cos_a - l2.z * sin_a + inst.x, l2.y + inst.y, l2.x * sin_a + l2.z * cos_a + inst.z)
			bucket.add(w0, w1, w2, uv0, uv1, uv2)
			if is_door:
				door_corners.append(w0)
				door_corners.append(w1)
				door_corners.append(w2)
			else:
				collision.add_triangle(w0, w1, w2)

	if not is_dynamic:
		return

	var group := Node3D.new()
	var mesh := ArrayMesh.new()
	for tex: String in buckets:
		var b: MeshBucket = buckets[tex]
		if b.verts.is_empty():
			continue
		_add_surface(mesh, tex, b)
	if mesh.get_surface_count() > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		group.add_child(mi)
	if is_pickup:
		group.position = Vector3(inst.x, inst.y, inst.z)
		group.rotation.y = -angle
	world_root.add_child(group)
	var lpos := Vector3(inst.x, inst.y, inst.z)
	var entry := add_level_object(group, lpos)
	if is_pickup:
		add_pickup(group, lpos, inst.name if inst.name != "" else obj_def.name, pdef)
	if is_door:
		var door := {"node": group, "position": lpos, "current_up": 0.0, "max_up": 200.0, "is_opening": false,
			"is_open": false, "tri_start": 0, "tri_count": 0, "bounds_min": Vector3.ZERO, "bounds_max": Vector3.ZERO,
			"level_obj": entry}
		doors.append(door)
		door_builds.append([door, door_corners])


func generate_and_load_new_level(descend: bool = false, override_options: Dictionary = {}) -> void:
	if level_load_in_flight:
		return
	level_load_in_flight = true
	if descend:
		set_dungeon_depth(dungeon_depth + 1)
	print("Generating new dungeon level...")
	var opts := gen_options.duplicate()
	opts.merge(override_options, true)
	var map_text := DungeonGenerator.generate(opts)
	storage_set(MAP_KEY, map_text)
	load_game_world(map_text)
	update_weapon_mesh()
	velocity = Vector3.ZERO
	camera.position = player_start_pos
	player_stats.health = float(player_stats.maxHealth)
	player_dead = false
	ui.show_death_screen(false)
	update_player_hud()
	audio.play_sound("spell3.wav", 0.8)
	fx.create_floating_text("DUNGEON LEVEL %d" % dungeon_depth if descend else "NEW DUNGEON GENERATED!", camera.position, "#38bdf8")
	ui.flash_screen("green", 0.4, 200)
	level_load_in_flight = false
	# Saved after the in-flight flag clears, so the new level (and portal depth) is what gets persisted.
	save_current_run()

# ---------------------------------------------------------------- Input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and playing and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not ui.is_menu_visible():
		var rot := camera.rotation
		rot.y -= event.relative.x * MOUSE_SENSITIVITY
		rot.x = clampf(rot.x - event.relative.y * MOUSE_SENSITIVITY, -PI / 2.0, PI / 2.0)
		rot.z = 0.0
		camera.rotation = rot
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if playing and not ui.is_menu_visible():
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				trigger_weapon_attack()
		return
	if event is InputEventKey:
		var key: int = event.physical_keycode
		if event.pressed and not event.echo and key == KEY_ESCAPE:
			if playing and not ui.is_menu_visible():
				pause_game_session()
			elif ui.is_menu_visible() and world_ready:
				ui.on_back_or_resume()
			return
		if not playing or ui.is_menu_visible():
			return
		if event.pressed:
			if not event.echo:
				_on_key_down(key)
			else:
				_set_move_key(key, true)
		else:
			_on_key_up(key)


func _set_move_key(key: int, down: bool) -> void:
	match key:
		KEY_UP, KEY_W: move_forward = down
		KEY_LEFT, KEY_A: move_left = down
		KEY_DOWN, KEY_S: move_backward = down
		KEY_RIGHT, KEY_D: move_right = down
		KEY_SHIFT: is_sprinting = down


func _on_key_down(key: int) -> void:
	_set_move_key(key, true)
	match key:
		KEY_SPACE:
			if fly_mode:
				move_up = true
			else:
				jump_requested = true
		KEY_C, KEY_CTRL:
			if fly_mode:
				move_down = true
		KEY_F, KEY_V:
			toggle_fly_mode()
		KEY_Q:
			cycle_weapon(1)
		KEY_Z:
			cycle_weapon(-1)
		KEY_E:
			open_nearby_door()
		KEY_N:
			set_normal_maps_enabled(not normal_maps_enabled)
			ui.sync_options()
			save_game_options()
		KEY_K:
			unlock_all()
		KEY_I:
			toggle_god_mode()
		KEY_G:
			generate_and_load_new_level(false)
		KEY_P, KEY_M:
			toggle_music_from_input()


func _on_key_up(key: int) -> void:
	_set_move_key(key, false)
	match key:
		KEY_SPACE:
			move_up = false
		KEY_C, KEY_CTRL:
			move_down = false


# ---------------------------------------------------------------- Frame loop

func _process(delta: float) -> void:
	_handle_screenshot(delta)
	var paused := is_paused()
	var gp: Dictionary = gamepad.poll(delta, paused)
	if paused:
		return
	if gp.get("pause_toggle", false):
		pause_game_session()
		return
	if gp.get("has_look", false):
		gamepad.apply_look(camera, delta, gp.look_x, gp.look_y)
	if gp.get("recenter_pitch", false):
		camera.rotation.x = 0.0
		vibrate(40, 0.2, 0.05)
	if gp.get("jump", false) and not fly_mode:
		jump_requested = true
	if gp.get("attack", false):
		trigger_weapon_attack()
	if gp.get("interact", false):
		open_nearby_door()
	if gp.get("cycle_weapon", 0) != 0:
		cycle_weapon(gp.cycle_weapon)
	if gp.get("toggle_god_mode", false):
		toggle_god_mode()
		vibrate(100, 0.4, 0.3)
	if gp.get("toggle_music", false):
		toggle_music_from_input()
	if gp.get("toggle_normal_maps", false):
		toggle_normal_maps_from_input()

	_time += delta
	var dt := minf(delta, 0.1)
	_update_player_movement(dt, gp)

	var pos := camera.position
	_pos_display_timer += delta
	if _pos_display_timer >= 0.1:
		_pos_display_timer = 0.0
		ui.set_info("pos", "%d, %d, %d" % [roundi(pos.x), roundi(pos.y), roundi(pos.z)])

	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		if game_started and not player_dead:
			save_current_run()

	if player_dead:
		player_death_timer -= dt
		if player_death_timer <= 0.0:
			respawn_player()

	for m: Monster in monsters:
		m.update(dt, pos)

	var gmx: float = gp.get("move_x", 0.0)
	var gmy: float = gp.get("move_y", 0.0)
	_update_player_weapon_animation(dt, move_forward or gmy < -0.1, move_backward or gmy > 0.1,
		move_left or gmx < -0.1, move_right or gmx > 0.1)
	_update_projectiles(dt)
	_update_pickups(dt, pos)
	_update_teleporters(dt, pos)
	_update_doors(dt)
	audio.update_music(dt)
	fx.update_lighting(_time, dt, pos)
	_update_distance_culling(pos)
	ui.update_minimap(pos, camera)


func _update_player_movement(delta: float, gp: Dictionary) -> void:
	var sprint := is_sprinting or bool(gp.get("sprint", false))
	var move_speed := 400.0 if sprint else 200.0
	var gmx: float = gp.get("move_x", 0.0)
	var gmy: float = gp.get("move_y", 0.0)
	var cam_basis := camera.global_transform.basis

	if fly_mode:
		var damp := pow(0.01, delta)
		velocity *= damp
		var dir := Vector3(float(move_right) - float(move_left) + gmx, 0.0, float(move_backward) - float(move_forward) + gmy)
		if dir.length_squared() > 0.0:
			var world_dir := cam_basis * dir.normalized()
			velocity += world_dir * move_speed * 8.0 * delta
		if move_up or gp.get("fly_up", false):
			velocity.y += move_speed * 8.0 * delta
		if move_down or gp.get("fly_down", false):
			velocity.y -= move_speed * 8.0 * delta
		camera.position += velocity * delta
		return

	var damp_xz := pow(0.001, delta)
	velocity.x *= damp_xz
	velocity.z *= damp_xz
	velocity.y -= CollisionWorld.GRAVITY * delta
	if jump_requested:
		if is_grounded:
			velocity.y = CollisionWorld.JUMP_SPEED
			is_grounded = false
		jump_requested = false

	var forward := cam_basis * Vector3(0, 0, -1)
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 1e-6 else Vector3(0, 0, -1)
	var right := cam_basis * Vector3(1, 0, 0)
	right.y = 0.0
	right = right.normalized() if right.length_squared() > 1e-6 else Vector3(1, 0, 0)

	var input_forward := float(move_forward) - float(move_backward) - gmy
	var input_right := float(move_right) - float(move_left) + gmx
	var world_dir := forward * input_forward + right * input_right
	var dir_len := world_dir.length()
	if dir_len > 0.001:
		var sc := minf(1.0, dir_len)
		world_dir = world_dir.normalized()
		velocity.x += world_dir.x * (move_speed * sc) * 10.0 * delta
		velocity.z += world_dir.z * (move_speed * sc) * 10.0 * delta

	var pos := camera.position
	var max_step := CollisionWorld.CAPSULE_RADIUS * 0.5
	var travel := maxf(absf(velocity.x), maxf(absf(velocity.y), absf(velocity.z))) * delta
	var steps := mini(16, maxi(1, ceili(travel / max_step)))
	var step_dt := delta / steps
	var grounded := false
	for s in steps:
		pos += velocity * step_dt
		var g := collision.resolve_capsule_world(pos, CollisionWorld.EYE_HEIGHT, CollisionWorld.CAPSULE_RADIUS,
			CollisionWorld.CAPSULE_HEIGHT, velocity, true, null, monsters, false, Vector3.ZERO)
		pos = collision.out_pos
		velocity = collision.out_vel
		grounded = g or grounded
	camera.position = pos
	is_grounded = grounded

	if is_grounded and (move_forward or move_backward or move_left or move_right or dir_len > 0.1):
		if velocity.x * velocity.x + velocity.z * velocity.z > 400.0:
			footstep_timer += delta * (1.5 if sprint else 1.0)
			if footstep_timer >= 0.38:
				footstep_timer = 0.0
				audio.play_sound("walk.wav", 0.18)
		else:
			footstep_timer = 0.3
	else:
		footstep_timer = 0.3


func _update_distance_culling(pos: Vector3) -> void:
	for obj: Dictionary in level_objects:
		var node: Node3D = obj.node
		if not is_instance_valid(node):
			continue
		var p: Vector3 = obj.follow.position if obj.follow != null else obj.position
		var reach: float = RENDER_DISTANCE + obj.radius
		node.visible = pos.distance_squared_to(p) <= reach * reach


func _handle_screenshot(delta: float) -> void:
	if _shot_path == "" or not world_ready:
		return
	_shot_delay -= delta
	if _shot_delay > 0.0:
		return
	_shot_frames += 1
	if _shot_frames < 3:
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_path)
	print("Screenshot saved to ", _shot_path)
	_shot_path = ""
	get_tree().quit()

# ---------------------------------------------------------------- Player stats

func damage_player(amount: float) -> void:
	if is_invincible or player_stats.health <= 0.0:
		return
	player_stats.health = maxf(0.0, player_stats.health - amount)
	audio.play_sound(AudioManager.random_sound(PLAYER_IMPACT_SOUNDS), 0.6)
	ui.flash_screen("red", 0.6, 150)
	update_player_hud()
	vibrate(220, 0.5, 0.85)
	if player_stats.health <= 0.0:
		kill_player()


func kill_player() -> void:
	player_dead = true
	player_death_timer = PLAYER_RESPAWN_DELAY
	audio.play_sound("die.wav", 0.8)
	ui.show_death_screen(true)
	vibrate(500, 0.8, 1.0)


func respawn_player() -> void:
	player_dead = false
	player_stats.health = float(player_stats.maxHealth)
	ui.show_death_screen(false)
	camera.position = player_start_pos
	velocity = Vector3.ZERO
	update_player_hud()


func heal_player(amount) -> void:
	if player_stats.health <= 0.0:
		return
	if amount is String and amount == "full":
		player_stats.health = float(player_stats.maxHealth)
	else:
		player_stats.health = minf(float(player_stats.maxHealth), player_stats.health + float(amount))
	update_player_hud()


func add_player_xp(amount: float) -> void:
	player_stats.xp += amount
	var leveled := false
	while player_stats.xp >= player_stats.nextXp:
		player_stats.xp -= player_stats.nextXp
		player_stats.level += 1
		player_stats.nextXp = floori(player_stats.nextXp * 1.5)
		player_stats.maxHealth += 20
		player_stats.health = float(player_stats.maxHealth)
		leveled = true
	update_player_hud()
	if leveled:
		var pos := camera.position
		fx.create_floating_text("LEVEL UP! LVL %d" % player_stats.level, pos, "#facc15")
		fx.create_pickup_particle_burst(pos, 0xfacc15)
		ui.flash_screen("xp", 0.6, 250)
		audio.play_sound("treasure.wav", 0.8)


func award_player_xp(amount: float) -> void:
	player_stats.kills += 1
	add_player_xp(amount)


func current_gun_name() -> String:
	return PLAYER_GUNS[current_gun_index] if current_gun_index < PLAYER_GUNS.size() else "AXE"


func update_player_hud() -> void:
	var gun := current_gun_name()
	var gun_text := "%s (%d)" % [gun, spell_counts[gun]] if spell_counts.has(gun) else gun
	ui.update_hud(player_stats, gun_text)


# ---------------------------------------------------------------- Weapons

func cycle_weapon(dir: int) -> void:
	var attempts := 0
	while true:
		current_gun_index = posmod(current_gun_index + dir, PLAYER_GUNS.size())
		attempts += 1
		if PLAYER_GUNS[current_gun_index] in unlocked_weapons or attempts >= PLAYER_GUNS.size():
			break
	update_weapon_mesh()


func update_weapon_mesh() -> void:
	var gun := current_gun_name()
	update_player_hud()
	if gun_mesh != null:
		gun_mesh.queue_free()
		gun_mesh = null
		gun_model = null
	weapon_anim_timer = 0.0
	weapon_anim = Monster.ANIMS.STAND
	is_weapon_attacking = false
	has_weapon_hit = false
	var def := model_list.get_model_by_name(gun)
	if def == null and gun in SPELL_NAMES:
		def = model_list.get_model_by_name("weaponsorcerer")
	if def == null:
		return
	var md2 := MD2Model.load_for_def(def)
	if md2 == null:
		return
	var s := def.scale
	gun_mesh = md2.create_instance(def.texture_alias)
	gun_mesh.scale = Vector3(s, s, s)
	gun_mesh.position = Vector3(0, -25, 5)
	gun_mesh.rotation = Vector3(0, PI / 2.0, 0)
	gun_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(gun_mesh)
	gun_model = md2


func trigger_weapon_attack() -> void:
	if player_dead:
		return
	var gun := current_gun_name()
	if spell_counts.has(gun):
		if spell_counts[gun] <= 0:
			audio.play_sound("buttonselect111.wav", 0.5)
			return
		spell_counts[gun] -= 1
		update_player_hud()
	is_weapon_attacking = true
	has_weapon_hit = false
	weapon_anim_timer = 0.0
	weapon_anim = Monster.ANIMS.ATTACK
	vibrate(90, 0.35, 0.2)
	match gun:
		"MAGIC MISSILE":
			has_weapon_hit = true
			audio.play_sound("spell1.wav", 0.7)
			launch_projectile("MAGIC MISSILE")
		"FIREBALL":
			has_weapon_hit = true
			audio.play_sound("fireball.wav", 0.8)
			launch_projectile("FIREBALL")
		"LIGHTNING":
			has_weapon_hit = true
			audio.play_sound("spell3.wav", 0.8)
			launch_projectile("LIGHTNING")
		"HEALING":
			has_weapon_hit = true
			audio.play_sound("spell2.wav", 0.8)
			cast_healing_spell()
		_:
			audio.play_sound(AudioManager.random_sound(SWISH_SOUNDS), 0.5)


func cast_healing_spell() -> void:
	heal_player(10)
	var p := camera.position
	fx.create_floating_text("+10 HP", p, "#22c55e")
	for i in 40:
		var angle := randf() * TAU
		var rad := 20.0 + randf() * 30.0
		fx.emit_particle(p.x + cos(angle) * rad, p.y - 60.0 + randf() * 20.0, p.z + sin(angle) * rad,
			(randf() - 0.5) * 20.0, 120.0 + randf() * 100.0, (randf() - 0.5) * 20.0, 0x4ade80, 10.0, 1.0)
	ui.flash_screen("green", 0.6, 200)


func look_direction() -> Vector3:
	return -camera.global_transform.basis.z.normalized()


func check_player_attack_hit() -> void:
	var player_pos := camera.position
	var player_dir := look_direction()
	var closest: Monster = null
	var closest_dist := INF
	for m: Monster in monsters:
		if m.dead or m.health <= 0.0:
			continue
		var to_m := m.position - player_pos
		var dist := to_m.length()
		if dist <= 140.0 and player_dir.dot(to_m.normalized()) >= 0.5 and dist < closest_dist:
			closest_dist = dist
			closest = m
	if closest == null:
		return
	var damage: float = WEAPON_DAMAGE.get(current_gun_name(), 25)
	var box := closest.bbox
	var has_box := not box.is_empty()
	var feet_y := box.min.y if has_box else closest.position.y
	var height := maxf(20.0, box.max.y - box.min.y) if has_box else 60.0
	var hit_pos := Vector3(closest.position.x - player_dir.x * 12.0, feet_y + height * (0.55 + randf() * 0.2),
		closest.position.z - player_dir.z * 12.0)
	var max_health: float = closest.config.maxHealth
	closest.take_damage(damage)
	var killed := closest.health <= 0.0
	fx.create_blood_splatter(hit_pos, player_dir, damage / max_health, feet_y, closest.config.get("bloodColor", 0x9a0a0a), killed)
	audio.play_sound(AudioManager.random_sound(IMPACT_SOUNDS), 0.6)


func _update_player_weapon_animation(delta: float, fwd: bool, back: bool, left: bool, right: bool) -> void:
	if gun_mesh == null or gun_model == null:
		return
	var moving := fwd or back or left or right
	var target: Dictionary = Monster.ANIMS.STAND
	if is_weapon_attacking:
		target = Monster.ANIMS.ATTACK
	elif not is_grounded and not fly_mode:
		target = Monster.ANIMS.JUMP
	elif moving:
		target = Monster.ANIMS.RUN
	if weapon_anim.name != target.name:
		weapon_anim = target
		weapon_anim_timer = 0.0
	weapon_anim_timer += delta
	var anim := weapon_anim
	var total_duration: float = (anim.end - anim.start + 1) / anim.fps
	if is_weapon_attacking and weapon_anim.name == "ATTACK":
		if not has_weapon_hit and weapon_anim_timer >= total_duration * 0.5:
			has_weapon_hit = true
			check_player_attack_hit()
	if not anim.loop and weapon_anim_timer >= total_duration:
		if is_weapon_attacking:
			is_weapon_attacking = false
			has_weapon_hit = false
			weapon_anim = Monster.ANIMS.RUN if moving else Monster.ANIMS.STAND
			weapon_anim_timer = 0.0
	var cur := weapon_anim
	var total: int = cur.end - cur.start + 1
	var progress: float = weapon_anim_timer * cur.fps
	var frame_a: int
	var frame_b: int
	var alpha: float
	if cur.loop:
		var idx := fmod(progress, total)
		frame_a = cur.start + floori(idx)
		frame_b = cur.start + (floori(idx) + 1) % total
		alpha = idx - floori(idx)
	else:
		var idx := minf(progress, total - 1)
		frame_a = cur.start + floori(idx)
		frame_b = cur.start + mini(floori(idx) + 1, total - 1)
		alpha = idx - floori(idx)
	if frame_a == frame_b or alpha <= 0.001:
		gun_model.set_pose(gun_mesh, [frame_a], [1.0 - alpha + (alpha if frame_a == frame_b else 0.0)])
	else:
		gun_model.set_pose(gun_mesh, [frame_a, frame_b], [1.0 - alpha, alpha])


# ---------------------------------------------------------------- Projectiles

func _make_projectile_node(type: String, spawn: Vector3) -> Node3D:
	var def: Dictionary = PROJECTILE_TYPES[type]
	var group := Node3D.new()
	group.position = spawn
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = def.coreRadius
	sphere.height = def.coreRadius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 8
	core.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var c := Effects.hex_color(def.coreColor)
	c.a = def.coreOpacity
	mat.albedo_color = c
	core.material_override = mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	group.add_child(core)
	group.add_child(fx.make_glare(0, true, Effects.hex_color(def.haloColor), def.haloOpacity, def.haloSize))
	world_root.add_child(group)
	return group


func launch_projectile(type: String) -> void:
	var def: Dictionary = PROJECTILE_TYPES[type]
	var look_dir := look_direction()
	var spawn := camera.position + look_dir * 40.0
	spawn.y -= 10.0
	var slot := fx.acquire_dynamic_light(def.lightColor, def.lightIntensity, def.lightDistance)
	if slot != null:
		slot.light.position = spawn
	active_projectiles.append({
		"type": type, "owner": "player", "node": _make_projectile_node(type, spawn), "light_slot": slot,
		"position": spawn, "velocity": look_dir * def.speed, "gravity": def.gravity, "radius": def.radius,
		"aoe_radius": def.aoeRadius, "damage": float(WEAPON_DAMAGE[type]), "life": 0.0, "max_life": def.maxLife,
		"color": def.colorHex,
	})


func launch_monster_projectile(monster: Monster, type: String, target_pos: Vector3) -> void:
	if not PROJECTILE_TYPES.has(type):
		type = "MAGIC MISSILE"
	var def: Dictionary = PROJECTILE_TYPES[type]
	var spawn := monster.position + Vector3(0, 40, 0)
	var dir := (target_pos + Vector3(0, 20, 0) - spawn).normalized()
	dir += Vector3((randf() - 0.5) * 0.08, (randf() - 0.5) * 0.05, (randf() - 0.5) * 0.08)
	dir = dir.normalized()
	var slot := fx.acquire_dynamic_light(def.lightColor, def.lightIntensity, def.lightDistance)
	if slot != null:
		slot.light.position = spawn
	var base_dmg: float = monster.config.damage if monster.config.damage else 15
	var mult := 1.25 if type == "FIREBALL" else (1.15 if type == "LIGHTNING" else 1.0)
	active_projectiles.append({
		"type": type, "owner": "monster", "node": _make_projectile_node(type, spawn), "light_slot": slot,
		"position": spawn, "velocity": dir * (def.speed * 0.88), "gravity": -120.0 if type == "FIREBALL" else 0.0,
		"radius": def.radius, "aoe_radius": def.aoeRadius, "damage": float(roundi(base_dmg * mult)), "life": 0.0,
		"max_life": def.maxLife, "color": def.colorHex,
	})


func _explosion_particles(pos: Vector3, count: int, base_speed: float, speed_range: float, color_hex: int, size: float, life: float) -> void:
	for i in count:
		var theta := randf() * TAU
		var phi := randf() * PI - PI / 2.0
		var speed := base_speed + randf() * speed_range
		fx.emit_particle(pos.x, pos.y, pos.z, cos(phi) * cos(theta) * speed, sin(phi) * speed,
			cos(phi) * sin(theta) * speed, color_hex, size, life)


func trigger_spell_explosion(pos: Vector3, type: String, damage: float, aoe_radius: float, color_hex: int) -> void:
	audio.play_sound("explod1.wav" if type == "FIREBALL" else "explod2.wav", 0.85)
	var dist_p := pos.distance_to(camera.position)
	if dist_p <= 600.0:
		var intensity := maxf(0.2, 1.0 - dist_p / 600.0)
		vibrate(180, 0.4 * intensity, 0.7 * intensity)
	_explosion_particles(pos, 60 if type == "FIREBALL" else 40, 120.0, 250.0, color_hex, 14.0, 0.6)
	fx.add_explosion_flash(pos, color_hex, aoe_radius)
	for m: Monster in monsters:
		if m.dead or m.health <= 0.0:
			continue
		var dist := pos.distance_to(m.position)
		if dist <= aoe_radius:
			var sc := maxf(0.5, 1.0 - (dist / aoe_radius) * 0.5)
			m.take_damage(roundi(damage * sc))
			audio.play_sound(AudioManager.random_sound(IMPACT_SOUNDS), 0.7)


func trigger_monster_spell_explosion(pos: Vector3, type: String, damage: float, aoe_radius: float, color_hex: int) -> void:
	audio.play_sound("explod1.wav" if type == "FIREBALL" else "explod2.wav", 0.85)
	_explosion_particles(pos, 50 if type == "FIREBALL" else 35, 100.0, 220.0, color_hex, 12.0, 0.65)
	fx.add_explosion_flash(pos, color_hex, aoe_radius)
	var player_pos := camera.position
	var dist := pos.distance_to(player_pos)
	if dist <= aoe_radius:
		var sc := maxf(0.5, 1.0 - (dist / aoe_radius) * 0.5)
		var actual := roundi(damage * sc)
		damage_player(actual)
		fx.create_floating_text("-%d HP" % actual, player_pos, "#ef4444")


func _projectile_hits(proj: Dictionary, p: Vector3) -> bool:
	var radius: float = proj.radius
	if proj.owner == "monster":
		var reach := radius + CollisionWorld.CAPSULE_RADIUS
		if p.distance_squared_to(camera.position) <= reach * reach:
			return true
	else:
		var reach := radius + CollisionWorld.MONSTER_CAPSULE_RADIUS
		for m: Monster in monsters:
			if m.dead or m.health <= 0.0:
				continue
			if p.distance_squared_to(m.position) <= reach * reach:
				return true
	return collision.hits_environment_at(p, radius)


func _explode_projectile(proj: Dictionary, at: Vector3) -> void:
	if proj.owner == "monster":
		trigger_monster_spell_explosion(at, proj.type, proj.damage, proj.aoe_radius, proj.color)
	else:
		trigger_spell_explosion(at, proj.type, proj.damage, proj.aoe_radius, proj.color)


func _remove_projectile(i: int) -> void:
	var proj: Dictionary = active_projectiles[i]
	(proj.node as Node3D).queue_free()
	fx.release_dynamic_light(proj.light_slot)
	active_projectiles.remove_at(i)


func _update_projectiles(delta: float) -> void:
	fx.update_explosion_flashes(delta)
	for i in range(active_projectiles.size() - 1, -1, -1):
		if i >= active_projectiles.size():
			continue
		var proj: Dictionary = active_projectiles[i]
		proj.life += delta
		if proj.life >= proj.max_life:
			_explode_projectile(proj, proj.position)
			_remove_projectile(i)
			continue
		if proj.owner == "monster" and proj.type == "MAGIC MISSILE":
			var to_player: Vector3 = (camera.position + Vector3(0, 20, 0) - proj.position).normalized()
			proj.velocity = (proj.velocity as Vector3).lerp(to_player * (PROJECTILE_TYPES["MAGIC MISSILE"].speed * 0.88), delta * 2.5)
		var vel: Vector3 = proj.velocity
		vel.y += proj.gravity * delta
		proj.velocity = vel
		var step: Vector3 = vel * delta
		var next: Vector3 = proj.position + step
		var segments := mini(8, maxi(1, ceili(step.length() / proj.radius)))
		var exploded := false
		for s in range(1, segments + 1):
			var sample: Vector3 = proj.position + step * (float(s) / segments)
			if _projectile_hits(proj, sample):
				exploded = true
				_explode_projectile(proj, sample)
				break
		if exploded:
			if i < active_projectiles.size() and is_same(active_projectiles[i], proj):
				_remove_projectile(i)
			continue
		proj.position = next
		(proj.node as Node3D).position = next
		if proj.light_slot != null:
			proj.light_slot.light.position = next
		if randf() < 0.7:
			for k in 4:
				fx.emit_particle(next.x + (randf() - 0.5) * 10.0, next.y + 10.0 + (randf() - 0.5) * 10.0, next.z + (randf() - 0.5) * 10.0,
					(randf() - 0.5) * 120.0, 50.0 + (randf() - 0.5) * 120.0, (randf() - 0.5) * 120.0, proj.color, 8.0, 0.5)

# ---------------------------------------------------------------- Pickups, doors, chests

func _remove_pickup(index: int) -> void:
	var pk: Dictionary = active_pickups[index]
	var node: Node3D = pk.node
	remove_level_object(node)
	node.queue_free()
	active_pickups.remove_at(index)


func _update_pickups(delta: float, player_pos: Vector3) -> void:
	fx.update_pickup_effects(delta)
	for i in range(active_pickups.size() - 1, -1, -1):
		if i >= active_pickups.size():
			continue
		var pk: Dictionary = active_pickups[i]
		var node: Node3D = pk.node
		if not is_instance_valid(node):
			continue
		if pk.state == "ACTIVE":
			if player_pos.distance_squared_to(pk.position) <= PICKUP_DISTANCE * PICKUP_DISTANCE:
				pk.state = "FLOATING"
				pk.float_timer = 0.0
				_collect_pickup(pk)
		elif pk.state == "FLOATING":
			pk.float_timer += delta
			var progress: float = pk.float_timer / 0.7
			node.position.y = pk.original_y + progress * progress * 350.0
			node.rotation.y += delta * 12.0
			node.scale = Vector3.ONE * (pk.base_scale * maxf(0.0, 1.0 - progress))
			if progress >= 1.0:
				_remove_pickup(i)


func _collect_pickup(pk: Dictionary) -> void:
	var name_clean := str(pk.name).to_upper().strip_edges()
	var def: Dictionary = pk.def
	var is_health: bool = def.get("type", "") == "health"
	var label: String = def.get("label", "+" + str(pk.name))
	var color_hex := 0x22c55e if is_health else 0xeab308
	var color_css := "#4ade80" if is_health else "#facc15"

	# Weapon names such as LIGHTNINGSWORD contain spell names, so they must never match as scrolls.
	var is_weapon_name := false
	for g in PLAYER_GUNS:
		if not spell_counts.has(g) and g == name_clean:
			is_weapon_name = true
	var scroll_name := "" if is_weapon_name else name_clean
	var spell_scroll := ""
	if scroll_name.contains("SPELLBOOK"):
		for s in ["MAGIC MISSILE", "FIREBALL", "LIGHTNING", "HEALING"]:
			spell_counts[s] += 5
		label = "+5 ALL SPELLS"
		color_hex = 0xa855f7
		color_css = "#c084fc"
		update_player_hud()
	elif scroll_name.contains("SCROLL-MAGICMISSLE") or scroll_name.contains("MAGICMISSLE") or scroll_name == "MAGIC MISSILE":
		spell_scroll = "MAGIC MISSILE"
		color_hex = 0x38bdf8
		color_css = "#38bdf8"
	elif scroll_name.contains("SCROLL-FIREBALL") or scroll_name.contains("FIREBALL"):
		spell_scroll = "FIREBALL"
		color_hex = 0xff5500
		color_css = "#ff7700"
	elif scroll_name.contains("SCROLL-LIGHTNING") or scroll_name.contains("LIGHTNING"):
		spell_scroll = "LIGHTNING"
		color_hex = 0x00ffff
		color_css = "#00ffff"
	elif scroll_name.contains("SCROLL-HEALING") or scroll_name.contains("HEALING"):
		spell_scroll = "HEALING"
		color_hex = 0x22c55e
		color_css = "#4ade80"

	if spell_scroll != "":
		spell_counts[spell_scroll] = spell_counts.get(spell_scroll, 0) + 5
		label = "+5 %s SPELLS" % spell_scroll
		update_player_hud()
	elif not name_clean.contains("SPELLBOOK"):
		var unlocked := ""
		for gun: String in PLAYER_GUNS:
			if spell_counts.has(gun):
				continue
			if gun == name_clean:
				unlocked = gun
				break
			if name_clean != "" and (name_clean.contains(gun) or gun.contains(name_clean)):
				if unlocked == "" or gun.length() > unlocked.length():
					unlocked = gun
		if unlocked == "" and def.get("type", "") == "weapon":
			unlocked = str(pk.name)
		if unlocked != "":
			var was_unlocked := unlocked in unlocked_weapons
			if not was_unlocked:
				unlocked_weapons.append(unlocked)
			label = "+" + unlocked
			color_hex = 0x38bdf8
			color_css = "#38bdf8"
			# Only switch to the weapon the first time it is picked up
			if not was_unlocked:
				var idx := PLAYER_GUNS.find(unlocked)
				if idx != -1:
					current_gun_index = idx
					update_weapon_mesh()
		elif is_health:
			heal_player(def.amount)
		elif def.get("amount", 0):
			add_player_xp(float(def.amount))

	audio.play_pickup_sound(is_health)
	vibrate(60, 0.35, 0.1)
	fx.create_floating_text(label, pk.position, color_css)
	fx.create_pickup_particle_burst(pk.position, color_hex)
	ui.flash_screen("health" if is_health else "xp", 0.5, 150)


func _update_doors(delta: float) -> void:
	for door: Dictionary in doors:
		if not door.is_opening or door.is_open:
			continue
		var dy := 200.0 * delta
		if door.current_up + dy >= door.max_up:
			dy = door.max_up - door.current_up
			door.current_up = door.max_up
			door.is_opening = false
			door.is_open = true
		else:
			door.current_up += dy
		if dy > 0.0:
			_move_door(door, dy)


func _move_door(door: Dictionary, dy: float) -> void:
	(door.node as Node3D).position.y += dy
	var lo: Dictionary = door.level_obj
	lo.position = lo.position + Vector3(0, dy, 0)
	collision.offset_triangles_y(door.tri_start, door.tri_count, dy)
	door.bounds_min = door.bounds_min + Vector3(0, dy, 0)
	door.bounds_max = door.bounds_max + Vector3(0, dy, 0)


func _open_door_instantly(door: Dictionary) -> void:
	var dy: float = door.max_up - door.current_up
	door.current_up = door.max_up
	door.is_opening = false
	door.is_open = true
	if dy > 0.0:
		_move_door(door, dy)


func open_nearby_door() -> void:
	if not playing:
		return
	var player_pos := camera.position
	var max_sq := 250.0 * 250.0
	var nearest_door: Dictionary = {}
	var best := max_sq
	for door: Dictionary in doors:
		if door.is_open or door.is_opening:
			continue
		var d := player_pos.distance_squared_to(door.position)
		if d <= best:
			best = d
			nearest_door = door
	if not nearest_door.is_empty():
		nearest_door.is_opening = true
		vibrate(90, 0.2, 0.35)
	var nearest_chest: Dictionary = {}
	best = max_sq
	for chest: Dictionary in chests:
		if chest.is_open:
			continue
		var d := player_pos.distance_squared_to(chest.position)
		if d <= best:
			best = d
			nearest_chest = chest
	if not nearest_chest.is_empty():
		open_chest(nearest_chest)
		vibrate(100, 0.25, 0.4)


func open_chest(chest: Dictionary, restoring: bool = false) -> void:
	if chest.is_empty() or chest.is_open:
		return
	chest.is_open = true
	var open_def := model_list.get_model_by_name(chest.get("open_model_name", "cdooropenchest"))
	if open_def != null:
		var tds := TDSModel.load_for_def(open_def)
		if tds != null:
			var open_model := tds.instantiate()
			var s: float = open_def.scale if open_def.scale else chest.scale
			open_model.scale = Vector3(s, s, s)
			open_model.position = chest.position
			open_model.rotation.y = chest.rotation_y
			var old: Node3D = chest.model
			remove_level_object(old)
			old.queue_free()
			world_root.add_child(open_model)
			add_level_object(open_model, chest.position)
			chest.model = open_model
			var new_box := tds.world_box(open_model.transform)
			if not new_box.is_empty():
				var box: CollisionWorld.Box = chest.box
				if box != null and collision.boxes.has(box):
					box.min = new_box.min
					box.max = new_box.max
				else:
					collision.boxes.append(new_box)
					chest.box = new_box
	if restoring:
		return
	audio.play_sound("topen.wav", 0.8)
	chest.position = chest.position + Vector3(0, 40, 0)
	drop_treasure(chest.position, true)


# treasure_name and silent are used when restoring a saved drop: same item, no random roll or effects.
func drop_treasure(position: Vector3, force_drop: bool = false, treasure_name: String = "", silent: bool = false) -> void:
	if not force_drop and randf() >= 0.8:
		return
	var treasure: String = treasure_name if treasure_name != "" else TREASURE_DROPS[randi() % TREASURE_DROPS.size()]
	var def := model_list.get_model_by_name(treasure)
	if def == null:
		return
	var model: Node3D = null
	if def.is_3ds():
		var tds := TDSModel.load_for_def(def)
		if tds != null:
			model = tds.instantiate()
	elif def.is_md2():
		var md2 := MD2Model.load_for_def(def)
		if md2 != null:
			model = md2.create_instance(def.texture_alias)
	if model == null:
		return
	var s := def.scale
	model.scale = Vector3(s, s, s)
	model.position = position
	model.rotation.y = randf() * TAU
	world_root.add_child(model)
	add_level_object(model, position)
	var pdef := get_pickup_definition(treasure)
	if pdef.is_empty():
		pdef = get_pickup_definition(def.name)
	if not pdef.is_empty():
		add_pickup(model, position, def.name if def.name != "" else treasure, pdef)
	if silent:
		return
	var dist := position.distance_to(camera.position)
	if dist <= 1200.0:
		audio.play_sound("treasure.wav", maxf(0.1, (1.0 - dist / 1200.0) * 0.8))
	fx.create_treasure_drop_effect(position)


# ---------------------------------------------------------------- Exit teleporter

func _additive_material(color_hex: int, opacity: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var c := Effects.hex_color(color_hex)
	c.a = opacity
	mat.albedo_color = c
	return mat


static func _ring_mesh(inner: float, outer: float, segments: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var i0 := Vector3(cos(a0) * inner, sin(a0) * inner, 0)
		var o0 := Vector3(cos(a0) * outer, sin(a0) * outer, 0)
		var i1 := Vector3(cos(a1) * inner, sin(a1) * inner, 0)
		var o1 := Vector3(cos(a1) * outer, sin(a1) * outer, 0)
		verts.append_array([i0, o1, o0, i0, i1, o1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func create_exit_teleporter(position: Vector3) -> void:
	var group := Node3D.new()
	group.position = position
	var beam := MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 40.0
	beam_mesh.bottom_radius = 50.0
	beam_mesh.height = 400.0
	beam_mesh.radial_segments = 16
	beam_mesh.rings = 1
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	beam.mesh = beam_mesh
	beam.material_override = _additive_material(0x38bdf8, 0.35)
	beam.position.y = 200.0
	group.add_child(beam)
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 15.0
	core_mesh.bottom_radius = 20.0
	core_mesh.height = 420.0
	core_mesh.radial_segments = 16
	core_mesh.rings = 1
	core_mesh.cap_top = false
	core_mesh.cap_bottom = false
	core.mesh = core_mesh
	core.material_override = _additive_material(0x818cf8, 0.6)
	core.position.y = 210.0
	group.add_child(core)
	var rings: Array = []
	var ring_mesh := _ring_mesh(20.0, 65.0, 32)
	var ring_colors := [0x38bdf8, 0x818cf8, 0xc084fc, 0x38bdf8]
	for i in 4:
		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.material_override = _additive_material(ring_colors[i], 0.7)
		ring.rotation.x = PI / 2.0
		ring.position.y = 15.0 + i * 45.0
		group.add_child(ring)
		rings.append(ring)
	for child in group.get_children():
		(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var slot := fx.acquire_dynamic_light(0x38bdf8, 12000.0, 600.0)
	if slot != null:
		slot.light.position = position + Vector3(0, 100, 0)
	fx.create_floating_text("DUNGEON EXIT PORTAL", position, "#38bdf8")
	world_root.add_child(group)
	active_teleporters.append({"node": group, "beam": beam, "core": core, "rings": rings, "light_slot": slot,
		"position": position, "timer": 0.0})


func _update_teleporters(delta: float, player_pos: Vector3) -> void:
	if teleporter_cooldown > 0.0:
		teleporter_cooldown -= delta
	for tp: Dictionary in active_teleporters:
		var dx: float = player_pos.x - tp.position.x
		var dz: float = player_pos.z - tp.position.z
		var dist_sq := dx * dx + dz * dz
		# Far-away portals are invisible through fog: skip animation and particles entirely.
		if dist_sq > 2500.0 * 2500.0:
			continue
		tp.timer += delta
		var t: float = tp.timer
		var beam: MeshInstance3D = tp.beam
		beam.rotation.y += delta * 1.5
		(beam.material_override as StandardMaterial3D).albedo_color.a = 0.25 + sin(t * 4.0) * 0.15
		var core: MeshInstance3D = tp.core
		core.rotation.y -= delta * 2.5
		(core.material_override as StandardMaterial3D).albedo_color.a = 0.5 + cos(t * 6.0) * 0.2
		var rings: Array = tp.rings
		for r in rings.size():
			var ring: MeshInstance3D = rings[r]
			var dir := 1.0 if r % 2 == 0 else -1.0
			ring.rotation.z += delta * (2.0 + r * 0.8) * dir
			ring.position.y = 15.0 + r * 45.0 + sin(t * 3.0 + r) * 12.0
			ring.scale = Vector3.ONE * (1.0 + sin(t * 2.0 + r) * 0.15)
		if randf() < 0.8:
			for k in 3:
				var angle := t * 8.0 + (k * TAU / 3.0)
				var radius := 30.0 + sin(t * 5.0 + k) * 10.0
				var p: Vector3 = tp.position
				fx.emit_particle(p.x + cos(angle) * radius, p.y + randf() * 20.0, p.z + sin(angle) * radius,
					-sin(angle) * 40.0, 120.0 + randf() * 80.0, cos(angle) * 40.0,
					0x38bdf8 if k % 2 == 0 else 0xc084fc, 10.0, 0.8)
		if dist_sq <= 75.0 * 75.0 and teleporter_cooldown <= 0.0:
			teleporter_cooldown = 3.0
			audio.play_sound("spell3.wav", 0.9)
			ui.flash_screen("xp", 0.8, 350)
			fx.create_floating_text("LEVEL COMPLETE! TELEPORTING...", player_pos, "#38bdf8")
			generate_and_load_new_level(true)
			return
