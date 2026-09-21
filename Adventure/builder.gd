extends Node3D
const Modules := preload("res://Adventure/modules.gd")
const Build := preload("res://Adventure/construction.gd")
var session: Node3D
var enabled: bool=false
var index: int=0
var turn: int=0
var storey: int=0
var ghost: Node3D
var candidate: Vector3
var valid: bool=false
var removal_id: String=""
var removal_armed: bool=false
var _last_module: String=""
var _tint: StandardMaterial3D

func key(code: int) -> bool:
	if code==KEY_B:
		enabled=not enabled
		if not enabled: session.build_hint=""
		return true
	if not enabled: return false
	if code==KEY_DELETE:
		removal_armed=not removal_armed; removal_id=""; return true
	if code==KEY_X: index=(index+1)%Modules.catalog().size()
	elif code==KEY_Z: index=posmod(index-1,Modules.catalog().size())
	elif code==KEY_T or code==KEY_R: turn=(turn+1)%4
	elif code==KEY_PAGEUP: storey=mini(3,storey+1)
	elif code==KEY_PAGEDOWN: storey=maxi(0,storey-1)
	elif code==KEY_F and valid: session.place(Modules.catalog().keys()[index],candidate,turn)
	else: return false
	return true

func update(camera: Camera3D, blocked: bool) -> void:
	if ghost!=null: ghost.visible=enabled and session.running and not blocked
	if not enabled or not session.running or blocked:
		if not enabled and session.running:
			for placed: Node3D in session.world.placed_nodes.values(): _highlight(placed,false)
		return
	var actor: CharacterBody3D=session.local_player()
	if actor==null: return
	if removal_armed:
		if ghost!=null: ghost.hide()
		valid=false
		var center_ray: Vector2=camera.get_viewport().get_visible_rect().size*0.5
		var start_ray: Vector3=camera.project_ray_origin(center_ray)
		var query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(start_ray,start_ray+camera.project_ray_normal(center_ray)*20,4)
		var result_hit: Dictionary=session.world.get_world_3d().direct_space_state.intersect_ray(query)
		removal_id=""
		if not result_hit.is_empty():
			for key_id: String in session.world.placed_nodes:
				if session.world.placed_nodes[key_id].is_ancestor_of(result_hit.collider): removal_id=key_id; break
		for key_id: String in session.world.placed_nodes:
			_highlight(session.world.placed_nodes[key_id],key_id==removal_id)
		session.build_hint="Disassemble: aim at an owned piece · Left click to review · Delete back"
		return
	for placed: Node3D in session.world.placed_nodes.values(): _highlight(placed,false)
	var id: String=Modules.catalog().keys()[index]
	if id!=_last_module:
		if ghost!=null: ghost.queue_free()
		ghost=Modules.visual(id); add_child(ghost)
		_tint=StandardMaterial3D.new(); _tint.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		_tint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		_tint.no_depth_test=false
		_paint(ghost); _last_module=id
	var center: Vector2=camera.get_viewport().get_visible_rect().size*0.5
	var start: Vector3=camera.project_ray_origin(center)
	var ray: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(start,start+camera.project_ray_normal(center)*22,5)
	var hit: Dictionary=session.world.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		valid=false; ghost.hide(); session.build_hint="Aim at ground or a building within 10 m · Right click catalog"; return
	ghost.show()
	candidate=Build.snap(id,hit.position,turn)
	var kind: String=Modules.definition(id)["kind"]
	var base: float=session.world.height_at(Vector2(candidate.x,candidate.z))+0.25
	var nearest: float=8
	var records: Array=session.state.get("world_delta",{}).get("structures",[])
	for record: Dictionary in records:
		if Modules.definition(record["module_id"])["kind"] not in ["foundation","floor"]: continue
		if Modules.definition(record["module_id"])["kind"]=="floor" and Build.position(record).y-session.world.height_at(Vector2(record.position[0],record.position[2]))>1.5: continue
		var q: Vector3=Build.position(record)
		var d: float=Vector2(q.x,q.z).distance_to(Vector2(candidate.x,candidate.z))
		if d<nearest: nearest=d; base=q.y
	if kind in ["foundation","floor"] and nearest==8:
		if kind=="foundation": base=maxf(base,session.world.geography.water_height(Vector2(candidate.x,candidate.z))+.25)
		for offset: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			base=maxf(base,session.world.height_at(Vector2(candidate.x,candidate.z)+offset)+0.1)
	if kind!="foundation" and nearest<8:
		storey=clampi(roundi((float(hit.position.y)-base)/3.0),0,3)
	candidate.y=base+storey*3
	if kind=="decoration": candidate=hit.position
	if kind in ["roof","roof_panel","roof_trim","chimney"]: candidate.y=base+maxf(3,snappedf(hit.position.y-base,3))
	if kind=="fence" and nearest==8: candidate.y-=0.25
	var snapped_connection: bool=false
	if not Input.is_physical_key_pressed(KEY_SHIFT):
		var connection: Dictionary=Build.connector_candidate(records,id,hit.position,turn)
		if not connection.is_empty():
			candidate=connection.position; turn=connection.turn; snapped_connection=true
	var result: Dictionary=Build.validate(session.world,records,id,candidate,turn,session.local_profile.get("id",""),actor.position)
	valid=result["ok"] and preload("res://Adventure/world_store.gd").afford(session.local_profile,Modules.definition(id)["cost"])
	ghost.position=candidate; ghost.rotation.y=turn*PI/2
	if kind=="foundation" or (kind=="floor" and candidate.y-session.world.height_at(Vector2(candidate.x,candidate.z))<=1.5): Modules.update_foundation_supports(ghost,session.world); _paint(ghost)
	_tint.albedo_color=(Color(0.2,0.9,0.85,0.45) if snapped_connection else Color(0.35,1,0.5,0.45)) if valid else Color(1,0.25,0.2,0.45)
	session.build_hint=Modules.definition(id)["label"]+" · level "+str(storey+1)+"\n"+cost_text(Modules.definition(id)["cost"])+"\n"+(result["reason"] if not result["ok"] else ("Left click place" if valid else "Gather more materials"))+"\nR rotate · Shift free grid · Wheel piece · RMB catalog · C clear grass · V flatten · Delete remove · B exit"

func _paint(node: Node) -> void:
	if node is CollisionObject3D: node.collision_layer=0; node.collision_mask=0
	if node is MeshInstance3D: node.material_override=_tint; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children(): _paint(child)

func _highlight(node: Node, active: bool) -> void:
	if node.get_meta("removal_highlight",false)==active: return
	node.set_meta("removal_highlight",active)
	if node is MeshInstance3D:
		if active:
			var material: StandardMaterial3D=StandardMaterial3D.new(); material.albedo_color=Color(1,0.5,0.12,0.35); material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			node.material_overlay=material
		else: node.material_overlay=null
	for child: Node in node.get_children(): _highlight(child,active)

func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray=[]
	for resource: String in cost: parts.append(resource.capitalize()+" "+str(cost[resource]))
	return " · ".join(parts)
