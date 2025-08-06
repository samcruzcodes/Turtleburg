extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.do_save()
	var new_dialog = Dialogic.start('jaysonhouse')
	new_dialog.pause_mode = PAUSE_MODE_PROCESS
	add_child(new_dialog)
	new_dialog.connect('timeline_end', self, 'end_dialog')
	get_tree().paused = true

func end_dialog(_data):
	get_tree().paused = false
