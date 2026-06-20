extends Label

func _ready() -> void:
	var start_y = position.y
	var bounce_distance = 5.0  # How far it travels up and down
	var speed = 0.6             # How many seconds it takes to travel one direction

	# 1. Create a tween and tell it to loop forever
	var tween = create_tween().set_loops()
	
	# 2. Add the "Gravity" effect (Sine curve, easing in and out smoothly)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 3. Move UP
	tween.tween_property(self, "position:y", start_y - bounce_distance, speed)
	
	# 4. Move DOWN
	tween.tween_property(self, "position:y", start_y + bounce_distance, speed)
