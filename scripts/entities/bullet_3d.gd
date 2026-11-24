extends Area3D

const SPEED := 30.0
const RANGE := 100.0
const DAMAGE := 25.0

var travelled_distance := 0.0
var shooter: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	var step := SPEED * delta
	global_position += -global_transform.basis.z * step
	travelled_distance += step
	if travelled_distance >= RANGE:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body == shooter:
		return
	_apply_damage_if_possible(body)
	queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area == shooter or area.get_parent() == shooter:
		return
	_apply_damage_if_possible(area)
	queue_free()

func _apply_damage_if_possible(target: Node) -> void:
	var health := _find_health_component(target)
	if health != null:
		health.take_damage(DAMAGE)

func _find_health_component(node: Node) -> HealthComponent:
	if node is HealthComponent:
		return node
	for child in node.get_children():
		if child is HealthComponent:
			return child
	var parent := node.get_parent()
	if parent != null:
		for child in parent.get_children():
			if child is HealthComponent:
				return child
	return null
