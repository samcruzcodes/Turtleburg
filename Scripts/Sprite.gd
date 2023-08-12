extends Sprite

onready var anim = $AnimationPlayer

var last_glb_position = Vector2.ZERO

var walk_directions = [
	"left",
	"up",
	"right",
	"down",
]

var walk_directions_size = float(walk_directions.size())

func _physics_process(_delta):
	var current_move_vec = global_position - last_glb_position
	last_glb_position = global_position

	var norm_move_vec = current_move_vec.normalized()
	var direction_id = int(walk_directions_size * (norm_move_vec.rotated(PI / walk_directions_size).angle() + PI) / TAU)
	anim.play(str(walk_directions[direction_id]))
	
	if get_tree().paused == true:
		anim.play("idle")
		
	
