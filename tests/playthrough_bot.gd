extends Node
# TEST-ONLY autoload (not part of the game, excluded from git/export).
# Drives a full New Game -> ending playthrough with real key events.

const OUT = "/Users/samcruz/Documents/Turtleburg-g3-recovery/project/shots/"
var t = 0.0
var n = 0
var last_scene = ""
var fails = []
var player = null
var chosen_log = []
var dialogs_seen = {}
var game_pos_log = ""
var tl_log = []
var tl_names = {}
var diag_done = false

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	_load_names()
	print("[BOT] harness ready, timeline names mapped: ", tl_names.size())
	call_deferred("run")

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

func L(msg):
	print("[BOT] t=%.1f %s" % [t, msg])

func FAIL(msg):
	fails.append(msg)
	print("[BOT] *** FAIL: ", msg)

func CHECK(cond, msg):
	if cond:
		print("[BOT] PASS: ", msg)
	else:
		FAIL(msg)

func shot(tag):
	var img = get_viewport().get_texture().get_data()
	img.flip_y()
	var p = OUT + "%02d_%s.png" % [n, tag]
	n += 1
	img.save_png(p)
	L("screenshot " + p.get_file())

func _process(delta):
	t += delta
	var cs = get_tree().current_scene
	var nm = cs.filename if cs else "none"
	if nm != last_scene:
		last_scene = nm
		L("SCENE -> %s paused=%s" % [nm, str(get_tree().paused)])
	if t > 500.0:
		FAIL("global watchdog 500s")
		finish()

func wait(sec):
	yield(get_tree().create_timer(sec, true), "timeout")

func key(code, hold = 0.12, ctrl = false):
	var ev = InputEventKey.new()
	ev.scancode = code
	ev.control = ctrl
	ev.pressed = true
	Input.parse_input_event(ev)
	yield(get_tree().create_timer(hold, true), "timeout")
	var up = InputEventKey.new()
	up.scancode = code
	up.control = ctrl
	up.pressed = false
	Input.parse_input_event(up)
	yield(get_tree().create_timer(0.05, true), "timeout")

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

func scene_root():
	return get_tree().current_scene

func wait_scene(path, timeout = 40.0):
	var start = t
	while t - start < timeout:
		var cs = get_tree().current_scene
		if cs and cs.filename == path:
			yield(get_tree().create_timer(0.6, true), "timeout")
			return true
		yield(get_tree().create_timer(0.2, true), "timeout")
	FAIL("timed out waiting for scene " + path)
	return false

# Advance/answer dialogs until none is left. Returns true on clean finish.
func pump(label, timeout = 120.0):
	yield(get_tree(), "idle_frame")
	var start = t
	var steps = 0
	var seen_dialog = false
	var idle = 0
	while t - start < timeout:
		var d = dialog_node()
		if d == null:
			idle += 1
			if idle > 6:
				L("dialog '%s' finished after %d steps (seen=%s)" % [label, steps, str(seen_dialog)])
				return seen_dialog
			yield(get_tree().create_timer(0.12, true), "timeout")
			continue
		idle = 0
		seen_dialog = true
		if not dialogs_seen.has(d.get_instance_id()):
			dialogs_seen[d.get_instance_id()] = true
			var nm_ = tl_names.get(str(d.timeline).get_file(), str(d.timeline))
			tl_log.append(nm_)
			L("TIMELINE START: '%s' (during %s)" % [nm_, label])
		var bc = d.button_container
		if d.waiting_for_answer and bc != null and bc.get_child_count() > 0:
			yield(get_tree().create_timer(1.3, true), "timeout")
			bc = d.button_container
			if bc != null and bc.get_child_count() > 0:
				var texts = []
				for b in bc.get_children():
					texts.append(b.text)
				var pick = choose(texts)
				chosen_log.append("%s: %s -> [%s]" % [label, str(texts), texts[pick]])
				L("choice %s -> %d (%s)" % [str(texts), pick, texts[pick]])
				bc.get_child(pick).emit_signal("pressed")
				yield(get_tree().create_timer(0.4, true), "timeout")
		else:
			key(KEY_SPACE, 0.05)
			steps += 1
			yield(get_tree().create_timer(0.1, true), "timeout")
	FAIL("dialog '%s' did not finish in %ss" % [label, str(timeout)])
	return false

func choose(texts):
	var want = ["yes", "enter", "sure", "ok", "pick", "let's", "lets", "go", "i will", "i'll", "of course", "absolutely", "clean"]
	for i in range(texts.size()):
		var tl = str(texts[i]).to_lower().strip_edges()
		for w in want:
			if tl.begins_with(w):
				return i
	return 0

func find_player():
	return scene_root().find_node("Player", true, false)

func shape_pos(node):
	for c in node.get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			return c.global_position
	return node.global_position

func interact(target, label, timeout = 120.0):
	yield(get_tree(), "idle_frame")
	player = find_player()
	if player == null:
		FAIL("no player for " + label)
		return false
	player.global_position = shape_pos(target)
	player.motion = Vector2.ZERO
	yield(get_tree().create_timer(0.35, true), "timeout")
	key(KEY_SPACE, 0.12)
	yield(get_tree().create_timer(0.5, true), "timeout")
	var res = pump(label, timeout)
	if res is GDScriptFunctionState:
		res = yield(res, "completed")
	return res

func by_script(suffix):
	var out = []
	find_scripted(scene_root(), suffix, out)
	return out

func has_tl(name_):
	return tl_log.has(name_)

func diag_polys():
	if diag_done:
		return
	diag_done = true
	var bad = []
	var stack = [scene_root()]
	while stack.size() > 0:
		var nd = stack.pop_back()
		if nd is CollisionPolygon2D:
			if nd.build_mode == CollisionPolygon2D.BUILD_SOLIDS and nd.polygon.size() >= 3:
				var dec = Geometry.triangulate_polygon(nd.polygon)
				if dec.size() == 0:
					bad.append(str(scene_root().get_path_to(nd)) + " pts=" + str(nd.polygon.size()) + " disabled=" + str(nd.disabled))
		for c in nd.get_children():
			stack.append(c)
	L("DIAG polygons failing convex decomposition: %d" % bad.size())
	for b in bad:
		L("   DIAG bad polygon: " + b)

func idx():
	return str(Global.indices)

func run():
	yield(get_tree().create_timer(1.0, true), "timeout")
	L("=== STAGE A: start menu -> New Game ===")
	var ok = wait_scene("res://Scenes/Start Menu.tscn", 10)
	if ok is GDScriptFunctionState: ok = yield(ok, "completed")
	shot("menu")
	var start_btn = scene_root().get_node("VBoxContainer/Start")
	CHECK(start_btn.has_focus(), "Start button has keyboard focus on boot")
	yield(key(KEY_SPACE, 0.1), "completed")   # keyboard: Space on focused New Game
	ok = wait_scene("res://Scenes/World.tscn", 40)
	if ok is GDScriptFunctionState: ok = yield(ok, "completed")
	CHECK(ok, "New Game reaches World.tscn")
	if not ok:
		finish()
		return

	L("=== STAGE B: opening dialogue (Start timeline) ===")
	yield(get_tree().create_timer(1.0, true), "timeout")
	shot("opening_dialog")
	var r = pump("Start", 240)
	if r is GDScriptFunctionState: r = yield(r, "completed")
	CHECK(r, "opening 'Start' timeline played to the end")
	CHECK(get_tree().paused == false, "game unpaused after opening dialogue")
	shot("after_opening")
	L("indices " + idx())

	L("=== STAGE C: controls (real key events) ===")
	player = find_player()
	var p0 = player.global_position
	yield(key(KEY_D, 0.5), "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	var p1 = player.global_position
	CHECK(p1.x > p0.x + 5, "D moves right (%s -> %s)" % [str(p0), str(p1)])
	yield(key(KEY_A, 0.5), "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	var p2 = player.global_position
	CHECK(p2.x < p1.x - 5, "A moves left")
	yield(key(KEY_DOWN, 0.5), "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	var p3 = player.global_position
	CHECK(p3.y > p2.y + 5, "Arrow Down moves down")
	yield(key(KEY_W, 0.5), "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	var p4 = player.global_position
	CHECK(p4.y < p3.y - 5, "W moves up")
	yield(key(KEY_RIGHT, 0.4), "completed")
	yield(key(KEY_LEFT, 0.4), "completed")
	yield(key(KEY_S, 0.3), "completed")
	yield(key(KEY_UP, 0.3), "completed")
	# pause
	var pm = scene_root().find_node("PauseMenu", true, false)
	yield(key(KEY_ESCAPE, 0.1), "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	CHECK(get_tree().paused and pm.visible, "Esc opens pause menu")
	shot("pause_menu")
	yield(key(KEY_ESCAPE, 0.1), "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	CHECK((not get_tree().paused) and (not pm.visible), "Esc closes pause menu")
	# map
	var mm = scene_root().find_node("minimap", true, false)
	yield(key(KEY_M, 0.1), "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	CHECK(mm.visible, "M opens map")
	shot("map")
	yield(key(KEY_M, 0.1), "completed")
	yield(get_tree().create_timer(0.3, true), "timeout")
	CHECK(not mm.visible, "M closes map")
	# Ctrl+S save
	var dir = Directory.new()
	if dir.file_exists(Global.save_path):
		dir.remove(Global.save_path)
	yield(key(KEY_S, 0.1, true), "completed")
	yield(get_tree().create_timer(0.4, true), "timeout")
	CHECK(dir.file_exists(Global.save_path), "Ctrl+S writes save (%s)" % Global.save_path)

	L("=== STAGE D: town hall ===")
	var towndoor = scene_root().find_node("towndoor", true, false)
	r = interact(towndoor, "towndoor")
	if r is GDScriptFunctionState: r = yield(r, "completed")
	ok = wait_scene("res://Scenes/townhall.tscn", 20)
	if ok is GDScriptFunctionState: ok = yield(ok, "completed")
	CHECK(ok, "town hall door leads to townhall.tscn")
	if ok:
		yield(get_tree().create_timer(0.8, true), "timeout")
		shot("townhall")
		r = pump("towncenter0", 240)
		if r is GDScriptFunctionState: r = yield(r, "completed")
		CHECK(has_tl("towncenter0"), "town hall opening timeline 'towncenter0' played")
		CHECK(Global.indices["town"] == 1, "town index == 1 after first visit")
		L("indices " + idx())
		# Kate (townhall.tscn uses kate.gd)
		var kates = by_script("kate.gd")
		CHECK(kates.size() > 0, "kate.gd loaded in townhall (case-fixed path)")
		if kates.size() > 0:
			r = interact(kates[0], "kate")
			if r is GDScriptFunctionState: r = yield(r, "completed")
			L("kate dialog result=" + str(r))
		# leave via exit.gd exit
		var exits = by_script("exit.gd")
		CHECK(exits.size() > 0, "town hall has exit.gd exit")
		if exits.size() > 0:
			r = interact(exits[0], "townleave")
			if r is GDScriptFunctionState: r = yield(r, "completed")
		ok = wait_scene("res://Scenes/World.tscn", 20)
		if ok is GDScriptFunctionState: ok = yield(ok, "completed")
		CHECK(ok, "leaving town hall returns to World.tscn")
		if not ok:
			finish()
			return

	L("=== STAGE E: townies / NPCs in World ===")
	diag_polys()
	r = pump("world_reenter", 60)
	if r is GDScriptFunctionState: r = yield(r, "completed")
	var npcs = get_tree().get_nodes_in_group("NPC")
	L("NPCs in World: " + str(npcs.size()))
	for npc in npcs:
		L("NPC: %s script=%s" % [npc.name, npc.get_script().resource_path.get_file()])
	for name_ in ["jayson", "brock", "steven"]:
		var found = null
		for npc in get_tree().get_nodes_in_group("NPC"):
			if npc.name == name_:
				found = npc
		CHECK(found != null, "NPC %s exists" % name_)
		if found:
			var times = 3 if name_ == "steven" else 2
			for i in range(times):
				r = interact(found, "npc_%s_%d" % [name_, i])
				if r is GDScriptFunctionState: r = yield(r, "completed")
				CHECK(r, "talk to %s #%d produced a dialogue" % [name_, i])
				yield(get_tree().create_timer(0.5, true), "timeout")
	L("indices " + idx())
	shot("after_npcs")

	L("=== STAGE H: Jayson's house ===")
	var jd = scene_root().find_node("jaysondoor", true, false)
	r = interact(jd, "jaysondoor")
	if r is GDScriptFunctionState: r = yield(r, "completed")
	ok = wait_scene("res://Scenes/Jaysonhome.tscn", 25)
	if ok is GDScriptFunctionState: ok = yield(ok, "completed")
	CHECK(ok, "Jayson's door leads to Jaysonhome.tscn")
	if ok:
		yield(get_tree().create_timer(0.8, true), "timeout")
		shot("jayson_house_intro")
		r = pump("jaysonhouse_intro", 240)
		if r is GDScriptFunctionState: r = yield(r, "completed")
		var items = []
		for sfx in ["old toilet jayson.gd", "old bathtub jayson.gd"]:
			for nd in by_script(sfx):
				items.append(nd)
		CHECK(items.size() == 2, "Jayson's toilet+bathtub objects found (%d)" % items.size())
		for it in items:
			r = interact(it, "jayson_item_" + str(it.name))
			if r is GDScriptFunctionState: r = yield(r, "completed")
		CHECK(Global.indices["jayhouse"] > 1, "jayhouse index > 1 (is %d)" % Global.indices["jayhouse"])
		shot("jayson_house_done")
		var lv = by_script("jaysonleave.gd")
		CHECK(lv.size() > 0, "Jayson's leave exit exists")
		if lv.size() > 0:
			r = interact(lv[0], "jaysonleave")
			if r is GDScriptFunctionState: r = yield(r, "completed")
		ok = wait_scene("res://Scenes/World.tscn", 25)
		if ok is GDScriptFunctionState: ok = yield(ok, "completed")
		CHECK(ok, "leaving Jayson's house returns to World.tscn")
		L("indices " + idx())
		r = pump("world_after_jayson", 60)
		if r is GDScriptFunctionState: r = yield(r, "completed")

	L("=== STAGE I: Brock's house ===")
	var bd = scene_root().find_node("brockdoor", true, false)
	r = interact(bd, "brockdoor")
	if r is GDScriptFunctionState: r = yield(r, "completed")
	ok = wait_scene("res://Scenes/brockhome.tscn", 25)
	if ok is GDScriptFunctionState: ok = yield(ok, "completed")
	CHECK(ok, "Brock's door leads to brockhome.tscn")
	if ok:
		yield(get_tree().create_timer(0.8, true), "timeout")
		shot("brock_house_intro")
		r = pump("brockhouse_intro", 240)
		if r is GDScriptFunctionState: r = yield(r, "completed")
		var bitems = []
		for sfx in ["brocktoilet.gd", "brocktubn.gd", "dirty counter.gd", "shakes.gd"]:
			for nd in by_script(sfx):
				bitems.append(nd)
		L("Brock's house interactables: %d" % bitems.size())
		for it in bitems:
			r = interact(it, "brock_item_" + str(it.name))
			if r is GDScriptFunctionState: r = yield(r, "completed")
		L("indices " + idx())
		shot("brock_house_done")
		var bl = by_script("brockleave.gd")
		CHECK(bl.size() > 0, "Brock's leave exit exists")
		if bl.size() > 0:
			r = interact(bl[0], "brockleave")
			if r is GDScriptFunctionState: r = yield(r, "completed")
		ok = wait_scene("res://Scenes/World.tscn", 25)
		if ok is GDScriptFunctionState: ok = yield(ok, "completed")
		CHECK(ok, "leaving Brock's house returns to World.tscn")

	L("=== STAGE G: Steven's house (dialogue only) ===")
	var sd = scene_root().find_node("stevendoor", true, false)
	r = interact(sd, "stevendoor")
	if r is GDScriptFunctionState: r = yield(r, "completed")
	CHECK(r, "Steven's door produced a dialogue")

	L("=== STAGE F: collect trash until pollution > 5 ===")
	var trash = by_script("pollution.gd")
	CHECK(trash.size() > 0, "pollution.gd loaded in World (case-fixed path), count=%d" % trash.size())
	for tnode in trash:
		if Global.indices["pollution"] > 5:
			break
		if tnode.sprite.visible:
			r = interact(tnode, "trash_" + str(tnode.name))
			if r is GDScriptFunctionState: r = yield(r, "completed")
	CHECK(Global.indices["pollution"] > 5, "pollution index > 5 (is %d)" % Global.indices["pollution"])
	L("indices " + idx())
	shot("after_trash")

	L("=== STAGE D2: second town-hall visit (World reload -> ending check) ===")
	var td2 = scene_root().find_node("towndoor", true, false)
	r = interact(td2, "towndoor2")
	if r is GDScriptFunctionState: r = yield(r, "completed")
	ok = wait_scene("res://Scenes/townhall.tscn", 20)
	if ok is GDScriptFunctionState: ok = yield(ok, "completed")
	CHECK(ok, "second town hall visit loads townhall.tscn")
	if ok:
		yield(get_tree().create_timer(0.8, true), "timeout")
		r = pump("towncenter_second", 120)
		if r is GDScriptFunctionState: r = yield(r, "completed")
		CHECK(Global.indices["town"] == 2, "town index == 2 after second visit")
		L("TIMELINES so far: " + str(tl_log))
		var kates2 = by_script("kate.gd")
		if kates2.size() > 0:
			r = interact(kates2[0], "kate_all_done")
			if r is GDScriptFunctionState: r = yield(r, "completed")
			L("KATE with all conditions met -> dialog shown=" + str(r) + " (false = 'trash' key bug swallowed it)")
		var exits2 = by_script("exit.gd")
		r = interact(exits2[0], "townleave2")
		if r is GDScriptFunctionState: r = yield(r, "completed")
		ok = wait_scene("res://Scenes/World.tscn", 20)
		if ok is GDScriptFunctionState: ok = yield(ok, "completed")
		CHECK(ok, "returned to World after second town visit")
		r = pump("after_second_town", 240)
		if r is GDScriptFunctionState: r = yield(r, "completed")

	L("=== STAGE J: ending ===")
	L("indices " + idx())
	CHECK(Global.indices["pollution"] > 5 and Global.indices["jayhouse"] > 1 and Global.indices["brockhouse"] > 1, "ending condition met")
	yield(get_tree().create_timer(1.0, true), "timeout")
	shot("ending_dialog")
	CHECK(has_tl("ending"), "'ending' timeline played on returning to World")
	var endn = scene_root().find_node("end", true, false)
	CHECK(endn != null and endn.visible, "'end' marker visible")
	r = interact(endn, "theend")
	if r is GDScriptFunctionState: r = yield(r, "completed")
	CHECK(r, "'theend' timeline played")
	ok = wait_scene("res://Scenes/finale.tscn", 25)
	if ok is GDScriptFunctionState: ok = yield(ok, "completed")
	CHECK(ok, "finale.tscn reached")
	if ok:
		yield(get_tree().create_timer(2.0, true), "timeout")
		shot("finale_anim")
		var lbl = scene_root().get_node("Label")
		var waited = 0.0
		while not lbl.visible and waited < 60.0:
			yield(get_tree().create_timer(0.5, true), "timeout")
			waited += 0.5
		CHECK(lbl.visible, "finale animation finished and THE END label shown (waited %.1fs)" % waited)
		shot("finale_end")
	finish()

func finish():
	L("=== SUMMARY ===")
	L("timelines played in order: " + str(tl_log))
	L("choices made:")
	for c in chosen_log:
		print("   ", c)
	L("final indices " + idx())
	if fails.size() == 0:
		print("[BOT] RESULT: ALL CHECKS PASSED")
	else:
		print("[BOT] RESULT: %d FAILURES" % fails.size())
		for f in fails:
			print("[BOT]   - ", f)
	get_tree().quit()

# Exported builds ship compiled scripts (.gdc / .gde): compare by the source name so tests work in both.
func _script_name(s):
	var n = str(s.resource_path)
	if n.ends_with(".gdc") or n.ends_with(".gde"):
		n = n.substr(0, n.length() - 1)
	return n
