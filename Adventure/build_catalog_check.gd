extends SceneTree
const Modules = preload("res://Adventure/modules.gd")

func _initialize() -> void:
	var files: PackedStringArray = DirAccess.get_files_at("res://Adventure/data/buildings")
	print("Files found: ", files.size())
	for file: String in files:
		if not file.ends_with(".tres"): continue
		var data: Resource = load("res://Adventure/data/buildings/" + file)
		if data == null:
			print("LOAD_FAILED ", file)
		elif not ("id" in data):
			print("NO_ID_PROPERTY ", file, " -> ", data)
		else:
			print("OK ", file, " id=", data.id)
	var catalog: Dictionary = Modules.catalog()
	print("CATALOG_SIZE ", catalog.size())
	if catalog.size() > 0:
		print("PASS build catalog is non-empty")
	else:
		print("FAIL build catalog is empty")

	# Simulate opening the Build tab a second time after catalog() already cached a result --
	# this is exactly the staleness scenario reported ("No matching pieces" after adding new
	# building pieces to a session that was already running).
	Modules.refresh_catalog()
	var refreshed: Dictionary = Modules.catalog()
	print("REFRESHED_CATALOG_SIZE ", refreshed.size())
	if refreshed.size() == catalog.size():
		print("PASS refresh_catalog reproduces the same catalog")
	else:
		print("FAIL refresh_catalog changed the catalog size unexpectedly")

	print("BUILD_CATALOG_CHECK_COMPLETE")
	quit()
