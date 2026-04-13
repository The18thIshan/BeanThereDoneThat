extends Node2D

# This variable prevents the "null value" error by ensuring 
# we only try to change the scene once.
var is_changing_scene: bool = false

func _ready():
	Global.current_level_name = "level_3"
	Global.update_paths()

func _on_transition_point_body_entered(body: Node2D) -> void:
	# Check for player and ensure we aren't already switching
	if body.has_method("player") and not is_changing_scene:
		is_changing_scene = true
		print("Level 3 Complete!")
		# Pass the path and the name to our helper function
		change_scene("res://Scenes/ui/end_screen.tscn", "end_screen")

func _on_death_transition_point_1_body_entered(body: Node2D) -> void:
	if body.has_method("player") and not is_changing_scene:
		is_changing_scene = true
		print("Player died on Level 3")
		# Assuming your death scene is in the same UI folder as Level 2
		change_scene("res://Scenes/ui/Death_scene.tscn", "death")

# This helper function handles the Global logic and the actual scene swap
func change_scene(target_path: String, scene_name: String) -> void:
	Global.transition_scene = false
	Global.current_scene = scene_name
	
	# The safety check to prevent the "null" crash
	if get_tree():
		get_tree().change_scene_to_file(target_path)
