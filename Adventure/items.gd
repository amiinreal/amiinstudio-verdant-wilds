extends RefCounted
## Reusable tool definitions. Resource rewards and costs are owned by world_store.gd.
const TOOLS: Dictionary={
	"hand":{"name":"Hands","resource":"fiber","model":"","grip":Vector3.ZERO,"rotation":Vector3.ZERO},
	"axe":{"name":"Axe","resource":"wood","model":"res://Fantasy Props Megakit/Exports/FBX/Axe_Bronze.fbx","grip":Vector3(0,-0.22,0),"rotation":Vector3(PI,0,0)},
	"pickaxe":{"name":"Pickaxe","resource":"stone","model":"res://Fantasy Props Megakit/Exports/FBX/Pickaxe_Bronze.fbx","grip":Vector3(0,-0.30,0),"rotation":Vector3(PI,0,0)},
	"hammer":{"name":"Building hammer","resource":"building","model":"res://Adventure/generated/BuildingHammer.glb","grip":Vector3.ZERO,"rotation":Vector3(PI,0,0)}
}
static var RECIPES: Dictionary={}
static func recipes() -> Dictionary:
	if not RECIPES.is_empty(): return RECIPES
	for file: String in DirAccess.get_files_at("res://Adventure/data/recipes"):
		if not file.ends_with(".tres"): continue
		var data: Resource=load("res://Adventure/data/recipes/"+file)
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
		var path: String="res://Adventure/generated/items/"+id+".png"
		_icons[id]=load(path) if ResourceLoader.exists(path) else null
	return _icons[id]
