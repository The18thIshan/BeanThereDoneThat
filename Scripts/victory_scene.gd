extends Control




func _on_next_pressed() -> void:
	get_tree().change_scene_to_file(Global.next_scene_path)


func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
