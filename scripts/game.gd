extends Node2D

@onready var player = $player  # Make sure this matches the exact name of your player node
@onready var hud = $HUD        # Make sure this matches your HUD node

func _ready() -> void:
	# Connect the player's health signal directly to the HUD's update function
	player.health_changed.connect(hud.update_health)
	
	# Force an initial update so the health bar draws immediately on frame 1
	hud.update_health(player.max_health, player.max_health)
