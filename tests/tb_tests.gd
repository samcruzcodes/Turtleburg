extends Node
# Turtleburg regression tests (test-only autoload; never part of a release build).
# Select with env TB_TEST = doors | saves_unit | saves_p1 | saves_p2 | saves_p3 | blur | repro_old
# Other env: TB_OUT (dir for results/screenshots, must end with /), TB_SHOT=1 (save screenshots)
var t = 0.0
var fails = []
var passes = 0
var tl_log = []
var tl_names = {}
var seen_dialogs = {}
var held = {}
var player = null
var OUT = ""

# ------------------------------------------------------------------ basics
func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	OUT = OS.get_environment("TB_OUT")
	_load_names()
	call_deferred("main")

func _process(d):
	t += d
	if t > float(OS.get_environment("TB_TIMEOUT") if OS.get_environment("TB_TIMEOUT") != "" else "560"):
		FAIL("global timeout")
		finish()

func L(m):
	print("[TEST] ", m)

func CHECK(c, m):
	if c:
		passes += 1
		print("[TEST] PASS: ", m)
	else:
		FAIL(m)

func FAIL(m):
	fails.append(m)
	print("[TEST] *** FAIL: ", m)

func finish():
	release_all()
	if fails.size() == 0:
		print("[TEST] RESULT: ALL %d CHECKS PASSED" % passes)
	else:
		print("[TEST] RESULT: %d FAILURES (%d passed)" % [fails.size(), passes])
		for f in fails:
			print("[TEST]   - ", f)
	get_tree().quit()

func _load_names():
	var dir = Directory.new()
	if dir.open("res://dialogic/timelines") != OK:
		return
	dir.list_dir_begin(true)
	var f = dir.get_next()
	while f != "":
		if f.ends_with(".json"):
			var file = File.new()
			file.open("res://dialogic/timelines/" + f, File.READ)
			var res = JSON.parse(file.get_as_text())
			file.close()
			if res.error == OK and res.result.has("metadata"):
				tl_names[f] = str(res.result["metadata"].get("name", f))
		f = dir.get_next()

func wait(sec):
	yield(get_tree().create_timer(sec, true), "timeout")

func _key(code, down, ctrl = false):
	var ev = InputEventKey.new()
	ev.scancode = code
	ev.control = ctrl
	ev.pressed = down
	Input.parse_input_event(ev)

func tap(code, hold = 0.08, ctrl = false):
	_key(code, true, ctrl)
	yield(get_tree().create_timer(hold, true), "timeout")
	_key(code, false, ctrl)
	yield(get_tree().create_timer(0.05, true), "timeout")

func set_hold(code, on):
	if on and not held.has(code):
		held[code] = true
		_key(code, true)
	elif (not on) and held.has(code):
		held.erase(code)
		_key(code, false)

func release_all():
	for c in held.keys():
		_key(c, false)
	held.clear()

func scene_path():
	var cs = get_tree().current_scene
	return cs.filename if cs else ""

func root():
	return get_tree().current_scene

func find_scripted(node, suffix, out):
	var s = node.get_script()
	if s and _script_name(s).ends_with(suffix):
		out.append(node)
	for c in node.get_children():
		find_scripted(c, suffix, out)

func by_script(suffix):
	var out = []
	find_scripted(root(), suffix, out)
	return out

func dialog_node():
	var out = []
	find_scripted(get_tree().root, "DialogNode.gd", out)
	return out[0] if out.size() > 0 else null

func wait_scene(path, timeout = 40.0):
	var start = t
	while t - start < timeout:
		if scene_path() == path:
			yield(get_tree().create_timer(0.8, true), "timeout")
			return true
		yield(get_tree().create_timer(0.2, true), "timeout")
	FAIL("timed out waiting for scene " + path)
	return false

func choose(texts):
	var want = ["yes", "enter", "sure", "ok", "pick", "let's", "lets", "go", "i will", "i'll", "of course", "absolutely", "clean"]
	for i in range(texts.size()):
		var tl = str(texts[i]).to_lower().strip_edges()
		for w in want:
			if tl.begins_with(w):
				return i
	return 0

# Advance / answer dialogue until none remains. Returns true if a dialogue was shown.
func pump(label = "", timeout = 150.0):
	yield(get_tree(), "idle_frame")
	var start = t
	var idle = 0
	var seen = false
	while t - start < timeout:
		var d = dialog_node()
		if d == null:
			idle += 1
			if idle > 6:
				return seen
			yield(get_tree().create_timer(0.12, true), "timeout")
			continue
		idle = 0
		seen = true
		if not seen_dialogs.has(d.get_instance_id()):
			seen_dialogs[d.get_instance_id()] = true
			tl_log.append(tl_names.get(str(d.timeline).get_file(), str(d.timeline)))
		var bc = d.button_container
		if d.waiting_for_answer and bc != null and bc.get_child_count() > 0:
			yield(get_tree().create_timer(1.3, true), "timeout")
			bc = d.button_container
			if bc != null and bc.get_child_count() > 0:
				var texts = []
				for b in bc.get_children():
					texts.append(b.text)
				bc.get_child(choose(texts)).emit_signal("pressed")
				yield(get_tree().create_timer(0.4, true), "timeout")
		else:
			tap(KEY_SPACE, 0.05)
			yield(get_tree().create_timer(0.1, true), "timeout")
	FAIL("dialogue '%s' did not finish" % label)
	return seen

func has_tl(n):
	return tl_log.has(n)

func shot(tag):
	if OS.get_environment("TB_SHOT") != "1":
		return
	yield(VisualServer, "frame_post_draw")
	var img = get_viewport().get_texture().get_data()
	img.flip_y()
	img.save_png(OUT + tag + ".png")

func grab():
	yield(VisualServer, "frame_post_draw")
	var img = get_viewport().get_texture().get_data()
	img.flip_y()
	img.lock()
	return img

func new_game_to_world():
	var ok = wait_scene("res://Scenes/Start Menu.tscn", 15)
	if ok is GDScriptFunctionState:
		ok = yield(ok, "completed")
	var c = tap(KEY_SPACE, 0.1)       # New Game is focused: real keyboard press
	if c is GDScriptFunctionState:
		yield(c, "completed")
	ok = wait_scene("res://Scenes/World.tscn", 40)
	if ok is GDScriptFunctionState:
		ok = yield(ok, "completed")
	var p = pump("opening", 240)
	if p is GDScriptFunctionState:
		yield(p, "completed")
	yield(get_tree().create_timer(0.8, true), "timeout")
	player = root().find_node("Player", true, false)
	return ok

# ------------------------------------------------------------------ geometry / walking
var gstep = 12.0
var gx0 = 0.0
var gy0 = 0.0
var gw = 0
var gh = 0
var gfree = {}

func feet():
	return player.get_node("CollisionShape2D").global_position

func foot_delta():
	return feet() - player.global_position

func key_of(ix, iy):
	return ix * 100000 + iy

func cell_pos(ix, iy):
	return Vector2(gx0 + ix * gstep, gy0 + iy * gstep)

func cell_of(p):
	return Vector2(int(round((p.x - gx0) / gstep)), int(round((p.y - gy0) / gstep)))

func is_free_origin(origin):
	var xf = player.global_transform
	xf.origin = origin
	return not player.test_move(xf, Vector2(0.01, 0.0))

func grid_build(box):
	gx0 = box.position.x
	gy0 = box.position.y
	gw = int(box.size.x / gstep) + 1
	gh = int(box.size.y / gstep) + 1
	gfree.clear()
	var fd = foot_delta()
	for iy in range(gh):
		for ix in range(gw):
			gfree[key_of(ix, iy)] = is_free_origin(cell_pos(ix, iy) - fd)

func grid_path(from_p, to_p):
	var s = cell_of(from_p)
	var g = cell_of(to_p)
	if not gfree.get(key_of(int(g.x), int(g.y)), false):
		# nearest free cell to the goal
		var best = null
		var bd = 1e18
		for k in gfree.keys():
			if gfree[k]:
				var p = cell_pos(int(k / 100000), int(k % 100000))
				var d = (p - to_p).length()
				if d < bd:
					bd = d
					best = Vector2(int(k / 100000), int(k % 100000))
		if best == null:
			return []
		g = best
	var prev = {}
	prev[key_of(int(s.x), int(s.y))] = Vector2(-1, -1)
	var q = [s]
	var head = 0
	var found = false
	while head < q.size():
		var c = q[head]
		head += 1
		if c == g:
			found = true
			break
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var n = c + d
			if n.x < 0 or n.y < 0 or n.x >= gw or n.y >= gh:
				continue
			var k = key_of(int(n.x), int(n.y))
			if prev.has(k) or not gfree.get(k, false):
				continue
			prev[k] = c
			q.append(n)
	if not found:
		return []
	var chain = []
	var c2 = g
	while c2.x >= 0:
		chain.push_front(cell_pos(int(c2.x), int(c2.y)))
		c2 = prev[key_of(int(c2.x), int(c2.y))]
	return chain

func seg_free(a, b):
	var n = int((a - b).length() / 6.0) + 1
	for i in range(n + 1):
		var p = a.linear_interpolate(b, float(i) / n)
		var c = cell_of(p)
		if not gfree.get(key_of(int(c.x), int(c.y)), false):
			return false
	return true

func walk_feet(target, timeout = 20.0):
	var start = t
	var last = feet()
	var last_check = t
	var stuck = 0
	while t - start < timeout:
		var e = target - feet()
		if abs(e.x) < 3.0 and abs(e.y) < 3.0:
			break
		set_hold(KEY_D, e.x > 3.0)
		set_hold(KEY_A, e.x < -3.0)
		set_hold(KEY_S, e.y > 3.0)
		set_hold(KEY_W, e.y < -3.0)
		yield(get_tree(), "physics_frame")
		if t - last_check > 0.4:
			stuck = stuck + 1 if (feet() - last).length() < 2.0 else 0
			last = feet()
			last_check = t
			if stuck >= 2:
				break
	release_all()
	yield(get_tree().create_timer(0.25, true), "timeout")
	return (target - feet()).length() < 8.0

# Walk with real key presses to a feet position, planning around collision. Returns true if reached.
func walk_to(target, margin = 260.0):
	yield(get_tree(), "idle_frame")
	var from_p = feet()
	var box = Rect2(Vector2(min(from_p.x, target.x), min(from_p.y, target.y)), (from_p - target).abs()).grow(margin)
	grid_build(box)
	var chain = grid_path(from_p, target)
	if chain.size() == 0:
		return false
	var i = 0
	var guard = 0
	while i < chain.size() - 1 and guard < 400:
		guard += 1
		var j = chain.size() - 1
		var cur = feet()
		while j > i and not seg_free(cur, chain[j]):
			j -= 1
		if j == i:
			j = i + 1
		var w = walk_feet(chain[j], 20.0)
		if w is GDScriptFunctionState:
			w = yield(w, "completed")
		if not w:
			# re-plan from where we are
			return (feet() - target).length() < 12.0
		i = j
	return (feet() - target).length() < 12.0

func teleport_feet(p):
	player.global_position += p - feet()
	player.motion = Vector2.ZERO

func rect_of_area(door):
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

# Stand next to an Area2D door/exit by really walking there, then press Space.
# approach_dir: which side to come from (unit-ish vector). Returns the player position at the press.
func walk_to_area_and_interact(area, approach_dir, stage_dist = 280.0, press = true):
	yield(get_tree(), "idle_frame")
	var rect = rect_of_area(area)
	var center = rect.position + rect.size * 0.5
	var fd = foot_delta()
	# stage: a free spot about stage_dist away on the requested side (teleport only to get into range)
	var want = center + approach_dir.normalized() * (max(rect.size.x, rect.size.y) * 0.5 + stage_dist)
	var box = Rect2(center - Vector2(1, 1) * (stage_dist + 220.0), Vector2(1, 1) * (2.0 * (stage_dist + 220.0)))
	grid_build(box)
	var stage = null
	var bd = 1e18
	for k in gfree.keys():
		if gfree[k]:
			var p = cell_pos(int(k / 100000), int(k % 100000))
			var d = (p - want).length()
			if d < bd:
				bd = d
				stage = p
	if stage == null:
		return null
	teleport_feet(stage)
	yield(get_tree().create_timer(0.3, true), "timeout")
	# target: free cell whose player origin is within ~45px of the door shape, nearest to the stage
	var tgt = null
	bd = 1e18
	for k in gfree.keys():
		if gfree[k]:
			var p = cell_pos(int(k / 100000), int(k % 100000))
			var origin = p - fd
			var inside = rect.has_point(origin)
			var dx = max(max(rect.position.x - origin.x, 0.0), origin.x - rect.end.x)
			var dy = max(max(rect.position.y - origin.y, 0.0), origin.y - rect.end.y)
			var dist = Vector2(dx, dy).length()
			if (dist <= 45.0 or inside) and not rect.grow(-1.0).has_point(p):
				var d = (p - stage).length()
				if d < bd:
					bd = d
					tgt = p
	if tgt == null:
		return null
	var w = walk_to(tgt, 220.0)
	if w is GDScriptFunctionState:
		w = yield(w, "completed")
	yield(get_tree().create_timer(0.2, true), "timeout")
	var at_press = player.global_position
	if not press:
		return {"pos": at_press, "walked": w}
	var c = tap(KEY_SPACE, 0.12)
	if c is GDScriptFunctionState:
		yield(c, "completed")
	yield(get_tree().create_timer(0.5, true), "timeout")
	return {"pos": at_press, "walked": w}

func interact_tp(node):
	# teleport onto the target's shape, then a real Space press (items/NPCs inside rooms)
	var rect = rect_of_area(node) if node is Area2D else Rect2(node.global_position, Vector2(1, 1))
	teleport_feet(rect.position + rect.size * 0.5 + Vector2(0, 0))
	yield(get_tree().create_timer(0.35, true), "timeout")
	var c = tap(KEY_SPACE, 0.12)
	if c is GDScriptFunctionState:
		yield(c, "completed")
	yield(get_tree().create_timer(0.5, true), "timeout")
	var p = pump("interact", 120)
	if p is GDScriptFunctionState:
		p = yield(p, "completed")
	return p

func idx():
	return Global.indices.duplicate()

# ------------------------------------------------------------------ doors
func clean_house(kind):
	if kind == "jayson":
		for sfx in ["old toilet jayson.gd", "old bathtub jayson.gd"]:
			for nd in by_script(sfx):
				var r = interact_tp(nd)
				if r is GDScriptFunctionState:
					yield(r, "completed")
	else:
		for sfx in ["brocktoilet.gd", "brocktubn.gd", "dirty counter.gd", "shakes.gd"]:
			for nd in by_script(sfx):
				var r = interact_tp(nd)
				if r is GDScriptFunctionState:
					yield(r, "completed")

func leave_by_exit(exit_suffix):
	var ex = by_script(exit_suffix)
	if ex.size() == 0:
		FAIL("no exit " + exit_suffix)
		return false
	var rect = rect_of_area(ex[0])
	var tgt = rect.position + rect.size * 0.5
	var w = walk_to(tgt, 500.0)
	if w is GDScriptFunctionState:
		w = yield(w, "completed")
	if not w:
		# the straight search area was too small: stage a short distance away, then really walk the rest
		var r2 = walk_to_area_and_interact(ex[0], Vector2(0, -1))
		if r2 is GDScriptFunctionState:
			r2 = yield(r2, "completed")
		w = r2 != null and r2["walked"]
	else:
		var c = tap(KEY_SPACE, 0.12)
		if c is GDScriptFunctionState:
			yield(c, "completed")
	yield(get_tree().create_timer(0.5, true), "timeout")
	var p = pump("exit", 120)
	if p is GDScriptFunctionState:
		yield(p, "completed")
	return w

func world_door(name_):
	return root().find_node(name_, true, false)

func test_doors():
	var ok = new_game_to_world()
	if ok is GDScriptFunctionState:
		yield(ok, "completed")
	CHECK(player != null, "New Game reached the world")
	var order = [
		["towndoor", Vector2(0, 1), "res://Scenes/townhall.tscn", "exit.gd"],
		["jaysondoor", Vector2(0, 1), "res://Scenes/Jaysonhome.tscn", "jaysonleave.gd"],
		["brockdoor", Vector2(0, 1), "res://Scenes/brockhome.tscn", "brockleave.gd"],
		["towndoor", Vector2(-1, 0), "res://Scenes/townhall.tscn", "exit.gd"],
	]
	var visit_no = 0
	for v in order:
		visit_no += 1
		var door = world_door(v[0])
		var door_rect = rect_of_area(door)
		var r = null
		# try the preferred side first, then the other sides, until a real walk reaches the door
		for dir in [v[1], Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1)]:
			r = walk_to_area_and_interact(door, dir)
			if r is GDScriptFunctionState:
				r = yield(r, "completed")
			if r != null and r["walked"]:
				break
			if r != null and scene_path() != "res://Scenes/World.tscn":
				break
		if r == null:
			FAIL("visit %d: could not reach a spot beside %s" % [visit_no, v[0]])
			continue
		var pre = r["pos"]
		L("visit %d %s: pressed Space at %s (walked=%s)" % [visit_no, v[0], str(pre), str(r["walked"])])
		var pp = pump("enter_" + v[0], 150)
		if pp is GDScriptFunctionState:
			yield(pp, "completed")
		var in_ = wait_scene(v[2], 25)
		if in_ is GDScriptFunctionState:
			in_ = yield(in_, "completed")
		CHECK(in_, "visit %d: %s leads to %s" % [visit_no, v[0], v[2].get_file()])
		if not in_:
			break
		var d1 = pump("interior_intro", 120)
		if d1 is GDScriptFunctionState:
			yield(d1, "completed")
		player = root().find_node("Player", true, false)
		# houses must be cleaned before the exit works
		if v[2].ends_with("Jaysonhome.tscn"):
			var cc = clean_house("jayson")
			if cc is GDScriptFunctionState:
				yield(cc, "completed")
		elif v[2].ends_with("brockhome.tscn"):
			var cc2 = clean_house("brock")
			if cc2 is GDScriptFunctionState:
				yield(cc2, "completed")
		L("visit %d: after cleaning, indices=%s trash=%s" % [visit_no, str(Global.indices), str(Global.collected_trash.size())])
		var lv = leave_by_exit(v[3])
		if lv is GDScriptFunctionState:
			lv = yield(lv, "completed")
		L("visit %d: leave_by_exit walked=%s player=%s paused=%s dialog=%s" % [visit_no, str(lv), str(player.global_position) if is_instance_valid(player) else "scene changed", str(get_tree().paused), str(dialog_node() != null)])
		var back = wait_scene("res://Scenes/World.tscn", 25)
		if back is GDScriptFunctionState:
			back = yield(back, "completed")
		CHECK(back, "visit %d: leaving %s returns to the world" % [visit_no, v[2].get_file()])
		if not back:
			break
		yield(get_tree().create_timer(1.2, true), "timeout")
		player = root().find_node("Player", true, false)
		door = world_door(v[0])
		door_rect = rect_of_area(door)
		var now = player.global_position
		var d_pre = (now - pre).length()
		var feet_now = feet()
		var keep_out = door_rect.grow(40.0)
		CHECK(is_free_origin(now), "visit %d: return spot is not inside a wall (%s)" % [visit_no, str(now)])
		CHECK(not keep_out.has_point(feet_now), "visit %d: return spot is outside the %s doorway" % [visit_no, v[0]])
		var po = player.global_position
		var rdx = max(max(door_rect.position.x - po.x, 0.0), po.x - door_rect.end.x)
		var rdy = max(max(door_rect.position.y - po.y, 0.0), po.y - door_rect.end.y)
		var icn = player.get_node("interact_area/CollisionShape2D")
		var reach = icn.shape.radius * icn.global_transform.get_scale().x
		CHECK(Vector2(rdx, rdy).length() > reach, "visit %d: the interact circle (radius %.0f) does not reach the %s (%.0f px away)" % [visit_no, reach, v[0], Vector2(rdx, rdy).length()])
		CHECK(d_pre <= 40.0 or (feet_now - (door_rect.position + door_rect.size * 0.5)).length() < 500.0, "visit %d: back near %s (moved %.0f px from where they stood)" % [visit_no, v[0], d_pre])
		for other in ["towndoor", "jaysondoor", "brockdoor"]:
			if other != v[0]:
				var orect = rect_of_area(world_door(other))
				CHECK((feet_now - (orect.position + orect.size * 0.5)).length() > (feet_now - (door_rect.position + door_rect.size * 0.5)).length(), "visit %d: closer to %s than to %s" % [visit_no, v[0], other])
		CHECK(dialog_node() == null and not get_tree().paused, "visit %d: no dialogue/re-entry triggered on arrival" % visit_no)
		CHECK(Global.visit.empty(), "visit %d: visit record consumed" % visit_no)
		shot("door_return_%d_%s" % [visit_no, v[0]])
	# click entry from far away (mouse): the return spot must still be next to that door
	var d = world_door("towndoor")
	var drect = rect_of_area(d)
	var far = drect.position + drect.size * 0.5 + Vector2(-380, 330)
	var best = null
	var gb = Rect2(far - Vector2(200, 200), Vector2(400, 400))
	grid_build(gb)
	var bd = 1e18
	for k in gfree.keys():
		if gfree[k]:
			var p = cell_pos(int(k / 100000), int(k % 100000))
			if (p - far).length() < bd:
				bd = (p - far).length()
				best = p
	teleport_feet(best)
	yield(get_tree().create_timer(0.5, true), "timeout")
	var pre2 = player.global_position
	var sp = get_viewport().get_canvas_transform().xform(drect.position + drect.size * 0.5)
	L("click entry: player %s door screen pos %s" % [str(pre2), str(sp)])
	var ev = InputEventMouseButton.new()
	ev.button_index = BUTTON_LEFT
	ev.pressed = true
	ev.position = sp
	ev.global_position = sp
	var mm = InputEventMouseMotion.new()
	mm.position = sp
	mm.global_position = sp
	Input.parse_input_event(mm)
	yield(get_tree().create_timer(0.2, true), "timeout")
	Input.parse_input_event(ev)
	yield(get_tree().create_timer(0.1, true), "timeout")
	ev.pressed = false
	Input.parse_input_event(ev)
	yield(get_tree().create_timer(0.6, true), "timeout")
	var started = dialog_node() != null
	CHECK(started, "mouse click on the town hall door starts the door dialogue")
	if started:
		var pp2 = pump("click_enter", 150)
		if pp2 is GDScriptFunctionState:
			yield(pp2, "completed")
		var in2 = wait_scene("res://Scenes/townhall.tscn", 25)
		if in2 is GDScriptFunctionState:
			in2 = yield(in2, "completed")
		if in2:
			var d2 = pump("townhall_intro", 120)
			if d2 is GDScriptFunctionState:
				yield(d2, "completed")
			player = root().find_node("Player", true, false)
			var lv2 = leave_by_exit("exit.gd")
			if lv2 is GDScriptFunctionState:
				yield(lv2, "completed")
			var b2 = wait_scene("res://Scenes/World.tscn", 25)
			if b2 is GDScriptFunctionState:
				b2 = yield(b2, "completed")
			yield(get_tree().create_timer(1.2, true), "timeout")
			player = root().find_node("Player", true, false)
			var dr = rect_of_area(world_door("towndoor"))
			var ff = feet()
			CHECK(b2 and is_free_origin(player.global_position), "click entry: returned to the world on a free spot")
			CHECK(not dr.grow(40.0).has_point(ff) and (ff - (dr.position + dr.size * 0.5)).length() < 500.0, "click entry: returned just outside the town hall door (%.0f px from its centre) although entered from %.0f px away" % [(ff - (dr.position + dr.size * 0.5)).length(), (pre2 - (dr.position + dr.size * 0.5)).length()])
	finish()

# ------------------------------------------------------------------ saves (unit-style, single process)
func read_bytes(path):
	var f = File.new()
	if not f.file_exists(path):
		return null
	f.open(path, File.READ)
	var b = f.get_buffer(f.get_len())
	f.close()
	return b

func write_raw(path, bytes):
	var f = File.new()
	f.open(path, File.WRITE)
	f.store_buffer(bytes)
	f.close()

func rm(path):
	var d = Directory.new()
	if d.file_exists(path):
		d.remove(path)

func key_save():
	var c = tap(KEY_S, 0.1, true)       # real Ctrl+S
	if c is GDScriptFunctionState:
		yield(c, "completed")
	yield(get_tree().create_timer(0.35, true), "timeout")


# ------------------------------------------------------------------ cue + draw order while walking
var sampling = false
var lay = null
var lay_stats = {}

func _physics_process(_d):
	if sampling and lay != null and is_instance_valid(lay) and is_instance_valid(player):
		sample_layers()

func sample_layers():
	var fy = lay.feet_y()
	for o in lay.objects:
		var n = o["node"]
		if not is_instance_valid(n):
			continue
		var key = "%s#%d" % [o["name"], lay.objects.find(o)]
		var z = n.z_index
		if not lay_stats.has(key):
			lay_stats[key] = {"z": z, "toggles": 0, "last": -9.0, "flick": 0, "run": 0, "maxrun": 0}
		var st = lay_stats[key]
		if z != st["z"]:
			st["toggles"] += 1
			if t - st["last"] < 0.3:
				st["flick"] += 1
			st["last"] = t
			st["z"] = z
		var want = 1 if fy < o["base"] else -1
		if z != want:
			st["run"] += 1
			st["maxrun"] = max(st["maxrun"], st["run"])
		else:
			st["run"] = 0

func cue_ok(node, what):
	yield(get_tree().create_timer(0.35, true), "timeout")
	var cue = player.cue
	var good = cue != null and cue.is_inside_tree() and cue.is_visible_in_tree() and player.cue_target == node
	CHECK(good, "cue shows on %s (target=%s visible=%s)" % [what, str(player.cue_target.name) if player.cue_target != null else "none", str(cue.visible) if cue != null else "?"])
	if good:
		var r = player.get_node("interact_area/CollisionShape2D").global_position
		CHECK(cue.global_position.distance_to(r) < 300.0, "cue for %s is near the player/target (%d px)" % [what, int(cue.global_position.distance_to(r))])
	return good

func cue_gone(what):
	yield(get_tree().create_timer(0.35, true), "timeout")
	CHECK(player.cue != null and player.cue.is_inside_tree() and not player.cue.visible and player.cue_target == null, "cue gone: " + what)

func walk_layers_scene(label, home):
	player = root().find_node("Player", true, false)
	var ls = by_script("interior_layering.gd")
	if ls.size() == 0:
		FAIL(label + ": no interior_layering node")
		return
	lay = ls[0]
	lay_stats = {}
	teleport_feet(home)
	yield(get_tree().create_timer(0.4, true), "timeout")
	sampling = true
	var travelled = 0.0
	var last = feet()
	var shots = 0
	# laps of real key presses around the room; collision stops the player at furniture, walls and counters
	var laps = [[KEY_W, 1.4], [KEY_D, 1.3], [KEY_S, 2.6], [KEY_A, 1.6], [KEY_W, 2.4], [KEY_D, 2.0], [KEY_S, 2.2], [KEY_A, 2.6], [KEY_W, 1.8], [KEY_D, 1.0], [KEY_S, 1.4]]
	for lap in laps:
		set_hold(lap[0], true)
		var t0 = t
		while t - t0 < lap[1]:
			yield(get_tree(), "physics_frame")
			travelled += (feet() - last).length()
			last = feet()
		release_all()
		if shots < 3 and lap[0] == KEY_W:
			shots += 1
			var shw = shot("walk_%s_%d" % [label, shots])
			if shw is GDScriptFunctionState:
				yield(shw, "completed")
	sampling = false
	var flick = 0
	var stuck = 0
	var toggled = 0
	for k in lay_stats.keys():
		var st = lay_stats[k]
		flick += st["flick"]
		if st["toggles"] > 0:
			toggled += 1
		if st["maxrun"] > 3:
			stuck += 1
			L("out-of-step object: %s (max %d frames, %d toggles)" % [k, st["maxrun"], st["toggles"]])
	L("%s: walked %d px; %d objects changed side, %d flicker events, %d objects out of step >3 frames (of %d)" % [label, int(travelled), toggled, flick, stuck, lay_stats.size()])
	CHECK(travelled > 300.0, label + ": walked around the room with real keys (%d px)" % int(travelled))
	CHECK(toggled > 0, label + ": draw order changed while walking")
	CHECK(flick == 0, label + ": no flicker (no object flipped sides twice within 0.3 s)")
	CHECK(stuck == 0, label + ": draw order always matches the feet rule")
	lay = null

func _by_area(a, b):
	return a["area"] > b["area"]

func test_cues_walk():
	var ok = new_game_to_world()
	if ok is GDScriptFunctionState:
		yield(ok, "completed")
	CHECK(player != null, "New Game reached the world")
	var old_player = player
	# --- outdoors: cue on the town hall door, then walk away
	var door = world_door("towndoor")
	var r = walk_to_area_and_interact(door, Vector2(0, 1), 280.0, false)
	if r is GDScriptFunctionState:
		r = yield(r, "completed")
	CHECK(r != null, "reached the town hall door")
	var c1 = cue_ok(door, "town hall door")
	if c1 is GDScriptFunctionState:
		yield(c1, "completed")
	var w = walk_feet(feet() + Vector2(0, 260), 8.0)
	if w is GDScriptFunctionState:
		yield(w, "completed")
	var g1 = cue_gone("walked away from the door")
	if g1 is GDScriptFunctionState:
		yield(g1, "completed")
	# --- the cue target is what Space opens
	r = walk_to_area_and_interact(door, Vector2(0, 1), 280.0, false)
	if r is GDScriptFunctionState:
		r = yield(r, "completed")
	var c2 = cue_ok(door, "town hall door (again)")
	if c2 is GDScriptFunctionState:
		yield(c2, "completed")
	var tc = tap(KEY_SPACE, 0.12)
	if tc is GDScriptFunctionState:
		yield(tc, "completed")
	yield(get_tree().create_timer(0.4, true), "timeout")
	CHECK(dialog_node() != null and not player.cue.visible, "Space on the cue target starts its dialogue and the cue hides")
	var pp = pump("enter_towndoor", 150)
	if pp is GDScriptFunctionState:
		yield(pp, "completed")
	var in_ = wait_scene("res://Scenes/townhall.tscn", 25)
	if in_ is GDScriptFunctionState:
		in_ = yield(in_, "completed")
	CHECK(in_, "Space on the cue target went into the town hall")
	CHECK(not is_instance_valid(old_player) or old_player.is_queued_for_deletion(), "cue (and its player) removed on scene change")
	var d1 = pump("townhall_intro", 120)
	if d1 is GDScriptFunctionState:
		yield(d1, "completed")
	player = root().find_node("Player", true, false)
	yield(get_tree().create_timer(0.6, true), "timeout")
	# --- town hall: cue on every usable thing, tested by standing on it
	var th_home = feet()
	var n_checked = 0
	for nd in get_tree().get_nodes_in_group("EXIT") + get_tree().get_nodes_in_group("DOOR") + get_tree().get_nodes_in_group("NPC"):
		if n_checked >= 6 or not (nd is Area2D or nd is PhysicsBody2D):
			continue
		var rect = rect_of_area(nd)
		var ctr = rect.position + rect.size * 0.5
		teleport_feet(ctr)
		var cc = cue_ok(nd, "town hall: " + str(nd.name))
		if cc is GDScriptFunctionState:
			cc = yield(cc, "completed")
		n_checked += 1
	CHECK(n_checked >= 3, "checked the cue on several town hall objects (%d)" % n_checked)
	var wl = walk_layers_scene("townhall", th_home)
	if wl is GDScriptFunctionState:
		yield(wl, "completed")
	# --- leave, then a house
	var lv = leave_by_exit("exit.gd")
	if lv is GDScriptFunctionState:
		yield(lv, "completed")
	var back = wait_scene("res://Scenes/World.tscn", 25)
	if back is GDScriptFunctionState:
		back = yield(back, "completed")
	CHECK(back, "left the town hall")
	player = root().find_node("Player", true, false)
	yield(get_tree().create_timer(0.8, true), "timeout")
	var jd = world_door("jaysondoor")
	var rj = walk_to_area_and_interact(jd, Vector2(0, 1), 280.0, false)
	if rj is GDScriptFunctionState:
		rj = yield(rj, "completed")
	var c3 = cue_ok(jd, "Jayson's door")
	if c3 is GDScriptFunctionState:
		yield(c3, "completed")
	var tc2 = tap(KEY_SPACE, 0.12)
	if tc2 is GDScriptFunctionState:
		yield(tc2, "completed")
	var pj = pump("enter_jaysondoor", 150)
	if pj is GDScriptFunctionState:
		yield(pj, "completed")
	var inj = wait_scene("res://Scenes/Jaysonhome.tscn", 25)
	if inj is GDScriptFunctionState:
		inj = yield(inj, "completed")
	CHECK(inj, "Space on the cue target went into Jayson's house")
	var d2 = pump("house_intro", 120)
	if d2 is GDScriptFunctionState:
		yield(d2, "completed")
	player = root().find_node("Player", true, false)
	yield(get_tree().create_timer(0.6, true), "timeout")
	var jh_home = feet()
	# the room objects: stand on the toilet, cue, Space, cue disappears once it is used
	var toilet = by_script("old toilet jayson.gd")[0]
	var rt = rect_of_area(toilet)
	teleport_feet(rt.position + rt.size * 0.5)
	var c4 = cue_ok(toilet, "old toilet in the house")
	if c4 is GDScriptFunctionState:
		yield(c4, "completed")
	var shc = shot("cue_in_room")
	if shc is GDScriptFunctionState:
		yield(shc, "completed")
	var ti = tap(KEY_SPACE, 0.12)
	if ti is GDScriptFunctionState:
		yield(ti, "completed")
	var pi = pump("toilet", 120)
	if pi is GDScriptFunctionState:
		yield(pi, "completed")
	var g2 = cue_gone("old toilet is done")
	if g2 is GDScriptFunctionState:
		yield(g2, "completed")
	var wh = walk_layers_scene("jaysonhome", jh_home)
	if wh is GDScriptFunctionState:
		yield(wh, "completed")
	finish()


# ------------------------------------------------------------------ map open: nothing may move the player
func log_drift(label, p0, dur):
	var t0 = t
	var worst = 0.0
	while t - t0 < dur:
		yield(get_tree(), "physics_frame")
		worst = max(worst, (player.global_position - p0).length())
	L("%s: max drift %.2f px, end drift %.2f px" % [label, worst, (player.global_position - p0).length()])
	return worst

func test_map_drift():
	var ok = new_game_to_world()
	if ok is GDScriptFunctionState:
		yield(ok, "completed")
	# A: open the map while a movement key is held, then release it
	set_hold(KEY_S, true)
	yield(get_tree().create_timer(0.7, true), "timeout")
	var m = tap(KEY_M, 0.08)
	if m is GDScriptFunctionState:
		yield(m, "completed")
	release_all()
	yield(get_tree().create_timer(0.15, true), "timeout")
	var p0 = player.global_position
	var d = log_drift("A held key at map open", p0, 1.5)
	if d is GDScriptFunctionState:
		d = yield(d, "completed")
	CHECK(d < 0.5, "A: player stays put while the map is open after walking into it (%.2f px)" % d)
	var m2 = tap(KEY_M, 0.08)
	if m2 is GDScriptFunctionState:
		yield(m2, "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	CHECK((player.global_position - p0).length() < 0.5, "A: no snap when the map closes (%.2f px)" % (player.global_position - p0).length())
	# B: an NPC walks through the player while the map is open
	var npcs = get_tree().get_nodes_in_group("NPC")
	L("npcs: %d" % npcs.size())
	for npc in npcs:
		var start = player.global_position
		player.global_position = npc.global_position + Vector2(0, 8)
		yield(get_tree().create_timer(0.2, true), "timeout")
		var m3 = tap(KEY_M, 0.08)
		if m3 is GDScriptFunctionState:
			yield(m3, "completed")
		var q0 = player.global_position
		var npc0 = npc.global_position
		var d2 = log_drift("B NPC %s overlapping, map open" % npc.name, q0, 2.0)
		if d2 is GDScriptFunctionState:
			d2 = yield(d2, "completed")
		L("B: %s itself moved %.0f px in that time" % [npc.name, (npc.global_position - npc0).length()])
		CHECK(d2 < 0.5, "B: %s cannot move the player while the map is open (%.2f px)" % [npc.name, d2])
		var m4 = tap(KEY_M, 0.08)
		if m4 is GDScriptFunctionState:
			yield(m4, "completed")
		var d3 = log_drift("B NPC %s after the map closes" % npc.name, q0, 0.8)
		if d3 is GDScriptFunctionState:
			d3 = yield(d3, "completed")
		player.global_position = start
	finish()


# ------------------------------------------------------------------ polish smoke: jog, keys, markers
func mk(node):
	return player.markers.sprite_of(node)

func shown(node):
	var m = mk(node)
	return m != null and m.visible

func bright(node):
	return shown(node) and mk(node).modulate.a > 0.9

func measure_speed(keys, shift, dur = 0.5):
	var home = player.global_position
	for k in keys:
		set_hold(k, true)
	if shift:
		set_hold(KEY_SHIFT, true)
	yield(get_tree().create_timer(0.25, true), "timeout")
	var p0 = player.global_position
	var t0 = t
	yield(get_tree().create_timer(dur, true), "timeout")
	var d = (player.global_position - p0).length() / (t - t0)
	release_all()
	yield(get_tree().create_timer(0.2, true), "timeout")
	player.global_position = home
	return d

func test_polish_smoke():
	var ok = new_game_to_world()
	if ok is GDScriptFunctionState:
		yield(ok, "completed")
	# --- jog: +25%, same on diagonals, WASD and arrows
	var res = {}
	for cfg in [["walk S", [KEY_S], false], ["jog S", [KEY_S], true], ["jog arrow-down", [KEY_DOWN], true], ["jog S+D", [KEY_S, KEY_D], true], ["walk S+D", [KEY_S, KEY_D], false]]:
		var v = measure_speed(cfg[1], cfg[2])
		if v is GDScriptFunctionState:
			v = yield(v, "completed")
		res[cfg[0]] = v
		L("speed %s = %.1f px/s" % [cfg[0], v])
	CHECK(abs(res["jog S"] / res["walk S"] - 1.25) < 0.06, "jog is ~25%% faster than walking (%.2f)" % (res["jog S"] / res["walk S"]))
	CHECK(abs(res["jog arrow-down"] / res["jog S"] - 1.0) < 0.05, "arrows and WASD jog at the same speed")
	if res["jog S+D"] > 20.0:
		CHECK(abs(res["jog S+D"] / res["jog S"] - 1.0) < 0.06, "diagonal jog equals straight jog (%.2f)" % (res["jog S+D"] / res["jog S"]))
		CHECK(abs(res["walk S+D"] / res["walk S"] - 1.0) < 0.06, "diagonal walk equals straight walk (%.2f)" % (res["walk S+D"] / res["walk S"]))
	else:
		L("diagonal blocked by scenery here (not checked)")
	# --- an interact key never activates two things: use a townie door and advance with Enter
	var tdoors = by_script("towniedoor.gd")
	var done_two = false
	for td in tdoors:
		var r = walk_to_area_and_interact(td, Vector2(0, 1), 280.0, false)
		if r is GDScriptFunctionState:
			r = yield(r, "completed")
		if r == null:
			continue
		yield(get_tree().create_timer(0.3, true), "timeout")
		if player.cue_target != td:
			continue
		CHECK(bright(td), "marker on the townie door in reach is bright")
		var e = tap(KEY_E, 0.1)
		if e is GDScriptFunctionState:
			yield(e, "completed")
		yield(get_tree().create_timer(0.4, true), "timeout")
		CHECK(dialog_node() != null and not shown(td), "E opens exactly that door's dialogue and its marker hides")
		var n = 0
		while dialog_node() != null and n < 60:
			var en = tap(KEY_ENTER, 0.08)
			if en is GDScriptFunctionState:
				yield(en, "completed")
			yield(get_tree().create_timer(0.35, true), "timeout")
			n += 1
		yield(get_tree().create_timer(0.8, true), "timeout")
		CHECK(dialog_node() == null, "Enter that closes the dialogue does not reopen it (%d presses)" % n)
		done_two = true
		break
	if not done_two:
		L("no townie door reachable for the one-press check")
	# --- the town hall door: outdoors only the door in reach has a marker
	var door = world_door("towndoor")
	var r2 = walk_to_area_and_interact(door, Vector2(0, 1), 280.0, false)
	if r2 is GDScriptFunctionState:
		r2 = yield(r2, "completed")
	yield(get_tree().create_timer(0.4, true), "timeout")
	var vis = 0
	for e2 in player.markers.entries:
		if is_instance_valid(e2["sprite"]) and e2["sprite"].visible:
			vis += 1
	CHECK(bright(door) and vis == 1, "outdoors: only the town hall door in reach shows a marker (%d visible)" % vis)
	var sh1 = shot("markers_door")
	if sh1 is GDScriptFunctionState:
		yield(sh1, "completed")
	var tc = tap(KEY_SPACE, 0.1)
	if tc is GDScriptFunctionState:
		yield(tc, "completed")
	var pp = pump("enter_towndoor", 150)
	if pp is GDScriptFunctionState:
		yield(pp, "completed")
	var in_ = wait_scene("res://Scenes/townhall.tscn", 25)
	if in_ is GDScriptFunctionState:
		in_ = yield(in_, "completed")
	CHECK(in_, "Space on the highlighted door entered the town hall")
	var d1 = pump("townhall_intro", 120)
	if d1 is GDScriptFunctionState:
		yield(d1, "completed")
	player = root().find_node("Player", true, false)
	yield(get_tree().create_timer(0.8, true), "timeout")
	var nv = 0
	for e3 in player.markers.entries:
		if e3["sprite"].visible:
			nv += 1
	L("town hall: %d markers visible on room load" % nv)
	CHECK(nv >= 2, "town hall: usable objects carry markers from the moment the room loads")
	var sh2 = shot("markers_townhall")
	if sh2 is GDScriptFunctionState:
		yield(sh2, "completed")
	var lv = leave_by_exit("exit.gd")
	if lv is GDScriptFunctionState:
		yield(lv, "completed")
	var back = wait_scene("res://Scenes/World.tscn", 25)
	if back is GDScriptFunctionState:
		back = yield(back, "completed")
	player = root().find_node("Player", true, false)
	yield(get_tree().create_timer(0.8, true), "timeout")
	# --- Jayson's house: markers on load, exit locked, bright on the one in reach, hide when done
	var jd = world_door("jaysondoor")
	var rj = walk_to_area_and_interact(jd, Vector2(0, 1), 280.0, false)
	if rj is GDScriptFunctionState:
		rj = yield(rj, "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	CHECK(bright(jd), "Jayson's door in reach shows the bright marker")
	var te = tap(KEY_E, 0.1)
	if te is GDScriptFunctionState:
		yield(te, "completed")
	var pj = pump("enter_jaysondoor", 150)
	if pj is GDScriptFunctionState:
		yield(pj, "completed")
	var inj = wait_scene("res://Scenes/Jaysonhome.tscn", 25)
	if inj is GDScriptFunctionState:
		inj = yield(inj, "completed")
	CHECK(inj, "E on the highlighted door entered Jayson's house")
	var d2 = pump("house_intro", 120)
	if d2 is GDScriptFunctionState:
		yield(d2, "completed")
	player = root().find_node("Player", true, false)
	yield(get_tree().create_timer(0.8, true), "timeout")
	var toilet = by_script("old toilet jayson.gd")[0]
	var tub = by_script("old bathtub jayson.gd")[0]
	var leave = by_script("jaysonleave.gd")[0]
	CHECK(shown(toilet) and shown(tub), "house: toilet and bathtub carry subtle markers on load")
	CHECK(not shown(leave), "house: the locked exit has no marker")
	CHECK(not bright(toilet), "house: markers out of reach are subtle (not bright)")
	var rt = rect_of_area(toilet)
	teleport_feet(rt.position + rt.size * 0.5)
	yield(get_tree().create_timer(0.4, true), "timeout")
	CHECK(bright(toilet) and not bright(tub) and player.cue_target == toilet, "house: the toilet in reach is bright and is the target")
	var sh3 = shot("markers_house")
	if sh3 is GDScriptFunctionState:
		yield(sh3, "completed")
	var ts = tap(KEY_SPACE, 0.1)
	if ts is GDScriptFunctionState:
		yield(ts, "completed")
	var pi = pump("toilet", 120)
	if pi is GDScriptFunctionState:
		yield(pi, "completed")
	yield(get_tree().create_timer(0.5, true), "timeout")
	CHECK(not shown(toilet), "house: a finished toilet loses its marker")
	var rb = rect_of_area(tub)
	teleport_feet(rb.position + rb.size * 0.5)
	yield(get_tree().create_timer(0.4, true), "timeout")
	var tn = tap(KEY_ENTER, 0.1)
	if tn is GDScriptFunctionState:
		yield(tn, "completed")
	var pb = pump("tub", 120)
	if pb is GDScriptFunctionState:
		yield(pb, "completed")
	yield(get_tree().create_timer(0.5, true), "timeout")
	CHECK(not shown(tub) and shown(leave), "house: Enter finished the bathtub; the exit unlocks and gets its marker")
	var home = feet()
	var wl = walk_layers_scene("jaysonhome", home)
	if wl is GDScriptFunctionState:
		yield(wl, "completed")
	finish()

func test_saves_unit():
	for p in ["user://saves/save.dat", "user://saves/save.dat.bak", "user://saves/save.dat.tmp"]:
		rm(p)
	var ok = new_game_to_world()
	if ok is GDScriptFunctionState:
		yield(ok, "completed")
	CHECK(not Global.has_save(), "fresh profile: no save exists after New Game + opening dialogue (no hidden autosave)")
	# --- allowed outdoors, before any mission
	var ks2 = key_save()
	if ks2 is GDScriptFunctionState:
		yield(ks2, "completed")
	CHECK(Global.has_save(), "Ctrl+S outdoors (before any mission) writes a save")
	CHECK(Global.last_toast == "Game saved", "success toast shown after the write (\"%s\")" % Global.last_toast)
	var first_bytes = read_bytes("user://saves/save.dat")
	var data = Global._read_file("user://saves/save.dat")
	CHECK(data != null and data.get("version", 0) == 2 and data["indices"]["town"] == 0 and (data["player_position"] - player.global_position).length() < 15.0, "saved file is the v2 format and holds the current progress and outdoor position (%s vs player %s)" % [str(data), str(player.global_position)])
	# --- blocked inside a mission house; available again afterwards
	var door = world_door("jaysondoor")
	var tdoor = world_door("towndoor")
	var rr = walk_to_area_and_interact(tdoor, Vector2(0, 1))
	if rr is GDScriptFunctionState:
		yield(rr, "completed")
	# --- blocked during a conversation (the town hall door prompt is a real dialogue)
	CHECK(dialog_node() != null, "a conversation is active")
	var ksd = key_save()
	if ksd is GDScriptFunctionState:
		yield(ksd, "completed")
	CHECK(read_bytes("user://saves/save.dat") == first_bytes, "Ctrl+S during a conversation leaves the save untouched")
	CHECK("conversation" in Global.last_toast, "blocked save shows a reason (\"%s\")" % Global.last_toast)
	var pp2 = pump("town", 150)
	if pp2 is GDScriptFunctionState:
		yield(pp2, "completed")
	var w1 = wait_scene("res://Scenes/townhall.tscn", 25)
	if w1 is GDScriptFunctionState:
		yield(w1, "completed")
	var pp3 = pump("town_intro", 120)
	if pp3 is GDScriptFunctionState:
		yield(pp3, "completed")
	player = root().find_node("Player", true, false)
	var ks3 = key_save()
	if ks3 is GDScriptFunctionState:
		yield(ks3, "completed")
	CHECK(read_bytes("user://saves/save.dat") == first_bytes, "Ctrl+S in the town hall leaves the save untouched (%s)" % Global.last_toast)
	var lv = leave_by_exit("exit.gd")
	if lv is GDScriptFunctionState:
		yield(lv, "completed")
	var b = wait_scene("res://Scenes/World.tscn", 25)
	if b is GDScriptFunctionState:
		yield(b, "completed")
	yield(get_tree().create_timer(1.0, true), "timeout")
	player = root().find_node("Player", true, false)
	# immediately after a scene change saving is refused briefly
	Global._scene_changed_at = OS.get_ticks_msec()
	var reason = Global.save_block_reason()
	CHECK("scene change" in reason, "saving is refused right after a scene change (\"%s\")" % reason)
	yield(get_tree().create_timer(0.9, true), "timeout")
	CHECK(Global.save_block_reason() == "", "...and available again once the scene has settled")
	# jayson's house: active cleanup
	var rr2 = walk_to_area_and_interact(world_door("jaysondoor"), Vector2(0, 1))
	if rr2 is GDScriptFunctionState:
		yield(rr2, "completed")
	var pp4 = pump("jayson_door", 150)
	if pp4 is GDScriptFunctionState:
		yield(pp4, "completed")
	var w2 = wait_scene("res://Scenes/Jaysonhome.tscn", 25)
	if w2 is GDScriptFunctionState:
		yield(w2, "completed")
	var pp5 = pump("jayson_intro", 120)
	if pp5 is GDScriptFunctionState:
		yield(pp5, "completed")
	player = root().find_node("Player", true, false)
	CHECK(Global.mission_state("jayson") == "active", "Jayson's mission is active once inside")
	var ks4 = key_save()
	if ks4 is GDScriptFunctionState:
		yield(ks4, "completed")
	CHECK(read_bytes("user://saves/save.dat") == first_bytes, "Ctrl+S inside the house before cleaning is blocked (%s)" % Global.last_toast)
	var items = by_script("old toilet jayson.gd")
	var r1 = interact_tp(items[0])
	if r1 is GDScriptFunctionState:
		yield(r1, "completed")
	CHECK(Global.indices["jayhouse"] == 1, "one item cleaned (mission in progress)")
	var ks5 = key_save()
	if ks5 is GDScriptFunctionState:
		yield(ks5, "completed")
	CHECK(read_bytes("user://saves/save.dat") == first_bytes, "Ctrl+S during active cleanup is blocked (%s)" % Global.last_toast)
	var r2 = interact_tp(by_script("old bathtub jayson.gd")[0])
	if r2 is GDScriptFunctionState:
		yield(r2, "completed")
	CHECK(Global.mission_state("jayson") == "done", "Jayson's mission is completed")
	var ks6 = key_save()
	if ks6 is GDScriptFunctionState:
		yield(ks6, "completed")
	CHECK(read_bytes("user://saves/save.dat") == first_bytes, "Ctrl+S is still blocked while inside the (finished) house")
	var lv2 = leave_by_exit("jaysonleave.gd")
	if lv2 is GDScriptFunctionState:
		yield(lv2, "completed")
	var b2 = wait_scene("res://Scenes/World.tscn", 25)
	if b2 is GDScriptFunctionState:
		yield(b2, "completed")
	yield(get_tree().create_timer(1.2, true), "timeout")
	player = root().find_node("Player", true, false)
	var pp6 = pump("after_house", 60)
	if pp6 is GDScriptFunctionState:
		yield(pp6, "completed")
	var ks7 = key_save()
	if ks7 is GDScriptFunctionState:
		yield(ks7, "completed")
	var after = Global._read_file("user://saves/save.dat")
	CHECK(after != null and after["indices"]["jayhouse"] >= 2 and Global.last_toast == "Game saved", "after completing the mission, Ctrl+S works again and records it")
	var bak = Global._read_file("user://saves/save.dat.bak")
	CHECK(bak != null and bak["indices"]["jayhouse"] == 0, "the previous good save was kept as save.dat.bak")
	# --- failed write keeps the previous good save
	var good = read_bytes("user://saves/save.dat")
	Global._test_fail_write = true
	var ks8 = key_save()
	if ks8 is GDScriptFunctionState:
		yield(ks8, "completed")
	Global._test_fail_write = false
	CHECK(read_bytes("user://saves/save.dat") == good and Global._read_file("user://saves/save.dat") != null, "a failed write leaves the previous save intact and loadable (%s)" % Global.last_toast)
	CHECK("failed" in Global.last_toast.to_lower(), "failed write is reported to the player")
	# --- old format
	rm("user://saves/save.dat.bak")
	var f = File.new()
	f.open("user://saves/save.dat", File.WRITE)
	f.store_var({"indices": {"pollution": 3, "jayhouse": 2, "town": 1}, "player_position": Vector2(0, 0)})   # original format, partial keys
	f.close()
	var lr = Global.load_game()
	CHECK(lr["ok"], "an old-format save (missing fields) loads")
	CHECK(Global.indices["pollution"] == 3 and Global.indices["brockhouse"] == 0 and Global.indices.has("world") and Global.collected_trash.empty(), "missing fields get safe defaults, present ones are kept")
	CHECK(not Global.has_saved_position, "an old save's (0,0) position is not treated as a real location")
	# --- unreadable save is kept intact, not overwritten
	var junk = PoolByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
	write_raw("user://saves/save.dat", junk)
	var lr2 = Global.load_game()
	CHECK(not lr2["ok"], "an unreadable save is refused")
	CHECK(read_bytes("user://saves/save.dat") == junk, "...and the unreadable file is left untouched")
	Global.reset_for_new_game()
	var ks9 = key_save()
	if ks9 is GDScriptFunctionState:
		yield(ks9, "completed")
	var d = Directory.new()
	var kept = false
	d.open("user://saves")
	d.list_dir_begin(true)
	var fn = d.get_next()
	while fn != "":
		if fn.begins_with("save.unreadable"):
			kept = read_bytes("user://saves/" + fn) == junk
		fn = d.get_next()
	CHECK(kept, "saving again moved the unreadable file aside byte-for-byte instead of destroying it")
	CHECK(Global._read_file("user://saves/save.dat") != null, "...and wrote a fresh valid save")
	# --- corrupt primary, valid backup
	var bkdata = Global._read_file("user://saves/save.dat")
	var f2 = File.new()
	f2.open("user://saves/save.dat.bak", File.WRITE)
	f2.store_var(Global.build_save_data())
	f2.close()
	write_raw("user://saves/save.dat", junk)
	var lr3 = Global.load_game()
	CHECK(lr3["ok"], "unreadable primary falls back to the backup")
	finish()

# ------------------------------------------------------------------ saves: relaunch phases
func write_json(name_, d):
	var f = File.new()
	f.open(OUT + name_, File.WRITE)
	f.store_string(to_json(d))
	f.close()

func read_json(name_):
	var f = File.new()
	if f.open(OUT + name_, File.READ) != OK:
		return null
	var r = JSON.parse(f.get_as_text())
	f.close()
	return r.result if r.error == OK else null

func trash_state():
	var vis = {}
	for n in by_script("pollution.gd"):
		vis[n.name] = n.sprite.visible
	return vis

func test_saves_p1():
	for p in ["user://saves/save.dat", "user://saves/save.dat.bak"]:
		rm(p)
	var ok = new_game_to_world()
	if ok is GDScriptFunctionState:
		yield(ok, "completed")
	# town hall (real walking), then talk to the townies
	var r = walk_to_area_and_interact(world_door("towndoor"), Vector2(0, 1))
	if r is GDScriptFunctionState:
		yield(r, "completed")
	var p1 = pump("town", 150)
	if p1 is GDScriptFunctionState:
		yield(p1, "completed")
	var w = wait_scene("res://Scenes/townhall.tscn", 25)
	if w is GDScriptFunctionState:
		yield(w, "completed")
	var p2 = pump("town_intro", 120)
	if p2 is GDScriptFunctionState:
		yield(p2, "completed")
	player = root().find_node("Player", true, false)
	var lv = leave_by_exit("exit.gd")
	if lv is GDScriptFunctionState:
		yield(lv, "completed")
	var b = wait_scene("res://Scenes/World.tscn", 25)
	if b is GDScriptFunctionState:
		yield(b, "completed")
	yield(get_tree().create_timer(1.0, true), "timeout")
	player = root().find_node("Player", true, false)
	for pair in [["jayson", 2], ["steven", 3]]:
		for n in get_tree().get_nodes_in_group("NPC"):
			if n.name == pair[0]:
				for i in range(pair[1]):
					var ip = interact_tp(n)
					if ip is GDScriptFunctionState:
						yield(ip, "completed")
	# Jayson's mission, start to finish
	var r2 = walk_to_area_and_interact(world_door("jaysondoor"), Vector2(0, 1))
	if r2 is GDScriptFunctionState:
		yield(r2, "completed")
	var p3 = pump("jd", 150)
	if p3 is GDScriptFunctionState:
		yield(p3, "completed")
	var w2 = wait_scene("res://Scenes/Jaysonhome.tscn", 25)
	if w2 is GDScriptFunctionState:
		yield(w2, "completed")
	var p4 = pump("ji", 120)
	if p4 is GDScriptFunctionState:
		yield(p4, "completed")
	player = root().find_node("Player", true, false)
	var cc = clean_house("jayson")
	if cc is GDScriptFunctionState:
		yield(cc, "completed")
	var lv2 = leave_by_exit("jaysonleave.gd")
	if lv2 is GDScriptFunctionState:
		yield(lv2, "completed")
	var b2 = wait_scene("res://Scenes/World.tscn", 25)
	if b2 is GDScriptFunctionState:
		yield(b2, "completed")
	yield(get_tree().create_timer(1.2, true), "timeout")
	player = root().find_node("Player", true, false)
	var pp = pump("after", 60)
	if pp is GDScriptFunctionState:
		yield(pp, "completed")
	# pick up three pieces of trash
	var picked = 0
	for tn in by_script("pollution.gd"):
		if picked >= 3:
			break
		var ip2 = interact_tp(tn)
		if ip2 is GDScriptFunctionState:
			yield(ip2, "completed")
		picked += 1
	# walk somewhere recognisable with real keys, then save
	var hk = tap(KEY_D, 1.1)
	if hk is GDScriptFunctionState:
		yield(hk, "completed")
	hk = tap(KEY_S, 0.7)
	if hk is GDScriptFunctionState:
		yield(hk, "completed")
	yield(get_tree().create_timer(0.6, true), "timeout")
	var ks = key_save()
	if ks is GDScriptFunctionState:
		yield(ks, "completed")
	CHECK(Global.last_toast == "Game saved", "phase 1: Ctrl+S saved outdoors after the mission and trash (%s)" % Global.last_toast)
	# the position that was written to disk (Ctrl+S also presses S, which nudges the live player afterwards)
	var saved_file = Global._read_file("user://saves/save.dat")
	var pos = saved_file["player_position"]
	write_json("expected.json", {"indices": Global.indices, "pos": [pos.x, pos.y], "trash": trash_state(), "collected": Global.collected_trash.keys()})
	L("phase 1 saved: indices=%s pos=%s trash=%s" % [str(Global.indices), str(pos), str(trash_state())])
	CHECK(Global.indices["jayhouse"] >= 2 and Global.collected_trash.size() == 3, "phase 1 state: mission done and 3 trash collected")
	finish()

func press_continue():
	var menu = root()
	var btn = menu.get_node("VBoxContainer/Load")
	var c = tap(KEY_S, 0.08)          # focus moves from New Game to Continue
	if c is GDScriptFunctionState:
		yield(c, "completed")
	yield(get_tree().create_timer(0.2, true), "timeout")
	CHECK(btn.has_focus(), "Continue has keyboard focus")
	c = tap(KEY_SPACE, 0.1)
	if c is GDScriptFunctionState:
		yield(c, "completed")

func test_saves_p2():
	var expd = read_json("expected.json")
	CHECK(expd != null, "expected.json from phase 1 is present")
	var ok = wait_scene("res://Scenes/Start Menu.tscn", 15)
	if ok is GDScriptFunctionState:
		yield(ok, "completed")
	yield(get_tree().create_timer(0.8, true), "timeout")
	var btn = root().get_node("VBoxContainer/Load")
	CHECK(btn.visible, "after a full relaunch the menu shows Continue")
	shot("menu_with_continue")
	var sha_before = File.new().get_sha256("user://saves/save.dat")
	var pc = press_continue()
	if pc is GDScriptFunctionState:
		yield(pc, "completed")
	ok = wait_scene("res://Scenes/World.tscn", 40)
	if ok is GDScriptFunctionState:
		ok = yield(ok, "completed")
	player = root().find_node("Player", true, false)
	L("position right after Continue loaded: %s motion=%s" % [str(player.global_position), str(player.motion)])
	yield(get_tree().create_timer(1.5, true), "timeout")
	L("position 1.5 s later: %s motion=%s held=%s" % [str(player.global_position), str(player.motion), str(held)])
	CHECK(dialog_node() == null and not get_tree().paused, "Continue does not replay the opening dialogue")
	var same = true
	for k in expd["indices"].keys():
		if int(Global.indices.get(k, -1)) != int(expd["indices"][k]):
			same = false
			L("index mismatch %s: %s vs %s" % [k, str(Global.indices.get(k)), str(expd["indices"][k])])
	CHECK(same, "all story indices restored (dialogue / doors / mission progress)")
	var pos = player.global_position
	CHECK((pos - Vector2(expd["pos"][0], expd["pos"][1])).length() < 6.0, "outdoor position restored (%s vs %s)" % [str(pos), str(expd["pos"])])
	var ts = trash_state()
	var trash_ok = true
	for k in ts.keys():
		var was_collected = expd["collected"].has(k)
		if ts[k] == was_collected:      # visible must be the opposite of collected
			trash_ok = false
	CHECK(trash_ok and expd["collected"].size() == 3, "collected trash stays gone, the rest is still there")
	# the finished mission is still finished: Jayson's door says "done"
	var r = walk_to_area_and_interact(world_door("jaysondoor"), Vector2(0, 1))
	if r is GDScriptFunctionState:
		yield(r, "completed")
	var pp = pump("jd", 90)
	if pp is GDScriptFunctionState:
		yield(pp, "completed")
	CHECK(has_tl("done"), "Jayson's door still reports the completed mission (%s)" % str(tl_log))
	# remaining trash can still be collected and counts once
	var before = Global.indices["pollution"]
	for tn in by_script("pollution.gd"):
		if tn.sprite.visible:
			var ip = interact_tp(tn)
			if ip is GDScriptFunctionState:
				yield(ip, "completed")
			break
	CHECK(Global.indices["pollution"] == before + 1, "picking up one more piece adds exactly one")
	CHECK(File.new().get_sha256("user://saves/save.dat") == sha_before, "Continue itself never rewrites the save file")
	write_json("p2.json", {"sha": sha_before})
	finish()

func test_saves_p3():
	var p2 = read_json("p2.json")
	var ok = wait_scene("res://Scenes/Start Menu.tscn", 15)
	if ok is GDScriptFunctionState:
		yield(ok, "completed")
	yield(get_tree().create_timer(0.6, true), "timeout")
	var nm = new_game_to_world()
	if nm is GDScriptFunctionState:
		yield(nm, "completed")
	yield(get_tree().create_timer(3.0, true), "timeout")
	var fresh = true
	for k in Global.indices.keys():
		if k != "world" and int(Global.indices[k]) != 0:
			fresh = false
	CHECK(fresh and Global.indices["world"] == 1, "New Game starts from fresh state")
	var all_visible = true
	for k in trash_state().values():
		if not k:
			all_visible = false
	CHECK(all_visible and Global.collected_trash.empty(), "New Game: all trash is back")
	CHECK(File.new().get_sha256("user://saves/save.dat") == p2["sha"], "New Game did not touch the existing save file")
	finish()

# ------------------------------------------------------------------ map blur
func frac_diff(a, b, tol = 0.05, step = 2):
	var n = 0
	var d = 0
	for y in range(0, a.get_height(), step):
		for x in range(0, a.get_width(), step):
			var pa = a.get_pixel(x, y)
			var pb = b.get_pixel(x, y)
			n += 1
			if abs(pa.r - pb.r) + abs(pa.g - pb.g) + abs(pa.b - pb.b) > tol:
				d += 1
	return float(d) / n

func sharpness(img, mask_a, mask_b):
	# mean absolute horizontal gradient over pixels where the two images differ
	var s = 0.0
	var n = 0
	for y in range(0, img.get_height(), 2):
		for x in range(2, img.get_width() - 2, 2):
			var pa = mask_a.get_pixel(x, y)
			var pb = mask_b.get_pixel(x, y)
			if abs(pa.r - pb.r) + abs(pa.g - pb.g) + abs(pa.b - pb.b) > 0.05:
				var p0 = img.get_pixel(x - 1, y)
				var p1 = img.get_pixel(x + 1, y)
				s += abs(p0.r - p1.r) + abs(p0.g - p1.g) + abs(p0.b - p1.b)
				n += 1
	return s / max(1, n)

func map_cycle(label):
	var blur = root().find_node("MapBlur", true, false)
	var mm = root().find_node("minimap", true, false)
	# A: normal play
	var a = grab()
	if a is GDScriptFunctionState:
		a = yield(a, "completed")
	CHECK(blur != null and not blur.visible and not mm.visible, "%s: map closed -> blur hidden" % label)
	var c = tap(KEY_M, 0.1)
	if c is GDScriptFunctionState:
		yield(c, "completed")
	yield(get_tree().create_timer(0.4, true), "timeout")
	CHECK(mm.visible and blur.visible and not Global.moving, "%s: M opens map and blur, movement locked" % label)
	var b = grab()      # map over blurred world
	if b is GDScriptFunctionState:
		b = yield(b, "completed")
	blur.visible = false
	var c2 = grab()     # map over sharp world
	if c2 is GDScriptFunctionState:
		c2 = yield(c2, "completed")
	blur.visible = true
	var world_changed = frac_diff(b, c2)
	var sb = sharpness(b, b, c2)
	var sc = sharpness(c2, b, c2)
	CHECK(world_changed > 0.02, "%s: the world behind the map is blurred (%.1f%% of the screen changed)" % [label, world_changed * 100.0])
	CHECK(sb < sc * 0.8, "%s: blurred area has clearly less edge contrast (%.3f vs %.3f)" % [label, sb, sc])
	# map pixels must be identical with and without blur => the map/labels are drawn above it, crisp
	var map_px_same = 0
	var map_px = 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var pa = a.get_pixel(x, y)
			var pc = c2.get_pixel(x, y)
			if abs(pa.r - pc.r) + abs(pa.g - pc.g) + abs(pa.b - pc.b) > 0.05:      # map covers this pixel
				map_px += 1
				var pb = b.get_pixel(x, y)
				if abs(pb.r - pc.r) + abs(pb.g - pc.g) + abs(pb.b - pc.b) < 0.02:
					map_px_same += 1
	CHECK(map_px > 1000 and float(map_px_same) / map_px > 0.97, "%s: map and its labels stay crisp (%d of %d map pixels unchanged by the blur)" % [label, map_px_same, map_px])
	if OS.get_environment("TB_SHOT") == "1":
		b.unlock()
		b.save_png(OUT + "map_open_%s.png" % label)
		b.lock()
	a.unlock(); b.unlock(); c2.unlock()
	c = tap(KEY_M, 0.1)
	if c is GDScriptFunctionState:
		yield(c, "completed")
	yield(get_tree().create_timer(0.4, true), "timeout")
	CHECK((not mm.visible) and (not blur.visible) and Global.moving, "%s: M closes map and blur, movement restored" % label)
	var a2 = grab()
	if a2 is GDScriptFunctionState:
		a2 = yield(a2, "completed")
	var back = frac_diff(a2, a2)
	a2.unlock()

func test_blur():
	var ok = new_game_to_world()
	if ok is GDScriptFunctionState:
		yield(ok, "completed")
	var mc = map_cycle("first")
	if mc is GDScriptFunctionState:
		yield(mc, "completed")
	# normal play is untouched: identical to a frame taken with the blur node removed
	var blur = root().find_node("MapBlur", true, false)
	var f1 = grab()
	if f1 is GDScriptFunctionState:
		f1 = yield(f1, "completed")
	blur.get_parent().remove_child(blur)
	var f2 = grab()
	if f2 is GDScriptFunctionState:
		f2 = yield(f2, "completed")
	CHECK(frac_diff(f1, f2, 0.01) < 0.001, "normal play is pixel-identical with the blur layer present but hidden")
	f1.unlock(); f2.unlock()
	root().find_node("minimap", true, false).get_parent().add_child(blur)
	# repeated open/close
	var okc = true
	for i in range(8):
		var c = tap(KEY_M, 0.08)
		if c is GDScriptFunctionState:
			yield(c, "completed")
		yield(get_tree().create_timer(0.15, true), "timeout")
		var opened = root().find_node("minimap", true, false).visible and blur.visible and not Global.moving
		c = tap(KEY_M, 0.08)
		if c is GDScriptFunctionState:
			yield(c, "completed")
		yield(get_tree().create_timer(0.15, true), "timeout")
		var closed = (not root().find_node("minimap", true, false).visible) and (not blur.visible) and Global.moving
		if not (opened and closed):
			okc = false
	CHECK(okc, "8 rapid open/close cycles stay consistent")
	# pause menu while the map is open
	var c3 = tap(KEY_M, 0.1)
	if c3 is GDScriptFunctionState:
		yield(c3, "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	c3 = tap(KEY_ESCAPE, 0.1)
	if c3 is GDScriptFunctionState:
		yield(c3, "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	CHECK(get_tree().paused and root().find_node("PauseMenu", true, false).visible, "Esc still pauses while the map is open")
	c3 = tap(KEY_ESCAPE, 0.1)
	if c3 is GDScriptFunctionState:
		yield(c3, "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	CHECK(not get_tree().paused and root().find_node("minimap", true, false).visible, "Esc resumes and the map is still open")
	c3 = tap(KEY_M, 0.1)
	if c3 is GDScriptFunctionState:
		yield(c3, "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	# after entering and leaving a scene
	var r = walk_to_area_and_interact(world_door("towndoor"), Vector2(0, 1))
	if r is GDScriptFunctionState:
		yield(r, "completed")
	var p1 = pump("town", 150)
	if p1 is GDScriptFunctionState:
		yield(p1, "completed")
	var w = wait_scene("res://Scenes/townhall.tscn", 25)
	if w is GDScriptFunctionState:
		yield(w, "completed")
	var p2 = pump("town_intro", 120)
	if p2 is GDScriptFunctionState:
		yield(p2, "completed")
	player = root().find_node("Player", true, false)
	var lv = leave_by_exit("exit.gd")
	if lv is GDScriptFunctionState:
		yield(lv, "completed")
	var b = wait_scene("res://Scenes/World.tscn", 25)
	if b is GDScriptFunctionState:
		yield(b, "completed")
	yield(get_tree().create_timer(1.2, true), "timeout")
	player = root().find_node("Player", true, false)
	CHECK(Global.moving and Global.isVisible, "after a scene change the map starts closed and movement is free")
	var mc2 = map_cycle("after_scene_change")
	if mc2 is GDScriptFunctionState:
		yield(mc2, "completed")
	finish()

# ------------------------------------------------------------------ reproduce the ORIGINAL save behaviour (run against the pre-change project)
func test_repro_old_a():
	var ok = new_game_to_world()
	if ok is GDScriptFunctionState:
		yield(ok, "completed")
	var f = File.new()
	L("REPRO right after New Game + opening dialogue: save file exists = %s" % str(f.file_exists(Global.save_path)))
	var r = walk_to_area_and_interact(world_door("towndoor"), Vector2(0, 1))
	if r is GDScriptFunctionState:
		yield(r, "completed")
	var p1 = pump("town", 150)
	if p1 is GDScriptFunctionState:
		yield(p1, "completed")
	var w = wait_scene("res://Scenes/townhall.tscn", 25)
	if w is GDScriptFunctionState:
		yield(w, "completed")
	var p2 = pump("town_intro", 120)
	if p2 is GDScriptFunctionState:
		yield(p2, "completed")
	player = root().find_node("Player", true, false)
	var lv = leave_by_exit("exit.gd")
	if lv is GDScriptFunctionState:
		yield(lv, "completed")
	var b = wait_scene("res://Scenes/World.tscn", 25)
	if b is GDScriptFunctionState:
		yield(b, "completed")
	yield(get_tree().create_timer(1.0, true), "timeout")
	player = root().find_node("Player", true, false)
	L("REPRO back from the town hall: player at %s (the door was at the top of the map)" % str(player.global_position))
	for n in get_tree().get_nodes_in_group("NPC"):
		if n.name == "jayson":
			var ip = interact_tp(n)
			if ip is GDScriptFunctionState:
				yield(ip, "completed")
	var picked = 0
	for tn in by_script("pollution.gd"):
		if picked >= 2:
			break
		var ip2 = interact_tp(tn)
		if ip2 is GDScriptFunctionState:
			yield(ip2, "completed")
		picked += 1
	var hk = tap(KEY_D, 1.1)
	if hk is GDScriptFunctionState:
		yield(hk, "completed")
	player.global_position = player.global_position   # no-op
	var pos = player.global_position
	var c = tap(KEY_S, 0.1, true)
	if c is GDScriptFunctionState:
		yield(c, "completed")
	yield(get_tree().create_timer(0.5, true), "timeout")
	var d = Global._read_old() if Global.has_method("_read_old") else null
	var f2 = File.new()
	var saved = null
	if f2.open(Global.save_path, File.READ) == OK:
		saved = f2.get_var()
		f2.close()
	L("REPRO after Ctrl+S outdoors: file exists=%s saved=%s" % [str(saved != null), str(saved)])
	L("REPRO live state: pos=%s indices=%s" % [str(pos), str(Global.indices)])
	var tr = {}
	for tn in by_script("pollution.gd"):
		tr[tn.name] = tn.sprite.visible
	write_json("old_expected.json", {"pos": [pos.x, pos.y], "indices": Global.indices, "trash": tr})
	finish()

func test_repro_old_b():
	var expd = read_json("old_expected.json")
	var ok = wait_scene("res://Scenes/Start Menu.tscn", 15)
	if ok is GDScriptFunctionState:
		yield(ok, "completed")
	yield(get_tree().create_timer(1.0, true), "timeout")
	var btn = root().get_node("VBoxContainer/Load")
	L("REPRO relaunch: Continue button visible = %s ; autoload Load.can_click = %s" % [str(btn.visible), str(Load.can_click)])
	shot("old_menu")
	# try Continue the way the game wires it (the button, if reachable; otherwise call its handler)
	root()._on_Controls_pressed()
	ok = wait_scene("res://Scenes/World.tscn", 40)
	if ok is GDScriptFunctionState:
		ok = yield(ok, "completed")
	yield(get_tree().create_timer(1.5, true), "timeout")
	player = root().find_node("Player", true, false)
	L("REPRO after Continue: reached world=%s opening dialogue shown=%s" % [str(ok), str(dialog_node() != null)])
	L("REPRO after Continue: pos=%s (saved pos was %s) indices=%s (saved %s)" % [str(player.global_position), str(expd["pos"]), str(Global.indices), str(expd["indices"])])
	var tr = {}
	for tn in by_script("pollution.gd"):
		tr[tn.name] = tn.sprite.visible
	L("REPRO trash visibility after Continue: %s (before: %s)" % [str(tr), str(expd["trash"])])
	finish()

# ------------------------------------------------------------------ dispatch
func main():
	yield(get_tree().create_timer(1.0, true), "timeout")
	var which = OS.get_environment("TB_TEST")
	L("running test: " + which)
	var r = null
	if which == "doors":
		r = test_doors()
	elif which == "polish_smoke":
		r = test_polish_smoke()
	elif which == "map_drift":
		r = test_map_drift()
	elif which == "cues_walk":
		r = test_cues_walk()
	elif which == "saves_unit":
		r = test_saves_unit()
	elif which == "saves_p1":
		r = test_saves_p1()
	elif which == "saves_p2":
		r = test_saves_p2()
	elif which == "saves_p3":
		r = test_saves_p3()
	elif which == "blur":
		r = test_blur()
	elif which == "repro_old_a":
		r = test_repro_old_a()
	elif which == "repro_old_b":
		r = test_repro_old_b()
	else:
		FAIL("unknown TB_TEST " + which)
		finish()
		return
	if r is GDScriptFunctionState:
		yield(r, "completed")

# Exported builds ship compiled scripts (.gdc / .gde): compare by the source name so tests work in both.
func _script_name(s):
	var n = str(s.resource_path)
	if n.ends_with(".gdc") or n.ends_with(".gde"):
		n = n.substr(0, n.length() - 1)
	return n
