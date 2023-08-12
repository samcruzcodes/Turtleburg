extends Node2D

var dialog_index = Global.indices["town"]
var town = "towncenter"

func _ready():
	Global.do_save()
	if dialog_index > 1:
		dialog_index = 1
	var new_dialog = Dialogic.start(town + str(dialog_index))
	new_dialog.pause_mode = PAUSE_MODE_PROCESS
	add_child(new_dialog)
	new_dialog.connect('timeline_end', self, 'end_dialog')
	get_tree().paused = true
	Global.increment_index("town")
	
func end_dialog(_data):
	get_tree().paused = false
