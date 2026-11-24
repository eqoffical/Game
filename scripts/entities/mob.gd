extends RigidBody3D

const SPEED := 3.0
const SIGHT_RANGE := 20.0
const MEMORY_TIME := 2.0	# keeps chasing this long after losing sight
const ATTACK_RANGE := 1.8
const ATTACK_DAMAGE := 15.0
const ATTACK_COOLDOWN := 1.0
const PAIN_TIME := 0.25		# freeze in place (even mid-air) when hit
const PAIN_COOLDOWN := 1.0	# no new flinch until this long after the last one (includes PAIN_TIME)

var memory := 0.0
var attack_timer := 0.0
var pain_timer := 0.0
var pain_cooldown := 0.0
var _saved_velocity := Vector3.ZERO

@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
	lock_rotation = true	# stop it tipping over when it bumps into things
	if health_component:
		health_component.damaged.connect(_on_damaged)
		health_component.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	pain_cooldown = maxf(pain_cooldown - delta, 0.0)
	if pain_timer > 0.0:
		pain_timer -= delta
		if pain_timer <= 0.0:
			freeze = false
			linear_velocity = _saved_velocity
		return

	attack_timer = maxf(attack_timer - delta, 0.0)

	if player == null or not is_instance_valid(player):
		return

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
	var distance := to_player.length()
	if distance < 0.1:
		return
	var direction := to_player.normalized()

	linear_velocity.x = direction.x * SPEED
	linear_velocity.z = direction.z * SPEED
	$MeshInstance3D.rotation.y = atan2(-direction.x, -direction.z)

	if distance <= ATTACK_RANGE and attack_timer <= 0.0:
		_attack_player()

func _attack_player() -> void:
	var player_health := player.get_node_or_null("HealthComponent") as HealthComponent
	if player_health != null:
		player_health.take_damage(ATTACK_DAMAGE)
		attack_timer = ATTACK_COOLDOWN

func _on_damaged(_amount: float) -> void:
	if pain_cooldown > 0.0:
		return	# still takes the damage, just doesn't flinch
	_saved_velocity = linear_velocity
	set_deferred("freeze", true)	# deferred: the hit usually arrives mid physics step
	pain_timer = PAIN_TIME
	pain_cooldown = PAIN_COOLDOWN

func _on_died() -> void:
	queue_free()

func can_see_player() -> bool:
	if global_position.distance_to(player.global_position) > SIGHT_RANGE:
		return false
	var from := global_position + Vector3.UP * 0.5
	var to := player.global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player
