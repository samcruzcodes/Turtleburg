extends Area2D

func _ready():
	add_to_group("EXIT")

# Kate's hint for the current mission step always takes priority. The first time she gives it in a
# step it is the original line; talking to her again before anything changes rotates through two
# short reminders (then the original again), never the same line twice in a row.
func start_leave_request_dialog():
	var state = ""
	var lines = []
	if Global.indices["brockhouse"] < 1:
		state = "brock"
		lines = ["talk2brock", "kate_brock2", "kate_brock3"]
	elif Global.indices["jayhouse"] < 1:
		state = "jayson"
		lines = ["talk2jayson", "kate_jayson2", "kate_jayson3"]
	elif Global.indices["steven"] < 3:
		state = "steven"
		lines = ["talk2steven", "kate_steven2", "kate_steven3"]
	elif Global.indices["pollution"] < 6:
		state = "pollution"
		lines = ["pollution", "kate_trash2", "kate_trash3"]
	else:
		return
	var dialog = Dialogic.start(Global.repeat_timeline("kate", lines, state))
	dialog.pause_mode = PAUSE_MODE_PROCESS
	get_parent().add_child(dialog)
	dialog.connect("timeline_end", self, "end_dialog")
	get_tree().paused = true

func end_dialog(_data):
	get_tree().paused = false
