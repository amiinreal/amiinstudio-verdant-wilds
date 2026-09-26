extends RefCounted
## Reusable tool definitions. Resource rewards and costs are owned by world_store.gd.
const TOOLS: Dictionary={
	"hand":{"name":"Hands","resource":"fiber","model":"","grip":Vector3.ZERO,"rotation":Vector3.ZERO},
	"axe":{"name":"Axe","resource":"wood","model":"res://Fantasy Props Megakit/Exports/FBX/Axe_Bronze.fbx","grip":Vector3(0,-0.22,0),"rotation":Vector3(PI,0,0)},
	"pickaxe":{"name":"Pickaxe","resource":"stone","model":"res://Fantasy Props Megakit/Exports/FBX/Pickaxe_Bronze.fbx","grip":Vector3(0,-0.30,0),"rotation":Vector3(PI,0,0)},
	"hammer":{"name":"Building hammer","resource":"building","model":"res://Adventure/generated/BuildingHammer.glb","grip":Vector3.ZERO,"rotation":Vector3(PI,0,0)},
	"bucket":{"name":"Bucket","resource":"","model":"res://Fantasy Props Megakit/Exports/FBX/Bucket_Wooden_1.fbx","grip":Vector3(0,-0.25,0),"rotation":Vector3.ZERO},
	"water_bucket":{"name":"Water bucket","resource":"","model":"res://Fantasy Props Megakit/Exports/FBX/Bucket_Wooden_1.fbx","grip":Vector3(0,-0.25,0),"rotation":Vector3.ZERO},
	"fishing_rod":{"name":"Fishing rod","resource":"","model":"res://FarmingFishing/Models/fishing_rod.glb","grip":Vector3(0,-0.3,0.1),"rotation":Vector3.ZERO},
	"wheat_seeds":{"name":"Wheat seeds","resource":"","model":"res://FarmingFishing/Models/wheat_seeds.glb","grip":Vector3(0,-0.15,0),"rotation":Vector3.ZERO},
	"carrot_seeds":{"name":"Carrot seeds","resource":"","model":"res://FarmingFishing/Models/carrot_seeds.glb","grip":Vector3(0,-0.15,0),"rotation":Vector3.ZERO}
}
static var RECIPES: Dictionary={}
const FOOD_MODELS: Dictionary = {
	"meat":preload("res://Adventure/cooking/raw_meat.glb"),
	"cooked_meat":preload("res://Adventure/cooking/cooked_meat.glb"),
	"carrot":preload("res://FarmingFishing/Models/carrot_harvest.glb"),
	"wheat":preload("res://FarmingFishing/Models/wheat_harvest.glb"),
	"river_fish":preload("res://FarmingFishing/Models/river_fish.glb"),
	"salmon":preload("res://FarmingFishing/Models/salmon.glb")
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
		var overrides: Dictionary={"meat":"res://Adventure/animals/meat.svg","cooked_meat":"res://Adventure/cooking/cooked_meat.svg"}
		var custom: String="res://Adventure/icons/"+id+".svg"
		var path: String=overrides.get(id,custom if ResourceLoader.exists(custom) else "res://Adventure/generated/items/"+id+".png")
		_icons[id]=load(path) if ResourceLoader.exists(path) else null
	return _icons[id]
