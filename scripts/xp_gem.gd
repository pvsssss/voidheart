extends Area2D

var target: Node2D = null
var is_magnetized: bool = false
var fly_speed: float = 0.0
var xp_value: int = 1

func _ready() -> void:
	# 1. Add a gentle floating "breathing" animation!
	var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($AnimatedSprite2D, "position:y", -4.0, 1.0)
	tween.tween_property($AnimatedSprite2D, "position:y", 0.0, 1.0)

	# 2. Connect the physical collection signal
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# 3. If a player got close, fly to them!
	if is_magnetized and target != null:
		# The speed rapidly accelerates the longer it flies
		fly_speed += 1500.0 * delta 
		var direction = global_position.direction_to(target.global_position)
		global_position += direction * fly_speed * delta

# This is called by the Player's Magnet Area!
func magnetize_to(player: Node2D) -> void:
	target = player
	is_magnetized = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# body.gain_xp(xp_value)  <-- We will uncomment this soon!
		
		# Optional: Add a tiny "ping" sound effect here!
		queue_free()
