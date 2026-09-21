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
var _last_module: String=""
var _tint: StandardMaterial3D

func key(code: int) -> bool:
	if code==KEY_B:
		enabled=not enabled
		if not enabled: session.build_hint=""
		return true
	if not enabled: return false
	if code==KEY_X: index=(index+1)%Modules.catalog().size()
	elif code==KEY_Z: index=posmod(index-1,Modules.catalog().size())
	elif code==KEY_T: turn=(turn+1)%4
	elif code==KEY_PAGEUP: storey=mini(3,storey+1)
	elif code==KEY_PAGEDOWN: storey=maxi(0,storey-1)
	elif code==KEY_F and valid: session.place(Modules.catalog().keys()[index],candidate,turn)
	else: return false
	return true

func update(yaw: float, blocked: bool) -> void:
	if ghost!=null: ghost.visible=enabled and session.running and not blocked
	if not enabled or not session.running or blocked: return
	var actor: CharacterBody3D=session.local_player()
	if actor==null: return
	var id: String=Modules.catalog().keys()[index]
	if id!=_last_module:
		if ghost!=null: ghost.queue_free()
		ghost=Modules.visual(id); add_child(ghost)
		_tint=StandardMaterial3D.new(); _tint.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		_tint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		_tint.no_depth_test=false
		_paint(ghost); _last_module=id
	var forward: Vector3=Basis(Vector3.UP,yaw)*Vector3(0,0,-1)
	candidate=Build.snap(id,actor.position+forward*4.5,turn)
	var kind: String=Modules.definition(id)["kind"]
	var base: float=session.world.height_at(Vector2(candidate.x,candidate.z))+0.25
	var nearest: float=8
	var records: Array=session.state.get("world_delta",{}).get("structures",[])
	for record: Dictionary in records:
		if Modules.definition(record["module_id"])["kind"]!="foundation": continue
		var q: Vector3=Build.position(record)
		var d: float=Vector2(q.x,q.z).distance_to(Vector2(candidate.x,candidate.z))
		if d<nearest: nearest=d; base=q.y
	if kind=="foundation" and nearest==8:
		for offset: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			base=maxf(base,session.world.height_at(Vector2(candidate.x,candidate.z)+offset)+0.1)
	candidate.y=base+storey*3
	if kind in ["roof","roof_trim","chimney"]: candidate.y+=3
	if kind=="fence" and nearest==8: candidate.y-=0.25
	var result: Dictionary=Build.validate(session.world,records,id,candidate,turn,session.local_profile.get("id",""),actor.position)
	valid=result["ok"] and preload("res://Adventure/world_store.gd").afford(session.local_profile,Modules.definition(id)["cost"])
	ghost.position=candidate; ghost.rotation.y=turn*PI/2
	_tint.albedo_color=Color(0.35,1,0.5,0.45) if valid else Color(1,0.25,0.2,0.45)
	session.build_hint=Modules.definition(id)["label"]+" · level "+str(storey+1)+"\n"+str(Modules.definition(id)["cost"])+"\n"+(result["reason"] if not result["ok"] else ("F place" if valid else "Gather more materials"))+"\nZ / X piece · T rotate · PgUp / PgDn level · B exit"

func _paint(node: Node) -> void:
	if node is MeshInstance3D: node.material_override=_tint; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children(): _paint(child)
