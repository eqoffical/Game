class_name Sfx
extends RefCounted

const PITCH_JITTER := 0.05	# small random pitch change so repeats don't sound identical
const BUS := "SFX"


static func set_volume(linear: float) -> void:
	var bus := _bus_index()
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(linear, 0.0, 1.0)))
	AudioServer.set_bus_mute(bus, linear <= 0.0)


static func get_volume() -> float:
	var bus := _bus_index()
	return 0.0 if AudioServer.is_bus_mute(bus) else db_to_linear(AudioServer.get_bus_volume_db(bus))


# Positional sound. Pass an Array to pick one at random.
static func play_at(from: Node3D, sound: Variant, volume := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	_setup(p, sound, volume)
	from.get_tree().current_scene.add_child(p)
	p.global_position = from.global_position
	p.finished.connect(p.queue_free)
	p.play()


# Non-positional sound (own gun, own pain).
static func play_flat(from: Node, sound: Variant, volume := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	_setup(p, sound, volume)
	from.get_tree().current_scene.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func _setup(p, sound: Variant, volume: float) -> void:	# p: AudioStreamPlayer or AudioStreamPlayer3D
	p.stream = _pick(sound)
	p.volume_db = linear_to_db(volume)
	p.pitch_scale = randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	p.bus = BUS if AudioServer.get_bus_index(BUS) != -1 else &"Master"


static func _bus_index() -> int:
	var i := AudioServer.get_bus_index(BUS)
	return i if i != -1 else 0	# 0 = Master


static func _pick(sound: Variant) -> AudioStream:
	if sound is Array:
		return (sound as Array).pick_random()
	return sound
