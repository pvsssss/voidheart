extends Label

var time_passed: float = 0.0

func _process(delta: float) -> void:
	time_passed += delta
	
	# The abs(sin()) math makes the alpha (transparency) bounce smoothly between 0 (invisible) and 1 (solid)
	var alpha = abs(sin(time_passed * 3.0))
	
	# Apply it to the modulate (color/transparency) of the text
	modulate = Color(1.0, 1.0, 1.0, alpha)
