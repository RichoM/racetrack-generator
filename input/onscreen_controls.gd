extends CanvasLayer

var hoffset := 60
var voffset := 10

var last_vw_size := Vector2.ZERO
onready var supports_multitouch : bool = Globals.supports_multitouch()

onready var left_button := $"%left_button"
onready var right_button := $"%right_button"
onready var accelerate_button := $"%accelerate_button"
onready var brake_button := $"%brake_button"


func _process(delta):
	var vw_size = get_viewport().get_visible_rect().size
	if vw_size == last_vw_size: return
	last_vw_size = vw_size
	
	var left = hoffset
	var bottom = vw_size.y - voffset
	var right = vw_size.x - hoffset
	
	left_button.position = Vector2(left, bottom)
	right_button.position = left_button.position + Vector2(133, 0)
	
	accelerate_button.position = Vector2(right, bottom)
	brake_button.position = accelerate_button.position - Vector2(133, 0)
	
func show():
	for btn in get_children(): 
		btn.show()
	
func hide():
	for btn in get_children(): 
		btn.hide()
		
func set_color(color):
	for btn in get_children():
		btn.modulate = color
