extends Area2D

func _ready():
	add_to_group("EXIT")

# First visit: the original conversation. After that: three short lines in rotation (gabe1 is the
# original short line, gabe2 and gabe3 are new), never the same one twice in a row. Nothing here
# touches quest progress.
func start_leave_request_dialog():
	var timeline = "gabe0"
	if Global.indices["gabe"] > 0:
		timeline = Global.repeat_timeline("gabe", ["gabe1", "gabe2", "gabe3"])
	else:
		Global.increment_index("gabe")
	var dialog = Dialogic.start(timeline)
	dialog.pause_mode = PAUSE_MODE_PROCESS
	get_parent().add_child(dialog)
	dialog.connect("timeline_end", self, "end_dialog")
	get_tree().paused = true


func end_dialog(_data):
	get_tree().paused = false
