extends CharacterBody3D

var SENSITIVITY = 0.06

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(_delta: float) -> void:
	%ViewmodelCamera.global_transform = $PlayerCamera.global_transform	# Copying viewmodel to player camera
	%Shotgun.rotation.y = sin(Time.get_ticks_msec() / 200.0) * 0.05		# Temporary debug wobble, will delte it later

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * SENSITIVITY
		$PlayerCamera.rotation_degrees.x -= event.relative.y * SENSITIVITY
		$PlayerCamera.rotation_degrees.x = clamp($PlayerCamera.rotation_degrees.x, -90.0, 90.0)
