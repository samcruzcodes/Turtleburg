extends Area2D

onready var dirty = $"dirty counter"
onready var clean = $"clean counter"
onready var collision = $CollisionShape2D
onready var check = $check

func _ready():
	add_to_group("EXIT")

func start_leave_request_dialog():
	var dialog = Dialogic.start("counter")
	dialog.pause_mode = PAUSE_MODE_PROCESS
	get_parent().add_child(dialog)
	dialog.connect("timeline_end", self, "end_dialog")
	get_tree().paused = true
	
	
func end_dialog(_data):
	Global.increment_index("brockhouse")
	get_tree().paused = false
	collision.disabled = true
	dirty.visible = false
	clean.visible = true   
	check.visible = false
