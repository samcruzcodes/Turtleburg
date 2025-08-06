extends Area2D

export var exit = "brockleave"

func _ready():
	add_to_group("EXIT")

func start_leave_request_dialog():
	if Global.indices["brockhouse"] < 4:
		var dialog = Dialogic.start("not-done")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
	else:
		var dialog = Dialogic.start(exit)
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
	
	
func end_dialog(_data):
	get_tree().paused = false


	
