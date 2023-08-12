extends Area2D

var dialog_index = Global.indices["gabe"]
var index = 0

func _ready():
	add_to_group("EXIT")

func start_leave_request_dialog():
	if dialog_index > 0:
		index = 1
		dialog_index = 1
	else:
		dialog_index = index
	var dialog = Dialogic.start("gabe"+str(dialog_index))
	dialog.pause_mode = PAUSE_MODE_PROCESS
	get_parent().add_child(dialog)
	dialog.connect("timeline_end", self, "end_dialog")
	get_tree().paused = true
	index = index + 1
	Global.increment_index("gabe")

	
func end_dialog(_data):
	get_tree().paused = false
