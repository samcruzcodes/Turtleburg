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

const JOG_FACTOR = 1.25   # holding Shift (action "jog") = about 25% faster than walking

func _physics_process(delta):
	if Global.moving == true:
		var input_vector = Vector2.ZERO
		input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		# diagonals are no faster than straight lines (a held W+D used to be 41% faster)
		input_vector = input_vector.limit_length(1.0)
		var speed = MAX_SPEED * (JOG_FACTOR if Input.is_action_pressed("jog") else 1.0)

		if input_vector != Vector2.ZERO:
			tree.set("parameters/Idle/blend_position", input_vector)
			tree.set ("parameters/walk/blend_position", input_vector)
			state.travel("walk")
			motion = motion.move_toward(input_vector * speed, acceleration * delta)
		else:
			state.travel("Idle")
			motion = motion.move_toward(Vector2.ZERO, friction * delta)
		motion = move_and_slide(motion)
	else:
		# map open (the only time the player is held without the tree being paused): nothing carries
		# the player. The old code kept sliding with whatever velocity a held key had left behind.
		motion = Vector2.ZERO
		state.travel("Idle")

	update_interaction()


# ---------------------------------------------------------------------------------------------
# Interaction + "!" markers (see interaction_markers.gd).
# Space, Enter and E are one action ("interact"). It activates exactly one thing: the nearest usable
# door, exit, object or NPC inside the interact circle - the same one the bright marker sits on.
# ---------------------------------------------------------------------------------------------
var markers = null
var cue = null            # marker sprite of the target in reach (tests / debugging)
var cue_target = null     # the target in reach: what the next keypress will activate

func _ready():
	markers = load("res://Scripts/interaction_markers.gd").new()
	markers.name = "InteractionMarkers"
	add_child(markers)
	markers.setup(self)

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
		# a usable target always wins over a locked / finished one standing closer
		if markers != null and not markers.is_usable(c):
			d += 100000.0
		if d < best_d:
			best_d = d
			best = c
	return best

func activate_target(c):
	if c.is_in_group("NPC") and c.has_method("start_dialog"):
		c.start_dialog()
	elif c.is_in_group("DOOR") and c.has_method("start_door_request_dialog"):
		c.start_door_request_dialog()
	elif c.is_in_group("EXIT") and c.has_method("start_leave_request_dialog"):
		c.start_leave_request_dialog()

func update_interaction():
	var target = find_interact_target() if Global.moving == true else null
	cue_target = target
	if markers != null:
		markers.update(target if target != null and markers.is_usable(target) else null)
		cue = markers.sprite_of(target) if target != null else null
	if target != null and Input.is_action_just_pressed("interact") and Global.interact_allowed():
		activate_target(target)
		if markers != null:
			markers.update(null)

func _on_interact_area_body_entered(body):
	if body.is_in_group("NPC"):
		body.start_dialog()

func _on_interact_area_area_entered(area):
	if area.is_in_group("DOOR"):
		area.start_door_request_dialog()
	if area.is_in_group("EXIT"):
		area.start_leave_request_dialog()
		

