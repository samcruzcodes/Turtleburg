extends Node2D

var index = Global.indices["world"]
onready var player = $Player
onready var end = $end
var mouse_over = false

func _ready():
	if Global.has_method("get_singleton"):
		var save_game = SaveGame.get_singleton()
		if save_game and save_game.isVisible:
			player.position = save_game.player_position
		else:
			player.position = Vector2(100, 100) 

	Global.do_save()
	_first_time()
	Global.connect("left_town", self, "_on_left_town")
	
	if Global.indices["pollution"] > 5 and Global.indices["jayhouse"] > 1 and Global.indices["brockhouse"] > 1:
		end.visible = true
		var new_dialog = Dialogic.start('ending')
		new_dialog.pause_mode = PAUSE_MODE_PROCESS
		add_child(new_dialog)
		new_dialog.connect('timeline_end', self, 'end_dialog')
		get_tree().paused = true
		


func _first_time():
	if index > 0:
		get_tree().paused = false
		$direct/CollisionPolygon2D.disabled = true
		$direct.visible = false
	else:
		var new_dialog = Dialogic.start('Start')
		new_dialog.pause_mode = PAUSE_MODE_PROCESS
		add_child(new_dialog)
		new_dialog.connect('timeline_end', self, 'end_dialog')
		get_tree().paused = true
		Global.increment_index("world")
		

func end_dialog(_data):
	get_tree().paused = false
	$direct/CollisionPolygon2D.disabled = false
	$direct.visible = true

func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_M:
		if Global.isVisible == true:
			$Player/Camera2D2/minimap.visible = true
			Global.moving = false
			$"top exteriors/exteriorTop".visible = false
			$"top exteriors/homesTop".visible = false
			$"top exteriors/homesTop2".visible = false
			$towndoor.visible = false
			$stevendoor.visible = false
			$jaysondoor.visible = false
			$brockdoor.visible = false
		else:
			Global.moving = true
			$Player/Camera2D2/minimap.visible = false
			$"top exteriors/exteriorTop".visible = true
			$"top exteriors/homesTop".visible = true
			$"top exteriors/homesTop2".visible = true
			$towndoor.visible = true
			$stevendoor.visible = true
			$jaysondoor.visible = true
			$brockdoor.visible = true
			
		Global.isVisible = !Global.isVisible
		


###################################
# Main Houses
###################################

func _on_towndoor_mouse_entered():
	$towndoor/TextureRect.visible = true
func _on_towndoor_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		$towndoor.start_door_request_dialog()
func _on_towndoor_mouse_exited():
	$towndoor/TextureRect.visible = false



func _on_stevendoor_mouse_entered():
	$stevendoor/TextureRect.visible = true
func _on_stevendoor_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		$stevendoor.start_door_request_dialog()
func _on_stevendoor_mouse_exited():
	$stevendoor/TextureRect.visible = false



func _on_jaysondoor_mouse_entered():
	$jaysondoor/TextureRect.visible = true
func _on_jaysondoor_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		$jaysondoor.start_door_request_dialog()
func _on_jaysondoor_mouse_exited():
	$jaysondoor/TextureRect.visible = false


func _on_brockdoor_mouse_entered():
	$brockdoor/TextureRect.visible = true
func _on_brockdoor_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		$brockdoor.start_door_request_dialog()
func _on_brockdoor_mouse_exited():
	$brockdoor/TextureRect.visible = false
