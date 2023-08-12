extends Button

var can_click = false

func _ready():
	connect_signals()
	
	var file: File = File.new()
	if(file.file_exists(Global.save_path)):
		can_click = true
		Load.visible = true
		pass
	else:
		Load.visible = false

func set_font_color(col : Color):
	set("custom_colors/font_color",col)
	set("custom_colors/font_color_hover",col)
	set("custom_colors/font_color_pressed",col)

func connect_signals():
	connect("mouse_entered",self,"_on_Button_mouse_entered")
	connect("pressed",self,"_on_Button_Pressed")
	
func _on_HowToPlay_pressed():
	pass
