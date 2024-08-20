tool
extends Spatial
class_name Track

var is_dirty = true

var curve : Curve3D setget , get_curve
func get_curve() -> Curve3D: return $path.curve

export var track_width := 20.0 setget set_track_width
func set_track_width(val):
	if val == track_width: return
	track_width = val
	force_update()

export var curb_threshold := 0.95 setget set_curb_threshold
func set_curb_threshold(val):
	if val == curb_threshold: return
	curb_threshold = val
	force_update()
	
export var curb_offset := 0.0 setget set_curb_offset
func set_curb_offset(val):
	if val == curb_offset: return
	curb_offset = val
	force_update()
	
export var curb_width := 3.0 setget set_curb_width
func set_curb_width(val):
	if val == curb_width: return
	curb_width = val
	force_update()
	
func _ready():
	force_update()

func force_update():
	is_dirty = true
	call_deferred("update")
	
func update():
	if !is_dirty: return
	is_dirty = false
		
	update_road()
	update_curb($left_curb/curb, -1)
	update_curb($right_curb/curb, 1)
	update_curb_path($left_curb, -1)
	update_curb_path($right_curb, 1)
			
func update_road():
	var road : CSGPolygon = $path/road
	if !road: return
	var x = track_width/2
	var y = 0.12
	var points = [Vector2(-x, 0), Vector2(-x, y),Vector2(x,y), Vector2(x, 0)]
	road.polygon = PoolVector2Array(points)

func update_curb(curb : CSGPolygon, direction):
	if !curb: return
	var x = curb_width
	var y = 0.1
	var points = [Vector2(x * direction, 0), Vector2(x * direction, y),Vector2(0,y), Vector2(0, 0)]
	curb.polygon = PoolVector2Array(points)


func update_curb_path(curb, direction):
	if !curb: return
	var curb_path = Curve3D.new()
	
	var road_path = $path.curve
	var road_length = road_path.get_baked_length()
	var full_count = floor(road_length/2)
	var real_dist = road_length / full_count
		
	var offset = 0
	var counter := 0
	var last_point : Vector3
	
	for i in range(full_count):
		var prev : Vector3 = road_path.interpolate_baked(offset - 25)
		var curr : Vector3 = road_path.interpolate_baked(offset)
		var next : Vector3 = road_path.interpolate_baked(offset + 25)
		
		var curr_prev := (curr - prev).normalized()
		var next_curr := (next - curr).normalized()
		var dot := curr_prev.dot(next_curr)
		if offset < 25: dot = 1
				
		var v = Vector3.ZERO
		var is_curb = abs(dot) <= curb_threshold
		var add_point = true
		
		if is_curb: 
			v = Vector3.RIGHT * (track_width * 0.5 + curb_offset)
		else:
			if counter > 15:
				counter = 0
			else:
				counter += 1
				add_point = i == 0 || i == full_count - 1
				
		if add_point: 
			var xf = Transform()
			xf.origin = road_path.interpolate_baked(offset)
			var lookat = (road_path.interpolate_baked(offset + 0.1) - xf.origin).normalized()
			var up = Vector3.UP
			xf.basis.z = lookat
			xf.basis.x = lookat.cross(up).normalized()
			xf.basis.y = xf.basis.x.cross(lookat).normalized()
			var v3 = xf.xform(v * direction)
			v3.y = 0 if is_curb else -1
			if last_point.distance_to(v3) > 5:
				curb_path.add_point(v3)
				last_point = v3
		offset += real_dist
	
	curb.curve = curb_path

func _on_path_curve_changed():
	force_update()

func get_length():
	return get_curve().get_baked_length()

func get_offset_at_point(point):
	return get_curve().get_closest_offset(point)

func get_closest_point(point):
	return get_curve().get_closest_point(point)
	
func get_closest_point_to_left_curb(point):
	return $left_curb.curve.get_closest_point(point)

func get_closest_point_to_right_curb(point):
	return $right_curb.curve.get_closest_point(point)
	
func get_point_at_offset(offset):
	return get_curve().interpolate_baked(offset)

func start_countdown():
	$start_finish/animation.play("race_begin")
