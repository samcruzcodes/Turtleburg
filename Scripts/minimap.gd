extends Node2D

func _ready():
	pass

func _on_stevenhouse_mouse_entered():
	$TextureRect/stevenhouse/TextureRect.visible = true
func _on_stevenhouse_mouse_exited():
	$TextureRect/stevenhouse/TextureRect.visible = false



func _on_brockhouse_mouse_entered():
	$TextureRect/brockhouse/TextureRect.visible = true
func _on_brockhouse_mouse_exited():
	$TextureRect/brockhouse/TextureRect.visible = false



func _on_townhall_mouse_entered():
	$TextureRect/jaysonhouse/TextureRect.visible = true

func _on_townhall_mouse_exited():
	$TextureRect/jaysonhouse/TextureRect.visible = false


func _on_jaysonhouse_mouse_entered():
	$TextureRect/townhall/TextureRect.visible = true

func _on_jaysonhouse_mouse_exited():
	$TextureRect/townhall/TextureRect.visible = false
	

	
