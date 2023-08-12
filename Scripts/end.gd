extends Area2D

func _ready():
	add_to_group("DOOR")

func start_door_request_dialog():
	var dialog = Dialogic.start("theend")
	dialog.pause_mode = PAUSE_MODE_PROCESS
	get_parent().add_child(dialog)
	dialog.connect("timeline_end", self, "end_dialog")
	get_tree().paused = true
	
func end_dialog(_data):
	get_tree().paused = false
	get_tree().change_scene("res://Scenes/finale.tscn")
