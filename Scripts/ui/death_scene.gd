extends Control

@onready var Score: Label = $Score

func _on_again_pressed() -> void:
	var level_to_reload = "res://Scenes/levels/" + Global.current_level_name + ".tscn"
	
	get_tree().change_scene_to_file(level_to_reload)

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/ui/main_menu.tscn")


func _ready():
	Global.save_level_score()
	# This shows the grand total after the level win was saved
	Score.text = "Total Coins: " + str(Global.total_score)
