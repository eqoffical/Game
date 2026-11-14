extends RigidBody3D

const SPEED := 3.0
const SIGHT_RANGE := 20.0
const MEMORY_TIME := 2.0	# keeps chasing this long after losing sight

var memory := 0.0

@onready var player: Node3D = get_tree().get_first_node_in_group("player")

func _ready() -> void:
	lock_rotation = true	# stop it tipping over when it bumps into things

func _physics_process(delta: float) -> void:
	if can_see_player():
		memory = MEMORY_TIME
	else:
		memory = maxf(memory - delta, 0.0)

	if memory <= 0.0:
		linear_velocity.x = 0.0
		linear_velocity.z = 0.0
		return

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() < 0.1:
		return
	var direction := to_player.normalized()

	linear_velocity.x = direction.x * SPEED
	linear_velocity.z = direction.z * SPEED
	$MeshInstance3D.rotation.y = atan2(-direction.x, -direction.z)

func can_see_player() -> bool:
	if global_position.distance_to(player.global_position) > SIGHT_RANGE:
		return false
	var from := global_position + Vector3.UP * 0.5
	var to := player.global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player
