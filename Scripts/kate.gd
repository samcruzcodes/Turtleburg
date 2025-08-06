extends Area2D

func _ready():
	add_to_group("EXIT")

func start_leave_request_dialog():
	
	if Global.indices["brockhouse"] < 1:
		var dialog = Dialogic.start("talk2brock")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		
	elif Global.indices["jayhouse"] < 1:
		var dialog = Dialogic.start("talk2jayson")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		
	elif Global.indices["steven"] < 3:
		var dialog = Dialogic.start("talk2steven")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		
	elif Global.indices["trash"] < 5:
		var dialog = Dialogic.start("pollution")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
	
func end_dialog(_data):
	get_tree().paused = false
