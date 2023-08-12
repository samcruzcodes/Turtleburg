extends Area2D

onready var bathtub = $"old bathtub"
onready var question = $"old bathtub/question"
onready var collision = $CollisionShape2D
onready var new_bathtub = $tub


func _ready():
	add_to_group("EXIT")

func start_leave_request_dialog():
	var dialog = Dialogic.start("brocktub")
	dialog.pause_mode = PAUSE_MODE_PROCESS
	get_parent().add_child(dialog)
	dialog.connect("timeline_end", self, "end_dialog")
	get_tree().paused = true
	
	
func end_dialog(_data):
	Global.increment_index("brockhouse")
	get_tree().paused = false
	bathtub.visible = false
	collision.disabled = true
	new_bathtub.visible = true
