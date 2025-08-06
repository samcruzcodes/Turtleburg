extends Area2D

export var exit = "townleave"

func _ready():
	add_to_group("EXIT")

func start_leave_request_dialog():
	var dialog = Dialogic.start(exit)
	dialog.pause_mode = PAUSE_MODE_PROCESS
	get_parent().add_child(dialog)
	dialog.connect("timeline_end", self, "end_dialog")
	get_tree().paused = true
	
	
func end_dialog(_data):
	get_tree().paused = false

func tp_back():
	Global.emit_signal("left_town")
	get_tree().change_scene("res://Scenes/World.tscn")

	
