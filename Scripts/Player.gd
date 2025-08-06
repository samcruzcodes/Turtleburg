extends KinematicBody2D

export var acceleration = 5000
export var friction = 5000
export var MAX_SPEED = 150 # The speed of the character

var StevenNPC = load("res://Scripts/stevennpc.gd").new()
var BrockNPC = load("res://Scripts/brocknpc.gd").new()
var JaysonNPC = load("res://Scripts/jaysonnpc.gd").new()
var door = load('res://Scripts/door.gd').new()

onready var tree = $AnimationTree
onready var anim = $AnimationPlayer
onready var state = tree.get("parameters/playback")

var motion = Vector2.ZERO

func _physics_process(delta): 
	
	if Global.moving == true:
		var input_vector = Vector2.ZERO
		input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		input_vector = input_vector
		
		if input_vector != Vector2.ZERO:
			tree.set("parameters/Idle/blend_position", input_vector)
			tree.set ("parameters/walk/blend_position", input_vector)
			state.travel("walk")
			motion = motion.move_toward(input_vector * MAX_SPEED, acceleration * delta)
		else:
			state.travel("Idle")
			motion = motion.move_toward(Vector2.ZERO, friction * delta)
	else:
		pass
	
	motion = move_and_slide(motion)
	
	update_interaction()


func update_interaction():
	if $interact_area/CollisionShape2D.disabled == false:
		$interact_area/CollisionShape2D.disabled = true
	if Input.is_action_just_pressed("interact"):
		$interact_area/CollisionShape2D.disabled = false

func _on_interact_area_body_entered(body):
	if body.is_in_group("NPC"):
		body.start_dialog()

func _on_interact_area_area_entered(area):
	if area.is_in_group("DOOR"):
		area.start_door_request_dialog()
	if area.is_in_group("EXIT"):
		area.start_leave_request_dialog()
		

