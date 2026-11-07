# HUD Controller updating stats, level depth, and current weapon
class_name HUD
extends CanvasLayer

const MinimapClass = preload("res://scripts/minimap.gd")

@onready var hp_label: Label = $MarginContainer/VBoxContainer/TopRow/HPLabel
@onready var xp_label: Label = $MarginContainer/VBoxContainer/TopRow/XPLabel
@onready var weapon_label: Label = $MarginContainer/VBoxContainer/BottomRow/WeaponLabel
@onready var minimap: Control = $MinimapContainer/Minimap

func update_stats(hp: int, max_hp: int, xp: int, level: int, weapon: String) -> void:
	if hp_label:
		hp_label.text = "HP: %d / %d" % [hp, max_hp]
	if xp_label:
		xp_label.text = "LVL: %d  XP: %d" % [level, xp]
	if weapon_label:
		weapon_label.text = "Weapon: " + weapon

func update_minimap(pos: Vector3, yaw: float, monsters: Array, walls: Array[Vector2]) -> void:
	if minimap and minimap.has_method("update_minimap"):
		minimap.update_minimap(pos, yaw, monsters, walls)
