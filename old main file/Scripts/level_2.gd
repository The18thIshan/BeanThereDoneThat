extends Node2D
	
func _ready():
	Global.current_level_name = "level_2"
	Global.update_paths()
	
func _on_transition_point_body_entered(body) :
	if body.has_method("player"):
		print("hi")
		Global.transition_scene = true
		change_scene()
		
func _on_transition_point_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		Global.transition_scene = false

	
	
func change_scene() -> void:
	if Global.transition_scene == true:
		Global.transition_scene = false
		Global.current_scene = "victory_scene"
		get_tree().change_scene_to_file("res://Scenes/victory_scene.tscn")
