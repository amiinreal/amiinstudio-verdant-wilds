extends RefCounted
## This object lives only on the authority. RPCs carry intent, never inventory/stat values.
const Modules := preload("res://Adventure/modules.gd")
const Build := preload("res://Adventure/construction.gd")
const Geo := preload("res://Adventure/geography.gd")
const Rules := preload("res://Adventure/rules.gd")
var directory: String="user://openworld_v2"
var data: Dictionary={}
var bindings: Dictionary={}
var cooldowns: Dictionary={}
var writable: bool=true

static func uid() -> String:
	return Crypto.new().generate_random_bytes(24).hex_encode()

func fresh(seed_value: int) -> void:
	data={"schema":2,"seed":seed_value,"music":Rules.fresh_state(seed_value),"profiles":{},"structures":[],"resources":{}}
	bindings.clear(); cooldowns.clear(); writable=true

func enter(peer: int, token: String="", host: bool=false) -> Dictionary:
	var id: String="host" if host else ""
	if not host and token.length()==48:
		for key: String in data["profiles"]:
			if data["profiles"][key].get("token_hash","")==token.sha256_text(): id=key; break
	if id.is_empty(): id=uid(); token=uid()
	if id in bindings.values(): return {}
	if not data["profiles"].has(id):
		data["profiles"][id]={"id":id,"token_hash":token.sha256_text(),"inventory":{"wood":0,"stone":0,"fiber":0,"planks":0,"rope":0},"stats":{"playtime":0.0,"sessions":0,"distance":0.0,"resources_gathered":0,"wood_gathered":0,"stone_gathered":0,"fiber_gathered":0,"items_crafted":0,"components_placed":0},"regions":[],"landmarks":[],"hidden":[],"bridges":[],"discovered_structures":[],"houses":{},"achievements":[]}
	bindings[peer]=id
	data["profiles"][id]["stats"]["sessions"]+=1
	return {"id":id,"token":token}

func profile(peer: int) -> Dictionary:
	return data.get("profiles",{}).get(bindings.get(peer,""),{})

func public_delta() -> Dictionary:
	return {"structures":data["structures"].duplicate(true),"resources":data["resources"].duplicate(true)}

func view(peer: int) -> Dictionary:
	var p: Dictionary=profile(peer).duplicate(true)
	p.erase("token_hash")
	return p

func leave(peer: int) -> void:
	bindings.erase(peer); cooldowns.erase(peer)

func gather(peer: int, resource_id: String, actor: Vector3, world: Node3D, now: float) -> Dictionary:
	var p: Dictionary=profile(peer)
	if p.is_empty() or now<float(cooldowns.get(peer,0)): return Build.fail("Wait a moment before gathering again.")
	var resource: Dictionary=world.resources.get(resource_id,{})
	if resource.is_empty(): return Build.fail("Unknown resource.")
	if actor.distance_to(resource["p"])>4.5: return Build.fail("Move closer to the resource.")
	var ray: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(actor+Vector3.UP,resource["p"]+Vector3.UP*0.7,5)
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit["position"].distance_to(resource["p"]+Vector3.UP*0.7)>1.1: return Build.fail("The resource is behind an obstacle.")
	var remaining: int=int(data["resources"].get(resource_id,resource["charges"]))
	if remaining<=0: return Build.fail("This resource has been gathered.")
	cooldowns[peer]=now+0.65
	data["resources"][resource_id]=remaining-1
	var kind: String=resource["kind"]; var amount: int=resource["amount"]
	p["inventory"][kind]+=amount
	p["stats"]["resources_gathered"]+=amount
	p["stats"][kind+"_gathered"]+=amount
	derive(peer)
	return {"ok":true,"reason":"Gathered %d %s" % [amount,kind]}

func craft(peer: int, recipe: String, now: float) -> Dictionary:
	var p: Dictionary=profile(peer)
	if p.is_empty() or now<float(cooldowns.get(peer,0)): return Build.fail("Wait a moment before crafting.")
	var recipes: Dictionary={"planks":{"cost":{"wood":2},"amount":2},"rope":{"cost":{"fiber":3},"amount":1}}
	if not recipes.has(recipe): return Build.fail("Unknown recipe.")
	if not afford(p,recipes[recipe]["cost"]): return Build.fail("Not enough materials.")
	pay(p,recipes[recipe]["cost"]); p["inventory"][recipe]+=recipes[recipe]["amount"]
	p["stats"]["items_crafted"]+=recipes[recipe]["amount"]
	cooldowns[peer]=now+0.25
	return {"ok":true,"reason":"Crafted "+recipe}

func place(peer: int, module: String, proposed: Vector3, turn: int, actor: Vector3, world: Node3D, now: float) -> Dictionary:
	var p: Dictionary=profile(peer)
	if p.is_empty() or now<float(cooldowns.get(peer,0)): return Build.fail("Wait a moment before placing.")
	if data["structures"].size()>=12000: return Build.fail("This world's component budget has been reached.")
	var result: Dictionary=Build.validate(world,data["structures"],module,proposed,turn,p["id"],actor)
	if not result["ok"]: return result
	var cost: Dictionary=Modules.definition(module)["cost"]
	if not afford(p,cost): return Build.fail("Materials needed: "+str(cost))
	var pos: Vector3=result["position"]
	var building_id: String=result["building_id"]
	if building_id.is_empty(): building_id=uid()
	var record: Dictionary={"id":uid(),"module_id":module,"position":[pos.x,pos.y,pos.z],"rotation":turn,"owner_id":p["id"],"building_id":building_id,"created_at":int(Time.get_unix_time_from_system()),"state":{"intact":true}}
	pay(p,cost); data["structures"].append(record)
	p["stats"]["components_placed"]+=1
	var homes: Dictionary=Build.houses(data["structures"],p["id"])
	for id: String in homes: p["houses"][id]=homes[id]
	derive(peer); cooldowns[peer]=now+0.2
	return {"ok":true,"reason":Modules.definition(module)["label"]+" placed","record":record}

static func afford(p: Dictionary, cost: Dictionary) -> bool:
	for kind: String in cost:
		if int(p["inventory"].get(kind,0))<int(cost[kind]): return false
	return true

static func pay(p: Dictionary, cost: Dictionary) -> void:
	for kind: String in cost: p["inventory"][kind]-=cost[kind]

func tick(peer: int, actor: Vector3, distance: float, delta: float, world: Node3D) -> void:
	var p: Dictionary=profile(peer)
	if p.is_empty(): return
	p["stats"]["playtime"]+=delta
	p["stats"]["distance"]+=clampf(distance,0,20*delta)
	var pos: Vector2=Vector2(actor.x,actor.z)
	if actor.y<world.height_at(pos)-1 or pos.length()>445: return
	var region: int=world.geography.region(pos)
	if region not in p["regions"]: p["regions"].append(region)
	for landmark: Dictionary in Geo.LANDMARKS:
		if pos.distance_to(landmark["p"])>18: continue
		if landmark["id"] not in p["landmarks"]: p["landmarks"].append(landmark["id"])
		var kind: String=landmark["kind"]
		if kind=="hidden" and landmark["id"] not in p["hidden"]: p["hidden"].append(landmark["id"])
		if kind in ["structure","settlement"] and landmark["id"] not in p["discovered_structures"]: p["discovered_structures"].append(landmark["id"])
	for bridge: Dictionary in world.geography.bridge_defs:
		if pos.distance_to(bridge["p"])<18 and bridge["id"] not in p["bridges"]: p["bridges"].append(bridge["id"])
	derive(peer)

func derive(peer: int) -> void:
	var p: Dictionary=profile(peer)
	if p.is_empty(): return
	var s: Dictionary=p["stats"]
	s["regions_discovered"]=p["regions"].size(); s["landmarks_discovered"]=p["landmarks"].size()
	s["hidden_locations_discovered"]=p["hidden"].size(); s["bridges_discovered"]=p["bridges"].size()
	s["structures_discovered"]=p["discovered_structures"].size(); s["buildings_completed"]=p["houses"].size()
	s["exploration_percentage"]=100.0*p["landmarks"].size()/Geo.LANDMARKS.size()
	var substantial: bool=false
	for size: Variant in p["houses"].values():
		if int(size)>=12: substantial=true
	var conditions: Dictionary={"First Shelter":p["houses"].size()>=1,"Homesteader":substantial,"Builder":s["components_placed"]>=25,"Master Builder":s["components_placed"]>=250,"Forest Wanderer":1 in p["regions"] or 4 in p["regions"],"Explorer":p["landmarks"].size()>=5,"World Traveler":p["regions"].size()==7,"Architect":p["houses"].size()>=3}
	for name: String in conditions:
		if conditions[name] and name not in p["achievements"]: p["achievements"].append(name)

func save(music: Dictionary) -> bool:
	if not writable: return false
	data["music"]=music.duplicate(true); data["music"].erase("world_delta")
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String=directory+"/world_%d.json" % int(data["seed"])
	var file: FileAccess=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(data)); file.close()
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path,path+".bak")!=OK: return false
	if DirAccess.rename_absolute(path+".tmp",path)!=OK: return false
	var manifest: FileAccess=FileAccess.open(directory+"/latest.txt",FileAccess.WRITE)
	if manifest!=null: manifest.store_string(str(data["seed"])); manifest.close()
	return true

func load_world(seed_value: int) -> bool:
	fresh(seed_value)
	var path: String=directory+"/world_%d.json" % seed_value
	if not FileAccess.file_exists(path): return false
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid_save(parsed,seed_value):
		# Preserve damaged data; do not overwrite it with an empty world.
		writable=false; return false
	data=parsed
	for record: Dictionary in data["structures"]:
		record["rotation"]=int(record["rotation"]); record["created_at"]=int(record["created_at"])
	for key: String in ["version","seed","shards","expedition"]: data["music"][key]=int(data["music"][key])
	for i in range(data["music"]["collected"].size()): data["music"]["collected"][i]=int(data["music"]["collected"][i])
	for p: Dictionary in data["profiles"].values():
		for key: String in p["inventory"]: p["inventory"][key]=int(p["inventory"][key])
		for key: String in p["stats"]:
			if key not in ["distance","playtime","exploration_percentage"]: p["stats"][key]=int(p["stats"][key])
		for i in range(p["regions"].size()): p["regions"][i]=int(p["regions"][i])
	return true

static func valid_save(value: Variant, seed_value: int) -> bool:
	if not value is Dictionary: return false
	if value.get("schema")!=2 or value.get("seed")!=seed_value: return false
	for key: String in ["profiles","resources","music"]:
		if not value.get(key) is Dictionary: return false
	if not value.get("structures") is Array or value["structures"].size()>12000: return false
	var music: Dictionary=value["music"].duplicate(true)
	for key: String in ["version","seed","shards","expedition"]:
		if not music.get(key) is float and not music.get(key) is int: return false
		music[key]=int(music[key])
	if not Rules.validate_state(music): return false
	var ids: Dictionary={}
	for r: Variant in value["structures"]:
		if not r is Dictionary: return false
		for key: String in ["id","module_id","owner_id","building_id"]:
			if not r.get(key) is String or r[key].is_empty(): return false
		if ids.has(r["id"]) or Modules.definition(r["module_id"]).is_empty(): return false
		ids[r["id"]]=true
		if not r.get("position") is Array or r["position"].size()!=3: return false
		for n: Variant in r["position"]:
			if (not n is float and not n is int) or not is_finite(float(n)) or absf(float(n))>1024: return false
		if not r.get("rotation") is float and not r.get("rotation") is int: return false
		if int(r["rotation"])<0 or int(r["rotation"])>3: return false
		if not value["profiles"].has(r["owner_id"]): return false
	for p: Variant in value["profiles"].values():
		if not p is Dictionary: return false
		for key: String in ["inventory","stats","houses"]:
			if not p.get(key) is Dictionary: return false
		for key: String in ["regions","landmarks","hidden","bridges","discovered_structures","achievements"]:
			if not p.get(key) is Array: return false
		for key: String in ["wood","stone","fiber","planks","rope"]:
			if not p["inventory"].has(key) or float(p["inventory"][key])<0: return false
		for key: String in ["playtime","sessions","distance","resources_gathered","wood_gathered","stone_gathered","fiber_gathered","items_crafted","components_placed"]:
			if not p["stats"].has(key): return false
	return true
