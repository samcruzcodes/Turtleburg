extends Node2D
# Active quest markers drawn ON the map artwork (child of the map node, so they scale, move and stay
# aligned with the art whenever the window or camera changes, and they draw above the map blur).
#
# One yellow "!" (the game's existing Sprites/interact.png icon) per location that an ACTIVE journal
# step points at - the same steps as the Q journal. Nothing shows before Kate's introduction, and
# completed or still-locked steps show nothing.
#
# World -> map: the map is a scaled copy of the world's tile layers, so a world point is carried over
# through the shared tile coordinates of the "base" layer in both.
const TEXTURE = "res://Sprites/interact.png"
const MARKER_SCALE = 0.8
const LIFT = 30.0               # screen px above the spot, so the icon sits over the art, not on it
const WORLD_TILEMAP = "baseNode/base"
const MAP_TILEMAP = "TextureRect/baseNode/base"

var world = null                # the World node (tiles, doors, NPCs, litter)
var map = null                  # the map node this lives under
var texture = null
var sprites = {}                # location key -> Sprite
var time = 0.0
var last_dests = []             # for tests: [{"key", "dest", "map_pos"}]

func setup(world_node):
	world = world_node
	map = get_parent()
	texture = load(TEXTURE)

func _process(delta):
	if world == null or map == null or not map.visible:
		return
	time += delta
	var wanted = {}
	last_dests = []
	if Global.journal != null and Global.journal.unlocked():
		var scene_path = get_tree().current_scene.filename if get_tree().current_scene != null else ""
		var list = Global.journal.entries(Global.indices, scene_path)
		for e in Global.journal.active(list):
			var d = e.get("dest", "")
			var spot = _spot(d)
			if d == "" or spot == null:
				continue
			var key = _location_key(d, spot)
			if wanted.has(key):
				continue                 # one ! per location
			var mp = _to_map(spot)
			if mp == null:
				continue
			var crowded = false
			for other in wanted.values():
				if other.distance_to(mp) < 18.0:
					crowded = true       # two steps landing on the same spot still get one !
			if crowded:
				continue
			wanted[key] = mp
			last_dests.append({"key": key, "dest": d, "map_pos": mp})
	for key in sprites.keys():
		if not wanted.has(key):
			sprites[key].visible = false
	for key in wanted.keys():
		if not sprites.has(key):
			var s = Sprite.new()
			s.name = "QuestMarker"
			s.texture = texture
			s.scale = Vector2(MARKER_SCALE, MARKER_SCALE)
			add_child(s)
			sprites[key] = s
		var sp = sprites[key]
		sp.global_position = wanted[key] + Vector2(0, -LIFT + sin(time * 4.0) * 2.0)
		sp.visible = true

# Where, in the world, a step happens (null if it cannot be found right now)
func _spot(dest):
	var kind = dest.get_slice(":", 0)
	var arg = dest.get_slice(":", 1)
	if kind == "npc":
		for n in get_tree().get_nodes_in_group("NPC"):
			if "npc" in n and str(n.npc) == arg:
				return n.global_position
		return null
	if kind == "door":
		var door = world.get_node_or_null(arg)
		if door == null:
			return null
		var cs = door.get_node_or_null("CollisionShape2D")
		return cs.global_position if cs != null else door.global_position
	if kind == "trash":
		var holder = world.get_node_or_null("end trash")
		if holder == null:
			return null
		var sum = Vector2.ZERO
		var n = 0
		for t in holder.get_children():
			if t is Node2D and not Global.collected_trash.has(t.name):
				sum += t.global_position
				n += 1
		return sum / n if n > 0 else null
	if kind == "pier":
		var end = world.get_node_or_null("end")
		if end == null:
			return null
		var cs2 = end.get_node_or_null("CollisionShape2D")
		return cs2.global_position if cs2 != null else end.global_position
	return null

# a stable id for "this location": steps that share a destination share one marker
func _location_key(dest, _spot):
	return dest

func _to_map(world_pos):
	var wt = world.get_node_or_null(WORLD_TILEMAP)
	var mt = map.get_node_or_null(MAP_TILEMAP)
	if wt == null or mt == null:
		return null
	return mt.to_global(wt.to_local(world_pos))
