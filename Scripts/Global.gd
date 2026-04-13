extends Node

var current_scene =""
var current_level_name = "level_1"
var level_number: int = 1
var current_level = ""
var next_scene_path = ""
var transition_scene = false
var total_score = 0
var current_level_coins = 0
var hoverrable: bool=false

func _ready() -> void:
	hoverrable = false
	
func update_paths():

	current_level = "level_%s" % level_number
	print(current_level)
	if current_level_name == "level_1":
		level_number += 1
		next_scene_path = "res://Scenes/Levels/Level2.tscn"
	elif current_level_name == "level_2":
		level_number += 1
		next_scene_path = "res://scenes/Level3.tscn"
	elif current_level_name == "level_3":
		level_number += 1
		next_scene_path = "res://scenes/level_4.tscn"
	elif current_level_name == "level_4":
		level_number += 1
		next_scene_path = "res://scenes/victory_scene.tscn"
	else:
		next_scene_path = "res://scenes/main_menu.tscn"

func add_coin():
	current_level_coins += 1

func save_level_score():
	total_score += current_level_coins
	current_level_coins = 0 

# Call this if the player dies (Death Scene)
func reset_level_score():
	current_level_coins = 0
