extends Node2D

# This variable prevents the game from trying to change scenes twice 
# in the same frame, which causes the "null value" error.
var is_changing_scene: bool = false

func _ready():
	Global.current_level_name = "level_2"
	Global.update_paths()

func _on_transition_body_entered(body: Node2D) -> void:
	# Only proceed if it's the player AND we aren't already switching scenes
	if body.has_method("player") and not is_changing_scene:
		is_changing_scene = true
		print("Player reached exit")
		change_scene("res://Scenes/ui/victory_scene.tscn", "victory_scene")

func _on_death_point_body_entered(body: Node2D) -> void:
	if body.has_method("player") and not is_changing_scene:
		is_changing_scene = true
		change_scene("res://Scenes/ui/Death_scene.tscn", "death")

func _on_death_point_2_body_entered(body: Node2D) -> void:
	if body.has_method("player") and not is_changing_scene:
		is_changing_scene = true
		change_scene("res://Scenes/ui/Death_scene.tscn", "death")

# I consolidated this function so it can handle both Victory AND Death
func change_scene(target_path: String, scene_name: String) -> void:
	Global.transition_scene = false
	Global.current_scene = scene_name
	
	# Safety check: ensures the Tree still exists before calling it
	if get_tree():
		get_tree().change_scene_to_file(target_path)
