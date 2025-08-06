extends Area2D

export var door = "name"

func _ready():
	add_to_group("DOOR")
	
func start_door_request_dialog():
	if Global.indices["brockhouse"] > 1:
		var dialog = Dialogic.start("done")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		
	elif Global.indices["brock"] >1:
		var dialog = Dialogic.start("brockknows")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		
	elif Global.indices["town"] == 1:
		var dialog = Dialogic.start("brockdontknow")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		
	elif Global.indices["brock"] == 0:
		var dialog = Dialogic.start("jaysondoor0")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
	
func end_dialog(_data):
	get_tree().paused = false
	
