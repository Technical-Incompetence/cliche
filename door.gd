extends Node2D

var color_steps = 10.0
@export var color = 0;


# Called when the node enters the scene tree for the first time.
func _ready():
	$Sprite2D.material.set_shader_parameter("new_color", Color.from_hsv(color/color_steps, 1.0, 1.0))
