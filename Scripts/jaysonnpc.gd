extends KinematicBody2D

export var npc = "jayson"
var dialog_index = Global.indices["jayson"]

var speed = 0.3
var motion = Vector2()
var gravity = 0.3

func _ready(): 
	add_to_group("NPC")

func start_dialog():
	
	if Global.indices["jayhouse"] > 1:
		var dialog = Dialogic.start("jayson1")	
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		
	elif Global.indices["jayson"] > 1 and Global.indices["jayhouse"] < 2:
		var dialog = Dialogic.start("go to house")	
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		
	elif Global.indices["town"] == 0:
		var dialog = Dialogic.start("Talk to the other townies first")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
	
	elif Global.indices["town"] != 0:
		var dialog = Dialogic.start("jayson0")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		Dialogic.set_variable("town_likeability", 0)
		Dialogic.set_variable(npc +str("_likeability"), 0)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		Global.increment_index("jayson")
	
func end_dialog(_data):
	get_tree().paused = false
