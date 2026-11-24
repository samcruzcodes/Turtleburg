extends Button
# Used both as the "Load" autoload (a plain holder) and as the menu's Continue button.

var can_click = false

func _ready():
	can_click = Global.has_save()
	# only the menu's Continue button is ever shown; the autoload instance stays hidden
	visible = can_click and get_parent() != get_tree().root
