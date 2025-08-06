extends KinematicBody2D

export var npc = "steven"
var dialog_index = Global.indices["steven"]

var speed = 0.3
var motion = Vector2()
var gravity = 0.3

func _ready(): 
	add_to_group("NPC")
	if dialog_index > 3:
		dialog_index = 3

func start_dialog():
	if Global.indices["town"] == 0:
		var dialog = Dialogic.start("Talk to the other townies first")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		
	elif Global.indices["steven"] == 1:
		var dialog = Dialogic.start("steven1")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		Dialogic.set_variable("town_likeability", 0)
		Dialogic.set_variable(npc +str("_likeability"), 0)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		Global.increment_index("steven")
		
	elif Global.indices["steven"] == 2:
		var dialog = Dialogic.start("steven2")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		Dialogic.set_variable("town_likeability", 0)
		Dialogic.set_variable(npc +str("_likeability"), 0)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		Global.increment_index("steven")
		
	elif Global.indices["steven"] == 3:
		var dialog = Dialogic.start("steven3")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		Dialogic.set_variable("town_likeability", 0)
		Dialogic.set_variable(npc +str("_likeability"), 0)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		Global.increment_index("steven")
		
	elif Global.indices["steven"] > 3:
		var dialog = Dialogic.start("steven3")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		Dialogic.set_variable("town_likeability", 0)
		Dialogic.set_variable(npc +str("_likeability"), 0)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		Global.increment_index("steven")
		
	else:
		var dialog = Dialogic.start("steven0")
		dialog.pause_mode = PAUSE_MODE_PROCESS
		get_parent().add_child(dialog)
		Dialogic.set_variable("town_likeability", 0)
		Dialogic.set_variable(npc +str("_likeability"), 0)
		dialog.connect("timeline_end", self, "end_dialog")
		get_tree().paused = true
		Global.increment_index("steven")
	
func end_dialog(_data):
	get_tree().paused = false
