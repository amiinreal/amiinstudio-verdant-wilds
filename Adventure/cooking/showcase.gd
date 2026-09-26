extends "res://Adventure/animals/showcase.gd"

func _ready() -> void:
	super._ready()
	for player: AnimationPlayer in players: player.get_parent().hide()
	for child: Node in get_children():
		if child is Label3D: child.hide()
		if child is Label: child.text = "VERDANT WILDS / CAMPFIRE COOKING\nRaw meat + wood → Grilled meat · 4 seconds"
	var ids: Array[String] = ["cooking_fire", "raw_meat", "cooked_meat"]
	var captions: Array[String] = ["COOKING FIRE", "RAW MEAT", "GRILLED MEAT"]
	for i: int in range(ids.size()):
		var model: Node3D = load("res://Adventure/cooking/"+ids[i]+".glb").instantiate()
		model.position.x = [-1.25,0.65,1.85][i]
		if i > 0: model.scale = Vector3.ONE * 2.0
		add_child(model)
		var label: Label3D = Label3D.new()
		label.text = captions[i]
		label.position = Vector3(model.position.x, 0.03, 0.95)
		label.rotation_degrees.x = -70
		label.font_size = 38
		label.pixel_size = 0.004
		add_child(label)
	var camera: Camera3D = get_viewport().get_camera_3d()
	camera.position = Vector3(2.3,3.5,5.4)
	camera.look_at(Vector3(0,0.3,0))
	camera.size = 4.6
