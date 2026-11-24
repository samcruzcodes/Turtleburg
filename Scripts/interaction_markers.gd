extends Node
# "!" markers (the existing Sprites/interact.png art) pinned to the things the player can use.
#
#   * Each marker belongs to one specific door / exit / NPC / object and floats just above the
#     visible part of it (its sprite's opaque top; if it has no sprite, the top of its collision).
#   * Inside rooms every usable target carries a subtle marker from the moment the room loads; the
#     one in reach (the one Space / Enter / E will activate) is brighter and larger.
#   * Outdoors only the target in reach shows a marker.
#   * Where the game's original "?" nodes exist (toilets, tubs, the laundry counter, the bedroom
#     notes, Brock's shakes) the "!" sits exactly where that "?" was; those old nodes stay hidden, so
#     there is only ever one marker per object. Hovering the object with the mouse brightens its marker.
#   * Locked or finished things (no active collision, or marker_usable() == false) show nothing.
#   * Markers are children of the Player, so they vanish with it on a scene change, and they are
#     hidden whenever the player cannot act (map open).
#
# Building ENTRANCES in the town (town hall, Jayson's, Brock's, Steven's and the neighbours' doors) get
# no "!": they get a small name plate above the doorway instead. It shows when the player is within
# interaction range of the entrance OR the mouse is over it (either is enough), whatever the quest
# state, and it only ever says the place's name. Everything else (people, toilets, tubs, litter, the
# notice board, exits) keeps its "!" exactly as before.
const TEXTURE = "res://Sprites/interact.png"
const Z = 95
const SUBTLE_SCALE = 1.1
const BRIGHT_SCALE = 1.6
const SUBTLE_ALPHA = 0.45
const HOVER_MARGIN = 10.0
const ORIGINAL_ART = "question-mark.png"

const ENTRANCE_SCRIPTS = ["towndoor.gd", "jaysondoor.gd", "brockdoor.gd", "stevenhouse.gd", "towniedoor.gd"]
const PLATE_NAMES = {"towndoor": "Town Hall", "jaysondoor": "Jayson's Home", "brockdoor": "Brock's Home", "stevendoor": "Steven's Home"}
const PLATE_FONT = "res://themes/Eight-Bit Madness.ttf"
const PLATE_FONT_SIZE = 26
const PLATE_PAD = Vector2(12, 5)
const PLATE_GAP = 8.0
const PLATE_HOLD = 0.12
const PLATE_FADE = 16.0

var plates = []      # [{ "target": door, "node": Node2D, "text": String, "alpha": float, "hold": float, "mode": String, "size": Vector2 }]
var mouse_override = null      # tests: a world position standing in for the mouse
var _plate_font = null
var player = null
var interior = false
var entries = []     # [{ "target": node, "sprite": Sprite }]
var time = 0.0
var texture = null
var _images = {}
var _tops = {}

func setup(p):
	player = p
	texture = load(TEXTURE)
	_plate_font = DynamicFont.new()
	_plate_font.font_data = load(PLATE_FONT)
	_plate_font.size = PLATE_FONT_SIZE
	_plate_font.use_filter = false
	var cs = get_tree().current_scene
	interior = cs != null and cs.filename != Global.WORLD_SCENE
	call_deferred("_scan")

func _scan():
	if player == null or not is_instance_valid(player):
		return
	var seen = {}
	for g in ["DOOR", "EXIT", "NPC"]:
		for nd in get_tree().get_nodes_in_group(g):
			if seen.has(nd) or not player._is_interactable(nd) or _has_own_sign(nd):
				continue
			seen[nd] = true
			if is_entrance(nd):
				_add_plate(nd)
				continue
			var orig = _original_marker(nd)
			if orig != null:
				orig.visible = false
			var s = Sprite.new()
			s.name = "Marker_" + str(nd.name)
			s.texture = texture
			s.set_as_toplevel(true)
			s.z_as_relative = false
			s.z_index = Z
			s.visible = false
			add_child(s)
			entries.append({"target": nd, "sprite": s, "orig": orig})

func is_entrance(nd):
	if interior or not nd.is_in_group("DOOR") or nd.get_script() == null:
		return false
	return ENTRANCE_SCRIPTS.has(nd.get_script().resource_path.get_file())

func plate_text(nd):
	var n = str(nd.name)
	if PLATE_NAMES.has(n):
		return PLATE_NAMES[n]
	return "Neighbor's Home"

# a small RPG name plate: dark wood-brown panel, warm cream border and text, a tiny pointer to the door
func _add_plate(nd):
	var text = plate_text(nd)
	var root = Node2D.new()
	root.name = "Plate_" + str(nd.name)
	root.set_as_toplevel(true)
	root.z_as_relative = false
	root.z_index = Z
	root.visible = false
	var ts = _plate_font.get_string_size(text)
	var size = Vector2(ceil(ts.x) + PLATE_PAD.x * 2.0, ceil(ts.y) + PLATE_PAD.y * 2.0)
	size.x += int(size.x) % 2           # even width: the pointer sits exactly in the middle
	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.rect_position = Vector2(-size.x * 0.5 + 2, -size.y + 2)
	shadow.rect_size = size
	root.add_child(shadow)
	var border = ColorRect.new()
	border.color = Color(0.93, 0.80, 0.50, 1)
	border.rect_position = Vector2(-size.x * 0.5, -size.y)
	border.rect_size = size
	root.add_child(border)
	var fill = ColorRect.new()
	fill.color = Color(0.17, 0.12, 0.08, 0.94)
	fill.rect_position = Vector2(-size.x * 0.5 + 2, -size.y + 2)
	fill.rect_size = size - Vector2(4, 4)
	root.add_child(fill)
	var l = Label.new()
	l.text = text
	l.add_font_override("font", _plate_font)
	l.add_color_override("font_color", Color(0.98, 0.93, 0.78, 1))
	l.align = Label.ALIGN_CENTER
	l.valign = Label.VALIGN_CENTER
	l.rect_position = Vector2(-size.x * 0.5, -size.y)
	l.rect_size = size
	root.add_child(l)
	var tip_o = Polygon2D.new()
	tip_o.polygon = PoolVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(0, 7)])
	tip_o.color = Color(0.93, 0.80, 0.50, 1)
	root.add_child(tip_o)
	var tip_i = Polygon2D.new()
	tip_i.polygon = PoolVector2Array([Vector2(-4, -2), Vector2(4, -2), Vector2(0, 4)])
	tip_i.color = Color(0.17, 0.12, 0.08, 1)
	root.add_child(tip_i)
	# the plate must never take a click meant for the door under or near it
	for ch in root.get_children():
		if ch is Control:
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	plates.append({"target": nd, "node": root, "text": text, "alpha": 0.0, "hold": 0.0, "mode": "", "size": size})

func plate_of(nd):
	for e in plates:
		if e["target"] == nd:
			return e
	return null

func plate_shown(nd):
	var e = plate_of(nd)
	return e != null and e["node"].visible and e["alpha"] > 0.5

func _notification(what):
	if what == NOTIFICATION_PAUSED:
		for e in plates:
			e["alpha"] = 0.0
			e["hold"] = 0.0
			e["node"].visible = false

# Called every physics frame with the interaction target in range (usable or not, so a finished
# house still shows its name) and whether the player can act right now.
func _update_plates(raw, free):
	var delta = get_physics_process_delta_time()
	var mouse = mouse_override if mouse_override != null else player.get_global_mouse_position()
	var placed = []
	var order = []
	for e in plates:
		var c = e["target"]
		var root = e["node"]
		if not free or not is_instance_valid(c) or player._collider_rect(c) == null:
			e["alpha"] = 0.0
			e["hold"] = 0.0
			e["mode"] = ""
			root.visible = false
			continue
		var by_range = (c == raw)
		var r = player._collider_rect(c)
		var by_mouse = r.grow(HOVER_MARGIN).has_point(mouse)
		if by_range or by_mouse:
			e["hold"] = PLATE_HOLD
			e["mode"] = "range" if by_range else "mouse"
		else:
			e["hold"] = max(0.0, e["hold"] - delta)
		var want = e["hold"] > 0.0
		e["alpha"] = clamp(e["alpha"] + (PLATE_FADE * delta if want else -PLATE_FADE * delta), 0.0, 1.0)
		if e["alpha"] <= 0.0:
			root.visible = false
			continue
		order.append(e)
	order.sort_custom(self, "_plate_priority")
	for e in order:
		var rr = player._collider_rect(e["target"])
		var pos = Vector2(rr.position.x + rr.size.x * 0.5, rr.position.y - PLATE_GAP - 7.0)
		pos = Vector2(round(pos.x), round(pos.y))
		var box = Rect2(pos - Vector2(e["size"].x * 0.5, e["size"].y), e["size"] + Vector2(0, 7))
		var guard = 0
		var moved = true
		while moved and guard < 4:
			moved = false
			guard += 1
			for q in placed:
				if box.grow(-1.0).intersects(q):
					pos.y = q.position.y - 4.0 - 7.0
					box = Rect2(pos - Vector2(e["size"].x * 0.5, e["size"].y), e["size"] + Vector2(0, 7))
					moved = true
		placed.append(box)
		e["node"].global_position = pos
		e["node"].modulate = Color(1, 1, 1, e["alpha"])
		e["node"].visible = true

func _plate_priority(a, b):
	return (0 if a["mode"] == "range" else 1) < (0 if b["mode"] == "range" else 1)

# things that already carry their own "!" sign (litter, the finale marker) get no second one
func _has_own_sign(c):
	for ch in c.get_children():
		if ch is Sprite and ch.texture != null and str(ch.texture.resource_path).ends_with("interact.png"):
			return true
	return false

# the game's own hidden "?" sprite for this object (null if it has none)
func _original_marker(c):
	for ch in c.get_children():
		if ch is Sprite and ch.texture != null and str(ch.texture.resource_path).ends_with(ORIGINAL_ART):
			return ch
		var deeper = _original_marker(ch) if not (ch is Area2D) and not (ch is KinematicBody2D) else null
		if deeper != null:
			return deeper
	return null

func is_usable(c):
	if c.has_method("marker_usable") and not c.marker_usable():
		return false
	return player._collider_rect(c) != null     # finished things switch their collision off

# Marker sprite of a target (null if it has none / is hidden): used by tests.
func sprite_of(c):
	for e in entries:
		if e["target"] == c:
			return e["sprite"]
	return null

func update(reach, raw = null):
	time += get_physics_process_delta_time()
	var free = Global.moving == true and not get_tree().paused
	_update_plates(raw, free)
	for e in entries:
		var c = e["target"]
		var s = e["sprite"]
		if not is_instance_valid(c):
			s.visible = false
			continue
		var orig = e.get("orig")
		if orig != null and is_instance_valid(orig):
			orig.visible = false              # never show the old "?" next to the "!"
		var is_reach = (c == reach)
		var show = free and is_usable(c) and (interior or is_reach)
		if not show:
			s.visible = false
			continue
		var hover = interior and _hovered(c, orig)
		var bright = is_reach or hover
		var bob = sin(time * 6.0) * 3.0 if is_reach else 0.0
		var sc = BRIGHT_SCALE if bright else SUBTLE_SCALE
		if orig != null and is_instance_valid(orig):
			# the original "?" position is the anchor (centre of the marker)
			var os = orig.get_global_transform().get_scale().x
			var base = clamp(abs(os), SUBTLE_SCALE, 1.5)
			sc = base * (1.45 if bright else 1.0)
			s.global_position = orig.global_position + Vector2(0, bob)
		else:
			s.global_position = _anchor(c) + Vector2(0, -16.0 * sc - 4.0 + bob)
		s.scale = Vector2(sc, sc)
		s.modulate = Color(1, 1, 1, 1.0 if bright else SUBTLE_ALPHA)
		s.visible = true

# mouse over the object (its collision area or the spot its marker sits on)
func _hovered(c, orig):
	var m = mouse_override if mouse_override != null else c.get_global_mouse_position()
	var r = player._collider_rect(c)
	if r != null and r.grow(HOVER_MARGIN).has_point(m):
		return true
	if orig != null and is_instance_valid(orig) and orig.global_position.distance_to(m) < 26.0:
		return true
	return false

# ------------------------------------------------------------------ where the visible part is
func _anchor(c):
	var best = null
	for s in _sprites(c, []):
		var p = _sprite_top(s)
		if p != null and (best == null or p.y < best.y):
			best = p
	if best != null:
		return best
	var r = player._collider_rect(c)
	if r != null:
		return Vector2(r.position.x + r.size.x * 0.5, r.position.y)
	return c.global_position

func _sprites(n, out):
	for ch in n.get_children():
		if ch is Sprite and ch.texture != null and ch.is_visible_in_tree() and not str(ch.texture.resource_path).ends_with(ORIGINAL_ART):
			out.append(ch)
		if not (ch is Area2D) and not (ch is KinematicBody2D):
			_sprites(ch, out)
		else:
			# nested targets belong to themselves
			pass
	return out

func _image_of(tex):
	if not _images.has(tex):
		_images[tex] = tex.get_data()
	return _images[tex]

# Global position of the top-centre of what a sprite really draws (transparent padding ignored).
func _sprite_top(s):
	var tex = s.texture
	var region = s.region_rect if s.region_enabled else Rect2(Vector2.ZERO, tex.get_size())
	if s.hframes > 1 or s.vframes > 1:
		var fw = tex.get_width() / float(s.hframes)
		var fh = tex.get_height() / float(s.vframes)
		region = Rect2((s.frame % s.hframes) * fw, (s.frame / s.hframes) * fh, fw, fh)
	var key = "%d:%s" % [tex.get_instance_id(), str(region)]
	var o
	if _tops.has(key):
		o = _tops[key]
	else:
		o = Rect2(Vector2.ZERO, region.size)
		var img = _image_of(tex)
		if img != null and not img.is_empty():
			img.lock()
			var minx = int(region.size.x)
			var maxx = -1
			var miny = int(region.size.y)
			var maxy = -1
			for y in range(int(region.size.y)):
				for x in range(int(region.size.x)):
					if img.get_pixel(int(region.position.x) + x, int(region.position.y) + y).a > 0.3:
						minx = min(minx, x)
						maxx = max(maxx, x)
						miny = min(miny, y)
						maxy = max(maxy, y)
			img.unlock()
			if maxx >= 0:
				o = Rect2(minx, miny, maxx - minx + 1, maxy - miny + 1)
		_tops[key] = o
	var full = s.get_rect()
	var local = full.position + Vector2(o.position.x + o.size.x * 0.5, o.position.y)
	return s.get_global_transform().xform(local)
