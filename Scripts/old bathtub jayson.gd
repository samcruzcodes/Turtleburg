extends Area2D

onready var toilet = $"old bathtub"
onready var question = $"old bathtub/question"
onready var new_toilet = $tub
onready var collision = $CollisionShape2D

func _ready():
	add_to_group("EXIT")

func start_leave_request_dialog():
	var dialog = Dialogic.start("jaybath")
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
	
	
	
