extends Area2D
export var door = "name"

func _ready():
	add_to_group("DOOR")

func start_door_request_dialog():
	var dialog = Dialogic.start(door)
	dialog.pause_mode = PAUSE_MODE_PROCESS
	get_parent().add_child(dialog)
	dialog.connect("timeline_end", self, "end_dialog")
	get_tree().paused = true
	
func end_dialog(_data):
	get_tree().paused = false
	
