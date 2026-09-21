extends Node3D
@export_enum("wood", "stone", "fiber", "metal", "dust", "water", "mist") var material_kind: String="wood"
func _ready() -> void:
	var effects: Script=preload("res://Adventure/effects.gd")
	if material_kind=="water": effects.splash(get_parent(),position,true)
	elif material_kind=="mist": effects.particles(get_parent(),position,Color(0.8,0.9,0.9,0.2),18,Vector3(1,0.1,0.3),0.7,2.0,0.7,true)
	elif material_kind=="metal": effects.particles(get_parent(),position,Color(1,0.65,0.25,0.8),6,Vector3.ONE*0.04,1.5,0.25,0.025,true)
	elif material_kind=="dust": effects.particles(get_parent(),position,Color(0.6,0.6,0.53,0.3),6,Vector3.ONE*0.1,0.4,0.6,0.12,true)
	else: effects.impact(get_parent(),position-Vector3.UP,material_kind)
	queue_free()
