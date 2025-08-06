tool
extends Node2D

class_name SaveGame

const SAVE_DIR = "user://saves/"
var save_path = SAVE_DIR + "save.dat"
var isVisible = true
var moving = true
var player_position = Vector2(0, 0)

var indices = {
	"pollution": 0,
	"jayhouse": 0,
	"brockhouse": 0,
	"stevenhouse": 0,
	"brock": 0, 
	"jayson": 0, 
	"steven": 0, 
	"jodi": 0, 
	"gabe":0, 
	"town": 0, 
	"jaysondoor": 0, 
	"world": 0, 
	}

func increment_index(idx):
	indices[idx] += 1

func _ready():
	pass

func do_save():
	var dir = Directory.new()
	if !dir.dir_exists(SAVE_DIR):
		dir.make_dir_recursive(SAVE_DIR)
	var file = File.new()
	file.open(save_path, File.WRITE)
	var save_data = {
		"indices": indices,
		"player_position": player_position
	}
	file.store_var(save_data)
	Dialogic.save()
	file.close()

func do_load():
	var file = File.new()
	if file.file_exists(save_path):
		file.open(save_path, File.READ)
		var save_data = file.get_var()
		indices = save_data["indices"]
		player_position = save_data["player_position"]
		Dialogic.load()
		file.close()


func _input(event):
	if event is InputEventKey and event.is_action_pressed("save_key"):
		do_save()

