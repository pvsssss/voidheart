extends CanvasLayer

@onready var margin_container: MarginContainer = $MarginContainer
@onready var health_bar: TextureProgressBar = $MarginContainer/HealthBar

# Shake variables
var original_pos: Vector2
var shake_intensity: float = 0.0

func _ready() -> void:
	# Save the exact starting position of the container so we can snap back to it
	original_pos = margin_container.position

func _process(delta: float) -> void:
	# If a shake is active, apply randomized movement
	if shake_intensity > 0:
		var random_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		
		# Move the container to the random offset
		margin_container.position = original_pos + random_offset
		
		# Decay the shake extremely fast so it feels like an impact, not an earthquake
		shake_intensity = lerpf(shake_intensity, 0.0, 15.0 * delta)
		
		# Once it's barely shaking, stop completely and reset to normal
		if shake_intensity < 0.5:
			shake_intensity = 0.0
			margin_container.position = original_pos

func update_health(current: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	
	# Did we LOSE health? If so, trigger the violent shake!
	if current < health_bar.value:
		shake_intensity = 15.0  # Crank this up to 25.0 or 30.0 for a more violent hit!
		
		# Smoothly drain the red bar down to the new health value
		var tween = create_tween()
		tween.tween_property(health_bar, "value", current, 0.2)
	else:
		# If we gained health (or just started the game), update instantly without shaking
		health_bar.value = current
