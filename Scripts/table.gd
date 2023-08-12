 extends Area2D

onready var table = $table
onready var collision = $CollisionShape2D

func _ready():
	add_to_group("EXIT")

func start_leave_request_dialog():
	var dialog = Dialogic.start("table")
	dialog.pause_mode = PAUSE_MODE_PROCESS
	get_parent().add_child(dialog)
	dialog.connect("timeline_end", self, "end_dialog")
	get_tree().paused = true
	
	
func end_dialog(_data):
	get_tree().paused = false
	table.visible = false
	collision.disabled = true
	
