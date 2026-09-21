extends RefCounted
## Verified native FBX resources, never .import files or guessed fallbacks.
const ROOT: String="res://styled Nature megaKit/FBX/"
const ASSETS: Array[String]=["CommonTree_1","CommonTree_2","CommonTree_3","CommonTree_4","CommonTree_5","Pine_1","Pine_2","Pine_3","Pine_4","Pine_5","TwistedTree_1","TwistedTree_2","TwistedTree_3","TwistedTree_4","TwistedTree_5","DeadTree_1","DeadTree_2","DeadTree_3","DeadTree_4","DeadTree_5","Bush_Common","Bush_Common_Flowers","Grass_Common_Short","Grass_Common_Tall","Grass_Wispy_Short","Grass_Wispy_Tall","Flower_3_Group","Flower_3_Single","Flower_4_Group","Flower_4_Single","Clover_1","Clover_2","Fern_1","Plant_1","Plant_1_Big","Plant_7","Plant_7_Big","Mushroom_Common","Mushroom_Laetiporus","Rock_Medium_1","Rock_Medium_2","Rock_Medium_3","Pebble_Round_1","Pebble_Round_2","Pebble_Round_3","Pebble_Round_4","Pebble_Round_5","Pebble_Square_1","Pebble_Square_2","Pebble_Square_3","Pebble_Square_4","Pebble_Square_5","Pebble_Square_6","RockPath_Round_Small_1","RockPath_Round_Small_2","RockPath_Round_Small_3","RockPath_Round_Thin","RockPath_Round_Wide","RockPath_Square_Small_1","RockPath_Square_Small_2","RockPath_Square_Small_3","RockPath_Square_Thin","RockPath_Square_Wide","Petal_1","Petal_2","Petal_3","Petal_4","Petal_5"]
static var scenes: Dictionary={}
static var verified: bool=false
static func verify() -> void:
	if verified: return
	var failures: int=0
	for id: String in ASSETS:
		var path: String=ROOT+id+".fbx"
		var scene: PackedScene=load(path) as PackedScene
		if scene==null: push_error("Nature asset failed to load: "+path); failures+=1
		scenes[id]=scene
	verified=true
	print("NATURE_FBX_VERIFIED ",ASSETS.size()-failures,"/",ASSETS.size()," failures=",failures)
static func scene(id: String) -> PackedScene:
	if id not in ASSETS: push_error("Unlisted nature asset requested: "+ROOT+id+".fbx"); return null
	if not scenes.has(id): scenes[id]=load(ROOT+id+".fbx")
	return scenes[id] as PackedScene
