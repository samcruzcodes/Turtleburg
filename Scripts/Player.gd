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


# ---------------------------------------------------------------------------------------------
# Interaction + the "?" cue.
# Space talks to / uses exactly one thing: the nearest door, exit, object or NPC inside the interact
# circle. The cue floats over that same thing, so what you see is what Space will activate. It is only
# shown while you are free to move, follows the target, and vanishes when you walk away, open the map,
# start a conversation or change scene (it is a child of this player).
# ---------------------------------------------------------------------------------------------
const CUE_TEXTURE = "res://Sprites/question-mark.png"
const CUE_SCALE = 2.0
var cue = null
var cue_target = null
var cue_time = 0.0

func _ready():
	cue = Sprite.new()
	cue.name = "InteractCue"
	cue.texture = load(CUE_TEXTURE)
	cue.set_as_toplevel(true)       # ignores the player's own scale / flips
	cue.z_as_relative = false
	cue.z_index = 95                # above the world and the interior layers, below the map
	cue.scale = Vector2(CUE_SCALE, CUE_SCALE)
	cue.visible = false
	add_child(cue)

# Global rect covered by a collider's active collision shapes (null if it has none).
func _collider_rect(c):
	var rect = null
	for ch in c.get_children():
		var pts = []
		if ch is CollisionShape2D and ch.shape != null and not ch.disabled:
			var sh = ch.shape
			if sh is RectangleShape2D:
				var e = sh.extents
				pts = [Vector2(-e.x, -e.y), Vector2(e.x, -e.y), Vector2(e.x, e.y), Vector2(-e.x, e.y)]
			elif sh is CircleShape2D:
				pts = [Vector2(-sh.radius, -sh.radius), Vector2(sh.radius, sh.radius)]
			elif sh is CapsuleShape2D:
				var hh = sh.radius + sh.height * 0.5
				pts = [Vector2(-sh.radius, -hh), Vector2(sh.radius, hh)]
			elif sh is ConvexPolygonShape2D:
				pts = Array(sh.points)
			else:
				pts = [Vector2(-64, -64), Vector2(64, 64)]
			pts = _xform_all(ch.global_transform, pts)
		elif ch is CollisionPolygon2D and not ch.disabled and ch.polygon.size() > 0:
			pts = _xform_all(ch.global_transform, Array(ch.polygon))
		if pts.size() > 0:
			var mn = pts[0]
			var mx = pts[0]
			for q in pts:
				mn = Vector2(min(mn.x, q.x), min(mn.y, q.y))
				mx = Vector2(max(mx.x, q.x), max(mx.y, q.y))
			var r = Rect2(mn, mx - mn)
			rect = r if rect == null else rect.merge(r)
	return rect

func _xform_all(xf, pts):
	var out = []
	for q in pts:
		out.append(xf.xform(q))
	return out

func _is_interactable(c):
	if not (c is Node) or not is_instance_valid(c):
		return false
	if c.is_in_group("NPC") and c.has_method("start_dialog"):
		return true
	if c.is_in_group("DOOR") and c.has_method("start_door_request_dialog"):
		return true
	if c.is_in_group("EXIT") and c.has_method("start_leave_request_dialog"):
		return true
	return false

# The nearest interactable overlapping the interact circle right now (same shape + layer mask the
# old Space press used), or null. Must run inside a physics frame.
func find_interact_target():
	var shape_node = $interact_area/CollisionShape2D
	var q = Physics2DShapeQueryParameters.new()
	q.set_shape(shape_node.shape)
	q.transform = shape_node.global_transform
	q.collision_layer = $interact_area.collision_mask
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = [get_rid()]
	var best = null
	var best_d = 1e18
	var centre = shape_node.global_position
	for hit in get_world_2d().direct_space_state.intersect_shape(q, 32):
		var c = hit["collider"]
		if not _is_interactable(c):
			continue
		var r = _collider_rect(c)
		var d = 0.0
		if r != null:
			d = Vector2(max(max(r.position.x - centre.x, 0.0), centre.x - r.end.x), max(max(r.position.y - centre.y, 0.0), centre.y - r.end.y)).length()
		else:
			d = (c.global_position - centre).length()
		if d < best_d:
			best_d = d
			best = c
	return best

# things that already carry their own "!" sign (litter, the finale marker) do not get a second cue
func _has_own_sign(c):
	for ch in c.get_children():
		if ch is Sprite and ch.texture != null and str(ch.texture.resource_path).ends_with("interact.png"):
			return true
	return false

func _update_cue(target):
	cue_target = target
	if target == null or _has_own_sign(target):
		cue.visible = false
		return
	var r = _collider_rect(target)
	var top = target.global_position + Vector2(0, -40)
	var x = target.global_position.x
	if r != null:
		x = clamp($interact_area/CollisionShape2D.global_position.x, r.position.x, r.end.x)
		# big collision areas (the bar, wide doorways): keep the cue close to the player, not far above
		top = Vector2(x, max(r.position.y - 26, $interact_area/CollisionShape2D.global_position.y - 110.0))
	cue_time += get_physics_process_delta_time()
	cue.global_position = top + Vector2(0, sin(cue_time * 5.0) * 3.0)
	cue.global_rotation = 0.0
	cue.visible = true

func activate_target(c):
	if c.is_in_group("NPC") and c.has_method("start_dialog"):
		c.start_dialog()
	elif c.is_in_group("DOOR") and c.has_method("start_door_request_dialog"):
		c.start_door_request_dialog()
	elif c.is_in_group("EXIT") and c.has_method("start_leave_request_dialog"):
		c.start_leave_request_dialog()

func update_interaction():
	var target = find_interact_target() if Global.moving == true else null
	_update_cue(target)
	if target != null and Input.is_action_just_pressed("interact"):
		cue.visible = false
		activate_target(target)

func _on_interact_area_body_entered(body):
	if body.is_in_group("NPC"):
		body.start_dialog()

func _on_interact_area_area_entered(area):
	if area.is_in_group("DOOR"):
		area.start_door_request_dialog()
	if area.is_in_group("EXIT"):
		area.start_leave_request_dialog()
		

