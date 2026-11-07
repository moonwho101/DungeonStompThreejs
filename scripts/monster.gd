# Monster AI state machine for Dungeon Stomp Godot 4.7.2
class_name Monster
extends Node3D

const CollisionSystemClass = preload("res://scripts/collision.gd")

enum State {
	IDLE,
	ALERT,
	CHASE,
	ATTACK,
	HURT,
	DEATH
}

@export var monster_id: int = 1
@export var monster_name: String = "Skeleton"
@export var max_health: int = 60
@export var health: int = 60
@export var move_speed: float = 180.0
@export var attack_damage: int = 15
@export var attack_range: float = 80.0
@export var aggro_range: float = 600.0

var state: State = State.IDLE
var velocity: Vector3 = Vector3.ZERO
var attack_timer: float = 0.0
var hurt_timer: float = 0.0

var collision_system: RefCounted = null
var player_ref: Node = null

signal monster_died(monster)

func _ready():
	health = max_health
	# Add visual representation
	var visual = MeshInstance3D.new()
	var capsule_mesh = CapsuleMesh.new()
	capsule_mesh.radius = 18.0
	capsule_mesh.height = 70.0
	visual.mesh = capsule_mesh
	visual.position = Vector3(0, 35, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.2, 0.2)
	visual.material_override = mat
	add_child(visual)

func take_damage(damage: int) -> void:
	if state == State.DEATH:
		return
	health -= damage
	if health <= 0:
		die()
	else:
		state = State.HURT
		hurt_timer = 0.3

func die() -> void:
	state = State.DEATH
	visible = false
	emit_signal("monster_died", self)

func get_pos() -> Vector3:
	return global_position if is_inside_tree() else position

func set_pos(p: Vector3) -> void:
	if is_inside_tree():
		global_position = p
	else:
		position = p

func update_ai(delta: float, player_pos: Vector3) -> void:
	if state == State.DEATH:
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	if hurt_timer > 0.0:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			state = State.CHASE

	var my_pos = get_pos()
	var to_player = player_pos - my_pos
	var dist = to_player.length()

	match state:
		State.IDLE:
			if dist < aggro_range:
				if collision_system == null or collision_system.has_line_of_sight(my_pos + Vector3(0, 30, 0), player_pos):
					state = State.ALERT
		State.ALERT:
			state = State.CHASE
		State.CHASE:
			if dist <= attack_range:
				state = State.ATTACK
			else:
				var dir = to_player.normalized()
				velocity.x = dir.x * move_speed
				velocity.z = dir.z * move_speed
				if is_inside_tree():
					look_at(Vector3(player_pos.x, my_pos.y, player_pos.z), Vector3.UP)
		State.ATTACK:
			if dist > attack_range * 1.5:
				state = State.CHASE
			elif attack_timer <= 0.0:
				attack_timer = 1.0 # 1 attack per second
				if player_ref and player_ref.has_method("take_damage"):
					player_ref.take_damage(attack_damage)
		State.HURT:
			velocity.x = 0
			velocity.z = 0

	# Gravity and collision
	velocity.y -= CollisionSystemClass.GRAVITY * delta
	var target_pos = my_pos + velocity * delta

	if collision_system:
		var res = collision_system.resolve_capsule(
			target_pos,
			CollisionSystemClass.MONSTER_CAPSULE_RADIUS,
			CollisionSystemClass.MONSTER_CAPSULE_HEIGHT,
			velocity,
			CollisionSystemClass.MONSTER_FOOT_OFFSET
		)
		set_pos(res.position)
		velocity = res.velocity
	else:
		set_pos(target_pos)
