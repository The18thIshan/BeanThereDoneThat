extends Control

func _on_again_pressed() -> void:
	var level_to_reload = "res://Scenes/" + Global.current_level_name + ".tscn"
	
	get_tree().change_scene_to_file(level_to_reload)

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
