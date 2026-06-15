extends CharacterBody2D

# --- THE STATE MACHINE ---
enum State { BURST, WAIT, CHARGE }
var current_state: State = State.WAIT

@export var speed: float = 180.0
@export var max_health: int = 3
@export var enemy_bullet_scene: PackedScene  # Assign your new EnemyBullet here!
@export var weapon_spread: float = 0.35

@onready var sprite: Sprite2D = $Sprite2D  # Ensure your sprite node is named exactly "Sprite2D"

var current_health: int
const SPRITE_OFFSET: float = -PI / 2.0

var player: Node2D = null
var orbit_direction: float = 1.0

# Timers to control the phases
var state_timer: float = 0.0
var shoot_timer: float = 0.0
var burst_shots_fired: int = 0

@onready var muzzle: Marker2D = $Muzzle

func _ready() -> void:
	current_health = max_health
	orbit_direction = 1.0 if randf() > 0.5 else -1.0
	
	# Give them 1.5 seconds to strafe into position before they attack!
	state_timer = 1.5

func _physics_process(delta: float) -> void:
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
		State.BURST:
			# 1. MOVEMENT: Strafe slowly. If the player gets too close, back up!
			if distance < 200.0:
				desired_velocity = -direction_to_player * (speed * 0.5)
			else:
				var strafe_dir = direction_to_player.rotated((PI / 2.0) * orbit_direction)
				desired_velocity = strafe_dir * (speed * 0.3)

			# 2. SHOOTING: Fire 3 quick shots
			shoot_timer -= delta
			if shoot_timer <= 0.0:
				_fire_bullet()
				burst_shots_fired += 1
				shoot_timer = 0.35  # Time between the 3 shots
				
				# If we fired 3 times, switch to WAIT phase
				if burst_shots_fired >= 3:
					current_state = State.WAIT
					# INCREASED DELAY: Wait and strafe for 2.5 seconds (was 1.5)
					state_timer = 2.5  

		State.WAIT:
			# 1. MOVEMENT: Keep strafing to reposition
			var strafe_dir = direction_to_player.rotated((PI / 2.0) * orbit_direction)
			desired_velocity = strafe_dir * (speed * 0.6)

			# 2. WAITING: Count down to the charge
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.CHARGE
				state_timer = 2.0  # Charge lasts for 2 seconds
				shoot_timer = 0.0  # Fire immediately when charge starts

		State.CHARGE:
			# 1. MOVEMENT: Aggressively fly straight at the player!
			desired_velocity = direction_to_player * (speed * 0.9)

			# 2. SHOOTING: Fire steadily while charging
			shoot_timer -= delta
			if shoot_timer <= 0.0:
				_fire_bullet()
				shoot_timer = 0.5  # Fire every half-second while charging

			# 3. END CHARGE: Go back to bursting
			state_timer -= delta
			if state_timer <= 0.0:
				current_state = State.BURST
				burst_shots_fired = 0
				shoot_timer = 1.5  
				orbit_direction *= -1.0 # Flip orbit direction for unpredictability
				
	# Apply smooth inertia
	velocity = velocity.lerp(desired_velocity, 5.0 * delta)
	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# If the thing we hit was the player, bounce off them!
		if collider and collider.is_in_group("player"):
			# get_normal() pushes the enemy perfectly away from the collision point
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
		
	# 1. Get the perfect mathematical direction to the player
	var perfect_dir = muzzle.global_position.direction_to(player.global_position)
	
	# 2. Calculate a random spray offset (between -0.15 and 0.15 radians)
	var random_spray = randf_range(-weapon_spread, weapon_spread)
	
	# 3. Apply the spray to the perfect angle, and convert it back to a Directional Vector2
	var final_dir = Vector2.from_angle(perfect_dir.angle() + random_spray)
	
	# 4. Initialize the bullet with the new, slightly inaccurate trajectory
	bullet.init(muzzle.global_position, final_dir)

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	current_health -= amount
	
	# 1. FLASH RED
	if sprite:
		# Modulate the sprite to solid red
		sprite.modulate = Color.RED
		# Create a Tween to smoothly fade it back to white over 0.2 seconds
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	# 2. KNOCKBACK
	# Instantly shove the enemy in the direction the bullet was flying.
	# Because of the lerp() in your _physics_process, they will naturally slow down and recover!
	velocity += knockback_dir * 450.0 
	
	# 3. INTERRUPT & RESET STATE
	current_state = State.WAIT
	state_timer = 1.0  # Only stun them for half a second so they don't get stun-locked
	shoot_timer = 0.0
	burst_shots_fired = 0
	
	if current_health <= 0:
		queue_free()
