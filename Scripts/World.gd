extends Node2D

var index = Global.indices["world"]
onready var player = $Player
onready var end = $end
var mouse_over = false
var map_blur = null

func _ready():
	# map / movement state never carries across a scene change
	Global.moving = true
	Global.isVisible = true
	_place_player()
	_setup_map_blur()
	_setup_map_quest_markers()
	_first_time()
	Global.connect("left_town", self, "_on_left_town")
	
	if Global.indices["pollution"] > 5 and Global.indices["jayhouse"] > 1 and Global.indices["brockhouse"] > 1:
		end.visible = true
		var new_dialog = Dialogic.start('ending')
		new_dialog.pause_mode = PAUSE_MODE_PROCESS
		add_child(new_dialog)
		new_dialog.connect('timeline_end', self, 'end_dialog')
		get_tree().paused = true
		


func _first_time():
	if index > 0:
		get_tree().paused = false
		$direct/CollisionPolygon2D.disabled = true
		$direct.visible = false
	else:
		var new_dialog = Dialogic.start('Start')
		new_dialog.pause_mode = PAUSE_MODE_PROCESS
		add_child(new_dialog)
		new_dialog.connect('timeline_end', self, 'end_dialog')
		get_tree().paused = true
		Global.increment_index("world")
		

func end_dialog(_data):
	get_tree().paused = false
	$direct/CollisionPolygon2D.disabled = false
	$direct.visible = true

func _input(event):
	if not (event is InputEventKey) or not event.pressed or event.is_echo():
		return
	if Global.isVisible == false:
		# map open: M, Esc and every Interact key (Space, Enter, keypad Enter, E) close it. The press is
		# consumed here, so it cannot also open Pause (handled in _unhandled_input), and Global's
		# interact guard stops the same press from talking to someone or entering a door afterwards.
		if event.scancode == KEY_M or event.is_action_pressed("pause") or event.is_action_pressed("interact"):
			_toggle_map()
			get_tree().set_input_as_handled()
	elif event.scancode == KEY_M and not (Global.journal != null and Global.journal.is_open):
		_toggle_map()

# Opens the map if it is closed (used by the notice board). Closing stays on M, as before.
func open_map():
	if Global.isVisible == true and Global.moving == true and not get_tree().paused:
		_toggle_map()

# The map art hangs under the camera node, which sits at the player, not at the middle of the screen
# (the camera's drag margins let the two differ). Every frame the map is open, move the art so its
# centre is the centre of the visible gameplay viewport. Markers are children of the map, so they
# stay on the same spots of the art.
var _map_bounds = null

func _map_local_bounds():
	if _map_bounds != null:
		return _map_bounds
	var mm = $Player/Camera2D2/minimap
	var inv = mm.get_global_transform().affine_inverse()
	var r = null
	var stack = [mm]
	while stack.size() > 0:
		var n = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is TileMap and n.get_used_cells().size() > 0:
			var ur = n.get_used_rect()
			var cs = n.cell_size
			var xf = inv * n.get_global_transform()
			for corner in [Vector2(ur.position.x, ur.position.y), Vector2(ur.end.x, ur.position.y), Vector2(ur.position.x, ur.end.y), Vector2(ur.end.x, ur.end.y)]:
				var pt = xf.xform(corner * cs)
				if r == null:
					r = Rect2(pt, Vector2.ZERO)
				else:
					r = r.expand(pt)
	_map_bounds = r if r != null else Rect2(Vector2.ZERO, Vector2.ZERO)
	return _map_bounds

func _center_map():
	var mm = $Player/Camera2D2/minimap
	var b = _map_local_bounds()
	if b.size == Vector2.ZERO:
		return
	var screen_centre = get_viewport().get_canvas_transform().affine_inverse().xform(get_viewport_rect().size * 0.5)
	var art_centre = mm.to_global(b.position + b.size * 0.5)
	mm.global_position += screen_centre - art_centre

func _process(_delta):
	if Global.isVisible == false:
		_center_map()

func _toggle_map():
	if Global.isVisible == true:
		$Player/Camera2D2/minimap.visible = true
		_center_map()
		map_blur.visible = true
		Global.moving = false
		$"top exteriors/exteriorTop".visible = false
		$"top exteriors/homesTop".visible = false
		$"top exteriors/homesTop2".visible = false
		$towndoor.visible = false
		$stevendoor.visible = false
		$jaysondoor.visible = false
		$brockdoor.visible = false
	else:
		Global.moving = true
		Global.map_closed_at = OS.get_ticks_msec()
		$Player/Camera2D2/minimap.visible = false
		map_blur.visible = false
		$"top exteriors/exteriorTop".visible = true
		$"top exteriors/homesTop".visible = true
		$"top exteriors/homesTop2".visible = true
		$towndoor.visible = true
		$stevendoor.visible = true
		$jaysondoor.visible = true
		$brockdoor.visible = true

	Global.isVisible = !Global.isVisible


###################################
# Main Houses
###################################

func _on_towndoor_mouse_entered():
	pass     # the location label (interaction_markers.gd) now follows the mouse and the player
func _on_towndoor_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		$towndoor.start_door_request_dialog()
func _on_towndoor_mouse_exited():
	pass     # the location label (interaction_markers.gd) now follows the mouse and the player



func _on_stevendoor_mouse_entered():
	pass     # the location label (interaction_markers.gd) now follows the mouse and the player
func _on_stevendoor_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		$stevendoor.start_door_request_dialog()
func _on_stevendoor_mouse_exited():
	pass     # the location label (interaction_markers.gd) now follows the mouse and the player



func _on_jaysondoor_mouse_entered():
	pass     # the location label (interaction_markers.gd) now follows the mouse and the player
func _on_jaysondoor_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		$jaysondoor.start_door_request_dialog()
func _on_jaysondoor_mouse_exited():
	pass     # the location label (interaction_markers.gd) now follows the mouse and the player


func _on_brockdoor_mouse_entered():
	pass     # the location label (interaction_markers.gd) now follows the mouse and the player
func _on_brockdoor_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		$brockdoor.start_door_request_dialog()
func _on_brockdoor_mouse_exited():
	pass     # the location label (interaction_markers.gd) now follows the mouse and the player


###################################
# Map blur
###################################

func _setup_map_blur():
	var cam = $Player/Camera2D2
	var mm = $Player/Camera2D2/minimap
	# the map and its labels always draw above the blur layer, which draws above the world
	mm.z_as_relative = false
	mm.z_index = 100
	map_blur = ColorRect.new()
	map_blur.name = "MapBlur"
	map_blur.set_script(load("res://Scripts/map_blur.gd"))
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/map_blur.shader")
	map_blur.material = mat
	# z ordering is a Node2D property, so the (Control) blur rect sits inside a Node2D holder
	var holder = Node2D.new()
	holder.name = "MapBlurLayer"
	holder.z_as_relative = false
	holder.z_index = 90
	cam.add_child(holder)
	holder.add_child(map_blur)


###################################
# Where the player appears
###################################

# Godot connects this to Global.left_town (emitted when leaving a house); nothing to do here.
func _on_left_town():
	pass

func _foot_delta():
	var cs = player.get_node("CollisionShape2D")
	return cs.global_position - player.global_position

func _is_free(origin):
	var xf = player.global_transform
	xf.origin = origin
	return not player.test_move(xf, Vector2(0.01, 0.0))

func _door_rect(door):
	var rect = null
	for c in door.get_children():
		var r = null
		if c is CollisionShape2D and c.shape != null:
			var sc = c.global_transform.get_scale()
			if c.shape is RectangleShape2D:
				var e = c.shape.extents * sc
				r = Rect2(c.global_position - e, e * 2.0)
			elif c.shape is CircleShape2D:
				var rr = c.shape.radius * sc.x
				r = Rect2(c.global_position - Vector2(rr, rr), Vector2(rr, rr) * 2.0)
			else:
				r = Rect2(c.global_position - Vector2(64, 64), Vector2(128, 128))
		elif c is CollisionPolygon2D and c.polygon.size() > 0:
			var xf = c.global_transform
			var mn = xf.xform(c.polygon[0])
			var mx = mn
			for p in c.polygon:
				var g = xf.xform(p)
				mn = Vector2(min(mn.x, g.x), min(mn.y, g.y))
				mx = Vector2(max(mx.x, g.x), max(mx.y, g.y))
			r = Rect2(mn, mx - mn)
		if r != null:
			rect = r if rect == null else rect.merge(r)
	if rect == null:
		rect = Rect2(door.global_position - Vector2(64, 64), Vector2(128, 128))
	return rect

# distance from a point to a rectangle (0 when inside)
func _dist_to_rect(p, r):
	var dx = max(max(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy = max(max(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()

# How far the player's interact circle reaches (Player.tscn interact_area), plus a little slack.
func _interact_reach():
	var cs = player.get_node_or_null("interact_area/CollisionShape2D")
	var radius = 76.0
	if cs != null and cs.shape is CircleShape2D:
		radius = cs.shape.radius * cs.global_transform.get_scale().x
	return radius + 8.0

# Free of collision, the feet are outside the doorway, and pressing interact there can't reach the door
# again (so the first Space press after arriving never re-enters).
func _spot_ok(origin, keep_out, door_rect):
	if not _is_free(origin) or keep_out.has_point(origin + _foot_delta()):
		return false
	if _dist_to_rect(origin, door_rect) <= _interact_reach():
		return false
	return true

func _return_to_door(v):
	var door = find_node(v["door"], true, false)
	if door == null:
		return
	var rect = _door_rect(door)
	var keep_out = rect.grow(40.0)
	var foot = _foot_delta()
	var pre = v["player_pos"] if v.get("has_player_pos", false) else null
	var chosen = null
	# 1. exactly where the player stood before entering, if that was by this door and is still safe
	if pre != null and keep_out.grow(300.0).has_point(pre + foot) and _spot_ok(pre, keep_out, rect):
		chosen = pre
	# 2. otherwise the nearest safe spot just outside this door, closest to where they came from
	if chosen == null:
		var anchor = pre if pre != null else (rect.position + rect.size * 0.5 + Vector2(0, rect.size.y))
		var best_d = 1e18
		for ring in [24.0, 56.0, 96.0, 144.0, 208.0, 288.0, 400.0]:
			var box = keep_out.grow(ring)
			var n = int((box.size.x + box.size.y) * 2.0 / 24.0) + 4
			for i in range(n):
				var t = float(i) / n * 4.0
				var pt
				if t < 1.0:
					pt = Vector2(box.position.x + box.size.x * t, box.position.y)
				elif t < 2.0:
					pt = Vector2(box.end.x, box.position.y + box.size.y * (t - 1.0))
				elif t < 3.0:
					pt = Vector2(box.end.x - box.size.x * (t - 2.0), box.end.y)
				else:
					pt = Vector2(box.position.x, box.end.y - box.size.y * (t - 3.0))
				var origin = pt - foot
				if _spot_ok(origin, keep_out, rect):
					var d = (origin - anchor).length()
					if d < best_d:
						best_d = d
						chosen = origin
			if chosen != null:
				break
	if chosen != null:
		player.global_position = chosen

func _place_player():
	var v = Global.take_return_point()
	if not v.empty():
		_return_to_door(v)
	elif Global.continue_pending:
		Global.continue_pending = false
		if Global.has_saved_position:
			player.global_position = Global.player_position


###################################
# Quest markers on the map
###################################

var map_quest_markers = null

func _setup_map_quest_markers():
	map_quest_markers = load("res://Scripts/map_quest_markers.gd").new()
	map_quest_markers.name = "QuestMarkers"
	$Player/Camera2D2/minimap.add_child(map_quest_markers)
	map_quest_markers.setup(self)
