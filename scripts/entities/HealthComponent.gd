class_name HealthComponent
extends Node

signal health_changed(current_hp: float, max_hp: float)
signal died

@export var max_hp: float = 100.0
@onready var current_hp: float = max_hp

func take_damage(amount: float) -> void:
	if current_hp <= 0.0:
		return
	current_hp = max(current_hp - amount, 0.0)
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	if current_hp <= 0.0:
		return
	current_hp = min(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)
