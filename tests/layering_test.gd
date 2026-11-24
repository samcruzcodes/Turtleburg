extends Node
# TEST-ONLY. Pixel-based layering check for an interior scene.
# env: TB_SCENE (res path), TB_MODE = before | after | walk, TB_LIMIT (max objects, 0 = all), TB_TAG
var OUT = OS.get_environment("TB_OUT") if OS.get_environment("TB_OUT") != "" else "user://"
var t = 0.0
var player = null
var layering = null
var results = []
var mode = "after"
var held = {}
var shots_taken = 0
var build_local_only = false

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func _process(d):
	t += d

func L(m):
	print("[LAYER] ", m)

func find_scripted(node, suffix, out):
	var s = node.get_script()
	if s and _script_name(s).ends_with(suffix):
		out.append(node)
	for c in node.get_children():
		find_scripted(c, suffix, out)

func dialog_node():
	var out = []
	find_scripted(get_tree().root, "DialogNode.gd", out)
	return out[0] if out.size() > 0 else null

func tap(code, hold = 0.05):
	_key(code, true)
	yield(get_tree().create_timer(hold, true), "timeout")
	_key(code, false)

func _key(code, down):
	var ev = InputEventKey.new()
	ev.scancode = code
	ev.pressed = down
	Input.parse_input_event(ev)

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

func pump():
	var idle = 0
	var start = t
	while idle < 8 and t - start < 120:
		var d = dialog_node()
		if d == null:
			idle += 1
		else:
			idle = 0
			if d.waiting_for_answer and d.button_container != null and d.button_container.get_child_count() > 0:
				yield(get_tree().create_timer(1.3, true), "timeout")
				if d.button_container != null and d.button_container.get_child_count() > 0:
					d.button_container.get_child(0).emit_signal("pressed")
			else:
				tap(KEY_SPACE, 0.04)
		yield(get_tree().create_timer(0.12, true), "timeout")

func grab():
	yield(VisualServer, "frame_post_draw")
	var img = get_viewport().get_texture().get_data()
	img.flip_y()
	img.lock()
	return img

func feet():
	return player.get_node("CollisionShape2D").global_position

func place_feet(target):
	# teleport (survey modes)
	var delta = target - feet()
	player.global_position += delta
	player.motion = Vector2.ZERO

func walk_feet(target, timeout = 14.0):
	# real keyboard walking; stops early when the player is blocked by collision
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
			if (feet() - last).length() < 2.0:
				stuck += 1
			else:
				stuck = 0
			last = feet()
			last_check = t
			if stuck >= 2:
				break
	release_all()
	yield(get_tree().create_timer(0.3, true), "timeout")
	return (target - feet()).length() < 6.0


var step = 12.0
var gx0 = 0.0
var gy0 = 0.0
var gw = 0
var gh = 0
var free = {}
var reach = {}
var foot_delta = Vector2.ZERO

func key_of(ix, iy):
	return ix * 100000 + iy

func cell_pos(ix, iy):
	return Vector2(gx0 + ix * step, gy0 + iy * step)

func build_grid(root):
	var minp = Vector2(1e9, 1e9)
	var maxp = Vector2(-1e9, -1e9)
	for o in layering.objects:
		var n = o["node"]
		var r = n.region_rect if n is Sprite and n.region_enabled else Rect2(0, 0, 16, 16)
		var xf = n.get_global_transform()
		for corner in [r.position, r.end]:
			var g = xf.xform(corner)
			minp.x = min(minp.x, g.x); minp.y = min(minp.y, g.y)
			maxp.x = max(maxp.x, g.x); maxp.y = max(maxp.y, g.y)
	minp -= Vector2(150, 150)
	maxp += Vector2(150, 250)
	gx0 = minp.x
	gy0 = minp.y
	gw = int((maxp.x - minp.x) / step) + 1
	gh = int((maxp.y - minp.y) / step) + 1
	foot_delta = feet() - player.global_position
	var xf0 = player.global_transform
	for iy in range(gh):
		for ix in range(gw):
			var origin = cell_pos(ix, iy) - foot_delta
			var xf = xf0
			xf.origin = origin
			free[key_of(ix, iy)] = not player.test_move(xf, Vector2(0.01, 0.0))
	# flood fill from the player's current feet cell (4-neighbour)
	var sx = int(round((feet().x - gx0) / step))
	var sy = int(round((feet().y - gy0) / step))
	var q = [Vector2(sx, sy)]
	reach.clear()
	reach[key_of(sx, sy)] = Vector2(-1, -1)
	var head = 0
	while head < q.size():
		var c = q[head]
		head += 1
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var n = c + d
			if n.x < 0 or n.y < 0 or n.x >= gw or n.y >= gh:
				continue
			var k = key_of(int(n.x), int(n.y))
			if reach.has(k) or not free.get(k, false):
				continue
			reach[k] = c
			q.append(n)
	L("grid %dx%d reachable cells=%d of %d" % [gw, gh, reach.size(), gw * gh])

func segment_free(a, b):
	var n = int((a - b).length() / 6.0) + 1
	for i in range(n + 1):
		var p = a.linear_interpolate(b, float(i) / n)
		var ix = int(round((p.x - gx0) / step))
		var iy = int(round((p.y - gy0) / step))
		if not free.get(key_of(ix, iy), false):
			return false
	return true

func path_to(cell):
	# cell = Vector2 grid coordinate (must be reachable); returns list of feet positions from start
	var chain = []
	var c = cell
	var guard = 0
	while c.x >= 0 and guard < 100000:
		chain.push_front(cell_pos(int(c.x), int(c.y)))
		c = reach[key_of(int(c.x), int(c.y))]
		guard += 1
	return chain

func walk_path(cell):
	var chain = path_to(cell)
	var i = 0
	while i < chain.size() - 1:
		var j = chain.size() - 1
		var cur = feet()
		while j > i and not segment_free(cur, chain[j]):
			j -= 1
		if j == i:
			j = i + 1
		var w = walk_feet(chain[j], 20.0)
		if w is GDScriptFunctionState:
			w = yield(w, "completed")
		i = j
		# re-sync: if we are far from the chain point, restart from the player's cell
		if (feet() - chain[j]).length() > 10.0:
			break
	var dist = (feet() - cell_pos(int(cell.x), int(cell.y))).length()
	if OS.get_environment("TB_DEBUG") == "1":
		L("WALK target_cell=%s feet=%s dist=%.1f chain=%d" % [str(cell), str(feet()), dist, chain.size()])
	return dist < 10.0

func pick_cell(xmin, xmax, ymin, ymax, cx, cy):
	# nearest reachable cell inside the box to (cx, cy); returns Vector2(-1,-1) if none
	var best = Vector2(-1, -1)
	var bd = 1e18
	for k in reach.keys():
		var ix = int(k / 100000)
		var iy = int(k % 100000)
		var p = cell_pos(ix, iy)
		if p.x < xmin or p.x > xmax or p.y < ymin or p.y > ymax:
			continue
		var d = (p - Vector2(cx, cy)).length()
		if d < bd:
			bd = d
			best = Vector2(ix, iy)
	return best


func write_map():
	var sc = 2
	var img = Image.new()
	img.create(gw * sc, gh * sc, false, Image.FORMAT_RGB8)
	img.lock()
	for iy in range(gh):
		for ix in range(gw):
			var k = key_of(ix, iy)
			var col = Color(0.08, 0.08, 0.1)
			if reach.has(k):
				col = Color(0.2, 0.6, 0.25)
			elif free.get(k, false):
				col = Color(0.2, 0.25, 0.4)
			for a in range(sc):
				for b in range(sc):
					img.set_pixel(ix * sc + a, iy * sc + b, col)
	for o in layering.objects:
		var n = o["node"]
		var r = n.region_rect
		var xf = n.get_global_transform()
		var p0 = xf.xform(Vector2(0, 0))
		var p1 = xf.xform(r.size)
		var c = Color(0.9, 0.8, 0.2)
		for xx in range(int((p0.x - gx0) / step * sc), int((p1.x - gx0) / step * sc)):
			for yy in [int((p0.y - gy0) / step * sc), int((p1.y - gy0) / step * sc) - 1]:
				if xx >= 0 and yy >= 0 and xx < gw * sc and yy < gh * sc:
					img.set_pixel(xx, yy, Color(1, 0.2, 0.2) if yy == int((p1.y - gy0) / step * sc) - 1 else c)
		for yy in range(int((p0.y - gy0) / step * sc), int((p1.y - gy0) / step * sc)):
			for xx in [int((p0.x - gx0) / step * sc), int((p1.x - gx0) / step * sc) - 1]:
				if xx >= 0 and yy >= 0 and xx < gw * sc and yy < gh * sc:
					img.set_pixel(xx, yy, c)
	img.unlock()
	img.save_png(OUT + "walkmap_" + OS.get_environment("TB_TAG") + ".png")


func write_sheet():
	var uniq = {}
	var order = []
	for o in layering.objects:
		var n = o["node"]
		if not (n is Sprite):
			continue
		var key = "%s|%s" % [n.texture.resource_path.get_file(), str(n.region_rect)]
		if not uniq.has(key):
			uniq[key] = {"node": n, "names": []}
			order.append(key)
		uniq[key]["names"].append(o["name"])
	var sc = 3
	var cellw = 150
	var cellh = 130
	var cols = 8
	var rows = int(ceil(float(order.size()) / cols))
	var img = Image.new()
	img.create(cols * cellw, rows * cellh, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.3, 0.35, 1))
	var idx = 0
	for key in order:
		var n = uniq[key]["node"]
		var src = n.texture.get_data()
		var r = n.region_rect
		var piece = Image.new()
		piece.create(int(r.size.x), int(r.size.y), false, Image.FORMAT_RGBA8)
		piece.blit_rect(src, r, Vector2(0, 0))
		var w = int(r.size.x * sc)
		var h = int(r.size.y * sc)
		if w > cellw - 6 or h > cellh - 20:
			var f = min(float(cellw - 6) / w, float(cellh - 20) / h)
			w = int(w * f)
			h = int(h * f)
		piece.resize(max(1, w), max(1, h), Image.INTERPOLATE_NEAREST)
		var cx = (idx % cols) * cellw + 3
		var cy = (idx / cols) * cellh + 16
		img.blend_rect(piece, Rect2(0, 0, piece.get_width(), piece.get_height()), Vector2(cx, cy))
		L("SHEET #%d  %s  size=%s  x%d  e.g. %s" % [idx, key, str(r.size), uniq[key]["names"].size(), uniq[key]["names"][0]])
		idx += 1
	img.save_png(OUT + "sheet_" + OS.get_environment("TB_TAG") + ".png")


func conv_check(root):
	# compare original TileMap rendering with the converted sprites (player hidden), at several spots
	player.visible = false
	var names = []
	for c in root.get_children():
		names.append(c.name)
	L("root children: " + str(names))
	var holder = root.get_node("LayeredObjects")
	var start = feet()
	var spots = []
	var minp = Vector2(1e9, 1e9)
	var maxp = Vector2(-1e9, -1e9)
	for o in layering.objects:
		var g = o["node"].global_position
		minp.x = min(minp.x, g.x); minp.y = min(minp.y, g.y)
		maxp.x = max(maxp.x, g.x); maxp.y = max(maxp.y, g.y)
	var cols = 3
	var rows = 3
	for ry in range(rows):
		for rx in range(cols):
			spots.append(Vector2(lerp(minp.x, maxp.x, float(rx) / (cols - 1)), lerp(minp.y, maxp.y, float(ry) / (rows - 1))))
	var total_diff = 0
	var total_px = 0
	var idx = 0
	for sp in spots:
		player.global_position = sp - (feet() - player.global_position)
		player.motion = Vector2.ZERO
		yield(get_tree().create_timer(0.5, true), "timeout")
		# A: converted sprites
		var a = grab()
		if a is GDScriptFunctionState: a = yield(a, "completed")
		# B: original tilemaps
		holder.visible = false
		for tm in layering.converted_tilemaps:
			tm.visible = true
		var b = grab()
		if b is GDScriptFunctionState: b = yield(b, "completed")
		holder.visible = true
		for tm in layering.converted_tilemaps:
			tm.visible = false
		var diff = 0
		var minx = 99999; var miny = 99999; var maxx = -1; var maxy = -1
		for y in range(0, a.get_height(), 2):
			for x in range(0, a.get_width(), 2):
				var pa = a.get_pixel(x, y)
				var pb = b.get_pixel(x, y)
				if abs(pa.r - pb.r) + abs(pa.g - pb.g) + abs(pa.b - pb.b) > 0.05:
					diff += 1
					minx = min(minx, x); miny = min(miny, y); maxx = max(maxx, x); maxy = max(maxy, y)
		total_diff += diff
		total_px += (a.get_width() / 2) * (a.get_height() / 2)
		L("CONV spot %d %s: differing=%d  bbox=(%d,%d)-(%d,%d)" % [idx, str(sp), diff, minx, miny, maxx, maxy])
		if diff > 0 and OS.get_environment("TB_SHOT") == "1":
			a.unlock(); b.unlock()
			a.save_png(OUT + "conv_%s_%d_converted.png" % [OS.get_environment("TB_TAG"), idx])
			b.save_png(OUT + "conv_%s_%d_original.png" % [OS.get_environment("TB_TAG"), idx])
			a.lock(); b.lock()
		a.unlock(); b.unlock()
		idx += 1
	L("CONV total differing sample px=%d of %d (%.3f%%)" % [total_diff, total_px, 100.0 * total_diff / max(1, total_px)])
	player.visible = true

func img_alpha_at(node, gpt):
	# is the object's sprite opaque at this global point?
	var xf = node.get_global_transform().affine_inverse()
	var lp = xf.xform(gpt)
	var rect = node.region_rect
	if lp.x < 0 or lp.y < 0 or lp.x >= rect.size.x or lp.y >= rect.size.y:
		return false
	var im = node.texture.get_data()
	im.lock()
	var px = im.get_pixel(int(rect.position.x + lp.x), int(rect.position.y + lp.y))
	im.unlock()
	return px.a > 0.5

func to_screen(g):
	return get_viewport().get_canvas_transform().xform(g)

func differs(a, b, sp):
	var x = int(sp.x)
	var y = int(sp.y)
	if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
		return null
	var pa = a.get_pixel(x, y)
	var pb = b.get_pixel(x, y)
	return abs(pa.r - pb.r) + abs(pa.g - pb.g) + abs(pa.b - pb.b) > 0.04

func set_all_z(z):
	for o in layering.objects:
		o["node"].z_index = z

func local_grid(center, half):
	# small grid around `center`, flooded from the player's current feet
	var box = Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
	gx0 = box.position.x
	gy0 = box.position.y
	gw = int(box.size.x / step) + 1
	gh = int(box.size.y / step) + 1
	free.clear()
	reach.clear()
	foot_delta = feet() - player.global_position
	var xf0 = player.global_transform
	for iy in range(gh):
		for ix in range(gw):
			var xf = xf0
			xf.origin = cell_pos(ix, iy) - foot_delta
			free[key_of(ix, iy)] = not player.test_move(xf, Vector2(0.01, 0.0))
	var sx = int(round((feet().x - gx0) / step))
	var sy = int(round((feet().y - gy0) / step))
	if not free.get(key_of(sx, sy), false):
		return false
	var q = [Vector2(sx, sy)]
	reach[key_of(sx, sy)] = Vector2(-1, -1)
	var head = 0
	while head < q.size():
		var c = q[head]
		head += 1
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var n = c + d
			if n.x < 0 or n.y < 0 or n.x >= gw or n.y >= gh:
				continue
			var k = key_of(int(n.x), int(n.y))
			if reach.has(k) or not free.get(k, false):
				continue
			reach[k] = c
			q.append(n)
	return true

func probe(o, side):
	var node = o["node"]
	var xf = node.get_global_transform()
	var rect = node.region_rect
	var s = xf.get_scale().y
	var x0 = min(xf.xform(Vector2(0, 0)).x, xf.xform(Vector2(rect.size.x, rect.size.y)).x)
	var x1 = max(xf.xform(Vector2(0, 0)).x, xf.xform(Vector2(rect.size.x, rect.size.y)).x)
	var cx = (x0 + x1) * 0.5
	var base = o["base"]
	# stage: teleport to the free spot nearest the front of the object, then plan locally
	var probe_center = Vector2(cx, base)
	var lg = local_grid(probe_center, 200.0) if false else null
	# find any free spot near the object by scanning a grid around it (no reachability yet)
	gx0 = probe_center.x - 260.0
	gy0 = probe_center.y - 260.0
	gw = int(520.0 / step) + 1
	gh = int(520.0 / step) + 1
	var fd = feet() - player.global_position
	var xf0 = player.global_transform
	var stage = null
	var bd = 1e18
	for iy in range(gh):
		for ix in range(gw):
			var p = cell_pos(ix, iy)
			var d = (p - Vector2(cx, base + 70.0)).length()
			if d < bd:
				var x2 = xf0
				x2.origin = p - fd
				if not player.test_move(x2, Vector2(0.01, 0.0)):
					bd = d
					stage = p
	if stage == null:
		return {"n": 0, "wrong": 0, "expect_hidden": side == "behind", "reached": false, "feet": feet(), "unreachable": true}
	player.global_position += stage - feet()
	player.motion = Vector2.ZERO
	yield(get_tree().create_timer(0.2, true), "timeout")
	var okg = local_grid(probe_center, 260.0)
	var cell
	if side == "behind":
		cell = pick_cell(x0 - 20.0, x1 + 20.0, base - 60.0, base - 4.0, cx, base - 10.0)
	else:
		cell = pick_cell(x0 - 20.0, x1 + 20.0, base + 4.0, base + 40.0, cx, base + 14.0)
	if cell.x < 0:
		return {"n": 0, "wrong": 0, "expect_hidden": side == "behind", "reached": false, "feet": feet(), "unreachable": true}
	var ok = walk_path(cell)
	if ok is GDScriptFunctionState:
		ok = yield(ok, "completed")
	yield(get_tree().create_timer(0.15, true), "timeout")
	var f = feet()
	var expect_hidden = layering.feet_y() < base
	layering.set_process(false)
	var saved = []
	for ob in layering.objects:
		saved.append(ob["node"].z_index)
	set_all_z(-1)
	var c = grab()
	if c is GDScriptFunctionState:
		c = yield(c, "completed")
	player.visible = false
	var b = grab()
	if b is GDScriptFunctionState:
		b = yield(b, "completed")
	player.visible = true
	for i in range(layering.objects.size()):
		layering.objects[i]["node"].z_index = saved[i]
	if mode == "before":
		set_all_z(-1)
	else:
		layering._update_layers()
	var a = grab()
	if a is GDScriptFunctionState:
		a = yield(a, "completed")
	var n = 0
	var wrong = 0
	for dy in range(-60, 4, 3):
		for dx in range(-12, 13, 4):
			var gp = Vector2(f.x + dx * s, f.y + dy)
			if not img_alpha_at(node, gp):
				continue
			var sp = to_screen(gp)
			var sil = differs(c, b, sp)
			if sil != true:
				continue
			var d = differs(a, b, sp)
			if d == null:
				continue
			n += 1
			# player visible where it should be hidden, or hidden where it should show
			if d == expect_hidden:
				wrong += 1
	if OS.get_environment("TB_SHOT") == "1" and shots_taken < 60 and n > 0:
		a.unlock()
		a.save_png(OUT + "shot_%s_%s_%s_%s.png" % [OS.get_environment("TB_TAG"), mode, o["name"].replace(" ", "_"), side])
		shots_taken += 1
		a.lock()
	c.unlock()
	b.unlock()
	a.unlock()
	if mode != "before":
		layering.set_process(true)
	return {"n": n, "wrong": wrong, "expect_hidden": expect_hidden, "reached": ok, "feet": f}

func run():
	mode = OS.get_environment("TB_MODE")
	var limit = int(OS.get_environment("TB_LIMIT"))
	yield(get_tree().create_timer(1.0, true), "timeout")
	var scn = OS.get_environment("TB_SCENE")
	get_tree().change_scene(scn)
	yield(get_tree().create_timer(1.5, true), "timeout")
	var p = pump()
	if p is GDScriptFunctionState:
		yield(p, "completed")
	yield(get_tree().create_timer(0.5, true), "timeout")
	var root = get_tree().current_scene
	player = root.find_node("Player", true, false)
	layering = root.get_node_or_null("Layering")
	if layering == null:
		L("NO LAYERING NODE")
		get_tree().quit()
		return
	L("scene=%s mode=%s objects=%d" % [scn, mode, layering.objects.size()])
	if OS.get_environment("TB_SHEET") == "1":
		write_sheet()
		get_tree().quit()
		return
	if OS.get_environment("TB_CONV") == "1":
		var cc = conv_check(root)
		if cc is GDScriptFunctionState:
			yield(cc, "completed")
		get_tree().quit()
		return
	if OS.get_environment("TB_LOCAL") == "1":
		build_local_only = true
	else:
		build_grid(root)
		# --- exposure: reachable standing cells north of each object's base that overlap its art
	var exposed = []
	for o in (layering.objects if not build_local_only else []):
		var nn = o["node"]
		var xf = nn.get_global_transform()
		var rc = nn.region_rect
		var xa = xf.xform(Vector2(0, 0)).x
		var xb = xf.xform(Vector2(rc.size.x, 0)).x
		var top = xf.xform(Vector2(0, 0)).y
		var cnt_b = 0
		var cnt_f = 0
		for k in reach.keys():
			var cp = cell_pos(int(k / 100000), int(k % 100000))
			if cp.x >= xa - 10 and cp.x <= xb + 10:
				if cp.y < o["base"] and cp.y > o["base"] - 70.0 and cp.y > top - 10.0:
					cnt_b += 1
				elif cp.y >= o["base"] and cp.y < o["base"] + 40.0:
					cnt_f += 1
		if cnt_b > 0:
			exposed.append(o)
		L("EXPOSURE %-24s base=%7.1f art_x=[%d,%d] behind_cells=%d front_cells=%d" % [o["name"], o["base"], xa, xb, cnt_b, cnt_f])
	if build_local_only:
		exposed = layering.objects.duplicate()
	L("objects with reachable 'behind' standing cells: %d of %d" % [exposed.size(), layering.objects.size()])
	if OS.get_environment("TB_EXPOSURE") == "1":
		get_tree().quit()
		return
	if OS.get_environment("TB_SHEET") == "1":
		write_sheet()
		get_tree().quit()
		return
	if OS.get_environment("TB_MAP") == "1":
		write_map()
		get_tree().quit()
		return
	# order objects by base y; skip ones whose centre is far outside the room
	var objs = exposed.duplicate() if OS.get_environment("TB_EXPOSED_ONLY") == "1" else layering.objects.duplicate()
	objs.sort_custom(self, "by_base")
	var done = 0
	var f = File.new()
	f.open(OUT + OS.get_environment("TB_TAG") + "_" + mode + ".txt", File.WRITE)
	f.store_line("scene=%s mode=%s" % [scn, mode])
	var passed = 0
	var failed = 0
	var nooverlap = 0
	var unreachable = 0
	var fail_names = []
	var every = int(OS.get_environment("TB_EVERY")) if OS.get_environment("TB_EVERY") != "" else 1
	var ii = -1
	for o in objs:
		ii += 1
		if ii % every != 0:
			continue
		if limit > 0 and done >= limit:
			break
		done += 1
		var parts = []
		for side in ["behind", "front"]:
			var r = probe(o, side)
			if r is GDScriptFunctionState:
				r = yield(r, "completed")
			var word = "hidden" if r["expect_hidden"] else "shown"
			if r.has("unreachable"):
				unreachable += 1
				parts.append("%s:unreachable" % side)
			elif r["n"] == 0:
				nooverlap += 1
				parts.append("%s:no-overlap(reached=%s)" % [side, str(r["reached"])])
			elif r["wrong"] == 0:
				passed += 1
				parts.append("%s:PASS(%s %d px)" % [side, word, r["n"]])
			else:
				failed += 1
				fail_names.append(o["name"] + "/" + side)
				parts.append("%s:FAIL(expected %s, wrong %d/%d)" % [side, word, r["wrong"], r["n"]])
		var line = "%-30s base=%7.1f  %s | %s" % [o["name"], o["base"], parts[0], parts[1]]
		f.store_line(line)
		L(line)
	var summary = "SUMMARY mode=%s probes: pass=%d FAIL=%d no-overlap=%d unreachable=%d failures=%s" % [mode, passed, failed, nooverlap, unreachable, str(fail_names)]
	f.store_line(summary)
	f.close()
	L(summary)
	get_tree().quit()

func by_base(a, b):
	return a["base"] < b["base"]

# Exported builds ship compiled scripts (.gdc / .gde): compare by the source name so tests work in both.
func _script_name(s):
	var n = str(s.resource_path)
	if n.ends_with(".gdc") or n.ends_with(".gde"):
		n = n.substr(0, n.length() - 1)
	return n
