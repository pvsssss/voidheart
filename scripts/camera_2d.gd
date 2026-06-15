extends Camera2D

func _ready() -> void:
	var screen_size = get_viewport_rect().size
	global_position = screen_size / 2.0
