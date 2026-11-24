extends CanvasLayer
# Quest journal (Q) and an optional pinned tracker.
#
# Nothing here stores or changes progress: the checklist is rebuilt from Global.indices (the same
# numbers the NPCs, doors and the ending already use), so Continue and older saves show the right
# tasks. The gates it mirrors:
#   * unlocked by the town hall introduction            -> indices["town"] >= 1
#   * Jayson / Brock: talk to them (index >= 1), which reveals "Visit <house>" and its task
#   * Jayson's house is done at JAYSON_CLEANUP_TARGET, Brock's at BROCK_CLEANUP_TARGET (the exit gates)
#   * Steven: three conversations (Kate asks for them; the ending does not need them)
#   * beach cleanup is revealed with Kate's last hint (both houses started, Steven done) or as soon as
#     any litter has been picked up; the ending needs pollution > 5, i.e. 6 pieces
#   * the final pointer to the pier appears with the ending's real conditions
const TOWN_HALL_FIRST_LINE = 1
const TRASH_TARGET = 6          # the ending needs pollution > 5
const STEVEN_TALKS = 3          # Kate's check: steven < 3
const Z = 85

var pinned = false              # session only; always starts off
var is_open = false
var _font = null            # body text: a clear, readable font (the pixel font is kept for the title)
var _font_title = null
var _font_small = null
var _panel_root = null
var _list = null
var _pin_box = null
var _tracker = null
var _tracker_list = null
var _sig = ""

# ------------------------------------------------------------------ the checklist (pure function of progress)
func entries(ind, scene_path):
	var out = []
	if int(ind.get("town", 0)) < TOWN_HALL_FIRST_LINE:
		return out
	var jay_talk = int(ind.get("jayson", 0)) >= 1
	var jay_n = int(ind.get("jayhouse", 0))
	var jay_target = Global.JAYSON_CLEANUP_TARGET
	var brock_talk = int(ind.get("brock", 0)) >= 1
	var brock_n = int(ind.get("brockhouse", 0))
	var brock_target = Global.BROCK_CLEANUP_TARGET
	var steven_n = int(ind.get("steven", 0))
	var trash_n = int(ind.get("pollution", 0))
	# "dest" tells the map where each step happens (see map_quest_markers.gd)
	out.append({"text": "Talk to Jayson", "done": jay_talk, "dest": "npc:jayson"})
	if jay_talk:
		out.append({"text": "Visit Jayson's house", "done": jay_n >= 1 or scene_path == Global.JAYSON_HOME_SCENE, "dest": "door:jaysondoor"})
		out.append({"text": "Fix Jayson's toilet and bathtub (%d of %d)" % [min(jay_n, jay_target), jay_target], "done": jay_n >= jay_target, "sub": true, "dest": "door:jaysondoor"})
	out.append({"text": "Talk to Brock", "done": brock_talk, "dest": "npc:brock"})
	if brock_talk:
		out.append({"text": "Visit Brock's house", "done": brock_n >= 1 or scene_path == Global.BROCK_HOME_SCENE, "dest": "door:brockdoor"})
		out.append({"text": "Clean up Brock's house (%d of %d)" % [min(brock_n, brock_target), brock_target], "done": brock_n >= brock_target, "sub": true, "dest": "door:brockdoor"})
	out.append({"text": "Talk to Steven (%d of %d, optional)" % [min(steven_n, STEVEN_TALKS), STEVEN_TALKS], "done": steven_n >= STEVEN_TALKS, "dest": "npc:steven"})
	var cleanup_open = (jay_n >= 1 and brock_n >= 1 and steven_n >= STEVEN_TALKS) or trash_n > 0
	if cleanup_open:
		out.append({"text": "Pick up litter on the beach (%d of %d)" % [min(trash_n, TRASH_TARGET), TRASH_TARGET], "done": trash_n >= TRASH_TARGET, "dest": "trash"})
	if trash_n >= TRASH_TARGET and jay_n >= 2 and brock_n >= 2:
		out.append({"text": "Head to the pier at the tip of the beach", "done": false, "dest": "pier"})
	return out

func active(list):
	var out = []
	for e in list:
		if not e["done"]:
			out.append(e)
	return out

# ------------------------------------------------------------------ availability
func _eligible_scene():
	var cs = get_tree().current_scene
	if cs == null:
		return false
	var p = cs.filename
	return p == Global.WORLD_SCENE or p == Global.TOWNHALL_SCENE or p == Global.JAYSON_HOME_SCENE or p == Global.BROCK_HOME_SCENE

func unlocked():
	return int(Global.indices.get("town", 0)) >= TOWN_HALL_FIRST_LINE

# Why Q does nothing right now ("" = it can open). Conversations, pause and the map stay silent; the
# other reasons get a short toast so a blocked press is never a mystery.
func _block_reason():
	if not _eligible_scene() or get_tree().paused or Global._dialogue_active():
		return "silent"
	if not unlocked():
		return "Quests unlock after the town hall introduction"
	if Global.moving != true:
		return "silent"
	if OS.get_ticks_msec() - Global._scene_changed_at <= 300:
		return "silent"
	return ""

func _can_open():
	return unlocked() and _eligible_scene() and Global.moving == true and not get_tree().paused and not Global._dialogue_active() and OS.get_ticks_msec() - Global._scene_changed_at > 300

# ------------------------------------------------------------------ UI
func _ready():
	layer = Z
	pause_mode = Node.PAUSE_MODE_PROCESS
	_font = _make_font("res://addons/dialogue_manager/example_balloon/Open_Sans/OpenSans-Regular.ttf", 21)
	_font_title = _make_font("res://addons/dialogue_manager/example_balloon/Open_Sans/OpenSans-Bold.ttf", 26)
	_font_small = _make_font("res://addons/dialogue_manager/example_balloon/Open_Sans/OpenSans-Regular.ttf", 17)
	_build_panel()
	_build_tracker()
	_panel_root.visible = false
	_tracker.visible = false

func _make_font(path, size):
	var f = DynamicFont.new()
	f.font_data = load(path)
	f.size = size
	f.use_filter = true
	return f

func _style(alpha):
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.1, 0.1, alpha)
	sb.border_color = Color(0.2, 0.95, 0.35, 0.9)
	sb.set_border_width_all(2)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb

func _label(text, color = Color(1, 1, 1), font = null):
	var l = Label.new()
	l.text = text
	l.add_font_override("font", font if font != null else _font)
	l.add_color_override("font_color", color)
	return l

func _build_panel():
	_panel_root = Control.new()
	_panel_root.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel_root)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(center)
	var pc = PanelContainer.new()
	pc.add_stylebox_override("panel", _style(0.96))
	center.add_child(pc)
	var box = VBoxContainer.new()
	box.add_constant_override("separation", 16)
	pc.add_child(box)
	box.add_child(_label("Quests", Color(0.35, 1.0, 0.45), _font_title))
	_list = VBoxContainer.new()
	_list.add_constant_override("separation", 14)       # room between objectives
	_list.rect_min_size = Vector2(640, 0)               # wide enough that no objective wraps
	box.add_child(_list)
	_pin_box = CheckBox.new()
	_pin_box.text = "Pin active tasks on screen"
	_pin_box.add_font_override("font", _font_small)
	_pin_box.focus_mode = Control.FOCUS_NONE     # Space / Enter must never toggle it by accident
	_pin_box.pressed = false
	_pin_box.connect("toggled", self, "_on_pin_toggled")
	box.add_child(_pin_box)
	var hint = Label.new()                      # default font: the pixel font draws Q like O
	hint.text = "Press Q again to close"
	hint.add_font_override("font", _font_small)
	hint.add_color_override("font_color", Color(0.7, 0.8, 0.75))
	box.add_child(hint)

func _build_tracker():
	_tracker = PanelContainer.new()
	_tracker.add_stylebox_override("panel", _style(0.55))
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracker.rect_position = Vector2(14, 96)
	add_child(_tracker)
	_tracker_list = VBoxContainer.new()
	_tracker_list.add_constant_override("separation", 8)
	_tracker.add_child(_tracker_list)

func _on_pin_toggled(on):
	pinned = on
	_refresh()

func _fill(box, list, only_active):
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var shown = active(list) if only_active else list
	if shown.size() == 0:
		box.add_child(_label("Nothing left to do here" if only_active else "No quests yet", Color(0.7, 0.8, 0.75)))
		return
	if only_active:
		box.add_child(_label("Quests", Color(0.35, 1.0, 0.45), _font_title))
	for e in shown:
		var col = Color(0.55, 0.7, 0.6) if e["done"] else Color(1, 1, 1)
		# one row per objective: a fixed-width check mark, then the text on a single line
		var row = HBoxContainer.new()
		row.add_constant_override("separation", 10)
		var mark = _label("[x]" if e["done"] else "[  ]", col)
		mark.rect_min_size = Vector2(46, 0)
		row.add_child(mark)
		row.add_child(_label(e["text"], col))
		if e.get("sub", false):
			var indent = MarginContainer.new()
			indent.add_constant_override("margin_left", 36)
			indent.add_child(row)
			box.add_child(indent)
		else:
			box.add_child(row)

func _refresh():
	var list = entries(Global.indices, _scene_path())
	_sig = var2str(list) + str(pinned) + str(is_open)
	_fill(_list, list, false)
	_fill(_tracker_list, list, true)
	_tracker.rect_size = Vector2.ZERO

func _scene_path():
	var cs = get_tree().current_scene
	return cs.filename if cs != null else ""

# ------------------------------------------------------------------ open / close / show
func open():
	if is_open:
		return
	var why = _block_reason()
	if why != "":
		if why != "silent":
			Global.show_toast(why, false)
		return
	if not _can_open():
		return
	is_open = true
	_refresh()
	_panel_root.visible = true
	_tracker.visible = false
	# Like the map: the world and the NPCs keep moving, the player is simply held (Global.moving).
	Global.moving = false

func close():
	if not is_open:
		return
	is_open = false
	_panel_root.visible = false
	Global.moving = true
	Global.map_closed_at = OS.get_ticks_msec()      # the closing key press must not also interact

func _input(event):
	if event.is_action_pressed("quests") and not event.is_echo():
		if is_open:
			close()
		else:
			open()
		get_tree().set_input_as_handled()
	elif is_open and event.is_action_pressed("pause"):
		close()
		get_tree().set_input_as_handled()

func _process(_delta):
	# anything else taking over (a scene change, a conversation, the pause menu, a reset of Global.moving)
	# closes the journal instead of leaving it open over a walking player
	if is_open and (not _eligible_scene() or Global._dialogue_active() or get_tree().paused or Global.moving == true):
		close()
	var show = pinned and not is_open and unlocked() and _eligible_scene() and Global.moving == true and not get_tree().paused
	if show:
		var list = entries(Global.indices, _scene_path())
		var sig = var2str(list) + str(pinned)
		if sig != _sig:
			_sig = sig
			_fill(_tracker_list, list, true)
			_tracker.rect_size = Vector2.ZERO
	_tracker.visible = show
