extends Spatial

var camera_mode = 0

func _ready():
	OS.window_fullscreen = false

func _process(delta):
	if Input.is_action_just_pressed("change_view"):
		camera_mode += 1
		camera_mode %= 3
		
	$cameras.get_child(camera_mode).current = true
