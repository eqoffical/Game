extends Control

const GAME_SCENE_PATH := "res://scenes/levels/trenchbroom_test.tscn"

@onready var play_button: TextureButton = $StartButton
@onready var quit_button: TextureButton = $ExitButton

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_quit_pressed() -> void:
	get_tree().quit()
