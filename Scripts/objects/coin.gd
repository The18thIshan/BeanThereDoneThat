extends Area2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

#
#func _on_body_entered(body: Node2D) -> void:
	## Check if the thing hitting the coin is actually the player
	#if body.has_method("player") :
		#Global.add_coin()
		#animation_player.play("pickup")
		#if "PointLight2D":
			#get_node("PointLight2D").queue_free()
		#self.queue_free()
		#
	#
#func _ready():
	#var main = get_tree().current_scene
	#get_parent().remove_child(self) # <-- DETACHES FROM LEVEL
	#main.add_child(self)
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		Global.add_coin()
		
		# 1. Hide the coin visuals so it "looks" collected
		$AnimatedSprite2D.hide() 
		if has_node("PointLight2D"):
			$PointLight2D.hide()
			
		# 2. Disable the collision so it doesn't trigger again
		monitoring = false 
		
		# 3. Play the pickup animation (which includes the sound)
		animation_player.play("pickup")
		
		# 4. Wait for the animation to finish before deleting
		await animation_player.animation_finished
		queue_free()
