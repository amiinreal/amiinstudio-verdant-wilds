extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path: String="user://openworld_v2/world_73129.json"
	if not FileAccess.file_exists(path): quit(); return
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var world: Node3D=Node3D.new(); world.set_script(load("res://Adventure/open_world.gd")); root.add_child(world); world.build(int(old["seed"]))
	var records: Array=[]
	for id: String in old["resources"]:
		if not world.resources.has(id): continue
		var r: Dictionary=world.resources[id]; var p: Vector3=r["p"]
		records.append({"kind":r["kind"],"position":[p.x,p.y,p.z],"remaining":int(old["resources"][id])})
	var file: FileAccess=FileAccess.open("C:/Users/amiin/AppData/Local/Temp/openworld_build/Adventure/v2_ecology_73129.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records)); file.close()
	print("MIGRATION_AUDIT_COMPLETE resources=",records.size()); quit()
