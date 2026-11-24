extends Node
# Feet-based draw ordering for the interiors (town hall, Jayson's home, Brock's home).
#
# The interiors are built from TileMap layers whose furniture tiles are multi-cell regions, and the
# Player node is drawn after all of them, so the player was always painted on top of everything.
# Godot 3 can only y-sort TileMap cells by their anchor cell, which is wrong for tall objects, so:
#   * floor-level layers (floor, rug, walls) are pushed below everything,
#   * every furniture tile is mirrored as a Sprite with identical art/position/scale (the TileMap is
#     only hidden; its cells and any collision shapes stay exactly as authored),
#   * every object (those sprites plus the Sprite nodes already placed in the scenes) is drawn in
#     front of the player when the player's feet are north of the object's base line, and behind the
#     player otherwise.
# Nothing here touches collision, art or dialogue.

# Layers that always stay underneath the player and every object.
const BACKGROUND_LAYERS = ["outerwall", "inner wall", "floor", "rug"]
const Z_BACKGROUND = -2
const Z_BEHIND_PLAYER = -1
const Z_IN_FRONT_OF_PLAYER = 1

# Tiles whose region is no taller than this many pixels *and* wider than tall are treated as flat
# floor decals (mats etc.) and never cover the player. 0 disables the heuristic.
export var flat_decal_max_height = 0

var player = null
var feet_shape = null
var objects = []      # [{ "node": CanvasItem, "base": float (global y), "name": String }]
var converted_tilemaps = []

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	# the scene root is still busy setting up its children, so build the layers right after _ready
	call_deferred("_setup")

func _setup():
	var found = get_tree().get_nodes_in_group("Player")
	if found.size() == 0:
		return
	player = found[0]
	feet_shape = player.get_node_or_null("CollisionShape2D")
	var scene_root = get_parent()
	var holder = Node2D.new()
	holder.name = "LayeredObjects"
	scene_root.add_child(holder)
	var tilemaps = []
	var sprites = []
	_collect(scene_root, holder, tilemaps, sprites)
	for tm in tilemaps:
		if BACKGROUND_LAYERS.has(tm.name):
			tm.z_as_relative = false
			tm.z_index = Z_BACKGROUND
		else:
			_convert_tilemap(tm, holder)
	for s in sprites:
		_register_sprite(s)
	_update_layers()

func _collect(node, holder, tilemaps, sprites):
	for c in node.get_children():
		if c == holder or c == player or c.name == "GUI":
			continue
		if c is TileMap:
			tilemaps.append(c)
			continue
		if c is Sprite and c.texture != null and not (node is Sprite):
			sprites.append(c)
		_collect(c, holder, tilemaps, sprites)

func _convert_tilemap(tm, holder):
	if tm.tile_set == null or tm.get_used_cells().size() == 0:
		return
	var ts = tm.tile_set
	for cell in tm.get_used_cells():
		var id = tm.get_cellv(cell)
		var tex = ts.tile_get_texture(id)
		if tex == null:
			continue
		var region = ts.tile_get_region(id)
		var mode = ts.tile_get_tile_mode(id)
		if mode != TileSet.SINGLE_TILE:
			var sz = ts.autotile_get_size(id)
			var sp = ts.autotile_get_spacing(id)
			var co = tm.get_cell_autotile_coord(int(cell.x), int(cell.y))
			region = Rect2(region.position + Vector2(co.x * (sz.x + sp), co.y * (sz.y + sp)), sz)
		var transposed = tm.is_cell_transposed(int(cell.x), int(cell.y))
		var off = ts.tile_get_texture_offset(id)
		if transposed:
			off = Vector2(off.y, off.x)
		var local = tm.map_to_world(cell) + off
		var spr = Sprite.new()
		spr.texture = tex
		spr.centered = false
		spr.region_enabled = true
		spr.region_rect = region
		var fx = tm.is_cell_x_flipped(int(cell.x), int(cell.y))
		var fy = tm.is_cell_y_flipped(int(cell.x), int(cell.y))
		# TileMap flips after transposing, so the flags swap axes for transposed cells
		spr.flip_h = fy if transposed else fx
		spr.flip_v = fx if transposed else fy
		spr.modulate = tm.modulate * ts.tile_get_modulate(id)
		spr.z_as_relative = false
		spr.z_index = Z_BEHIND_PLAYER
		spr.name = "%s_%d_%d" % [tm.name, int(cell.x), int(cell.y)]
		holder.add_child(spr)
		# TileMap "transpose" swaps the tile's x/y axes (some furniture and the bar are authored rotated)
		var cell_xf = Transform2D(Vector2(0, 1), Vector2(1, 0), local) if transposed else Transform2D(Vector2(1, 0), Vector2(0, 1), local)
		spr.global_transform = tm.global_transform * cell_xf
		var base = _base_of(spr)
		var flat = flat_decal_max_height > 0 and region.size.y <= flat_decal_max_height and region.size.x > region.size.y
		if flat:
			spr.z_index = Z_BEHIND_PLAYER
			continue
		objects.append({"node": spr, "base": base, "name": spr.name})
	tm.visible = false
	converted_tilemaps.append(tm)

var _images = {}      # texture -> Image (kept locked-free copies for alpha scans)
var _opaque_cache = {}  # "texid:rect" -> Rect2 of opaque pixels inside the region (region space)

func _image_of(tex):
	if not _images.has(tex):
		_images[tex] = tex.get_data()
	return _images[tex]

# bounding box (in region space) of the pixels that are actually drawn; tiles are often padded with
# transparent rows, and sorting by the padded rectangle would put the object's base too low
func _opaque_rect(s):
	var tex = s.texture
	var region = s.region_rect if s.region_enabled else Rect2(Vector2.ZERO, tex.get_size())
	var key = "%d:%s" % [tex.get_instance_id(), str(region)]
	if _opaque_cache.has(key):
		return _opaque_cache[key]
	var result = Rect2(Vector2.ZERO, region.size)
	var img = _image_of(tex)
	if img != null and not img.is_empty():
		img.lock()
		var x0 = int(region.position.x)
		var y0 = int(region.position.y)
		var w = int(region.size.x)
		var h = int(region.size.y)
		var minx = w
		var miny = h
		var maxx = -1
		var maxy = -1
		for y in range(h):
			for x in range(w):
				if img.get_pixel(x0 + x, y0 + y).a > 0.3:
					if x < minx: minx = x
					if x > maxx: maxx = x
					if y < miny: miny = y
					if y > maxy: maxy = y
		img.unlock()
		if maxx >= 0:
			result = Rect2(minx, miny, maxx - minx + 1, maxy - miny + 1)
	_opaque_cache[key] = result
	return result

# lowest world y of what a sprite actually draws
func _base_of(s):
	var r = s.get_rect()
	if s.texture != null and s.hframes == 1 and s.vframes == 1:
		var o = _opaque_rect(s)
		var full = Rect2(Vector2.ZERO, r.size)
		var ox = o.position.x
		var oy = o.position.y
		var ex = o.end.x
		var ey = o.end.y
		if s.flip_h:
			var t = full.size.x - ex
			ex = full.size.x - ox
			ox = t
		if s.flip_v:
			var t2 = full.size.y - ey
			ey = full.size.y - oy
			oy = t2
		r = Rect2(r.position + Vector2(ox, oy), Vector2(ex - ox, ey - oy))
	var xf = s.get_global_transform()
	var ys = [xf.xform(r.position).y, xf.xform(Vector2(r.end.x, r.position.y)).y, xf.xform(Vector2(r.position.x, r.end.y)).y, xf.xform(r.end).y]
	return max(max(ys[0], ys[1]), max(ys[2], ys[3]))

func _register_sprite(s):
	var base = _base_of(s)
	s.z_as_relative = false
	s.z_index = Z_BEHIND_PLAYER
	objects.append({"node": s, "base": base, "name": str(get_parent().get_path_to(s))})

# The sole of the player's foot: the bottom edge of its collision rectangle (which is also the
# bottom of the sprite), not the shape's centre.
func feet_y():
	if feet_shape != null:
		var y = feet_shape.global_position.y
		if feet_shape.shape is RectangleShape2D:
			y += feet_shape.shape.extents.y * feet_shape.global_transform.get_scale().y
		return y
	return player.global_position.y

func _update_layers():
	var fy = feet_y()
	for o in objects:
		var want = Z_IN_FRONT_OF_PLAYER if fy < o["base"] else Z_BEHIND_PLAYER
		if o["node"].z_index != want:
			o["node"].z_index = want

func _process(_delta):
	if player != null:
		_update_layers()
