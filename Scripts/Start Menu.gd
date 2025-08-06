extends Control

onready var van = $van
onready var van2 = $van2

func _ready():
	$VBoxContainer/Start.grab_focus()
# the above makes it so you can use keyboard and mouse for menu

func _on_Start_pressed():
	van.visible = false
	van2.visible = true
	van2.play("off screen")

func _on_Controls_pressed():
	if(Load.can_click):
		van.visible = false
		van2.visible = true
		van2.play("off screen")
		Global.do_load()

func _on_Quit_pressed():
	get_tree().quit()

func _on_van2_animation_finished():
	get_tree().change_scene("res://Scenes/World.tscn")
