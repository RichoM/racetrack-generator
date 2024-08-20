extends KinematicBody
class_name Car

export var acceleration := 1.125
export var turnSpeed := 0.008
export var friction := 0.011

export var wheelBase := 5

var fences : Spatial # TODO(Richo): Maybe use a custom type here??

var track : Track setget set_track
var track_length

func set_track(t):
	track = t
	track_length = track.get_length()
	
var driver

var car_rotation := 0.0
var car_speed := 0.0
var car_steering := 0.0
var steer_multiplier := 0.0

var velocity := Vector2.ZERO

var is_on_road := true
var is_on_curb := false

onready var car_body = $"%body"
onready var ground_ray = $mesh/ground_ray
onready var engine_sfx : AudioStreamPlayer3D = $engine_sfx

onready var wheel_back_left = $mesh/body/wheel_back_left
onready var wheel_back_right = $mesh/body/wheel_back_right
onready var wheel_front_left = $mesh/body/wheel_front_left
onready var wheel_front_right = $mesh/body/wheel_front_right

export var input_enabled = false

var checkpoints = []
var laps = 0
var track_begin = 0
var lap_begin = 0
var cur_time = 0
var last_time = 0
var best_time = INF
var tot_time = 0

var current_offset := 0
var current_progress := -1.0
var wrong_way_counter := 0

var front_wheels_position : Vector3 setget , get_front_wheels_position
func get_front_wheels_position() -> Vector3: 
	return $front_wheel.global_transform.origin

var back_wheels_position : Vector3 setget , get_back_wheels_position
func get_back_wheels_position() -> Vector3: 
	return $back_wheel.global_transform.origin

onready var chase_camera : Camera = $"%chase"
onready var cockpit_camera : Camera = $"%cockpit"
onready var topdown_camera : Camera = $"%topdown"

signal lap_completed(lap_counter, lap_time, total_time)
signal wrong_checkpoint()
signal wrong_way()

var color_idx := 0
const colors := [
	preload("res://cars/colors/red.material"),
	preload("res://cars/colors/green.material"),
	preload("res://cars/colors/yellow.material"),
	preload("res://cars/colors/blue.material"),
	preload("res://cars/colors/purple.material"),
]

func debug_data():
	var data := []
	data.append("FPS: %d" % [Engine.get_frames_per_second()])
	data.append("Speed: %.2f" % [car_speed])
	data.append("Progress: %.2f" % [current_progress])
	data.append("Offset: %d/%d" % [current_offset, track_length])
	data.append("Rotation: %s" % [global_transform.basis.get_euler()])
	if driver:
		driver.append_debug_data(self, data)
	return "\n".join(data)

func _ready():
	car_rotation = global_transform.basis.get_euler().y
	engine_sfx.play()
	
	
func get_local_input() -> Dictionary:
	if driver != null:
		return driver.get_local_input(self)
	else:
		return {
			accelerate = false,
			brake = false,
			steer_left = false,
			steer_right = false
		}
	
func _physics_process(delta):
	update_progress()
	update_times()
	update_color()
	
	handle_input()
	update_velocity_and_rotation()
	apply_velocity_and_rotation()
	update_wheels()
	limit_speed()
	
#	check_collisions_with_other_cars()
	check_collisions_with_track()
		
	update_topdown_camera()
	update_chase_camera()
	update_engine_sfx()
			
func update_progress():
	if track == null: return
	
	var previous_progress = current_progress
	current_offset = track.get_offset_at_point(global_transform.origin)
	current_progress = current_offset/track_length
	if previous_progress < 0: return
	
	var previous_section = get_section(previous_progress)
	var current_section = get_section(current_progress)
	if previous_section != current_section:
		entered_checkpoint(current_section, 4)
		
	if previous_progress < current_progress && car_speed > 0:
		wrong_way_counter += 1
		if wrong_way_counter >= 120:
			wrong_way_counter = 0
			emit_signal("wrong_way")
	else:
		wrong_way_counter = 0

func get_section(progress):
	return int(progress*4) % 4

func entered_checkpoint(checkpoint : int, total : int):
	print("Enter checkpoint: ", checkpoint, "/", total)
	var now = OS.get_ticks_msec()
	
	if checkpoints.size() == 0:
		if checkpoint != 0:
			print("Wrong checkpoint!")
			emit_signal("wrong_checkpoint")
			return
	else:
		var last_checkpoint = checkpoints.back()
		if checkpoint == 0 and last_checkpoint == total - 1:
			print("Lap end!")
			laps += 1
			last_time = now - lap_begin
			if last_time < best_time: 
				best_time = last_time
			print("TIME: ", last_time)
			emit_signal("lap_completed", laps, last_time, tot_time)
			checkpoints.clear()
		elif checkpoint <= last_checkpoint or checkpoint - last_checkpoint != 1: 
			print("Wrong checkpoint!")
			emit_signal("wrong_checkpoint")
			return
	
	checkpoints.append(checkpoint)
	if checkpoints.size() == 1:
		print("Lap begin!")
		lap_begin = now
		if laps == 0:
			print("Track begin!")
			track_begin = now
	else:
		print("Checkpoint!")
		
func update_times():
	if track_begin > 0: 
		var now = OS.get_ticks_msec()
		tot_time = now - track_begin
		cur_time = now - lap_begin
		
func update_color():
	car_body.material_override = colors[color_idx]
		
func handle_input():
	if !input_enabled: return
	
	var input := get_local_input()
	if input.accelerate:
		car_speed += acceleration
	if input.brake:
		if car_speed > 0:
			car_speed -= acceleration*1.25
		else:
			car_speed -= acceleration*0.5
	
	var x = car_speed
	var y = -0.05*x+5
	steer_multiplier = clamp(y, 1, 3.75)
	if input.steer_left:
		car_steering -= turnSpeed*steer_multiplier
	if input.steer_right:
		car_steering += turnSpeed*steer_multiplier
		
func update_velocity_and_rotation():
	if abs(car_speed) < 0.1: return
	
	var delta = 0.016 # HACK(Richo): Assumes 60 FPS
	
	var car_position = Vector2(global_transform.origin.x, global_transform.origin.z)
	var frontWheel = car_position + wheelBase/2 * Vector2(cos(car_rotation), sin(car_rotation))
	var backWheel = car_position - wheelBase/2 * Vector2(cos(car_rotation), sin(car_rotation))
	
	var fwd = (frontWheel - backWheel).normalized()
	var dot = fwd.dot(velocity.normalized())
	
	backWheel += car_speed * delta * Vector2(cos(car_rotation), sin(car_rotation))
	frontWheel += car_speed * delta * Vector2(cos(car_rotation+car_steering), sin(car_rotation+car_steering))
	var new_position = (frontWheel + backWheel)/2.0
	var new_rotation = atan2(frontWheel.y - backWheel.y, frontWheel.x - backWheel.x)
	var new_velocity = new_position - car_position
		
	if abs(dot) > 0.9:
		velocity = new_velocity
	else:
		velocity += new_velocity
	
	car_rotation = new_rotation # TODO(Richo): lerp?
	
	# Update wheel markers
	$front_wheel.global_transform.origin = Vector3(frontWheel.x, $front_wheel.global_transform.origin.y, frontWheel.y)
	$back_wheel.global_transform.origin = Vector3(backWheel.x, $back_wheel.global_transform.origin.y, backWheel.y)
		
func apply_velocity_and_rotation():
	var collision = move_and_collide(Vector3(velocity.x, 0, velocity.y))
	if collision != null:
		handle_collision(collision)
	
	global_transform.basis = Basis(Vector3.UP, -car_rotation)
	
func update_wheels():
	wheel_front_right.rotation.z = PI + clamp(car_steering*5, -0.95, 0.95)
	wheel_front_left.rotation.z = PI + clamp(car_steering*5, -0.95, 0.95)
	
	var wheel_rotation_speed = -car_speed/300
	wheel_back_left.get_node("wheel").rotate_object_local(Vector3.RIGHT, wheel_rotation_speed)
	wheel_back_right.get_node("wheel").rotate_object_local(Vector3.RIGHT, wheel_rotation_speed)
	wheel_front_left.get_node("wheel").rotate_object_local(Vector3.RIGHT, wheel_rotation_speed)
	wheel_front_right.get_node("wheel").rotate_object_local(Vector3.RIGHT, wheel_rotation_speed)

func limit_speed():
	velocity *= 0.9
	car_speed *= (1 - friction)
	car_steering *= 0.9
	if abs(car_steering) < turnSpeed/2: car_steering = 0
		
func check_collisions_with_track():
	if track == null: return
	
	var collisions := []
	
	# TODO(Richo): Calculate collisions with all four corners?
	calculate_collisions(global_transform.origin, collisions)
	
	if !collisions.empty():
		$animation.play("RESET")
	elif !is_on_road:
		if is_on_curb: 
			car_speed *= 0.98
			$animation.play("camera_shake")
			$animation.playback_speed = clamp(car_speed/50, 0, 1)
		else:
			car_speed *= 0.965
			$animation.play("RESET")
	else:
		$animation.play("RESET")
		
func calculate_collisions(point, collisions):
	var closest_point_to_road = track.get_closest_point(point)
	$road_point.global_transform.origin = closest_point_to_road
	var distance_to_road = closest_point_to_road.distance_to(point)
	is_on_road = distance_to_road < track.track_width*0.5
	if is_on_road:
		is_on_curb = false
	else:
		is_on_curb = false
		var closest_point =  track.get_closest_point_to_left_curb(point)
		if closest_point.distance_to(point) < 3: 
			is_on_curb = true
		else:
			closest_point = track.get_closest_point_to_right_curb(point)
			if closest_point.distance_to(point) < 3:
				is_on_curb = true

		if fences != null && !is_on_curb:
			var closest_fence = null
			var closest_point_to_fence = null
			var closest_distance = INF
			var idx = 0
			
			for fence in fences.get_children():
				idx += 1
				closest_point = fence.get_node("path").curve.get_closest_point(point)
				get_node("fence_" + str(idx) + "_point").global_transform.origin = closest_point
				var distance = closest_point.distance_to(point)
				if closest_point_to_fence == null || distance < closest_distance:
					closest_point_to_fence = closest_point
					closest_distance = distance
					closest_fence = fence
			
			var distance_to_fence = closest_distance
			var distance_between_fence_and_road = closest_point_to_fence.distance_to(closest_point_to_road)
			if distance_to_road >= distance_between_fence_and_road:
				collisions.append(closest_point_to_fence)
				
func update_topdown_camera():
	if !topdown_camera.current: return
		
	var delta = clamp(lerp(0, 30, car_speed/100.0), 0, 30)
	var next_post_offset = fmod(current_offset + delta, track_length)
	var next_post : Vector3 = track.get_point_at_offset(next_post_offset)
	next_post.y = topdown_camera.global_transform.origin.y
	
	topdown_camera.global_transform.origin = lerp(topdown_camera.global_transform.origin, next_post, 0.01)
	topdown_camera.global_rotation = Vector3(deg2rad(-90), 0, 0)
	
func update_chase_camera():
	if !chase_camera.current: return
	
	chase_camera.h_offset = lerp(chase_camera.h_offset, car_steering * 7.5, 0.15)
	chase_camera.fov = lerp(50, 100, car_speed / 100)
	chase_camera.fov = clamp(chase_camera.fov, 40, 100)
	
func update_engine_sfx():
	if engine_sfx == null: return
	
	engine_sfx.pitch_scale = clamp(lerp(0.01, 1.0, car_speed / 120), 0.01, 2)
	engine_sfx.max_db = lerp(-20, 0, engine_sfx.pitch_scale/1.5) + 5
		
func get_forward_vector():
	# HACK(Richo): Instead of calculating the vector properly, we're using the front_wheels and
	# back_wheels marker objects (which were added for debugging purposes) and subtracting their
	# position. This means that if I ever remove these markers or stop updating their positions,
	# this method will fail.
	var front := get_front_wheels_position()
	var back := get_back_wheels_position()
	return front - back

func handle_collision(collision : KinematicCollision):
	var other_car := collision.collider as Car
	if other_car == null: return
	 
	var p1 := Vector2(global_transform.origin.x, global_transform.origin.z)
	var v1 := velocity
	
	var p2 := Vector2(other_car.global_transform.origin.x, other_car.global_transform.origin.z)
	var v2 := other_car.velocity
	
	# HACK(Richo): We assume both cars have the same mass, thus we can skip a few calculations
	var dp1 = p1 - p2
	var dv1 = v1 - v2
	var new_v1 = v1 - (dv1.dot(dp1) / dp1.length_squared()) * dp1 * 1.5
	
	var dp2 = p2 - p1
	var dv2 = v2 - v1
	var new_v2 = v2 - (dv2.dot(dp2) / dp2.length_squared()) * dp2 * 1.5
	
	velocity = new_v1
	other_car.velocity = new_v2
	
	#######
	var collision_point := collision.position
	var d := collision_point - global_transform.origin
	var forward_vector : Vector3 = get_forward_vector()
	var a := Vector2(forward_vector.x, forward_vector.z).normalized()
	var b := Vector2(d.x, d.z).normalized()
	var is_right := a.dot(Vector2(-b.y, b.x)) > 0
	var dot := a.dot(b)
	
	var delta_angle := clamp(dot, 0, 1) * deg2rad(5)
	if is_right:
		car_rotation += delta_angle
		other_car.car_rotation -= delta_angle
	else:
		car_rotation -= delta_angle
		other_car.car_rotation += delta_angle
		
	# TODO(Richo): Modify car_speed depending on the alignment between velocity and the forward_vector?
