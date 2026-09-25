extends RefCounted
## Reusable tool definitions. Resource rewards and costs are owned by world_store.gd.
const TOOLS: Dictionary={
	"hand":{"name":"Hands","resource":"fiber","model":"","grip":Vector3.ZERO,"rotation":Vector3.ZERO},
	"axe":{"name":"Axe","resource":"wood","model":"res://Fantasy Props Megakit/Exports/FBX/Axe_Bronze.fbx","grip":Vector3(0,-0.22,0),"rotation":Vector3(PI,0,0)},
	"pickaxe":{"name":"Pickaxe","resource":"stone","model":"res://Fantasy Props Megakit/Exports/FBX/Pickaxe_Bronze.fbx","grip":Vector3(0,-0.30,0),"rotation":Vector3(PI,0,0)},
	"hammer":{"name":"Building hammer","resource":"building","model":"res://Adventure/generated/BuildingHammer.glb","grip":Vector3.ZERO,"rotation":Vector3(PI,0,0)}
}
static var RECIPES: Dictionary={}
const FOOD_MODELS: Dictionary = {
	"meat":preload("res://Adventure/cooking/raw_meat.glb"),
	"cooked_meat":preload("res://Adventure/cooking/cooked_meat.glb")
}

static func food_preview(id: String) -> SubViewportContainer:
	var container: SubViewportContainer = SubViewportContainer.new()
	container.custom_minimum_size = Vector2(120, 88)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(120, 88)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	container.add_child(viewport)
	viewport.add_child(FOOD_MODELS[id].instantiate())
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	viewport.add_child(light)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.4, 0.6, 0.6)
	viewport.add_child(camera)
	camera.transform = camera.transform.looking_at(Vector3(0, 0.04, 0), Vector3.UP)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.65
	return container
static func recipes() -> Dictionary:
	if not RECIPES.is_empty(): return RECIPES
	for file: String in DirAccess.get_files_at("res://Adventure/data/recipes"):
		# Exported builds store a converted resource as "name.tres.remap"; see modules.gd.
		if not (file.ends_with(".tres") or file.ends_with(".tres.remap")): continue
		var data: Resource=load("res://Adventure/data/recipes/"+file.trim_suffix(".remap"))
		RECIPES[data.recipe_id]={"cost":data.ingredients,"amount":data.quantity,"data":data}
	return RECIPES
static func tool(id: String) -> Dictionary: return TOOLS.get(id,{})
static func model(id: String) -> Node3D:
	var def: Dictionary=tool(id)
	var root: Node3D=Node3D.new()
	if def.is_empty() or def["model"].is_empty(): return root
	var packed: PackedScene=load(def["model"]) as PackedScene
	if packed==null: push_error("Tool model failed to load: "+def["model"]); return root
	var native: Node3D=packed.instantiate(); native.position=def["grip"]; native.rotation=def["rotation"]; root.add_child(native)
	return root

static var _icons: Dictionary={}
static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path: String="res://Adventure/animals/meat.svg" if id == "meat" else "res://Adventure/generated/items/"+id+".png"
		if id == "cooked_meat": path = "res://Adventure/cooking/cooked_meat.svg"
		_icons[id]=load(path) if ResourceLoader.exists(path) else null
	return _icons[id]
