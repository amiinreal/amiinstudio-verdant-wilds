extends RefCounted
## This object lives only on the authority. RPCs carry intent, never inventory/stat values.
const Items := preload("res://Adventure/items.gd")
const Modules := preload("res://Adventure/modules.gd")
const Build := preload("res://Adventure/construction.gd")
const Geo := preload("res://Adventure/geography.gd")
const Rules := preload("res://Adventure/rules.gd")
var directory: String="user://openworld_v3"
var data: Dictionary={}
var bindings: Dictionary={}
var cooldowns: Dictionary={}
var writable: bool=true

static func uid() -> String:
	return Crypto.new().generate_random_bytes(24).hex_encode()

func fresh(seed_value: int) -> void:
	data={"schema":3,"seed":seed_value,"world":Rules.fresh_state(seed_value),"profiles":{},"structures":[],"resources":{}}
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
	_normalize_profiles()
	bindings[peer]=id
	data["profiles"][id]["stats"]["sessions"]+=1
	return {"id":id,"token":token}

func profile(peer: int) -> Dictionary:
	return data.get("profiles",{}).get(bindings.get(peer,""),{})

func enter_account(peer: int, account_id: String) -> Dictionary:
	# Called only with identity supplied by the authenticated relay, never an RPC argument.
	var stable: String = "account_" + account_id
	if stable in bindings.values(): return {}
	if not data.profiles.has(stable):
		var created: Dictionary = enter(peer)
		var p: Dictionary = data.profiles[created.id]
		data.profiles.erase(created.id)
		p.id = stable; p.token_hash = ""
		data.profiles[stable] = p
	else:
		data.profiles[stable].stats.sessions += 1
	bindings[peer] = stable
	return {"id": stable}

func public_delta() -> Dictionary:
	return {"animals":data.get("animals",{}).duplicate(true),"tamed":data.get("tamed",{}).duplicate(true),"structures":data["structures"].duplicate(true),"resources":data["resources"].duplicate(true),"terrain_edits":data.get("terrain_edits",{}).duplicate(true),"grass_clearings":data.get("grass_clearings",{}).duplicate(true)}

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
	var tool: Dictionary=Items.tool(p.get("equipped","hand"))
	if resource["kind"]!="fiber" and tool.get("resource","")!=resource["kind"]: return Build.fail("Equip an axe for wood or a pickaxe for stone.")
	if p.get("equipped","hand")!="hand" and int(p["inventory"].get(p["equipped"],0))<1: return Build.fail("You do not own the equipped tool.")
	if actor.distance_to(resource["p"])>4.5: return Build.fail("Move closer to the resource.")
	var ray: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(actor+Vector3.UP,resource["p"]+Vector3.UP*0.7,5)
	if world.resource_colliders.has(resource_id): ray.exclude=[world.resource_colliders[resource_id].get_rid()]
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
	var recipes: Dictionary=Items.recipes()
	if not recipes.has(recipe): return Build.fail("Unknown recipe.")
	if not afford(p,recipes[recipe]["cost"]): return Build.fail("Not enough materials.")
	var result_id: String=recipes[recipe].data.result
	pay(p,recipes[recipe]["cost"]); p["inventory"][result_id]=int(p["inventory"].get(result_id,0))+recipes[recipe]["amount"]
	p["stats"]["items_crafted"]+=recipes[recipe]["amount"]
	if recipe in ["axe","pickaxe","hammer"]: p["stats"]["tools_crafted"]+=1
	cooldowns[peer]=now+0.25
	return {"ok":true,"reason":"Crafted "+recipe}

func place(peer: int, module: String, proposed: Vector3, turn: int, actor: Vector3, world: Node3D, now: float) -> Dictionary:
	if not Modules.catalog().has(module): return Build.fail("Choose individual panels from Custom roofs.")
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
	p["fullness"] = maxf(0.0, float(p.get("fullness", 50)) - delta / 30.0)
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

func save(world_state: Dictionary) -> bool:
	if not writable: return false
	data["world"]=world_state.duplicate(true); data["world"].erase("world_delta")
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
	if not FileAccess.file_exists(path):
		var legacy: String="user://openworld_v2/world_%d.json" % seed_value
		if directory!="user://openworld_v3" or not FileAccess.file_exists(legacy): return false
		var previous: Variant=JSON.parse_string(FileAccess.get_file_as_string(legacy))
		if not previous is Dictionary or previous.get("schema")!=2: return false
		data["profiles"]=previous.get("profiles",{}).duplicate(true)
		data["structures"]=previous.get("structures",[]).duplicate(true)
		data["legacy_resources"]=previous.get("resources",{}).duplicate(true)
		data["migrated_from"]=2
		_normalize_profiles()
		return true
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not valid_save(parsed,seed_value):
		# Preserve damaged data; do not overwrite it with an empty world.
		writable=false; return false
	data=parsed
	for clearing: Array in data.get("grass_clearings",{}).values():
		clearing[0]=int(clearing[0]); clearing[1]=int(clearing[1])
	_normalize_profiles()
	for record: Dictionary in data["structures"]:
		record["rotation"]=int(record["rotation"]); record["created_at"]=int(record["created_at"])
	for key: String in ["version","seed"]: data["world"][key]=int(data["world"][key])
	for p: Dictionary in data["profiles"].values():
		for key: String in p["inventory"]: p["inventory"][key]=int(p["inventory"][key])
		for key: String in p["stats"]:
			if key not in ["distance","playtime","exploration_percentage"]: p["stats"][key]=int(p["stats"][key])
		for i in range(p["regions"].size()): p["regions"][i]=int(p["regions"][i])
	return true

static func valid_save(value: Variant, seed_value: int) -> bool:
	if not value is Dictionary: return false
	if value.get("schema")!=3 or value.get("seed")!=seed_value: return false
	var animals: Variant = value.get("animals", {})
	if not animals is Dictionary or animals.size() > 9: return false
	for key: Variant in animals:
		if not key is String or not (key in ["cat_0", "cat_1", "cat_2", "dog_0", "dog_1", "dog_2", "cow_0", "cow_1", "cow_2"]): return false
		if not (animals[key] is int or animals[key] is float) or not is_finite(float(animals[key])) or float(animals[key]) < 0 or float(animals[key]) > 100: return false
	for key: String in ["profiles","resources","world"]:
		if not value.get(key) is Dictionary: return false
	var tamed: Variant = value.get("tamed", {})
	if not tamed is Dictionary or tamed.size() > 9: return false
	for key: Variant in tamed:
		if not key is String or not (key in ["cat_0", "cat_1", "cat_2", "dog_0", "dog_1", "dog_2"]): return false
		if not tamed[key] is String or not value["profiles"].has(tamed[key]): return false
	if not value.get("structures") is Array or value["structures"].size()>12000: return false
	var edits: Variant=value.get("terrain_edits",{})
	if not edits is Dictionary or edits.size()>66049: return false
	for key: Variant in edits:
		if not key is String or not key.is_valid_int() or int(key)<0 or int(key)>=66049: return false
		var level: Variant=edits[key]
		if (not level is int and not level is float) or not is_finite(float(level)) or absf(float(level))>512: return false
	var clearings: Variant=value.get("grass_clearings",{})
	if not clearings is Dictionary or clearings.size()>10000: return false
	for location: Variant in clearings.values():
		if not location is Array or location.size()!=2: return false
		for coordinate: Variant in location:
			if (not coordinate is int and not coordinate is float) or not is_finite(float(coordinate)) or absf(float(coordinate))>1024: return false
	var world_state: Dictionary=value["world"].duplicate(true)
	for key: String in ["version","seed"]:
		if not world_state.get(key) is float and not world_state.get(key) is int: return false
		world_state[key]=int(world_state[key])
	if not Rules.validate_state(world_state): return false
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
		var fullness: Variant = p.get("fullness", 50)
		if not (fullness is int or fullness is float) or not is_finite(float(fullness)) or float(fullness) < 0 or float(fullness) > 100: return false
		for key: String in ["inventory","stats","houses"]:
			if not p.get(key) is Dictionary: return false
		for key: String in ["regions","landmarks","hidden","bridges","discovered_structures","achievements"]:
			if not p.get(key) is Array: return false
		for key: String in ["wood","stone","fiber","planks","rope"]:
			if not p["inventory"].has(key) or float(p["inventory"][key])<0: return false
		for food: String in ["meat", "cooked_meat", "bone"]:
			var amount: Variant = p["inventory"].get(food, 0)
			if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) < 0 or float(amount) != floorf(float(amount)): return false
		for key: String in ["playtime","sessions","distance","resources_gathered","wood_gathered","stone_gathered","fiber_gathered","items_crafted","components_placed"]:
			if not p["stats"].has(key): return false
	return true

func _normalize_profiles() -> void:
	for p: Dictionary in data["profiles"].values():
		if not p.has("fullness"): p["fullness"] = 50
		for tool: String in ["axe","pickaxe","hammer"]:
			if not p["inventory"].has(tool): p["inventory"][tool]=1
		if not p.has("equipped"): p["equipped"]="axe"
		for stat: String in ["tools_crafted","worlds_joined","multiplayer_sessions"]:
			if not p["stats"].has(stat): p["stats"][stat]=0

func hit_animal(peer: int, animal: Node3D, now: float) -> Dictionary:
	var p: Dictionary = profile(peer)
	if p.is_empty() or now < float(cooldowns.get(peer, 0)): return Build.fail("Wait for your next swing.")
	if not data.has("animals"): data["animals"] = {}
	var hp: int = int(data.animals.get(animal.animal_id, 100 if animal.species == "cow" else 50))
	if hp <= 0: return Build.fail("This animal is already gone.")
	var tool_id: String = p.get("equipped", "hand")
	if tool_id != "hand" and int(p.inventory.get(tool_id, 0)) < 1: return Build.fail("You do not own that tool.")
	hp = maxi(0, hp - (30 if tool_id in ["axe", "pickaxe"] else 15))
	data.animals[animal.animal_id] = hp
	cooldowns[peer] = now + 0.5
	var result_text: String = animal.species.capitalize() + " hit · " + str(hp) + " health"
	if hp == 0 and animal.species == "cow":
		p.inventory["meat"] = int(p.inventory.get("meat", 0)) + 3
		p.inventory["bone"] = int(p.inventory.get("bone", 0)) + 1
		result_text = "Cow harvested · +3 meat, +1 bone added to Food in your inventory"
	elif hp == 0: result_text = animal.species.capitalize() + " defeated."
	return {"ok":true, "reason":result_text}

## Cows are always a free, affectionate pet. Cats and dogs are wild until fed a bone
## (preferred) or meat, which tames them for life; only after that does petting them
## do anything -- a wild animal has no bond yet, so it gets no heart popup.
func interact_animal(peer: int, animal: Node3D) -> Dictionary:
	var p: Dictionary = profile(peer)
	if p.is_empty(): return Build.fail("Not signed in.")
	if not data.has("tamed"): data["tamed"] = {}
	var already_tamed: bool = data.tamed.has(animal.animal_id)
	if animal.species == "cow" or already_tamed:
		return {"ok":true, "reason":("You pet your " if already_tamed else "You pet the ") + animal.species + ".", "affection":true}
	var feed_item: String = "bone" if int(p.inventory.get("bone", 0)) > 0 else ("meat" if int(p.inventory.get("meat", 0)) > 0 else "")
	if feed_item.is_empty():
		return {"ok":true, "reason":"This " + animal.species + " is wild. Feed it a bone or meat (hold one, then press T) to tame it.", "affection":false}
	p.inventory[feed_item] = int(p.inventory[feed_item]) - 1
	data.tamed[animal.animal_id] = p.id
	return {"ok":true, "reason":animal.species.capitalize() + " is tamed! It will follow you now.", "tamed":true, "affection":true}

func inventory_action(peer: int, item: String, action: String, now: float) -> Dictionary:
	var p: Dictionary = profile(peer)
	if p.is_empty() or now < float(cooldowns.get(peer, 0)): return Build.fail("Wait a moment.")
	if action not in ["eat", "discard"] or int(p.inventory.get(item, 0)) < 1: return Build.fail("You do not have that item.")
	if action == "eat":
		if item != "cooked_meat": return Build.fail("Cook raw meat at a cooking fire first." if item == "meat" else "This item is not food.")
		if int(p.get("fullness", 50)) >= 100: return Build.fail("You are already full.")
		p.fullness = mini(100, int(p.get("fullness", 50)) + 40)
	p.inventory[item] = int(p.inventory[item]) - 1
	if p.inventory[item] == 0 and p.get("equipped", "hand") == item: p.equipped = "hand"
	cooldowns[peer] = now + 0.3
	return {"ok":true, "reason":("Ate grilled meat · +40 food" if action == "eat" else "Removed one " + item + " from inventory.")}

func equip(peer: int,tool: String) -> Dictionary:
	var p: Dictionary=profile(peer)
	if p.is_empty() or Items.tool(tool).is_empty(): return Build.fail("Unknown tool.")
	if tool!="hand" and int(p["inventory"].get(tool,0))<1: return Build.fail("Craft this tool first.")
	p["equipped"]=tool
	return {"ok":true,"reason":"Equipped "+Items.tool(tool)["name"]}

func migrate_resources(world: Node3D) -> void:
	if data.get("migrated_from",0)!=2 or data.get("ecology_migrated",false): return
	var path: String="res://Adventure/v2_ecology_%d.json" % int(data["seed"])
	if FileAccess.file_exists(path):
		var records: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if records is Array:
			for old: Dictionary in records:
				var target: Vector3=Vector3(old["position"][0],old["position"][1],old["position"][2])
				var nearest: String=""; var distance: float=14
				for id: String in world.resources:
					var r: Dictionary=world.resources[id]
					if r["kind"]==old["kind"] and r["p"].distance_to(target)<distance:
						nearest=id; distance=r["p"].distance_to(target)
				if not nearest.is_empty(): data["resources"][nearest]=int(old["remaining"])
	data["ecology_migrated"]=true

const REFUND_RATIO: float=0.5
func disassemble(peer: int, structure_id: String, actor: Vector3, world: Node3D, now: float) -> Dictionary:
	var p: Dictionary=profile(peer)
	if p.is_empty() or now<float(cooldowns.get(peer,0)): return Build.fail("Wait before disassembling.")
	var found: Dictionary={}
	for record: Dictionary in data.structures:
		if record.id==structure_id: found=record; break
	if found.is_empty() or found.owner_id!=p.id: return Build.fail("You can only disassemble your own pieces.")
	if actor.distance_to(Build.position(found))>10: return Build.fail("Move within 10 m.")
	var remaining: Array=data.structures.duplicate(); remaining.erase(found)
	# Validate dependents against the resulting structure before allowing removal.
	for record: Dictionary in remaining:
		if record.owner_id!=p.id or record.building_id!=found.building_id: continue
		if Build.position(record).distance_to(Build.position(found))>15: continue
		var others: Array=remaining.duplicate(); others.erase(record)
		var result: Dictionary=Build.validate(world,others,record.module_id,Build.position(record),int(record.rotation),p.id,Build.position(record),false)
		if not result.ok: return Build.fail("Remove supported pieces first: "+Modules.definition(record.module_id).label)
	data.structures=remaining
	for material: String in Modules.definition(found.module_id).cost:
		p.inventory[material]=int(p.inventory.get(material,0))+floori(Modules.definition(found.module_id).cost[material]*REFUND_RATIO)
	p.houses=Build.houses(remaining,p.id); derive(peer); cooldowns[peer]=now+0.3
	return {"ok":true,"reason":"Disassembled; 50% of materials returned."}
