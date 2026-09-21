extends RefCounted
const Modules := preload("res://Adventure/modules.gd")

static func position(record: Dictionary) -> Vector3:
	var p: Array=record["position"]
	return Vector3(p[0],p[1],p[2])

static func snap(module: String, p: Vector3, turn: int) -> Vector3:
	var kind: String=Modules.definition(module).get("kind","")
	var offset: Vector2=Vector2.ZERO
	if kind in ["wall","door","window","fence","wall_decoration"]:
		offset=Vector2(0,1) if turn%2==0 else Vector2(1,0)
	elif kind in ["corner","support","roof_trim"]: offset=Vector2.ONE
	elif kind=="roof" or kind=="stairs":
		var size: Vector2i=Modules.definition(module)["footprint"]
		if turn%2==1: size=Vector2i(size.y,size.x)
		offset=Vector2((size.x-1)%2,(size.y-1)%2)
	return Vector3(snappedf(p.x-offset.x,2)+offset.x,p.y,snappedf(p.z-offset.y,2)+offset.y)

static func validate(world: Node3D, records: Array, module: String, proposed: Vector3, turn: int, owner: String, actor: Vector3, check_physics: bool=true) -> Dictionary:
	var def: Dictionary=Modules.definition(module)
	if def.is_empty() or not proposed.is_finite() or turn<0 or turn>3: return fail("Invalid component or rotation.")
	if actor.distance_to(proposed)>10: return fail("Move within 10 m of the placement.")
	var p: Vector3=snap(module,proposed,turn)
	var kind: String=def["kind"]
	var geo: RefCounted=world.geography
	var ground: float=world.height_at(Vector2(p.x,p.z))
	if p.y<ground-0.15 or p.y>ground+13: return fail("Placement must be above ground and below four storeys.")
	var cells: Array=Modules.cells(module,p,turn)
	for cell: Vector2i in cells:
		if geo.reserved(Vector2(cell)*2,1.5): return fail("Keep roads, water and landmarks clear.")
		if kind!="foundation" and world.height_at(Vector2(cell)*2)>p.y+0.12: return fail("The component intersects rising terrain.")
	var building_id: String=""
	var support_count: int=0
	var floor_cells: Dictionary={}
	var lower_cells: Dictionary={}
	var walls: Array=[]
	var nearby: Array=[]
	for record: Dictionary in records:
		var q: Vector3=position(record)
		if q.distance_to(p)>15: continue
		nearby.append(record)
		var other: String=Modules.definition(record["module_id"])["kind"]
		if record["owner_id"]!=owner and q.distance_to(p)<4: return fail("Leave space around another traveler's property.")
		if record["owner_id"]!=owner: continue
		if other in ["foundation","floor"] and absf(q.y+3-p.y)<0.08:
			lower_cells[Vector2i(roundi(q.x/2),roundi(q.z/2))]=true
		if other in ["foundation","floor"] and absf(q.y-p.y)<0.08:
			floor_cells[Vector2i(roundi(q.x/2),roundi(q.z/2))]=true
			if Vector2(q.x,q.z).distance_to(Vector2(p.x,p.z))<2.9:
				support_count+=1; building_id=record["building_id"]
		if other in ["wall","door","window","support","corner"] and absf(q.y+3-p.y)<0.08:
			walls.append(record)
			if Vector2(q.x,q.z).distance_to(Vector2(p.x,p.z))<4.6: building_id=record["building_id"]
		var same_slot: bool=slot(kind)==slot(other) and q.distance_to(p)<0.12
		if same_slot:
			if slot(kind)!="edge" or int(record["rotation"])%2==turn%2: return fail("That connection is already occupied.")
		if kind=="roof" and other=="roof" and absf(q.y-p.y)<0.1:
			for cell: Vector2i in Modules.cells(record["module_id"],q,int(record["rotation"])):
				if cell in cells: return fail("Roof footprints overlap.")
	if kind=="foundation":
		for offset: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			var h: float=world.height_at(Vector2(p.x,p.z)+offset)
			if p.y-h<0.03 or p.y-h>1.5: return fail("Foundation legs must meet the ground (maximum 1.5 m).")
		# Neighbouring foundation bays share one exact floor elevation.
		for record: Dictionary in nearby:
			var q: Vector3=position(record)
			if Modules.definition(record["module_id"])["kind"]=="foundation" and Vector2(q.x,q.z).distance_to(Vector2(p.x,p.z))<2.1:
				if absf(q.y-p.y)>0.08: return fail("Snap to the neighbouring foundation's floor height.")
	elif kind in ["wall","door","window"]:
		var side: Vector3=Vector3(0,0,1) if turn%2==0 else Vector3(1,0,0)
		var supported: bool=false
		for q: Vector3 in [p+side,p-side]:
			if floor_cells.has(Vector2i(roundi(q.x/2),roundi(q.z/2))): supported=true
		if not supported: return fail("Wall sections snap to a floor edge.")
	elif kind in ["corner","support"]:
		if support_count==0: return fail("Posts need an adjacent floor bay.")
	elif kind=="roof":
		var bearing: int=0
		for cell: Vector2i in cells:
			if not lower_cells.has(cell): return fail("The roof must cover connected floor bays one storey below.")
			for wall: Dictionary in walls:
				var q: Vector3=position(wall)
				if Vector2(q.x,q.z).distance_to(Vector2(cell)*2)<1.5: bearing+=1
		if bearing<4: return fail("A roof needs at least four supporting wall edges or posts.")
	elif kind=="floor":
		for cell: Vector2i in cells:
			var supported: int=0
			for wall: Dictionary in walls:
				var q: Vector3=position(wall)
				if Vector2(q.x,q.z).distance_to(Vector2(cell)*2)<1.5: supported+=1
			if supported<2: return fail("Each upper bay needs two wall edges or posts below it.")
	elif kind=="stairs":
		for cell: Vector2i in cells:
			if not floor_cells.has(cell): return fail("Stairs need three connected floor bays.")
	elif kind in ["roof_trim","chimney"]:
		var roof_support: bool=false
		for record: Dictionary in nearby:
			if Modules.definition(record["module_id"])["kind"]=="roof" and absf(position(record).y-p.y)<0.08 and position(record).distance_to(p)<4:
				roof_support=true; building_id=record["building_id"]
		if not roof_support: return fail("This detail needs a roof at the selected storey.")
	elif kind=="fence":
		if absf(p.y-ground)>0.3 and support_count==0: return fail("Fences need ground or a floor.")
	else:
		if support_count==0: return fail("This detail needs a floor at the selected storey.")
	if check_physics and kind=="foundation":
		var shape: BoxShape3D=BoxShape3D.new(); shape.size=Vector3(1.8,2.5,1.8)
		var query: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
		query.shape=shape; query.transform.origin=p+Vector3.UP*1.4; query.collision_mask=5
		if not world.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(): return fail("Clear the tree or obstacle before building here.")
	if check_physics and kind!="foundation":
		var box: BoxShape3D=BoxShape3D.new()
		var dimensions: Vector2i=def["footprint"]
		if turn%2==1: dimensions=Vector2i(dimensions.y,dimensions.x)
		var height: float=2.8 if kind in ["wall","window","door","roof","stairs","support","corner"] else 0.25
		box.size=Vector3(dimensions.x*1.8,height,dimensions.y*1.8)
		if slot(kind)=="edge": box.size=Vector3(1.8,height,0.18) if turn%2==0 else Vector3(0.18,height,1.8)
		var query: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
		query.shape=box; query.transform.origin=p+Vector3.UP*(height/2+0.14); query.collision_mask=1
		if not world.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(): return fail("The component intersects a natural obstacle.")
	return {"ok":true,"reason":"Ready to place","position":p,"rotation":turn,"building_id":building_id}

static func slot(kind: String) -> String:
	if kind in ["foundation","floor"]: return "floor"
	if kind in ["wall","door","window","fence"]: return "edge"
	if kind in ["corner","support"]: return "post"
	return kind

static func fail(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}

static func houses(records: Array, owner: String) -> Dictionary:
	# A valid shelter has enclosed ground-floor bays, an entrance and roof coverage.
	var groups: Dictionary={}
	for r: Dictionary in records:
		if r["owner_id"]!=owner: continue
		if not groups.has(r["building_id"]): groups[r["building_id"]]=[]
		groups[r["building_id"]].append(r)
	var complete: Dictionary={}
	for id: String in groups:
		var floors: Dictionary={}; var edges: Dictionary={}; var roofs: Dictionary={}; var door: bool=false
		var base: float=INF
		for r: Dictionary in groups[id]:
			if Modules.definition(r["module_id"])["kind"]=="foundation": base=minf(base,position(r).y)
		for r: Dictionary in groups[id]:
			var p: Vector3=position(r); var kind: String=Modules.definition(r["module_id"])["kind"]
			if kind=="foundation" and absf(p.y-base)<0.1: floors[Vector2i(roundi(p.x/2),roundi(p.z/2))]=true
			if kind in ["wall","window","door"] and absf(p.y-base)<0.1:
				edges[Vector2i(roundi(p.x),roundi(p.z))]=true
				if kind=="door": door=true
			if kind=="roof" and p.y>base+2.9:
				for cell: Vector2i in Modules.cells(r["module_id"],p,int(r["rotation"])): roofs[cell]=true
		var valid: bool=door and floors.size()>=2
		for cell: Vector2i in floors:
			if not roofs.has(cell): valid=false
			for dir: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if not floors.has(cell+dir) and not edges.has(cell*2+dir): valid=false
		if valid: complete[id]=floors.size()
	return complete
