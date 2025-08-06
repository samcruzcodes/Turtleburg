extends Node2D

onready var finale = $AnimatedSprite
onready var the_end = $Label

func _ready():
	finale.play("final")

func _on_AnimatedSprite_animation_finished():
		the_end.visible = true

func _on_Button_pressed():
	Global.do_save()
	get_tree().quit()
