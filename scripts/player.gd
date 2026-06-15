extends CharacterBody2D

enum InputMode { KEYBOARD_MOUSE, CONTROLLER }

var move_speed: float = 300.0
var screen_size: Vector2
var input_mode: InputMode = InputMode.KEYBOARD_MOUSE

const STICK_DEADZONE: float = 0.2
const MOUSE_MOVE_THRESHOLD: float = 2.0
const STICK_ROTATION_BASE: float = 12.0
const STICK_ROTATION_MAX: float = 40.0
const MOVEMENT_BLEND_SPEED: float = 8.0
const MOVEMENT_INFLUENCE: float = 0.12

# Tune this if the ship still faces the wrong direction:
# PI / 2.0  = sprite faces UP in texture   (most likely for you)
# 0.0       = sprite faces RIGHT in texture
# PI        = sprite faces DOWN in texture
# -PI / 2.0 = sprite faces LEFT in texture
const SPRITE_OFFSET: float = PI / 2.0

@export var bullet_scene: PackedScene
@onready var muzzle: Marker2D = $Muzzle  # adjust path if nested differently

const FIRE_RATE: float = 0.15  # seconds between shots
var fire_timer: float = 0.0

var last_mouse_position: Vector2 = Vector2.ZERO
var mouse_moved: bool = false
var aim_direction: Vector2 = Vector2.UP

func _ready() -> void:
	screen_size = get_viewport_rect().size
	last_mouse_position = get_global_mouse_position()
	rotation = aim_direction.angle() + SPRITE_OFFSET

func _physics_process(delta: float) -> void:
	_detect_input_mode()
	_handle_movement()
	_handle_aim(delta)
	move_and_slide()
	_wrap()
	_handle_shoot(delta) 

func _detect_input_mode() -> void:
	var stick := _get_aim_stick()
	var mouse_pos := get_global_mouse_position()
	mouse_moved = mouse_pos.distance_to(last_mouse_position) > MOUSE_MOVE_THRESHOLD
	last_mouse_position = mouse_pos

	if stick.length() > STICK_DEADZONE:
		input_mode = InputMode.CONTROLLER
	elif mouse_moved:
		input_mode = InputMode.KEYBOARD_MOUSE

func _handle_shoot(delta: float) -> void:
	fire_timer -= delta
	if Input.is_action_pressed("shoot") and fire_timer <= 0.0:
		_fire()
		fire_timer = FIRE_RATE

func _fire() -> void:
	if not bullet_scene:
		return
	var bullet = bullet_scene.instantiate()
	# Add to the main scene, not the player — so bullet doesn't inherit player transform
	get_tree().current_scene.add_child(bullet)
	bullet.init(muzzle.global_position, aim_direction)

func _handle_movement() -> void:
	var direction := Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	)
	velocity = direction.normalized() * move_speed

func _handle_aim(delta: float) -> void:
	var has_movement := velocity.length() > 10.0
	var movement_dir := velocity.normalized() if has_movement else aim_direction

	match input_mode:
		InputMode.KEYBOARD_MOUSE:
			if mouse_moved:
				aim_direction = global_position.direction_to(get_global_mouse_position())
				rotation = aim_direction.angle() + SPRITE_OFFSET
			elif has_movement:
				var target: float = movement_dir.angle()
				rotation = lerp_angle(rotation, target + SPRITE_OFFSET, MOVEMENT_BLEND_SPEED * delta)
				aim_direction = Vector2.from_angle(rotation - SPRITE_OFFSET)

		InputMode.CONTROLLER:
			var stick := _get_aim_stick()
			if stick.length() > STICK_DEADZONE:
				var blended := stick.normalized().lerp(movement_dir, MOVEMENT_INFLUENCE).normalized()
				var target: float = blended.angle()
				var speed: float = _adaptive_rotation_speed(rotation - SPRITE_OFFSET, target)
				rotation = lerp_angle(rotation, target + SPRITE_OFFSET, speed * delta)
				aim_direction = Vector2.from_angle(rotation - SPRITE_OFFSET)
			elif has_movement:
				var target: float = movement_dir.angle()
				var speed: float = _adaptive_rotation_speed(rotation - SPRITE_OFFSET, target)
				rotation = lerp_angle(rotation, target + SPRITE_OFFSET, speed * delta)
				aim_direction = Vector2.from_angle(rotation - SPRITE_OFFSET)

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
