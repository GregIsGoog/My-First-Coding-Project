extends Node2D

var open_ui: bool = false

func _physics_process(delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _process(delta):
	if not open_ui:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	elif open_ui:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func die():
	_physics_process(false)
