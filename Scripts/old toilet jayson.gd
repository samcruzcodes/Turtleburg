extends Area2D

onready var toilet = $"old toilet"
onready var question = $"old toilet/question"
onready var new_toilet = $"toilet"
onready var collision = $shape

func _ready():
	add_to_group("EXIT")

func start_leave_request_dialog():
	var dialog = Dialogic.start("jaytoilet")
	dialog.pause_mode = PAUSE_MODE_PROCESS
	get_parent().add_child(dialog)
	dialog.connect("timeline_end", self, "end_dialog")
	get_tree().paused = true
	
	
func end_dialog(_data):
	Global.increment_index("jayhouse")
	get_tree().paused = false
	toilet.visible = false
	collision.disabled = true
	new_toilet.visible = true
	
	
	
