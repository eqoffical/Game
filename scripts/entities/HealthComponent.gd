class_name HealthComponent
extends Node

signal health_changed(current_hp: float, max_hp: float)
signal damaged(amount: float)
signal died

@export var max_hp := 100.0
var current_hp: float

func _ready() -> void:
	current_hp = max_hp

func take_damage(amount: float) -> void:
	if current_hp <= 0.0:
		return	# already dead, don't fire died twice
	current_hp = maxf(current_hp - amount, 0.0)
	damaged.emit(amount)
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		died.emit()
