extends Node

# This function creates a temporary audio player, plays the sound, 
# and destroys the player automatically when the sound ends!
func play_sound(stream: AudioStream, volume_db: float = 0.0) -> void:
	if not stream:
		return
		
	# 1. Create a brand new audio node on the fly
	var audio_player = AudioStreamPlayer.new()
	
	# 2. Assign the sound file and settings
	audio_player.stream = stream
	audio_player.volume_db = volume_db
	
	# 3. Add it as a child of this global manager
	add_child(audio_player)
	
	# 4. Turn it on!
	audio_player.play()
	
	# 5. THE MAGIC LINE: When the audio finishes playing, completely delete the temporary player
	audio_player.finished.connect(func(): audio_player.queue_free())
	
