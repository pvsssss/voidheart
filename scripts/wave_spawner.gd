extends Node

@export var basic_fighter_scene: PackedScene

var current_wave: int = 0
var screen_size: Vector2

# --- WAVE MANAGEMENT VARIABLES ---
var enemies_left_in_wave: int = 0
var max_concurrent_enemies: int = 5  # The hard cap for how many can be on screen!
var spawn_timer: float = 0.0
var time_between_spawns: float = 1.0 # Wait 1 second between dropping new enemies in

var is_between_waves: bool = true

func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	_start_next_wave()

func _process(delta: float) -> void:
	# If we are resting between waves, do absolutely nothing
	if is_between_waves:
		return

	# Count exactly how many enemies are currently alive
	var active_enemies = get_tree().get_nodes_in_group("enemy").size()

	# 1. IS THE WAVE OVER? (0 alive, and 0 waiting to spawn)
	if active_enemies == 0 and enemies_left_in_wave == 0:
		_start_next_wave()
		return

	# 2. DO WE HAVE ROOM TO SPAWN MORE?
	if active_enemies < max_concurrent_enemies and enemies_left_in_wave > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_enemy()
			enemies_left_in_wave -= 1
			spawn_timer = time_between_spawns # Reset the clock for the next spawn

func _start_next_wave() -> void:
	is_between_waves = true
	current_wave += 1
	
	# The waves now get MUCH larger, but they trickle in slowly!
	var total_wave_enemies = 4 + (current_wave * 2) 
	enemies_left_in_wave = total_wave_enemies
	
	# The on-screen cap slowly rises as you get to higher waves
	max_concurrent_enemies = 2 + (current_wave / 2) 
	
	print("--- WAVE ", current_wave, " ---")
	print("Total in Wave: ", total_wave_enemies, " | Max on Screen: ", max_concurrent_enemies)
	
	# Give the player 3 seconds of peace to breathe and reload
	await get_tree().create_timer(3.0).timeout
	
	# Ding ding! Round begins.
	is_between_waves = false
	spawn_timer = 0.0  # Force the very first enemy to spawn instantly!

func _spawn_enemy() -> void:
	if not basic_fighter_scene:
		return
		
	var enemy = basic_fighter_scene.instantiate()
	
	var spawn_pos = Vector2.ZERO
	var edge = randi() % 4 
	var offset = 50.0
	
	match edge:
		0: spawn_pos = Vector2(randf_range(0, screen_size.x), -offset)
		1: spawn_pos = Vector2(randf_range(0, screen_size.x), screen_size.y + offset)
		2: spawn_pos = Vector2(-offset, randf_range(0, screen_size.y))
		3: spawn_pos = Vector2(screen_size.x + offset, randf_range(0, screen_size.y))
			
	enemy.global_position = spawn_pos
	get_parent().add_child(enemy)
