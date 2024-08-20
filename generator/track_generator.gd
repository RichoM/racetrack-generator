extends Spatial
tool

export var dirty_flag := true
export var point_distance := 70
export var control_distance := 40
export var offset_distance := 70
export var track_type := 0
export var curve_angle_limit := 0.1
export var rng_seed := 0

onready var track := $"%track"
onready var seed_value_label := $"%seed_value"
onready var topdown_camera := $"%topdown_camera"

var track_settings setget set_track_settings, get_track_settings

func set_track_settings(settings):
	rng_seed = settings.rng_seed
	track_type = settings.track_type
	curve_angle_limit = settings.curve_angle_limit
	point_distance = settings.point_distance
	control_distance = settings.control_distance
	offset_distance = settings.offset_distance

func get_track_settings():
	return {
		rng_seed = rng_seed,
		track_type = track_type,
		curve_angle_limit = curve_angle_limit,
		point_distance = point_distance,
		control_distance = control_distance,
		offset_distance = offset_distance
	}

func v3(p, m) -> Vector3:
	return Vector3(p[0] * m, 0, p[1] * m)
	
func _ready():
	randomize()
	dirty_flag = true
	
func generate_random_track():
	rng_seed = randi()
	dirty_flag = true
	
func _process(_delta):
	if Input.is_action_just_pressed("ui_accept"):
		generate_random_track()
		
	if dirty_flag:
		dirty_flag = false
		update_curve()
		update_camera()
		seed_value_label.text = str(rng_seed)
		
			
func update_curve():
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	
	track_type = rng.randi()
	
	if track == null: track = $"%track"
	var curve : Curve3D = track.curve
	curve.clear_points()
		
	for ppp in Tracks.get_curve(track_type):
		var p_pos := v3(ppp[0], point_distance)
		var p_in := v3(ppp[1], control_distance)
		var p_out := v3(ppp[2], control_distance)
		curve.add_point(p_pos, p_in, p_out)

	if rng_seed == 0: return
	
	for idx in range(1, curve.get_point_count() - 2):
		var prev := curve.get_point_position(idx - 1)
		var prev_out := prev + curve.get_point_out(idx - 1)
		
		var keep_going := true
		var cur : Vector3
		while keep_going:
			cur = curve.get_point_position(idx)
			cur.x += rng.randf_range(-offset_distance, offset_distance)
			cur.z += rng.randf_range(-offset_distance, offset_distance)
			
			var cur_in := cur + curve.get_point_in(idx)
			keep_going = !is_valid_angle(prev, prev_out, cur_in, cur)
		
		curve.set_point_position(idx, cur)
		
	fix_last_point(curve)
	
func fix_last_point(curve : Curve3D):
	var idx := curve.get_point_count() - 3
	var prev := curve.get_point_position(idx - 1)
	var prev_out := prev + curve.get_point_out(idx - 1)
	var cur := curve.get_point_position(idx)
	var cur_in := cur + curve.get_point_in(idx)
	var cur_out := cur + curve.get_point_out(idx)
	var next := curve.get_point_position(idx + 1)
	var next_in := next + curve.get_point_in(idx + 1)
	if is_valid_angle(prev, prev_out, cur_in, cur) \
		&& is_valid_angle(cur, cur_out, next_in, next):
		return
			
	var average := (prev + next) / 2.0
	curve.set_point_position(idx, average)
		
func is_valid_angle(a : Vector3, b : Vector3, c : Vector3, d : Vector3) -> bool:
	var ba := (a - b).normalized()
	var bc := (c - b).normalized()
	var cd := (d - c).normalized()
	var cb := (b - c).normalized()
	
	var dot1 := ba.dot(bc)
	var dot2 := cd.dot(cb)
	return dot1 < curve_angle_limit && dot2 < curve_angle_limit

func min_dist_to_previous_points(curve : Curve3D, point : Vector3, limit : int):
	var min_dist = INF
	for idx in range(0, limit):
		var p := curve.get_point_position(idx)
		var dist = point.distance_to(p)
		if dist < min_dist:
			min_dist = dist
	return min_dist


func _on_test_track_btn_pressed():
	var race := preload("res://race/race.tscn").instance()
	race.track = track.duplicate()
	race.track_settings = get_track_settings()
	Globals.change_scene_to(race)

func update_camera():
	var curve : Curve3D = track.curve
	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF
	var count = curve.get_point_count()
	for idx in range(count):
		var point := curve.get_point_position(idx)
		if point.x < min_x: min_x = point.x
		if point.x > max_x: max_x = point.x
		if point.z < min_y: min_y = point.z
		if point.z > max_y: max_y = point.z
	
	var center = Vector2((min_x+max_x)/2.0, (min_y+max_y)/2.0)
	print("Center: ", center)
	topdown_camera.global_transform.origin.x = center.x
	topdown_camera.global_transform.origin.z = center.y
		


func _on_randomize_btyn_pressed():
	generate_random_track()
