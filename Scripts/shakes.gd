extends Area2D

onready var collision = $CollisionShape2D
onready var sprite = $Sprite

func _ready():
	add_to_group("EXIT")

func start_leave_request_dialog():
	var dialog = Dialogic.start("shakes")
	dialog.pause_mode = PAUSE_MODE_PROCESS
	get_parent().add_child(dialog)
	dialog.connect("timeline_end", self, "end_dialog")
	get_tree().paused = true
	
	
func end_dialog(_data):
	Global.increment_index("brockhouse")
	get_tree().paused = false
	collision.disabled = true
	sprite.visible = false
