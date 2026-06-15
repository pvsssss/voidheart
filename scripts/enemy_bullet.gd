extends Area2D

@export var speed: float = 480.0
var direction: Vector2 = Vector2.ZERO
var lifetime: float = 2.0
var damage: int = 1

func _ready() -> void:
	# Connect the screen notifier to auto-free off-screen bullets
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	# Also connect collision
	body_entered.connect(_on_body_entered)

func init(spawn_position: Vector2, aim_direction: Vector2) -> void:
	global_position = spawn_position
	direction = aim_direction.normalized()
	rotation = aim_direction.angle() + PI / 2.0  # match your SPRITE_OFFSET

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# Check if the object we hit has the take_damage function (like our enemy does)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# Destroy the bullet after it hits something
	queue_free()
