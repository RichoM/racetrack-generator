extends Node
class_name Player

func append_debug_data(car, data):
	pass

func get_local_input(_car) -> Dictionary:
	return {
		accelerate = Input.is_action_pressed("accelerate"),
		brake = Input.is_action_pressed("brake"),
		steer_left = Input.is_action_pressed("steer_left"),
		steer_right = Input.is_action_pressed("steer_right")
	}
