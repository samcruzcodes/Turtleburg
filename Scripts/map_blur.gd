extends ColorRect
# Full-screen blur layer that sits between the world and the map (see World.gd).
# It lives under the camera, which lives under the (scaled) Player, so every frame it re-fits itself to
# the viewport in world units and cancels whatever scale its parents carry.

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1, 1, 1, 1)
	visible = false

func _process(_delta):
	if not visible:
		return
	var inv = get_viewport().get_canvas_transform().affine_inverse()
	var s = inv.get_scale()
	# scale inherited from the parents (the Player is scaled), cancelled so the rect covers the screen
	var parent_xf = get_parent().get_global_transform() if get_parent() is Node2D else Transform2D.IDENTITY
	var ps = parent_xf.get_scale()
	ps = Vector2(max(abs(ps.x), 0.0001), max(abs(ps.y), 0.0001))
	rect_pivot_offset = Vector2.ZERO
	rect_scale = Vector2(1.0 / ps.x, 1.0 / ps.y)
	rect_size = get_viewport_rect().size * s
	rect_global_position = inv.xform(Vector2.ZERO)
