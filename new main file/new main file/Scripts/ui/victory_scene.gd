
extends Control



func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/ui/main_menu.tscn")


func _on_next_pressed() -> void:
	get_tree().change_scene_to_file(Global.next_scene_path)
