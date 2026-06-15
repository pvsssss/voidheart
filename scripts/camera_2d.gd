extends Camera2D

var shake_intensity: float = 0.0

func _ready() -> void:
	var screen_size = get_viewport_rect().size
	global_position = screen_size / 2.0
	
func _process(delta: float) -> void:
	if shake_intensity > 0:
		# Randomly offset the camera by the intensity amount
		offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		
		# Decay the shake rapidly
		shake_intensity = lerpf(shake_intensity, 0.0, 15.0 * delta)
		
		if shake_intensity < 0.5:
			shake_intensity = 0.0
			offset = Vector2.ZERO

# This is the function we called from the player's take_damage script!
func apply_shake(intensity: float) -> void:
	shake_intensity = intensity
