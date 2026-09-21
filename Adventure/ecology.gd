extends RefCounted
## Deterministic ecological fields and clustered composition; no unrestricted random scatter.
const Geo := preload("res://Adventure/geography.gd")
const BUILD_CLEARINGS: Array[Vector2]=[Vector2(-64,190),Vector2(-180,40),Vector2(115,115),Vector2(-248,-114),Vector2(120,230)]
var rng: RandomNumberGenerator=RandomNumberGenerator.new()
var wet_cache: Dictionary={}
var world: Node3D
var counts: Dictionary={}

func generate(value: Node3D) -> void:
	world=value; rng.seed=world.seed_value+90177; wet_cache.clear(); counts.clear()
	_trees(); _ground_patches(); _rock_groups(); _special_details()
	print("ECOLOGY_COUNTS ",counts)

func wetness(p: Vector2) -> float:
	var cell: Vector2i=Vector2i(floori(p.x/8),floori(p.y/8))
	if wet_cache.has(cell): return wet_cache[cell]
	var center: Vector2=Vector2(cell)*8+Vector2.ONE*4
	var distance: float=1000
	for line: Array[Vector3] in [Geo.RIVER,Geo.BROOK,Geo.STREAM]: distance=minf(distance,Geo.channel(center,line).x)
	distance=minf(distance,absf(((center-Vector2(25,120))/Vector2(58,48)).length()-0.86)*48)
	distance=minf(distance,absf(center.distance_to(Vector2(190,160))-12))
	var moisture: float=1-smoothstep(6,28,distance)
	wet_cache[cell]=moisture; return moisture

func clearing(p: Vector2) -> float:
	var density: float=1
	for center: Vector2 in BUILD_CLEARINGS: density*=smoothstep(12,27,p.distance_to(center))
	for town: Vector2 in Geo.SETTLEMENTS: density*=smoothstep(26,40,p.distance_to(town))
	return density

func valid(p: Vector2,road_margin: float=1.7,slope: float=0.8) -> bool:
	var h: float=world.height_at(p)
	return p.length()<438 and h>world.geography.water_height(p)+0.65 and h<125 and world.geography.slope_at(p)<slope and world.geography.road_distance(p)>road_margin and not world._crossing_clearance(p)

func add(asset: String,p: Vector2,size_value: float=1.0,resource_id: String="",kind: String="",charges: int=0,amount: int=0) -> void:
	if not kind.is_empty(): world.resource(resource_id,kind,p,charges,amount)
	world._queue_resource(asset,p,size_value,rng.randf()*TAU,resource_id)
	counts[asset]=int(counts.get(asset,0))+1

func _trees() -> void:
	for z in range(-72,73):
		for x in range(-72,73):
			var p: Vector2=Vector2(x,z)*6+Vector2(rng.randf_range(-1.6,1.6),rng.randf_range(-1.6,1.6))
			if not valid(p,5,0.72) or clearing(p)<0.1: continue
			var h: float=world.height_at(p)
			var density: float=world.geography.forest_density(p)
			var cluster: float=smoothstep(-0.1,0.45,world.geography.detail.get_noise_2dv(p*0.27))
			var chance: float=clampf(density*1.75+cluster*0.14-0.12,0,0.88)*clearing(p)
			if rng.randf()>chance: continue
			var alpine: float=smoothstep(35,80,h)*0.8+smoothstep(-100,-300,p.y)*0.12
			var ancient: bool=p.distance_to(Vector2(-270,-290))<95 and density>0.35
			var asset: String="Pine_%d" % rng.randi_range(1,5) if rng.randf()<alpine else "CommonTree_%d" % rng.randi_range(1,5)
			if ancient and rng.randf()<0.09: asset="TwistedTree_%d" % rng.randi_range(1,5)
			elif (h>65 or density<0.25) and rng.randf()<0.025: asset="DeadTree_%d" % rng.randi_range(1,5)
			var id: String="wood_%d_%d" % [x,z] if ("CommonTree" in asset or "Pine" in asset) and rng.randf()<0.28 else ""
			if id.is_empty(): id="decor_tree_%d_%d" % [x,z]
			add(asset,p,rng.randf_range(0.85,1.20),id,"wood" if not id.is_empty() else "",3,4)
			# All trunks use simplified collision only while their server/client chunk is relevant.
			world._solid_resource(id if not id.is_empty() else "decor_tree_%d_%d" % [x,z],Vector3(p.x,h+1.5,p.y),0.36,3)
			if ancient and rng.randf()<0.08:
				for i in range(3): add("Mushroom_Laetiporus",p+Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1)),rng.randf_range(0.55,0.85))

func _ground_patches() -> void:
	for i in range(19000):
		if i%2000==0: preload("res://Adventure/loading_screen.gd").show_progress(55+float(i)/19000*16,"Growing meadow flowers and plants…")
		var center: Vector2=Vector2(rng.randf_range(-430,430),rng.randf_range(-420,425))
		if not valid(center,1.9,0.74): continue
		var density: float=world.geography.forest_density(center)
		var moisture: float=wetness(center)
		var patch: float=world.geography.detail.get_noise_2dv(center*0.48)
		if patch< -0.17: continue # quiet ground between composed patches
		var road: float=world.geography.road_distance(center)
		var village: bool=false
		for town: Vector2 in Geo.SETTLEMENTS:
			if center.distance_to(town)<38: village=true
		var grass: String="Grass_Common_Short"
		if density>0.35: grass="Grass_Wispy_Short" if rng.randf()<0.4 else "Grass_Common_Short"
		elif moisture>0.5: grass="Grass_Wispy_Tall" if rng.randf()<0.5 else "Grass_Common_Tall"
		elif patch>0.22 and road>8 and not village: grass="Grass_Common_Tall" if rng.randf()<0.6 else "Grass_Wispy_Tall"
		else: grass="Grass_Wispy_Short" if rng.randf()<0.18 else "Grass_Common_Short"
		if road<5 or village: grass="Grass_Common_Short"
		var blades: int=4 if density>0.55 else (8 if patch<0.2 else 14)
		for j in range(blades):
			var p: Vector2=center+Vector2(rng.randf_range(-3.2,3.2),rng.randf_range(-3.2,3.2))
			if not valid(p,2.2,0.8): continue
			add(grass,p,rng.randf_range(0.40,0.68) if "Tall" in grass else rng.randf_range(0.65,0.95))
		var chance: float=rng.randf()
		if chance<0.06 and density<0.40 and patch>0.12:
			var flower: int=3 if rng.randf()<0.5 else 4
			for j in range(4):
				var p: Vector2=center+Vector2(rng.randf_range(-2,2),rng.randf_range(-2,2))
				if valid(p): add("Flower_%d_Group" % flower,p,rng.randf_range(0.75,1.0))
			for j in range(5):
				var p: Vector2=center+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(2,4)
				if valid(p): add("Flower_%d_Single" % flower,p,rng.randf_range(0.70,1.0))
		elif chance<0.12 and (density>0.35 or moisture>0.6):
			for j in range(3):
				var p: Vector2=center+Vector2(rng.randf_range(-2,2),rng.randf_range(-2,2))
				if valid(p): add("Fern_1",p,rng.randf_range(0.7,1.0))
		elif chance<0.16 and density>0.4:
			for j in range(4): add("Mushroom_Common",center+Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1)),rng.randf_range(0.45,0.8))
		elif chance<0.22:
			var asset: String="Plant_1_Big" if i%2==0 else "Plant_7_Big"
			if moisture<0.4: asset="Plant_1" if i%2==0 else "Plant_7"
			var id: String="fiber_%d" % i if i%3==0 else ""
			add(asset,center,rng.randf_range(0.65,1),id,"fiber" if not id.is_empty() else "",2,3)
		elif chance<0.26 and patch>0:
			add("Bush_Common_Flowers" if density<0.35 and i%5==0 else "Bush_Common",center,rng.randf_range(0.7,1.05))
		elif chance<0.34 and density<0.5:
			for j in range(3): add("Clover_1" if i%2==0 else "Clover_2",center+Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1)),rng.randf_range(0.65,1))

func _rock_groups() -> void:
	for i in range(1300):
		var center: Vector2=Vector2(rng.randf_range(-420,420),rng.randf_range(-410,420))
		if not valid(center,4,1.15) or clearing(center)<0.3: continue
		var moisture: float=wetness(center); var h: float=world.height_at(center)
		if moisture<0.25 and h<38 and rng.randf()>0.18: continue
		for j in range(rng.randi_range(2,5)):
			var p: Vector2=center+Vector2(rng.randf_range(-2.8,2.8),rng.randf_range(-2.8,2.8))
			if not valid(p,3,1.2): continue
			var id: String="stone_%d_%d" % [i,j] if j==0 and i%2==0 else ""
			if id.is_empty(): id="decor_rock_%d_%d" % [i,j]
			add("Rock_Medium_%d" % rng.randi_range(1,3),p,rng.randf_range(0.65,1.1),id,"stone" if not id.is_empty() else "",3,3)
			world._solid_resource(id if not id.is_empty() else "decor_rock_%d_%d" % [i,j],Vector3(p.x,world.height_at(p)+0.45,p.y),0.65,0.9)
		for j in range(9):
			var p: Vector2=center+Vector2(rng.randf_range(-5,5),rng.randf_range(-5,5))
			if valid(p,1.5,1.2): add("Pebble_Round_%d" % rng.randi_range(1,5) if moisture>0.3 else "Pebble_Square_%d" % rng.randi_range(1,6),p,rng.randf_range(0.7,1.1))

func _special_details() -> void:
	for center: Vector2 in [Vector2(-270,-307),Vector2(-285,10),Vector2(180,75)]:
		for i in range(15):
			var p: Vector2=center+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(2,9)
			if valid(p): add("Petal_%d" % rng.randi_range(1,5),p,rng.randf_range(0.75,1))

func _meadow_carpet() -> void:
	# A separate deterministic stream preserves every existing harvestable resource ID.
	rng.seed=world.seed_value+772301
	for z in range(-235,236):
		for x in range(-235,236):
			var p: Vector2=Vector2(x,z)*1.8+Vector2(rng.randf_range(-0.6,0.6),rng.randf_range(-0.6,0.6))
			var patch: float=world.geography.detail.get_noise_2dv(p*0.7)
			if patch< -0.2 or not valid(p,2.8,0.62): continue
			var forest: float=world.geography.forest_density(p)
			var chance: float=0.86 if forest<0.35 else 0.35
			if world.height_at(p)>65: chance*=0.25
			if rng.randf()>chance: continue
			add("Grass_Common_Short" if rng.randf()<0.7 else "Grass_Wispy_Short",p,rng.randf_range(0.42,0.65))
