extends Node

var current_scene =""
var current_level_name = "level_1"
var next_scene_path = ""
var transition_scene = false

func update_paths():
	if current_level_name == "level_1":
		next_scene_path = "res://scenes/level_2.tscn"
	elif current_level_name == "level_2":
		next_scene_path = "res://scenes/level_3.tscn"
	elif current_level_name == "level_3":
		next_scene_path = "res://scenes/level_4.tscn"
	elif current_level_name == "level_4":
		next_scene_path = "res://scenes/victory_scene.tscn"
	else:
		next_scene_path = "res://scenes/main_menu.tscn"
