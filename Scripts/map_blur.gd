extends ColorRect
# Full-screen blur layer that sits between the world and the map (see World.gd).
# It lives under the camera in world space, so it re-fits itself to the viewport every frame.

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1, 1, 1, 1)
	visible = false

func _process(_delta):
	if not visible:
		return
	var inv = get_viewport().get_canvas_transform().affine_inverse()
	var s = inv.get_scale()
	rect_scale = Vector2(1, 1)
	rect_global_position = inv.xform(Vector2.ZERO)
	rect_size = get_viewport_rect().size * s
