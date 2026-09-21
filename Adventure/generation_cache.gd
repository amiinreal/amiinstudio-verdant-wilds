extends RefCounted
## Only deterministic generated data is cached. Saves and player changes stay separate.
static var enabled: bool=true
static func path(kind: String,seed_value: int,version: int) -> String:
	var signature: String="roof-loading-v1"
	for source: String in ["geography.gd","ecology.gd","open_world.gd"]:
		signature+=FileAccess.get_md5("res://Adventure/"+source)
	var folder: String="res://.godot/verdant_cache" if OS.has_feature("editor") else "user://verdant_cache"
	return folder+"/%s_%d_%d_%s.bin" % [kind,seed_value,version,signature.sha256_text().left(16)]

static func read_data(kind: String,seed_value: int,version: int) -> Variant:
	if not enabled: return null
	var file: FileAccess=FileAccess.open(path(kind,seed_value,version),FileAccess.READ)
	if file==null: return null
	return file.get_var(false)

static func write_data(kind: String,seed_value: int,version: int,data: Variant) -> void:
	if not enabled: return
	var destination: String=path(kind,seed_value,version)
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var temporary: String=destination+".%d.tmp" % OS.get_process_id()
	var file: FileAccess=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return
	file.store_var(data,false); file.close()
	DirAccess.rename_absolute(temporary,destination)
