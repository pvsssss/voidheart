extends CharacterBody2D

# --- THE STATE MACHINE ---
# Added the new APPROACH state
enum State { APPROACH, BURST, WAIT, CHARGE }
var current_state: State = State.APPROACH

@export var xp_gem_scene: PackedScene
@export var explosion_sound: AudioStream  # Drag your explosion .wav file here!
@export var speed: float = 180.0
@export var max_health: int = 3
@export var enemy_bullet_scene: PackedScene 
@export var weapon_spread: float = 0.35

@onready var sprite: Sprite2D = $Sprite2D 

var current_health: int
const SPRITE_OFFSET: float = -PI / 2.0

var player: Node2D = null
var orbit_direction: float = 1.0

# The comfortable distance where they finally start shooting
const ENGAGE_DISTANCE: float = 350.0

var state_timer: float = 0.0
var shoot_timer: float = 0.0
var burst_shots_fired: int = 0

@onready var muzzle: Marker2D = $Muzzle

func _ready() -> void:
	current_health = max_health
	orbit_direction = 1.0 if randf() > 0.5 else -1.0
	# They start in the APPROACH state automatically now, no timer needed here!

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return
			
	if player.is_dead:
		velocity = velocity.lerp(Vector2.ZERO, 3.0 * delta)
		move_and_slide()
		return
		
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	var distance = global_position.distance_to(player.global_position)
	var direction_to_player = global_position.direction_to(player.global_position)
	var desired_velocity := Vector2.ZERO

	# ALWAYS look at the player smoothly
	var target_angle = direction_to_player.angle() + SPRITE_OFFSET
	rotation = lerp_angle(rotation, target_angle, 15.0 * delta)

	# --- BEHAVIOR PHASES ---
	match current_state:
		State.APPROACH:
			# 1. MOVEMENT: Fly straight into the arena quickly to get on screen
			desired_velocity = direction_to_player * (speed * 0.9)
			
			# 2. ENGAGE: If we cross the invisible line, start the combat loop!
			if distance <= ENGAGE_DISTANCE:
				current_state = State.WAIT
				state_timer = 0.5  # Take a brief half-second pause to stabilize before bursting

		State.BURST:
			# 1. MOVEMENT: Strafe slowly. If the player gets too close, back up!
			if distance < 200.0:
				desired_velocity = -direction_to_player * (speed * 0.5)
			else:
				var strafe_dir = direction_to_player.rotated((PI / 2.0) * orbit_direction)
				desired_velocity = strafe_dir * (speed * 0.3)

			# 2. SHOOTING: Only tick the timer and shoot if the player is in range!
			if distance <= ENGAGE_DISTANCE:
				shoot_timer -= delta
				if shoot_timer <= 0.0:
					_fire_bullet()
					burst_shots_fired += 1
					shoot_timer = 0.35 
					
					if burst_shots_fired >= 3:
						current_state = State.WAIT
						state_timer = 2.5  

		State.WAIT:
			# 1. MOVEMENT: Keep strafing to reposition
			var strafe_dir = direction_to_player.rotated((PI / 2.0) * orbit_direction)
			desired_velocity = strafe_dir * (speed * 0.6)

			# 2. WAITING: Count down to the charge
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.CHARGE
				state_timer = 2.0 
				shoot_timer = 0.0 

		State.CHARGE:
			# 1. MOVEMENT: Aggressively fly straight at the player!
			desired_velocity = direction_to_player * (speed * 0.9)

			# 2. SHOOTING: Only shoot while charging if the player is actually in range
			if distance <= ENGAGE_DISTANCE:
				shoot_timer -= delta
				if shoot_timer <= 0.0:
					_fire_bullet()
					shoot_timer = 0.5 

			# 3. END CHARGE: Go back to bursting
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.BURST
				burst_shots_fired = 0
				shoot_timer = 1.5  
				orbit_direction *= -1.0 
				
	# Apply smooth inertia
	velocity = velocity.lerp(desired_velocity, 5.0 * delta)
	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Bounce off the player
		if collider and collider.is_in_group("player"):
			velocity += collision.get_normal() * 400.0
	
func _fire_bullet() -> void:
	if not enemy_bullet_scene:
		return
		
	var bullet = enemy_bullet_scene.instantiate()
	var projectile_container = get_tree().current_scene.get_node_or_null("Projectiles")
	
	if projectile_container:
		projectile_container.add_child(bullet)
	else:
		get_tree().current_scene.add_child(bullet)
		
	var perfect_dir = muzzle.global_position.direction_to(player.global_position)
	var random_spray = randf_range(-weapon_spread, weapon_spread)
	var final_dir = Vector2.from_angle(perfect_dir.angle() + random_spray)
	
	bullet.init(muzzle.global_position, final_dir)

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	
	current_health -= amount
	
	if sprite:
		sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	velocity += knockback_dir * 450.0 
	
	current_state = State.WAIT
	state_timer = 1.0 
	shoot_timer = 0.0
	burst_shots_fired = 0
	
	if current_health <= 0:
		if explosion_sound:
			SoundManager.play_sound(explosion_sound)
		_drop_loot()
		queue_free()
		
func _drop_loot() -> void:
	if not xp_gem_scene:
		return
		
	var gem = xp_gem_scene.instantiate()
	gem.global_position = global_position # Drop it exactly where the enemy died
	
	# Throw it into the main world, NOT inside the enemy!
	var loot_container = get_tree().current_scene.get_node_or_null("Loot")
	if loot_container:
		loot_container.call_deferred("add_child", gem)
	else:
		get_tree().current_scene.call_deferred("add_child", gem)
