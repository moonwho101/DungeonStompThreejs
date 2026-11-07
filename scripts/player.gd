# Player controller for Dungeon Stomp Godot 4.7.2
class_name Player
extends Node3D

const CollisionSystemClass = preload("res://scripts/collision.gd")

signal stats_changed(hp, max_hp, xp, level, weapon_name)

@export var move_speed: float = 320.0
@export var sprint_speed: float = 560.0
@export var mouse_sensitivity: float = 0.002

var hp: int = 100
var max_hp: int = 100
var xp: int = 0
var level: int = 1
var god_mode: bool = false

var velocity: Vector3 = Vector3.ZERO
var is_grounded: bool = false
var yaw: float = 0.0
var pitch: float = 0.0

var collision_system: RefCounted = null
var monsters_ref: Array = []

const WEAPONS = [
	"Axe", "Flamesword", "Bastard Sword", "Battle Axe", "Ice Sword",
	"Lightning Sword", "Morning Star", "Spiked Flail", "Split Sword", "Super Flamesword",
	"Magic Missile", "Fireball", "Lightning", "Healing"
]
var current_weapon_idx: int = 0

@onready var camera: Camera3D = $Camera3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("stats_changed", hp, max_hp, xp, level, get_current_weapon_name())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -deg_to_rad(85), deg_to_rad(85))
		rotation.y = yaw
		if camera:
			camera.rotation.x = pitch

	if event.is_action_pressed("cycle_weapon"):
		cycle_weapon(1)
	elif event.is_action_pressed("prev_weapon"):
		cycle_weapon(-1)
	elif event.is_action_pressed("toggle_god_mode"):
		god_mode = not god_mode
		print("God mode:", god_mode)
	elif event.is_action_pressed("attack"):
		perform_attack()

func cycle_weapon(dir: int) -> void:
	current_weapon_idx = (current_weapon_idx + dir + WEAPONS.size()) % WEAPONS.size()
	emit_signal("stats_changed", hp, max_hp, xp, level, get_current_weapon_name())

func get_current_weapon_name() -> String:
	return WEAPONS[current_weapon_idx]

func perform_attack() -> void:
	var weapon = get_current_weapon_name()
	if weapon == "Healing":
		hp = min(max_hp, hp + 25)
		emit_signal("stats_changed", hp, max_hp, xp, level, weapon)
		return

	# Attack damage based on weapon type
	var damage = 25
	var attack_range = 100.0
	if weapon.contains("Super") or weapon == "Lightning":
		damage = 60
	elif weapon.contains("Fireball") or weapon.contains("Sword"):
		damage = 40

	if weapon == "Fireball" or weapon == "Magic Missile" or weapon == "Lightning":
		attack_range = 400.0

	var aim_dir = -transform.basis.z
	for m in monsters_ref:
		if is_instance_valid(m) and m.get("state") != 5: # not DEATH
			var m_pos = m.get_pos() if m.has_method("get_pos") else m.global_position
			var to_m = m_pos - global_position
			if to_m.length() <= attack_range:
				var forward_dot = aim_dir.dot(to_m.normalized())
				if forward_dot > 0.4:
					m.take_damage(damage)
					add_xp(20)
					break

func take_damage(amount: int) -> void:
	if god_mode:
		return
	hp = max(0, hp - amount)
	emit_signal("stats_changed", hp, max_hp, xp, level, get_current_weapon_name())

func add_xp(amount: int) -> void:
	xp += amount
	if xp >= level * 100:
		level += 1
		max_hp += 20
		hp = max_hp
	emit_signal("stats_changed", hp, max_hp, xp, level, get_current_weapon_name())

func update_physics(delta: float) -> void:
	var forward = -transform.basis.z
	var right = transform.basis.x
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	var move_dir = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		move_dir += forward
	if Input.is_action_pressed("move_back"):
		move_dir -= forward
	if Input.is_action_pressed("move_left"):
		move_dir -= right
	if Input.is_action_pressed("move_right"):
		move_dir += right

	if move_dir != Vector3.ZERO:
		move_dir = move_dir.normalized()
		var speed = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1000.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 1000.0 * delta)

	# Gravity and jumping
	if not is_grounded:
		velocity.y -= CollisionSystemClass.GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = CollisionSystemClass.JUMP_SPEED
		is_grounded = false

	var new_pos = global_position + velocity * delta

	if collision_system:
		var res = collision_system.resolve_capsule(
			new_pos,
			CollisionSystemClass.CAPSULE_RADIUS,
			CollisionSystemClass.CAPSULE_HEIGHT,
			velocity,
			CollisionSystemClass.EYE_HEIGHT
		)
		global_position = res.position
		velocity = res.velocity
		is_grounded = res.grounded
	else:
		global_position = new_pos
