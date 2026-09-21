extends RefCounted
## A 2 m panel uses four explicit corner heights, so every joint can be checked.
static func corners(id: String) -> Array[Vector3]:
	var heights: Array[float]=[1,1,0,0]
	if id=="roof_panel_steep": heights=[2,2,0,0]
	elif id=="roof_panel_flat": heights=[0,0,0,0]
	elif id=="roof_panel_corner": heights=[1,0,0,0]
	elif id=="roof_panel_valley": heights=[1,1,0,1]
	return [Vector3(-1,heights[0],-1),Vector3(1,heights[1],-1),Vector3(1,heights[2],1),Vector3(-1,heights[3],1)]

static func edges(id: String,p: Vector3,turn: int) -> Array:
	var points: Array[Vector3]=corners(id); var basis: Basis=Basis(Vector3.UP,turn*PI/2)
	var result: Array=[]
	for i in range(4): result.append([p+basis*points[i],p+basis*points[(i+1)%4]])
	return result

static func joins(a: Array,b: Array) -> bool:
	return (a[0].distance_to(b[1])<.06 and a[1].distance_to(b[0])<.06) or (a[0].distance_to(b[0])<.06 and a[1].distance_to(b[1])<.06)

static func visual(id: String) -> Node3D:
	var root: Node3D=Node3D.new(); var points: Array[Vector3]=corners(id)
	var surface: SurfaceTool=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Individual shingle strips provide readable seams without increasing the collision mesh complexity.
	for z in range(8):
		for x in range(6):
			var uv0: Vector2=Vector2(float(x)/6,float(z)/8)
			var uv1: Vector2=Vector2(float(x+1)/6,float(z+1)/8)
			var quad: Array[Vector2]=[uv0,Vector2(uv1.x,uv0.y),uv1,Vector2(uv0.x,uv1.y)]
			for index: int in [0,2,1,0,3,2]:
				var uv: Vector2=quad[index]
				var h: float
				if uv.x>uv.y: h=points[0].y+(points[1].y-points[0].y)*uv.x+(points[2].y-points[1].y)*uv.y
				else: h=points[0].y+(points[3].y-points[0].y)*uv.y+(points[2].y-points[3].y)*uv.x
				surface.set_color(Color("79563a").lightened(float((x*3+z*7)%5)*.045))
				surface.set_uv(uv); surface.add_vertex(Vector3(uv.x*2-1,h+.04+(.012 if index in [2,3] else 0),uv.y*2-1))
	# Fascia closes the visible thickness around all edges.
	for i in range(4):
		var a: Vector3=points[i]; var b: Vector3=points[(i+1)%4]
		for v: Vector3 in [a,b,a-Vector3.UP*.12,b,b-Vector3.UP*.12,a-Vector3.UP*.12]:
			surface.set_color(Color("463023")); surface.set_uv(Vector2(v.x,v.z)); surface.add_vertex(v)
	surface.generate_normals()
	var material: StandardMaterial3D=StandardMaterial3D.new(); material.vertex_color_use_as_albedo=true; material.vertex_color_is_srgb=true; material.cull_mode=BaseMaterial3D.CULL_DISABLED; material.roughness=.95
	var mesh: MeshInstance3D=MeshInstance3D.new(); mesh.mesh=surface.commit(); mesh.material_override=material; root.add_child(mesh)
	return root
