extends Area2D

func _ready():
	add_to_group("DOOR")
	
func start_door_request_dialog():
	if Global.indices["town"] == 0:
		var dialog = Dialogic.start("jaysondoor0")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
	else:
		var new_dialog = Dialogic.start('stevenhouse')
		new_dialog.pause_mode = PAUSE_MODE_PROCESS
		add_child(new_dialog)
		new_dialog.connect('timeline_end', self, 'end_dialog')
		get_tree().paused = true

func end_dialog(_data):
	get_tree().paused = false
