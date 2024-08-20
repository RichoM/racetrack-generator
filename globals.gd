extends Node

var settings := {}

var supports_multitouch = null

func _ready():
	Engine.target_fps = 30

func update_settings_file(camera_mode):
	pass

func supports_multitouch():
	if supports_multitouch != null: return supports_multitouch
	
	var result = OS.has_touchscreen_ui_hint()
	
	if OS.has_feature("JavaScript"):
		var max_touch_points = JavaScript.eval("navigator.maxTouchPoints")
		if max_touch_points != null:
			result = result && max_touch_points > 1
	
	supports_multitouch = result
	return result

func change_scene_to(next_scene):
	get_tree().get_root().add_child(next_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = next_scene
