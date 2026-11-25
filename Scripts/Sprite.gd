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

var last_direction_id = 2    # "right": what a zero move vector used to give, before the first real step

func _physics_process(_delta):
	var current_move_vec = global_position - last_glb_position
	last_glb_position = global_position

	# The path moves the NPC once per rendered frame, but this runs once per physics tick. Below 60 fps some
	# ticks see no movement at all; those keep the last real direction instead of falling through to "right".
	if current_move_vec.length_squared() > 0.0001:
		var norm_move_vec = current_move_vec.normalized()
		last_direction_id = int(walk_directions_size * (norm_move_vec.rotated(PI / walk_directions_size).angle() + PI) / TAU)
	anim.play(str(walk_directions[last_direction_id]))
	
	if get_tree().paused == true:
		anim.play("idle")
		
	
