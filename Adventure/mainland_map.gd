extends Control
const Geo := preload("res://Adventure/geography.gd")
var session: Node3D
func point(p: Vector2) -> Vector2:
	return (p+Vector2.ONE*512)/1024*Vector2(430,430)+Vector2(20,0)
func _draw() -> void:
	if session==null or session.world.map_texture==null: return
	draw_texture_rect(session.world.map_texture,Rect2(20,0,430,430),false)
	for route: PackedVector2Array in Geo.ROADS:
		var path: PackedVector2Array=[]
		for p: Vector2 in route: path.append(point(p))
		draw_polyline(path,Color("d2b073"),2,true)
	for route: PackedVector2Array in Geo.TRAILS:
		for i in range(route.size()-1): draw_dashed_line(point(route[i]),point(route[i+1]),Color("bfac85"),1,3)
	for river: Array in [Geo.RIVER,Geo.BROOK,Geo.STREAM]:
		var path: PackedVector2Array=[]
		for p: Vector3 in river: path.append(point(Vector2(p.x,p.z)))
		draw_polyline(path,Color("76b4c0"),2,true)
	for landmark: Dictionary in Geo.LANDMARKS:
		if landmark["kind"]=="hidden" and landmark["id"] not in session.local_profile.get("hidden",[]): continue
		var p: Vector2=point(landmark["p"])
		if landmark["kind"]=="settlement": draw_rect(Rect2(p-Vector2.ONE*3,Vector2.ONE*6),Color("ebe1c2"))
		else: draw_circle(p,2.5,Color("ebe1c2"))
	for bridge: Dictionary in session.world.geography.bridge_defs: draw_circle(point(bridge["p"]),2,Color("f1bd7d"))
	for record: Dictionary in session.state.get("world_delta",{}).get("structures",[]):
		draw_circle(point(Vector2(record["position"][0],record["position"][2])),1.5,Color("b8794d"))
	for id: int in session.players:
		var p: Vector3=session.players[id].position
		draw_circle(point(Vector2(p.x,p.z)),4,Color("ffe393") if id==session.local_id() else Color("79e0ec"))
	for position: Vector3 in session.world.cooking_stations:
		draw_circle(point(Vector2(position.x, position.z)), 3.0, Color("ff9c54"))
	if is_instance_valid(session.world.wildlife):
		for animal: Node3D in session.world.wildlife.get_children():
			if animal.health > 0: draw_circle(point(Vector2(animal.position.x, animal.position.z)), 2.0, Color("ade1c2"))
	draw_string(ThemeDB.fallback_font, Vector2(20, 452), "Orange: cooking fires   Green: animals", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("fff1ce"))
	for i in range(Geo.NAMES.size()):
		draw_string(ThemeDB.fallback_font,point(Geo.CENTERS[i])+Vector2(5,-7),Geo.NAMES[i].get_slice(" ",0),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("fff1ce"))
