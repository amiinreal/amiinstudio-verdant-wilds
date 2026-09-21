extends RefCounted
## A single watershed and continuous mainland; regions are overlapping ecological fields.
const SIZE: float = 1024.0
const RES: int = 256
const CENTERS: Array[Vector2] = [Vector2(-95,155), Vector2(-225,-180), Vector2(25,120), Vector2(170,-280), Vector2(-270,-300), Vector2(160,160), Vector2(40,400)]
const NAMES: Array[String] = ["Aldermead Valley", "Whisperwood Forest", "Mirrorwater Basin", "Greycrown Mountains", "Elderwood Deep Forest", "Sunfold Hills", "Southshore Coast"]
static var RIVER: Array[Vector3] = [Vector3(-40,64,-390),Vector3(-55,52,-315),Vector3(-12,39,-220),Vector3(28,30,-140),Vector3(5,24,-70),Vector3(38,20,-10),Vector3(45,20,42),Vector3(45,12,44),Vector3(25,12,120),Vector3(60,9,200),Vector3(45,5,300),Vector3(75,-0.4,460)]
static var BROOK: Array[Vector3] = [Vector3(-275,57,-275),Vector3(-225,48,-220),Vector3(-175,42,-190),Vector3(-105,35,-160),Vector3(28,30,-140)]
static var STREAM: Array[Vector3] = [Vector3(245,39,-60),Vector3(195,30,-15),Vector3(150,22,20),Vector3(90,15,75),Vector3(25,12,120)]
const BRIDGES: Array[Dictionary] = [{"id":"bridge_alder", "p":Vector2(5,-70),"kind":"wood","width":5.0,"span":36.0,"height":26.8,"yaw":PI/2}, {"id":"bridge_south", "p":Vector2(51,260),"kind":"stone","width":7.0,"span":38.0,"height":10.3,"yaw":PI/2}, {"id":"bridge_ravine", "p":Vector2(-175,-190),"kind":"rope","width":3.0,"span":32.0,"height":49.0,"yaw":0.0}]
static var ROADS: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-95,155),Vector2(-140,70),Vector2(-115,-20),Vector2(-70,-70),Vector2(5,-70),Vector2(75,-70),Vector2(150,-85),Vector2(205,15),Vector2(180,110),Vector2(155,180),Vector2(110,260),Vector2(51,260),Vector2(-30,260),Vector2(-100,235),Vector2(-95,155)]), PackedVector2Array([Vector2(-115,-20),Vector2(-200,-90),Vector2(-225,-145),Vector2(-175,-165),Vector2(-175,-190),Vector2(-175,-220),Vector2(-235,-270),Vector2(-270,-300)]), PackedVector2Array([Vector2(150,-85),Vector2(105,-140),Vector2(100,-205),Vector2(140,-250),Vector2(170,-280)])]
static var TRAILS: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-200,-90),Vector2(-255,-65),Vector2(-270,-45),Vector2(-285,10),Vector2(-220,60),Vector2(-140,70)]),PackedVector2Array([Vector2(75,-70),Vector2(80,-15),Vector2(78,43),Vector2(100,85),Vector2(180,110)]),PackedVector2Array([Vector2(-235,-270),Vector2(-330,-220),Vector2(-300,-150),Vector2(-200,-90)]),PackedVector2Array([Vector2(-100,235),Vector2(-70,320),Vector2(40,400),Vector2(140,355),Vector2(110,260)])]
const SETTLEMENTS: Array[Vector2] = [Vector2(-95,155),Vector2(-200,-90),Vector2(155,180)]
const LANDMARKS: Array[Dictionary] = [{"id":"aldermead", "name":"Aldermead Village", "p":Vector2(-95,155),"kind":"settlement"}, {"id":"logging_camp","name":"Whisperwood Hamlet","p":Vector2(-200,-90),"kind":"settlement"}, {"id":"farmstead","name":"Sunfold Farmstead","p":Vector2(155,180),"kind":"settlement"}, {"id":"waterfall","name":"Silverveil Falls","p":Vector2(65,44),"kind":"landmark"}, {"id":"elder_tree","name":"The Elder Crown","p":Vector2(-270,-300),"kind":"landmark"}, {"id":"watchtower","name":"Greycrown Watch","p":Vector2(140,-250),"kind":"structure"}, {"id":"cave","name":"Hollowroot Cave","p":Vector2(-270,-45),"kind":"hidden"}, {"id":"ruins","name":"Mossbound Ruins","p":Vector2(-320,-220),"kind":"structure"}, {"id":"viewpoint","name":"Shepherd's Lookout","p":Vector2(180,75),"kind":"landmark"}, {"id":"grotto","name":"Fernlight Clearing","p":Vector2(-285,10),"kind":"hidden"}, {"id":"beach","name":"Shellwind Beach","p":Vector2(40,400),"kind":"landmark"}]
var noise: FastNoiseLite = FastNoiseLite.new()
var detail: FastNoiseLite = FastNoiseLite.new()
var heights: PackedFloat32Array = PackedFloat32Array()
var bridge_defs: Array = []

func generate(seed_value: int) -> void:
	if RIVER.size()==12:
		RIVER=_curve_channel(RIVER); BROOK=_curve_channel(BROOK); STREAM=_curve_channel(STREAM)
	bridge_defs = BRIDGES.duplicate(true)
	for roads: Array in [ROADS, TRAILS]:
		for road: PackedVector2Array in roads:
			for points: Array[Vector3] in [RIVER, BROOK, STREAM]:
				for i in range(road.size()-1):
					for j in range(points.size()-1):
						var hit: Variant = Geometry2D.segment_intersects_segment(road[i],road[i+1],Vector2(points[j].x,points[j].z),Vector2(points[j+1].x,points[j+1].z))
						if hit == null: continue
						var nearby: bool = false
						for bridge: Dictionary in bridge_defs:
							nearby = nearby or hit.distance_to(bridge["p"]) < 45
						if not nearby:
							var d: Vector2 = (road[i+1]-road[i]).normalized()
							bridge_defs.append({"id":"crossing_%d" % bridge_defs.size(),"p":hit,"kind":"wood","width":4.0,"span":34.0,"height":channel(hit,points).y+3,"yaw":atan2(d.x,d.y)})
	noise.seed = seed_value
	noise.frequency = 0.008
	noise.fractal_octaves = 3
	detail.seed = seed_value + 91
	detail.frequency = 0.035
	heights.resize((RES + 1) * (RES + 1))
	for z in range(RES + 1):
		for x in range(RES + 1):
			heights[z * (RES + 1) + x] = raw_height(Vector2(x, z) * 4 - Vector2.ONE * 512)
	_grade_routes()

static func _curve_channel(points: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	for i in range(points.size()-1):
		var a: Vector2=Vector2(points[i].x,points[i].z); var b: Vector2=Vector2(points[i+1].x,points[i+1].z)
		var pre: Vector2=Vector2(points[maxi(0,i-1)].x,points[maxi(0,i-1)].z)
		var post: Vector2=Vector2(points[mini(points.size()-1,i+2)].x,points[mini(points.size()-1,i+2)].z)
		var steps: int=clampi(ceili(a.distance_to(b)/18),1,8)
		for j in range(steps):
			var t: float=float(j)/steps
			var p: Vector2=a.cubic_interpolate(b,pre,post,t) if steps>1 else a
			result.append(Vector3(p.x,lerpf(points[i].y,points[i+1].y,t),p.y))
	result.append(points[-1]); return result

func _grade_routes() -> void:
	# Smooth longitudinal grades, then blend the narrow road cut into surrounding slopes.
	var profiles: Array=[]
	for routes: Array in [ROADS,TRAILS]:
		for route: PackedVector2Array in routes:
			var path: PackedVector2Array=[]; var levels: PackedFloat32Array=[]
			for i in range(route.size()-1):
				var count: int=ceili(route[i].distance_to(route[i+1])/4)
				for step in range(count): path.append(route[i].lerp(route[i+1],float(step)/count))
			path.append(route[-1])
			for p: Vector2 in path: levels.append(height_at(p))
			for iteration in range(16):
				for i in range(1,path.size()):
					var limit: float=path[i].distance_to(path[i-1])*0.40
					levels[i]=clampf(levels[i],levels[i-1]-limit,levels[i-1]+limit)
				for i in range(path.size()-2,-1,-1):
					var limit: float=path[i].distance_to(path[i+1])*0.40
					levels[i]=clampf(levels[i],levels[i+1]-limit,levels[i+1]+limit)
				for i in range(path.size()):
					for bridge: Dictionary in bridge_defs:
						var p: Vector2=(path[i]-bridge["p"]).rotated(bridge["yaw"])
						if absf(p.x)<5 and absf(p.y)<bridge["span"]/2+5: levels[i]=bridge["height"]-0.05
			profiles.append({"path":path,"levels":levels,"width":4.5 if routes==ROADS else 2.5})
	var graded: PackedFloat32Array=heights.duplicate()
	for z in range(RES+1):
		for x in range(RES+1):
			var p: Vector2=Vector2(x,z)*4-Vector2.ONE*512
			var inside_bridge: bool=false
			for bridge: Dictionary in bridge_defs:
				var local: Vector2=(p-bridge["p"]).rotated(bridge["yaw"])
				if absf(local.x)<14 and absf(local.y)<bridge["span"]/2-3: inside_bridge=true
			if inside_bridge or water_height(p)>height_at(p): continue
			var nearest: float=12; var level: float=heights[z*(RES+1)+x]; var width: float=4.5
			for profile: Dictionary in profiles:
				var line: Vector3=closest_line(p,profile["path"])
				if line.x<nearest:
					nearest=line.x; width=profile["width"]
					level=lerpf(profile["levels"][int(line.y)],profile["levels"][int(line.y)+1],line.z)
			graded[z*(RES+1)+x]=lerpf(level,heights[z*(RES+1)+x],smoothstep(width,12,nearest))
	heights=graded

static func closest_line(p: Vector2, points: PackedVector2Array) -> Vector3:
	var result: Vector3 = Vector3(100000, 0, 0)
	for i in range(points.size() - 1):
		var edge: Vector2 = points[i + 1] - points[i]
		var t: float = clampf((p - points[i]).dot(edge) / edge.length_squared(), 0, 1)
		var d: float = p.distance_to(points[i] + edge * t)
		if d < result.x:
			result = Vector3(d, i, t)
	return result

static func channel(p: Vector2, points: Array[Vector3]) -> Vector2:
	var result: Vector2 = Vector2(100000, 0)
	for i in range(points.size() - 1):
		var a: Vector2 = Vector2(points[i].x, points[i].z)
		var b: Vector2 = Vector2(points[i + 1].x, points[i + 1].z)
		var t: float = clampf((p - a).dot(b - a) / a.distance_squared_to(b), 0, 1)
		var d: float = p.distance_to(a.lerp(b, t))
		if d < result.x:
			result = Vector2(d, lerpf(points[i].y, points[i + 1].y, t))
	return result

func water_height(p: Vector2) -> float:
	if ((p - Vector2(25,120)) / Vector2(58,48)).length() < 1:
		return 12
	if p.distance_to(Vector2(190,160)) < 12:
		return 15
	for entry: Array in [[RIVER, 7.5], [BROOK, 3.5], [STREAM, 2.5]]:
		var sample: Vector2 = channel(p, entry[0])
		if sample.x < float(entry[1]):
			return sample.y
	return -0.4

func road_distance(p: Vector2, include_trails: bool = true) -> float:
	var d: float = 100000
	for road: PackedVector2Array in ROADS:
		d = minf(d, closest_line(p, road).x)
	if include_trails:
		for trail: PackedVector2Array in TRAILS:
			d = minf(d, closest_line(p, trail).x)
	return d

func base_height(p: Vector2) -> float:
	var h: float = 12 + (120 - p.y) * 0.042 + noise.get_noise_2dv(p) * 9
	h += 100 * exp(-pow((p.x - 165) / 115, 2) - pow((p.y + 300) / 130, 2))
	h += 45 * exp(-pow((p.x + 310) / 120, 2) - pow((p.y + 180) / 160, 2))
	h += 15 * exp(-pow((p.x - 220) / 115, 2) - pow(p.y / 200, 2))
	h += 34 * exp(-pow((p.x + 35) / 140, 2) - pow((p.y + 345) / 175, 2))
	return h

func raw_height(p: Vector2) -> float:
	var h: float = base_height(p) + detail.get_noise_2dv(p) * 1.1
	# Carve channels into their banks; each authored water profile is monotonically downhill.
	for entry: Array in [[RIVER, 7.5], [BROOK, 3.5], [STREAM, 2.5]]:
		var s: Vector2 = channel(p, entry[0])
		var w: float = entry[1]
		var bank: float = s.y + 3
		if entry[1] == 3.5 and p.distance_to(Vector2(-175,-190)) < 38:
			bank = s.y + 8
		var bed: float = lerpf(s.y - 2.5, bank, smoothstep(w * 0.6, w + 4, s.x))
		h = lerpf(bed, h, smoothstep(w + 4, w + 22, s.x))
	var lake: float = ((p - Vector2(25,120)) / Vector2(58,48)).length()
	var lake_angle: float=(p-Vector2(25,120)).angle()
	lake*=1+0.08*sin(lake_angle*3)+0.05*sin(lake_angle*5+1)
	h = lerpf(7, h, smoothstep(0.60, 0.92, lake))
	var pond: float = p.distance_to(Vector2(190,160))
	h = lerpf(12, h, smoothstep(9, 17, pond))
	# Settlements and clearings settle into the surrounding grade instead of square biome pads.
	for center: Vector2 in SETTLEMENTS:
		h = lerpf(base_height(center), h, smoothstep(23, 42, p.distance_to(center)))
	for mark: Dictionary in LANDMARKS:
		if mark["kind"] in ["hidden", "structure"]:
			h = lerpf(base_height(mark["p"]), h, smoothstep(8, 18, p.distance_to(mark["p"])))
	# Roads follow the existing terrain; only crossing approaches need an explicit grade.
	for bridge: Dictionary in bridge_defs:
		var delta: Vector2 = (p - bridge["p"]).rotated(bridge["yaw"])
		if absf(delta.x)<8 and absf(delta.y)<bridge["span"]/2-3:
			h=minf(h,bridge["height"]-1.2)
		if absf(delta.x) < 9 and absf(delta.y) < bridge["span"] / 2 + 25:
			var along: float = absf(delta.y)
			if along > bridge["span"] / 2 - 4:
				var mask: float = (1 - smoothstep(3, 9, absf(delta.x))) * (1 - smoothstep(bridge["span"] / 2, bridge["span"] / 2 + 25, along))
				h = lerpf(h, bridge["height"] - 0.05, mask)
	# Continuous coast; one small natural offshore rock island, not progression stages.
	var coast: float = p.length() + noise.get_noise_2dv(p * 1.3) * 20
	h = lerpf(h, -9, smoothstep(420, 485, coast))
	if p.y > 350:
		h = lerpf(h, -8, smoothstep(390, 475, p.y + noise.get_noise_2dv(p) * 18))
	var island: float = p.distance_to(Vector2(-225,455))
	if island < 28:
		h = maxf(h, lerpf(4, -8, smoothstep(10, 27, island)))
	return h

func height_at(p: Vector2) -> float:
	if heights.is_empty():
		return raw_height(p)
	var grid: Vector2 = (p + Vector2.ONE * 512) / 4
	var x: int = clampi(floori(grid.x), 0, RES - 1)
	var z: int = clampi(floori(grid.y), 0, RES - 1)
	var f: Vector2 = Vector2(clampf(grid.x - x,0,1), clampf(grid.y - z,0,1))
	var a: float = heights[z * (RES + 1) + x]
	var b: float = heights[z * (RES + 1) + x + 1]
	var c: float = heights[(z + 1) * (RES + 1) + x]
	var d: float = heights[(z + 1) * (RES + 1) + x + 1]
	return a + (b-a)*f.x + (c-a)*f.y if f.x + f.y <= 1 else d + (c-d)*(1-f.x) + (b-d)*(1-f.y)

func slope_at(p: Vector2) -> float:
	return Vector2(height_at(p + Vector2(2,0)) - height_at(p - Vector2(2,0)), height_at(p + Vector2(0,2)) - height_at(p - Vector2(0,2))).length() / 4

func forest_density(p: Vector2) -> float:
	var west: float = 1 - smoothstep(-220, -55, p.x + noise.get_noise_2dv(p * 0.6) * 95)
	var north: float = 1 - smoothstep(-180, 60, p.y)
	var clusters: float = smoothstep(-0.45, 0.5, noise.get_noise_2dv(p * 3))
	var clearing: float = 1.0
	for mark: Dictionary in LANDMARKS:
		clearing *= smoothstep(10, 22, p.distance_to(mark["p"]))
	return clampf((0.12 + west * 0.65 + north * 0.2) * (0.2 + clusters * 0.9) * clearing, 0, 1)

func region(p: Vector2) -> int:
	if p.y > 350:
		return 6
	if height_at(p) > 63 and p.x > -70:
		return 3
	if p.x < -205 and p.y < -220:
		return 4
	if p.x < -130 and p.y < 55:
		return 1
	if p.distance_to(Vector2(25,120)) < 100:
		return 2
	if p.x > 90:
		return 5
	return 0

func reserved(p: Vector2, margin: float = 0.0) -> bool:
	if road_distance(p) < 6 + margin or water_height(p) > height_at(p) - 1.0:
		return true
	for mark: Dictionary in LANDMARKS:
		if p.distance_to(mark["p"]) < (30 if mark["kind"] == "settlement" else 12) + margin:
			return true
	for bridge: Dictionary in bridge_defs:
		if p.distance_to(bridge["p"]) < bridge["span"] * 0.65 + margin:
			return true
	return p.length() > 435
