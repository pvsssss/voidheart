extends CharacterBody2D

enum InputMode { KEYBOARD_MOUSE, CONTROLLER }

signal health_changed(current_health: int, max_health: int)

@export var move_speed: float = 400.0
var screen_size: Vector2
var input_mode: InputMode = InputMode.KEYBOARD_MOUSE

const STICK_DEADZONE: float = 0.2
const STICK_ROTATION_BASE: float = 12.0
const STICK_ROTATION_MAX: float = 40.0

# --- HEALTH & DAMAGE ---
@export var max_health: int = 6
var current_health: int

var is_invincible: bool = false
var invincibility_time: float = 1.0  # 1 second of safety after getting hit
var invincibility_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D  

const SPRITE_OFFSET: float = PI / 2.0

@export var bullet_scene: PackedScene
@onready var muzzle_left: Marker2D = $MuzzleLeft
@onready var muzzle_right: Marker2D = $MuzzleRight

const FIRE_RATE: float = 0.15  
var fire_timer: float = 0.0
var fire_from_left: bool = true

var aim_direction: Vector2 = Vector2.UP

# --- PHYSICS SEPARATION ---
var input_velocity: Vector2 = Vector2.ZERO
var knockback_velocity: Vector2 = Vector2.ZERO
var target_knockback: Vector2 = Vector2.ZERO  
func _ready() -> void:
	screen_size = get_viewport_rect().size
	rotation = aim_direction.angle() + SPRITE_OFFSET
	current_health = max_health  
	health_changed.emit(current_health, max_health)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
		input_mode = InputMode.KEYBOARD_MOUSE
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		if event is InputEventJoypadMotion and abs(event.axis_value) < STICK_DEADZONE:
			return
		input_mode = InputMode.CONTROLLER
		
func _physics_process(delta: float) -> void:
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0.0:
			is_invincible = false
			sprite.modulate = Color.WHITE

	_handle_movement(delta)
	
	# IMPROVEMENT 1: Combine the two forces.
	# Master velocity is now your engine power PLUS the bullet knockback
	velocity = input_velocity + knockback_velocity
	
	_handle_aim(delta)
	move_and_slide()
	_wrap()
	_handle_shoot(delta)
	
	# 1. The visual knockback smoothly accelerates toward the target (fixes the teleport)
	knockback_velocity = knockback_velocity.lerp(target_knockback, 20.0 * delta)
	
	# 2. The target force rapidly decays to zero (the friction)
	target_knockback = target_knockback.lerp(Vector2.ZERO, 12.0 * delta)
	
func _handle_shoot(delta: float) -> void:
	fire_timer -= delta
	if Input.is_action_pressed("shoot") and fire_timer <= 0.0:
		_fire()
		fire_timer = FIRE_RATE

func _fire() -> void:
	if not bullet_scene:
		return
		
	var bullet = bullet_scene.instantiate()
	
	var spawn_pos: Vector2
	if fire_from_left:
		spawn_pos = muzzle_left.global_position
	else:
		spawn_pos = muzzle_right.global_position
		
	fire_from_left = !fire_from_left
	
	var projectile_container = get_tree().current_scene.get_node_or_null("Projectiles")
	
	if projectile_container:
		projectile_container.add_child(bullet)
	else:
		get_tree().current_scene.add_child(bullet)
		
	bullet.init(spawn_pos, aim_direction)

func _handle_movement(delta: float) -> void:
	var direction := Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	).normalized()
	
	var desired_velocity = direction * move_speed

	# IMPROVEMENT 3: Apply your input ONLY to the input_velocity variable, not master velocity
	input_velocity = input_velocity.lerp(desired_velocity, 10.0 * delta)

func _handle_aim(delta: float) -> void:
	match input_mode:
		InputMode.KEYBOARD_MOUSE:
			aim_direction = global_position.direction_to(get_global_mouse_position())
			var target_angle: float = aim_direction.angle() + SPRITE_OFFSET
			rotation = lerp_angle(rotation, target_angle, 25.0 * delta)

		InputMode.CONTROLLER:
			var stick := _get_aim_stick()
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

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_invincible:
		return

	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	# IMPROVEMENT 4: Apply the massive push entirely to the separate knockback_velocity variable
	knockback_velocity = knockback_dir * 1200.0 
	
	var current_camera = get_viewport().get_camera_2d()
	if current_camera and current_camera.has_method("apply_shake"):
		current_camera.apply_shake(20.0)
	
	if current_health <= 0:
		_die()
	else:
		is_invincible = true
		invincibility_timer = invincibility_time
		if sprite:
			sprite.modulate = Color.RED
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.2)

func _die() -> void:
	get_tree().reload_current_scene()
