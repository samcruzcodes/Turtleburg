extends Area2D

onready var sprite = $Sprite
onready var collision = $CollisionShape2D

func _ready():
	add_to_group("EXIT")
	# trash that was already picked up (this session or in a loaded save) stays gone
	if Global.collected_trash.has(name):
		sprite.visible = false
		collision.set_deferred("disabled", true)

func start_leave_request_dialog():
	var dialog = Dialogic.start("trash")
	dialog.pause_mode = PAUSE_MODE_PROCESS
	get_parent().add_child(dialog)
	dialog.connect("timeline_end", self, "end_dialog")
	get_tree().paused = true
	Global.increment_index("pollution")


func end_dialog(_data):
	Global.collected_trash[name] = true
	get_tree().paused = false
	sprite.visible = false
	collision.disabled = true
