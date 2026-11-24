extends Node
# "!" markers (the existing Sprites/interact.png art) pinned to the things the player can use.
#
#   * Each marker belongs to one specific door / exit / NPC / object and floats just above the
#     visible part of it (its sprite's opaque top; if it has no sprite, the top of its collision).
#   * Inside rooms every usable target carries a subtle marker from the moment the room loads; the
#     one in reach (the one Space / Enter / E will activate) is brighter and larger.
#   * Outdoors only the target in reach shows a marker.
#   * Locked or finished things (no active collision, or marker_usable() == false) show nothing.
#   * Markers are children of the Player, so they vanish with it on a scene change, and they are
#     hidden whenever the player cannot act (map open).
const TEXTURE = "res://Sprites/interact.png"
const Z = 95
const SUBTLE_SCALE = 1.1
const BRIGHT_SCALE = 1.6
const SUBTLE_ALPHA = 0.45

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
			var s = Sprite.new()
			s.name = "Marker_" + str(nd.name)
			s.texture = texture
			s.set_as_toplevel(true)
			s.z_as_relative = false
			s.z_index = Z
			s.visible = false
			add_child(s)
			entries.append({"target": nd, "sprite": s})

# things that already carry their own "!" sign (litter, the finale marker) get no second one
func _has_own_sign(c):
	for ch in c.get_children():
		if ch is Sprite and ch.texture != null and str(ch.texture.resource_path).ends_with("interact.png"):
			return true
	return false

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

func update(reach):
	time += get_physics_process_delta_time()
	var free = Global.moving == true and not get_tree().paused
	for e in entries:
		var c = e["target"]
		var s = e["sprite"]
		if not is_instance_valid(c):
			s.visible = false
			continue
		var is_reach = (c == reach)
		var show = free and is_usable(c) and (interior or is_reach)
		if not show:
			s.visible = false
			continue
		var a = _anchor(c)
		var bob = sin(time * 6.0) * 3.0 if is_reach else 0.0
		var sc = BRIGHT_SCALE if is_reach else SUBTLE_SCALE
		s.scale = Vector2(sc, sc)
		s.modulate = Color(1, 1, 1, 1.0 if is_reach else SUBTLE_ALPHA)
		s.global_position = a + Vector2(0, -16.0 * sc - 4.0 + bob)
		s.visible = true

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
		if ch is Sprite and ch.texture != null and ch.is_visible_in_tree() and ch.name != "question" and ch.name != "check":
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
