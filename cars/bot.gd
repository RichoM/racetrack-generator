extends Node
class_name Bot

func append_debug_data(car, data):
	pass

func get_local_input(car) -> Dictionary:
	var track : Track = car.track
	var next_post_offset = fmod(car.current_offset + 50, car.track_length)
	var next_post : Vector3 = track.get_point_at_offset(next_post_offset)
	car.get_node("next_post").global_transform.origin = next_post
	
	var car_position : Vector3 = car.global_transform.origin
	var a : Vector3 = (next_post - car_position).normalized()
	var b : Vector3 = (car.get_forward_vector()).normalized()
	
	var dot := a.dot(b)
	
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var is_right := a2.dot(Vector2(-b2.y, b2.x)) > 0
	
	var accelerate = dot > 0.85 || car.car_speed < 20
	var brake = dot < 0.7 && car.car_speed > 35
	var steer_left = dot < 0.975 && !is_right
	var steer_right = dot < 0.975 && is_right
#
	return {
		accelerate = accelerate,
		brake = brake,
		steer_left = steer_left,
		steer_right = steer_right
	}
