extends Area2D
# The left notice board in front of the town hall opens the map. It behaves like a house entrance:
# Space / Enter / E activate it when the player is in reach (that is also when its "!" shows), and a
# left click on the board works when the player is close by. Closing the map stays on M.

const CLICK_REACH = 170.0      # how near the player must be for a mouse click to count

func _ready():
	add_to_group("DOOR")
	connect("input_event", self, "_on_input_event")

func start_door_request_dialog():
	var world = get_parent()
	if world != null and world.has_method("open_map"):
		world.open_map()

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		var p = get_tree().get_nodes_in_group("Player")
		if p.size() == 0:
			return
		var r = p[0]._collider_rect(self)
		if r == null:
			return
		var f = p[0].global_position
		var d = Vector2(max(max(r.position.x - f.x, 0.0), f.x - r.end.x), max(max(r.position.y - f.y, 0.0), f.y - r.end.y)).length()
		if d <= CLICK_REACH:
			start_door_request_dialog()
