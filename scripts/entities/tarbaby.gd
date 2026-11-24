class_name Tarbaby
extends RigidBody3D
## Port of Quake's Spawn (monster_tarbaby), id1 tarbaby.qc + the engine bits it
## relies on (sv_phys.c SV_Physics_Toss / ClipVelocity, sv_move.c CheckBottom).
##
## Like the Quake engine, the physics are done by hand: the body is frozen as a
## kinematic body and moved with move_and_collide(), so Godot's solver never
## touches it. That is what makes the 1.5 overbounce and the mid-bounce
## relaunch behave like the original.
##
## Logic runs in 0.1 s "thinks" (QuakeC nextthink), physics runs every frame.

const U := 1.0 / 64.0			# Quake units -> meters (player 320 u/s ~= SPEED 5.0)

# --- engine ---
const THINK_TIME := 0.1
const GRAVITY := 10.0			# same as player.gd (Quake: 800 u/s^2)
const OVERBOUNCE := 1.5			# MOVETYPE_BOUNCE backoff
const STOP_SPEED := 60.0 * U	# lands for good if bounce-up speed is below this
const STEP_SIZE := 18.0 * U		# CheckBottom tolerance

# --- tarbaby.qc ---
const LAUNCH_FORWARD := 600.0 * U
const LAUNCH_UP := 200.0 * U
const LAUNCH_UP_RANDOM := 150.0 * U
const DAMAGE_SPEED := 400.0 * U	# only hurts if moving faster than this on impact
const DAMAGE_MIN := 10.0
const DAMAGE_RANDOM := 10.0
const HOPS_BEFORE_RELAUNCH := 4	# fly1..fly4 loops before the "spawn hop" relaunch

# --- ai.qc / fight.qc ---
const YAW_SPEED := 20.0			# degrees per think
const WALK_DIST := 2.0 * U		# per think while in the run loop
const RANGE_MELEE := 120.0 * U
const RANGE_NEAR := 500.0 * U
const RANGE_MID := 1000.0 * U
const SIGHT_RANGE := 20.0
const NIGHTMARE := false		# skill 3: no delay between attacks

enum MoveType { STEP, BOUNCE }
enum State { RUN, JUMP1, JUMP2, JUMP3, JUMP4, JUMP5, JUMP6, FLY1, FLY2, FLY3, FLY4 }
enum AttackState { STRAIGHT, MELEE, MISSILE }
enum RangeBand { MELEE, NEAR, MID, FAR }

var velocity := Vector3.ZERO
var move_type := MoveType.STEP
var on_ground := false
var touch_armed := false		# self.touch = Tar_JumpTouch

var next_state := State.RUN		# self.think
var think_timer := THINK_TIME	# self.nextthink - time
var cnt := 0
var attack_state := AttackState.STRAIGHT
var attack_finished := 0.0
var ideal_yaw := 0.0
var time := 0.0

var _hull_min := Vector3.ZERO	# local-space collision bounds
var _hull_max := Vector3.ZERO

@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@onready var health_component: HealthComponent = $HealthComponent


func _ready() -> void:
	add_to_group("tarbaby")
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true

	var shape_node := $CollisionShape3D as CollisionShape3D
	var aabb: AABB = shape_node.transform * shape_node.shape.get_debug_mesh().get_aabb()
	_hull_min = aabb.position
	_hull_max = aabb.end

	if health_component:
		health_component.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	time += delta
	if move_type == MoveType.BOUNCE:
		_physics_toss(delta)
	else:
		_run_think(delta)
		_physics_step(delta)


# ======================================================================
# Engine: think scheduling + physics
# ======================================================================

func _run_think(delta: float) -> void:
	think_timer -= delta
	if think_timer <= 0.0:
		_enter_state(next_state)


# SV_Physics_Toss
func _physics_toss(delta: float) -> void:
	_run_think(delta)
	if velocity.y > 0.0:
		on_ground = false
	if on_ground:
		return

	velocity.y -= GRAVITY * delta
	var col := move_and_collide(velocity * delta)
	if col == null:
		return

	# SV_Impact: touch runs before the velocity is clipped
	if touch_armed:
		_jump_touch(col.get_collider())

	var n := col.get_normal()
	velocity = _clip_velocity(velocity, n, OVERBOUNCE)
	if n.y > 0.7 and velocity.y < STOP_SPEED:
		on_ground = true
		velocity = Vector3.ZERO


# MOVETYPE_STEP: only falls when not on the ground, walking is done by _walk_move
func _physics_step(delta: float) -> void:
	if on_ground:
		return
	velocity.y -= GRAVITY * delta
	var col := move_and_collide(velocity * delta)
	if col and col.get_normal().y > 0.7:
		on_ground = true
		velocity = Vector3.ZERO


# ClipVelocity
func _clip_velocity(v: Vector3, normal: Vector3, overbounce: float) -> Vector3:
	var out := v - normal * (v.dot(normal) * overbounce)
	for i in 3:
		if absf(out[i]) < 0.1 * U:
			out[i] = 0.0
	return out


# SV_CheckBottom (slow path): ground under the centre and all four corners,
# no corner more than STEP_SIZE below the centre.
func _check_bottom() -> bool:
	const INSET := 0.02
	var y := _hull_min.y
	var mid := _ground_y(Vector3((_hull_min.x + _hull_max.x) * 0.5, y, (_hull_min.z + _hull_max.z) * 0.5))
	if is_nan(mid):
		return false
	for cx in [_hull_min.x + INSET, _hull_max.x - INSET]:
		for cz in [_hull_min.z + INSET, _hull_max.z - INSET]:
			var g := _ground_y(Vector3(cx, y, cz))
			if is_nan(g) or mid - g > STEP_SIZE:
				return false
	return true


func _ground_y(local_point: Vector3) -> float:
	var from := global_transform * (local_point + Vector3.UP * 0.05)
	var to := from + Vector3.DOWN * (2.0 * STEP_SIZE + 0.05)
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return NAN if hit.is_empty() else hit.position.y


# PF_changeyaw (degrees, Godot yaw: 0 = facing -Z)
func _change_yaw() -> void:
	var move := clampf(wrapf(ideal_yaw - rotation_degrees.y, -180.0, 180.0), -YAW_SPEED, YAW_SPEED)
	rotation_degrees.y = wrapf(rotation_degrees.y + move, -180.0, 180.0)


func _facing_ideal() -> bool:
	return absf(wrapf(rotation_degrees.y - ideal_yaw, -180.0, 180.0)) <= 45.0


func _yaw_to(target: Vector3) -> float:
	var dir := target - global_position
	return rad_to_deg(atan2(-dir.x, -dir.z))


func _forward() -> Vector3:
	return -global_basis.z


# ======================================================================
# tarbaby.qc
# ======================================================================

# Tar_JumpTouch
func _jump_touch(other: Object) -> void:
	var hc: HealthComponent = null
	if other is Node and not (other as Node).is_in_group("tarbaby"):
		hc = (other as Node).get_node_or_null("HealthComponent") as HealthComponent
	if hc:
		if velocity.length() > DAMAGE_SPEED:
			hc.take_damage(DAMAGE_MIN + DAMAGE_RANDOM * randf())
			# sound: blob/hit1
	else:
		pass	# sound: blob/land1

	if not _check_bottom():
		if on_ground:	# stuck somewhere it can't stand: go back to walking
			touch_armed = false
			next_state = State.RUN
			move_type = MoveType.STEP
			think_timer = THINK_TIME
		return			# not on ground yet, keep bouncing

	touch_armed = false
	next_state = State.JUMP1
	think_timer = THINK_TIME


# QuakeC "[ $frame, next ] { code }": think/nextthink are set first,
# then the code runs and may override them.
func _enter_state(s: State) -> void:
	think_timer = THINK_TIME
	match s:
		State.RUN:
			next_state = State.RUN
			_ai_run(WALK_DIST)

		State.JUMP1, State.JUMP2, State.JUMP3, State.JUMP4:
			next_state = (s + 1) as State
			_ai_face()

		State.JUMP5:	# the launch
			next_state = State.JUMP6
			move_type = MoveType.BOUNCE
			touch_armed = true
			global_position.y += U
			velocity = _forward() * LAUNCH_FORWARD + Vector3.UP * (LAUNCH_UP + randf() * LAUNCH_UP_RANDOM)
			on_ground = false
			cnt = 0

		State.JUMP6:
			next_state = State.FLY1

		State.FLY1, State.FLY2, State.FLY3:
			next_state = (s + 1) as State

		State.FLY4:
			next_state = State.FLY1
			cnt += 1
			if cnt == HOPS_BEFORE_RELAUNCH:	# "spawn hop": still airborne, launch again
				_enter_state(State.JUMP5)


# ======================================================================
# ai.qc / fight.qc
# ======================================================================

func _ai_face() -> void:
	if _has_player():
		ideal_yaw = _yaw_to(player.global_position)
	_change_yaw()


func _ai_run(dist: float) -> void:
	if not _has_player() or not _can_see_player():
		return

	var r := global_position.distance_to(player.global_position)
	ideal_yaw = _yaw_to(player.global_position)

	# ai_run_melee / ai_run_missile: th_melee == th_missile == tbaby_jump1
	if attack_state == AttackState.MELEE or attack_state == AttackState.MISSILE:
		_change_yaw()
		if _facing_ideal():
			attack_state = AttackState.STRAIGHT
			_enter_state(State.JUMP1)
		return

	if _check_attack(_range_of(r)):
		return

	# movetogoal, simplified: turn toward the player and step, never off a ledge
	_change_yaw()
	_walk_move(dist)


func _range_of(r: float) -> RangeBand:
	if r < RANGE_MELEE:
		return RangeBand.MELEE
	if r < RANGE_NEAR:
		return RangeBand.NEAR
	if r < RANGE_MID:
		return RangeBand.MID
	return RangeBand.FAR


# CheckAttack
func _check_attack(rng: RangeBand) -> bool:
	if rng == RangeBand.MELEE:
		attack_state = AttackState.MELEE
		return true
	if time < attack_finished or rng == RangeBand.FAR:
		return false
	var chance := 0.2 if rng == RangeBand.NEAR else 0.05
	if randf() < chance:
		attack_state = AttackState.MISSILE
		# SUB_AttackFinished
		cnt = 0
		if not NIGHTMARE:
			attack_finished = time + 2.0 * randf()
		return true
	return false


func _walk_move(dist: float) -> void:
	var old := global_position
	move_and_collide(_forward() * dist)
	if not _check_bottom():
		global_position = old


func _has_player() -> bool:
	return player != null and is_instance_valid(player)


func _can_see_player() -> bool:
	if global_position.distance_to(player.global_position) > SIGHT_RANGE:
		return false
	var from := global_position + Vector3.UP * 0.5
	var to := player.global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player


func _on_died() -> void:
	queue_free()
