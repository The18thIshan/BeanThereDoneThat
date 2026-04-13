
extends Control

@onready var score: Label = $score

func _ready():
	Global.save_level_score()
	# This shows the grand total after the level win was saved
	score.text = "Total Coins: " + str(Global.total_score)

func _on_next_pressed() -> void:
	get_tree().change_scene_to_file(Global.next_scene_path)


func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
