extends Area2D

func _ready():
	add_to_group("EXIT")

# First visit: the original conversation. After that: three short lines in rotation (jodi1 is the
# original short line, jodi2 and jodi3 are new), never the same one twice in a row. Nothing here
# touches quest progress.
func start_leave_request_dialog():
	var timeline = "jodi0"
	if Global.indices["jodi"] > 0:
		timeline = Global.repeat_timeline("jodi", ["jodi1", "jodi2", "jodi3"])
	else:
		Global.increment_index("jodi")
	var dialog = Dialogic.start(timeline)
	dialog.pause_mode = PAUSE_MODE_PROCESS
	get_parent().add_child(dialog)
	dialog.connect("timeline_end", self, "end_dialog")
	get_tree().paused = true


func end_dialog(_data):
	get_tree().paused = false
