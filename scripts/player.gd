extends CharacterBody2D

enum InputMode { KEYBOARD_MOUSE, CONTROLLER }

var move_speed: float = 300.0
var screen_size: Vector2
var input_mode: InputMode = InputMode.KEYBOARD_MOUSE

const STICK_DEADZONE: float = 0.2
const STICK_ROTATION_BASE: float = 12.0
const STICK_ROTATION_MAX: float = 40.0

# Tune this if the ship still faces the wrong direction:
# PI / 2.0  = sprite faces UP in texture   (most likely for you)
# 0.0       = sprite faces RIGHT in texture
# PI        = sprite faces DOWN in texture
# -PI / 2.0 = sprite faces LEFT in texture
const SPRITE_OFFSET: float = PI / 2.0

@export var bullet_scene: PackedScene
@onready var muzzle_left: Marker2D = $MuzzleLeft
@onready var muzzle_right: Marker2D = $MuzzleRight

const FIRE_RATE: float = 0.15  # seconds between shots
var fire_timer: float = 0.0
var fire_from_left: bool = true

var aim_direction: Vector2 = Vector2.UP

func _ready() -> void:
	screen_size = get_viewport_rect().size
	rotation = aim_direction.angle() + SPRITE_OFFSET

func _input(event: InputEvent) -> void:
	# If a Mouse or Keyboard is touched
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		input_mode = InputMode.KEYBOARD_MOUSE
		
	# If a Controller is touched
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		# Ignore tiny stick drifts so resting the controller doesn't override the mouse
		if event is InputEventJoypadMotion and abs(event.axis_value) < STICK_DEADZONE:
			return
		input_mode = InputMode.CONTROLLER

func _physics_process(delta: float) -> void:
	_handle_movement()
	_handle_aim(delta)
	move_and_slide()
	_wrap()
	_handle_shoot(delta) 

func _handle_shoot(delta: float) -> void:
	fire_timer -= delta
	if Input.is_action_pressed("shoot") and fire_timer <= 0.0:
		_fire()
		fire_timer = FIRE_RATE

func _fire() -> void:
	if not bullet_scene:
		return
		
	var bullet = bullet_scene.instantiate()
	
	# 1. Determine which muzzle to spawn the bullet from
	var spawn_pos: Vector2
	if fire_from_left:
		spawn_pos = muzzle_left.global_position
	else:
		spawn_pos = muzzle_right.global_position
		
	# Toggle the boolean so the next shot comes from the other side
	fire_from_left = !fire_from_left
	
	# 2. Find the Projectiles node in the main scene
	var projectile_container = get_tree().current_scene.get_node_or_null("Projectiles")
	
	# 3. Safely add the bullet to the container (with a fallback just in case)
	if projectile_container:
		projectile_container.add_child(bullet)
	else:
		get_tree().current_scene.add_child(bullet)
		
	# 4. Initialize the bullet
	bullet.init(spawn_pos, aim_direction)

func _handle_movement() -> void:
	var direction := Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	)
	velocity = direction.normalized() * move_speed

func _handle_aim(delta: float) -> void:
	match input_mode:
		InputMode.KEYBOARD_MOUSE:
			# ALWAYS track the mouse. The crosshair is absolute.
			aim_direction = global_position.direction_to(get_global_mouse_position())
			
			var target_angle: float = aim_direction.angle() + SPRITE_OFFSET
			rotation = lerp_angle(rotation, target_angle, 25.0 * delta)

		InputMode.CONTROLLER:
			var stick := _get_aim_stick()
			
			# Only update aim_direction if the right stick is actually pushed
			if stick.length() > STICK_DEADZONE:
				aim_direction = stick.normalized()
			
			var target_angle: float = aim_direction.angle() + SPRITE_OFFSET
			var speed: float = _adaptive_rotation_speed(rotation - SPRITE_OFFSET, target_angle)
			
			rotation = lerp_angle(rotation, target_angle, speed * delta)

func _adaptive_rotation_speed(from_angle: float, to_angle: float) -> float:
	var diff: float = abs(wrapf(to_angle - from_angle, -PI, PI)) / PI
	return lerpf(STICK_ROTATION_BASE, STICK_ROTATION_MAX, diff)

func _get_aim_stick() -> Vector2:
	return Vector2(
		Input.get_action_strength("aim_right") - Input.get_action_strength("aim_left"),
		Input.get_action_strength("aim_down") - Input.get_action_strength("aim_up")
	)

func _wrap() -> void:
	var pos := global_position
	var wrapped := false

	if pos.x < 0:
		pos.x = screen_size.x
		wrapped = true
	elif pos.x > screen_size.x:
		pos.x = 0
		wrapped = true
	if pos.y < 0:
		pos.y = screen_size.y
		wrapped = true
	elif pos.y > screen_size.y:
		pos.y = 0
		wrapped = true

	if wrapped:
		global_position = pos
		reset_physics_interpolation()
