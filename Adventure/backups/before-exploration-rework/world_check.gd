extends SceneTree
const Session := preload("res://Adventure/session.gd")
const Modules := preload("res://Adventure/modules.gd")
const Build := preload("res://Adventure/construction.gd")
const Store := preload("res://Adventure/world_store.gd")
const Geo := preload("res://Adventure/geography.gd")
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ",text)
	if not ok: failures+=1
func run() -> void:
	var session: Node3D=Node3D.new(); session.set_script(Session); session.name="Session"; root.add_child(session)
	session.save_enabled=false
	session.start_solo(73129,"Validation")
	await physics_frame
	await physics_frame
	var world: Node3D=session.world
	check(world.terrain_meshes.size()==256,"continuous 1024 m terrain, 256 collision chunks")
	check(world.bridges.size()>=3,"normal bridges present before any song")
	check(session.state["solved"].count(true)==0,"exploration begins with every song unsolved")
	for river: Array in [Geo.RIVER,Geo.BROOK,Geo.STREAM]:
		var downhill: bool=true
		for i in range(river.size()-1): downhill=downhill and river[i].y>=river[i+1].y
		check(downhill,"water profile flows downhill")
	var max_grade: float=0
	var worst: Vector2=Vector2.ZERO
	for road: PackedVector2Array in Geo.ROADS:
		for i in range(road.size()-1):
			var length: float=road[i].distance_to(road[i+1])
			for step in range(ceili(length/2)):
				var a: Vector2=road[i].lerp(road[i+1],float(step)/ceili(length/2))
				var b: Vector2=road[i].lerp(road[i+1],float(step+1)/ceili(length/2))
				var bridge_zone: bool=false
				for bridge: Dictionary in world.geography.bridge_defs:
					if a.distance_to(bridge["p"])<bridge["span"]/2+3: bridge_zone=true
				if not bridge_zone:
					var grade: float=absf(world.height_at(a)-world.height_at(b))/a.distance_to(b)
					if grade>max_grade: max_grade=grade; worst=a
	print("ROAD_MAX_GRADE ",max_grade," at ",worst)
	check(max_grade<0.85,"main-road slopes are walkable")
	for bridge: Dictionary in world.geography.bridge_defs:
		for end: float in [-1,1]:
			var p: Vector2=bridge["p"]+Vector2(0,end*(bridge["span"]/2+1)).rotated(-bridge["yaw"])
			check(absf(world.height_at(p)-bridge["height"])<0.65,"bridge approach "+bridge["id"]+str(end))
		var clear: bool=true
		for step in range(ceili(bridge["span"])-8):
			var along: float=step-bridge["span"]/2+4
			var p: Vector2=bridge["p"]+Vector2(0,along).rotated(-bridge["yaw"])
			var deck: float=bridge["height"]-(sin((along+bridge["span"]/2)/bridge["span"]*PI) if bridge["kind"]=="rope" else 0.0)
			clear=clear and world.height_at(p)<deck+0.15
		check(clear,"terrain stays below bridge deck "+bridge["id"])
	for id: String in Modules.catalog():
		var node: Node3D=Modules.visual(id); check(node.get_child_count()>0,"native module "+id); node.free()
	var store: RefCounted=session.store
	var actor: CharacterBody3D=session.players[1]
	var selected: String=""
	for id: String in world.resources:
		var r: Dictionary=world.resources[id]
		if r["kind"]=="wood": selected=id; break
	var resource: Dictionary=world.resources[selected]
	actor.teleport(resource["p"]+Vector3(2,0.5,0))
	await physics_frame
	var got: Dictionary=store.gather(1,selected,actor.position,world,100)
	check(got["ok"],"server gathering grants materials: "+got["reason"])
	check(not store.gather(1,selected,actor.position,world,100.1)["ok"],"gather spam rejected")
	check(not store.gather(1,selected,actor.position+Vector3(100,0,0),world,101)["ok"],"remote gathering rejected")
	for t in [102.0,103.0]: store.gather(1,selected,actor.position,world,t)
	check(not store.gather(1,selected,actor.position,world,104)["ok"],"depleted node cannot duplicate rewards")
	check(store.craft(1,"planks",105)["ok"],"authoritative crafting")
	check(not store.craft(1,"free_gold",106)["ok"],"unknown recipe rejected")
	# Find a clear patch, then build a native 2x4 shelter from ten individual modules.
	var site: Vector3=Vector3.ZERO
	for z in range(50,230,4):
		if site!=Vector3.ZERO: break
		for x in range(-70,0,4):
			var p: Vector3=Vector3(x,world.height_at(Vector2(x,z))+0.5,z)
			var q: Vector3=p+Vector3(0,0,2)
			if Build.validate(world,[],"foundation_stone",p,0,"host",p)["ok"] and Build.validate(world,[],"foundation_stone",q,0,"host",q)["ok"]:
				site=p; break
	check(site!=Vector3.ZERO,"find valid construction land away from roads and water")
	var private_profile: Dictionary=store.profile(1)
	for kind: String in private_profile["inventory"]: private_profile["inventory"][kind]=1000 # test fixture, never a client API
	var parts: Array=[["foundation_stone",Vector3.ZERO,0],["foundation_stone",Vector3(0,0,2),0],["door_flat",Vector3(0,0,-1),0],["wall_plaster",Vector3(0,0,3),0],["wall_plaster",Vector3(-1,0,0),1],["window_wide",Vector3(1,0,0),1],["wall_plaster",Vector3(-1,0,2),1],["wall_plaster",Vector3(1,0,2),1],["roof_small",Vector3(0,3,1),0]]
	var now: float=110
	for part: Array in parts:
		var result: Dictionary=store.place(1,part[0],site+part[1],part[2],site+part[1]+Vector3(3,0,0),world,now)
		check(result["ok"],"place "+part[0]+": "+result["reason"]); now+=1
	check("First Shelter" in private_profile["achievements"],"achievement derived from enclosed modular shelter")
	check(not store.place(1,"foundation_stone",site,0,site,world,130)["ok"],"overlapping component rejected")
	check(not store.place(1,"foundation_stone",site+Vector3(6,8,0),0,site,world,131)["ok"],"floating foundation rejected")
	check(not store.place(1,"foundation_stone",Vector3(NAN,0,0),0,site,world,132)["ok"],"NaN transform rejected")
	var town: Vector2=Geo.SETTLEMENTS[0]
	var reserved: Vector3=Vector3(town.x,world.height_at(town)+0.5,town.y)
	check(not store.place(1,"foundation_stone",reserved,0,reserved,world,133)["ok"],"settlement and road placement rejected")
	# A longer roof spans its own six bays, permitting more than one prefab footprint.
	var long_records: Array=[]
	var long_site: Vector3=site+Vector3(20,0,0)
	long_site.y=world.height_at(Vector2(long_site.x,long_site.z))+1
	for x in range(2):
		for z in range(3): long_records.append({"id":str(x)+str(z),"module_id":"foundation_stone","position":[long_site.x+x*2,long_site.y,long_site.z+z*2],"rotation":0,"owner_id":"host","building_id":"long"})
	for offset: Vector3 in [Vector3(0,0,-1),Vector3(2,0,-1),Vector3(0,0,5),Vector3(2,0,5)]:
		var p: Vector3=long_site+offset
		long_records.append({"id":str(offset),"module_id":"wall_plaster","position":[p.x,p.y,p.z],"rotation":0,"owner_id":"host","building_id":"long"})
	var roof: Vector3=long_site+Vector3(1,3,2)
	var long_result: Dictionary=Build.validate(world,long_records,"roof_long",roof,0,"host",roof,false)
	check(long_result["ok"],"4x6 roof supports a distinct six-bay arrangement: "+long_result["reason"])
	var identity: Dictionary=store.enter(2)
	var stable_id: String=identity["id"]
	store.leave(2); check(store.enter(3,identity["token"])["id"]==stable_id,"server-issued credential resumes stable owner")
	check(store.enter(4,identity["token"]).is_empty(),"duplicate active identity rejected")
	check(not store.public_delta().has("profiles"),"private identities and inventories absent from broadcast")
	check(not Build.validate(world,store.data["structures"],"foundation_stone",site+Vector3(2,0,0),0,stable_id,site,false)["ok"],"another owner cannot attach to an occupied property")
	for region: Vector2 in Geo.CENTERS: store.tick(1,Vector3(region.x,world.height_at(region)+1,region.y),0,0.1,world)
	check("World Traveler" in private_profile["achievements"],"server derives region achievement")
	store.directory="user://qa_openworld_"+str(Time.get_ticks_msec())
	check(store.save(session.state),"atomic versioned persistence write")
	var restored: RefCounted=Store.new(); restored.directory=store.directory
	check(restored.load_world(73129),"reload modular placement data")
	var same: bool=restored.data["structures"].size()==store.data["structures"].size()
	for i in range(store.data["structures"].size()):
		var a: Dictionary=store.data["structures"][i]; var b: Dictionary=restored.data["structures"][i]
		for key: String in ["id","module_id","owner_id","building_id","rotation","created_at","state"]: same=same and a[key]==b[key]
		same=same and Build.position(a).is_equal_approx(Build.position(b))
	check(same,"component IDs, ownership, transforms and timestamps survive reload")
	check(restored.data["profiles"]["host"]["inventory"]==private_profile["inventory"],"inventory survives reload")
	world.apply_delta(restored.public_delta())
	check(world.placed_nodes.size()==parts.size(),"reconstruct native components from saved records")
	print("WORLD_CHECK_COMPLETE failures=",failures," resources=",world.resources.size())
	session.stop(false); quit(1 if failures else 0)
