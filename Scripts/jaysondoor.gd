extends Area2D
export var door = "jaysondoor"
var index = 0

func _ready():
	add_to_group("DOOR")
	

func start_door_request_dialog():
	
	if Global.indices["jayhouse"] > 1:
			var dialog = Dialogic.start("done")
			dialog.pause_mode = PAUSE_MODE_PROCESS
			get_parent().add_child(dialog)
			dialog.connect("timeline_end", self, "end_dialog")
			get_tree().paused = true
			
	elif Global.indices["jayson"] > 1:
		var dialog = Dialogic.start("jaysondoor2")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
	
	elif Global.indices["town"] == 1:
		var dialog = Dialogic.start("jaysondoor1")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		
	elif Global.indices["jayson"] == 0:
		var dialog = Dialogic.start("jaysondoor0")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true

func end_dialog(_data):
	get_tree().paused = false

