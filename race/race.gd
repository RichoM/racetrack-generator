extends Spatial


enum CameraMode {
	THIRD_PERSON = 0,
	COCKPIT = 1,
	TOPDOWN = 2
}

export(CameraMode) var camera_mode := CameraMode.THIRD_PERSON

var track_settings : Dictionary
var track : Track

onready var cars := $"%cars"
onready var debug_label := $"%debug_label"

var follow_car_idx := 0

func _ready():
	camera_mode = Globals.settings.get("camera_view", 0)
	
	if track == null: 
		track = $track
	else:
		$track.queue_free()
		add_child(track)
	
	var i = 0
	for car in cars.get_children():
		car.track = track
		car.color_idx = i
		if i == 0:
			car.driver = Player.new()
		else:
			car.driver = Bot.new()
		i += 1
		
	track.start_countdown()
	yield(get_tree().create_timer(3), "timeout")
	for car in cars.get_children():
		car.input_enabled = true

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		var track_generator = load("res://generator/track_generator.tscn").instance()
		track_generator.track_settings = track_settings
		Globals.change_scene_to(track_generator)
		return
	
	if Input.is_action_just_pressed("change_view"):
		camera_mode += 1
		camera_mode %= 3
		Globals.update_settings_file(camera_mode)
		
	if Input.is_action_just_pressed("ui_focus_next"):
		follow_car_idx += 1
		follow_car_idx %= cars.get_child_count()
	elif Input.is_action_just_pressed("ui_focus_prev"):
		follow_car_idx -= 1
		follow_car_idx %= cars.get_child_count()

	var follow_car : Car = cars.get_child(follow_car_idx)
	debug_label.text = follow_car.debug_data()
	if camera_mode == CameraMode.THIRD_PERSON: 
		follow_car.chase_camera.current = true
	elif camera_mode == CameraMode.COCKPIT:
		follow_car.cockpit_camera.current = true
	elif camera_mode == CameraMode.TOPDOWN:
		follow_car.topdown_camera.current = true
		
	for car in cars.get_children():
		var engine_sfx : AudioStreamPlayer3D = car.engine_sfx
		if car == follow_car:
			engine_sfx.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		else: 
			engine_sfx.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
