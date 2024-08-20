extends Node2D
	
func _process(delta):
	if !visible: return
	$sprite.frame = 1 if Input.is_action_pressed($button.action) else 0

func _on_button_pressed():
	$sprite.frame = 1

func _on_button_released():
	$sprite.frame = 0
