extends Node2D

class_name SaveGame

# ---------------------------------------------------------------------------------------------
# Global game state + save system.
#
# Save rules (see try_save / save_block_reason):
#   * saving is allowed only in the outdoor World scene, outside dialogue, outside scene changes
#     and outside any mission interior (houses / town hall);
#   * a blocked save shows a short reason and never touches the existing save;
#   * a successful save is verified after the write, then confirmed on screen;
#   * the previous good save is kept as save.dat.bak and an unreadable save.dat is moved aside
#     (never deleted or overwritten in place).
# ---------------------------------------------------------------------------------------------

const SAVE_DIR = "user://saves/"
const SAVE_FILE = "user://saves/save.dat"
const SAVE_TMP = "user://saves/save.dat.tmp"
const SAVE_BAK = "user://saves/save.dat.bak"
const SAVE_VERSION = 2

const WORLD_SCENE = "res://Scenes/World.tscn"
const JAYSON_HOME_SCENE = "res://Scenes/Jaysonhome.tscn"
const BROCK_HOME_SCENE = "res://Scenes/brockhome.tscn"
const TOWNHALL_SCENE = "res://Scenes/townhall.tscn"

# Items that must be cleaned before a house mission is complete (matches the exit checks in
# jaysonleave.gd / brockleave.gd).
const JAYSON_CLEANUP_TARGET = 2
const BROCK_CLEANUP_TARGET = 4

const SETTLE_MSEC = 700   # saving is refused this long after any scene change

signal left_town

var save_path = SAVE_FILE   # kept for load.gd
var isVisible = true         # true = map closed (existing meaning, used by World.gd)
var moving = true
var player_position = Vector2(0, 0)
var has_saved_position = false
var continue_pending = false

var indices = default_indices()
var collected_trash = {}     # trash node name -> true (pollution.gd)

# door -> interior -> door bookkeeping (see note_door_use / begin_visit / take_return_point)
var pending_door = {}
var visit = {}

# test hook: simulate a failing write
var _test_fail_write = false

var _last_scene = ""
var _scene_changed_at = 0
var _toast_layer = null
var _toast_label = null
var _toast_tween = null

static func default_indices():
	return {
		"pollution": 0,
		"jayhouse": 0,
		"brockhouse": 0,
		"stevenhouse": 0,
		"brock": 0,
		"jayson": 0,
		"steven": 0,
		"jodi": 0,
		"gabe": 0,
		"town": 0,
		"jaysondoor": 0,
		"world": 0,
	}

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	if OS.has_feature("JavaScript"):
		# an itch.io embed can be any shape: keep the 16:9 picture undistorted (black bars) instead of
		# stretching it to the page. Desktop builds keep the project's own stretch settings.
		get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_2D, SceneTree.STRETCH_ASPECT_KEEP, Vector2(1280, 720))
	_build_toast()
	# quest journal (Q) + optional pinned tracker; derived from the progress numbers below
	journal = load("res://Scripts/journal.gd").new()
	journal.name = "Journal"
	add_child(journal)

func increment_index(idx):
	if not indices.has(idx):
		indices[idx] = 0
	indices[idx] += 1

# ------------------------------------------------------------------ new game / state

# ------------------------------------------------------------------ repeat dialogue
# Which short repeat line an NPC says next. Session-only (never saved, never touches quest state):
# the lines rotate in order, so the same line is never said twice in a row; when `sig` changes
# (the NPC's mission state moved on) the rotation starts again from its first line.
var repeat_state = {}
var last_repeat_timeline = ""   # for tests

func repeat_timeline(key, lines, sig = ""):
	var st = repeat_state.get(key, {"sig": sig, "next": 0})
	if st["sig"] != sig:
		st = {"sig": sig, "next": 0}
	var i = int(st["next"]) % lines.size()
	st["next"] = i + 1
	repeat_state[key] = st
	last_repeat_timeline = lines[i]
	return lines[i]

func reset_for_new_game():
	repeat_state = {}
	indices = default_indices()
	collected_trash = {}
	player_position = Vector2(0, 0)
	has_saved_position = false
	continue_pending = false
	pending_door = {}
	visit = {}
	moving = true
	isVisible = true

# ------------------------------------------------------------------ missions

# "none" = not started, "active" = cleanup in progress, "done" = completed
func mission_state(which):
	var count = 0
	var target = 1
	var scene = ""
	if which == "jayson":
		count = indices["jayhouse"]
		target = JAYSON_CLEANUP_TARGET
		scene = JAYSON_HOME_SCENE
	else:
		count = indices["brockhouse"]
		target = BROCK_CLEANUP_TARGET
		scene = BROCK_HOME_SCENE
	if count >= target:
		return "done"
	if count > 0 or _current_scene_path() == scene:
		return "active"
	return "none"

func cleanup_active():
	var cs = _current_scene_path()
	return cs == JAYSON_HOME_SCENE or cs == BROCK_HOME_SCENE

# ------------------------------------------------------------------ door / visit tracking

# Called by door scripts when the player starts using a door that leads indoors.
func note_door_use(door):
	var p = null
	var found = get_tree().get_nodes_in_group("Player")
	if found.size() > 0:
		p = found[0]
	pending_door = {
		"door": door.name,
		"player_pos": p.global_position if p != null else Vector2.ZERO,
		"has_player_pos": p != null,
	}

# Called by each interior's script when it loads: freezes the return point for this visit.
func begin_visit(scene_path):
	visit = pending_door.duplicate()
	visit["scene"] = scene_path
	pending_door = {}

# Called by World when it loads: returns (and clears) the return point of the visit just ended.
func take_return_point():
	var v = visit
	visit = {}
	return v

# ------------------------------------------------------------------ scene tracking / toast

func _current_scene_path():
	var cs = get_tree().current_scene
	return cs.filename if cs != null else ""

var _was_paused = false
var _unpaused_at = -100000
var journal = null

func _process(_delta):
	var path = _current_scene_path()
	if path != _last_scene:
		_last_scene = path
		_scene_changed_at = OS.get_ticks_msec()
	var now_paused = get_tree().paused
	if _was_paused and not now_paused:
		_unpaused_at = OS.get_ticks_msec()      # a conversation / the journal just closed
	_was_paused = now_paused

# A keypress that arrived while a conversation was open (and may just have closed it) or right
# after a scene change must never also activate something in the world: one press, one action.
func interact_allowed():
	var now = OS.get_ticks_msec()
	# also ignore a quick second tap right after a conversation closes (players skip text by tapping
	# Space / Enter / E, and the last tap must not immediately talk to the same person again)
	return not _was_paused and now - _scene_changed_at > 300 and now - _unpaused_at > 250

func _build_toast():
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 100
	_toast_layer.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(_toast_layer)
	_toast_label = Label.new()
	var font = DynamicFont.new()
	font.font_data = load("res://themes/8-BIT WONDER.TTF")
	font.size = 16
	_toast_label.add_font_override("font", font)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.72)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_toast_label.add_stylebox_override("normal", sb)
	_toast_label.align = Label.ALIGN_CENTER
	_toast_label.visible = false
	_toast_layer.add_child(_toast_label)
	_toast_tween = Tween.new()
	_toast_tween.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(_toast_tween)

var last_toast = ""

func show_toast(text, good):
	last_toast = text
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.add_color_override("font_color", Color(0.55, 1.0, 0.55) if good else Color(1.0, 0.82, 0.45))
	_toast_label.visible = true
	_toast_label.modulate = Color(1, 1, 1, 1)
	_toast_label.rect_size = Vector2.ZERO
	var vp = get_viewport().get_visible_rect().size
	_toast_label.rect_position = Vector2((vp.x - _toast_label.rect_size.x) * 0.5, 28)
	_toast_tween.stop_all()
	_toast_tween.interpolate_property(_toast_label, "modulate:a", 1.0, 0.0, 0.6, Tween.TRANS_LINEAR, Tween.EASE_IN, 1.8)
	_toast_tween.start()

# ------------------------------------------------------------------ save rules

func _dialogue_active():
	return _find_dialog(get_tree().root) != null

func _find_dialog(node):
	var s = node.get_script()
	if s != null and str(s.resource_path).ends_with("DialogNode.gd"):
		return node
	for c in node.get_children():
		var r = _find_dialog(c)
		if r != null:
			return r
	return null

# "" = saving allowed, otherwise the short reason shown to the player.
func save_block_reason():
	var cs = get_tree().current_scene
	if cs == null or OS.get_ticks_msec() - _scene_changed_at < SETTLE_MSEC:
		return "Can't save during a scene change"
	if _dialogue_active():
		return "Can't save during a conversation"
	var path = cs.filename
	if path == JAYSON_HOME_SCENE or path == BROCK_HOME_SCENE:
		return "Finish the cleanup before saving"
	if path != WORLD_SCENE:
		return "Can't save indoors - go outside"
	if get_tree().paused:
		return "Can't save while paused"
	return ""

func try_save():
	var reason = save_block_reason()
	if reason != "":
		show_toast(reason, false)
		return false
	var err = _write_save(build_save_data())
	if err != OK:
		push_warning("Turtleburg: save write failed with error %d" % err)
		print("[SAVE] write failed, error code ", err)
		show_toast("Save failed - last save kept", false)
		return false
	show_toast("Game saved", true)
	return true

# kept for older callers
func do_save():
	return try_save()

func _input(event):
	if event is InputEventKey and event.is_action_pressed("save_key"):
		try_save()

# ------------------------------------------------------------------ save data

func build_save_data():
	var pos = player_position
	var found = get_tree().get_nodes_in_group("Player")
	if found.size() > 0 and _current_scene_path() == WORLD_SCENE:
		pos = found[0].global_position
	var trash = []
	for k in collected_trash.keys():
		trash.append(k)
	return {
		"version": SAVE_VERSION,
		"saved_at": OS.get_unix_time(),
		"indices": indices.duplicate(),
		"player_position": pos,
		"collected_trash": trash,
		"missions": {"jayson": mission_state("jayson"), "brock": mission_state("brock")},
	}

func _read_file(path):
	var f = File.new()
	if not f.file_exists(path):
		return null
	if f.open(path, File.READ) != OK:
		return null
	if f.get_len() < 4:
		f.close()
		return null
	var v = f.get_var()
	f.close()
	if typeof(v) != TYPE_DICTIONARY:
		return null
	return v

# Fills in anything missing so older / partial saves load with safe defaults.
static func normalize_save(data):
	var out = {}
	out["version"] = int(data["version"]) if data.has("version") and typeof(data["version"]) == TYPE_INT else 1
	var idx = default_indices()
	if data.has("indices") and typeof(data["indices"]) == TYPE_DICTIONARY:
		for k in data["indices"].keys():
			var v = data["indices"][k]
			if typeof(v) == TYPE_INT or typeof(v) == TYPE_REAL:
				idx[str(k)] = int(v)
	out["indices"] = idx
	var pos = Vector2(0, 0)
	var has_pos = false
	if data.has("player_position") and typeof(data["player_position"]) == TYPE_VECTOR2:
		pos = data["player_position"]
		has_pos = pos != Vector2(0, 0)
	out["player_position"] = pos
	out["has_position"] = has_pos
	var trash = {}
	if data.has("collected_trash") and typeof(data["collected_trash"]) == TYPE_ARRAY:
		for n in data["collected_trash"]:
			trash[str(n)] = true
	out["collected_trash"] = trash
	return out

func _write_save(data):
	var dir = Directory.new()
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir_recursive(SAVE_DIR)
	if _test_fail_write:
		return ERR_FILE_CANT_WRITE
	var f = File.new()
	var err = f.open(SAVE_TMP, File.WRITE)
	if err != OK:
		return err
	f.store_var(data)
	f.close()
	# verify what was written before touching the real save
	var check = _read_file(SAVE_TMP)
	if check == null or check.get("saved_at", -1) != data["saved_at"] or var2str(check.get("indices", {})) != var2str(data["indices"]):
		dir.remove(SAVE_TMP)
		return ERR_FILE_CORRUPT
	if dir.file_exists(SAVE_FILE):
		if _read_file(SAVE_FILE) != null:
			dir.copy(SAVE_FILE, SAVE_BAK)      # keep the previous good save
		else:
			# unreadable: keep it untouched, just move it aside
			dir.rename(SAVE_FILE, "%ssave.unreadable.%d.dat" % [SAVE_DIR, OS.get_unix_time()])
	err = dir.rename(SAVE_TMP, SAVE_FILE)
	if err != OK:
		# fall back: the verified tmp file is a complete save, copy it into place
		err = dir.copy(SAVE_TMP, SAVE_FILE)
		if err != OK:
			return err
		dir.remove(SAVE_TMP)
	Dialogic.save()
	return OK

func has_save():
	return _read_file(SAVE_FILE) != null or _read_file(SAVE_BAK) != null

# Returns {"ok": bool, "reason": String}. Never modifies the files it reads.
func load_game():
	var data = _read_file(SAVE_FILE)
	var used_backup = false
	if data == null:
		data = _read_file(SAVE_BAK)
		used_backup = data != null
	if data == null:
		var f = File.new()
		if f.file_exists(SAVE_FILE):
			return {"ok": false, "reason": "Save file unreadable - kept as is"}
		return {"ok": false, "reason": "No saved game found"}
	var n = normalize_save(data)
	indices = n["indices"]
	collected_trash = n["collected_trash"]
	player_position = n["player_position"]
	has_saved_position = n["has_position"]
	continue_pending = true
	pending_door = {}
	visit = {}
	moving = true
	isVisible = true
	var dd = Directory.new()
	if dd.dir_exists("user://dialogic"):
		Dialogic.load()
	return {"ok": true, "reason": "backup" if used_backup else ""}

func do_load():
	return load_game()
