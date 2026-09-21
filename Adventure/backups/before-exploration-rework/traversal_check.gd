extends SceneTree
const Session := preload("res://Adventure/session.gd")
var failures: int=0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session: Node3D=Node3D.new(); session.set_script(Session); session.name="Session"; root.add_child(session)
	session.save_enabled=false; session.start_solo(73129,"Walker"); session.set_physics_process(false)
	await physics_frame; await physics_frame
	var actor: CharacterBody3D=session.players[1]
	for bridge: Dictionary in session.world.geography.bridge_defs:
		for direction: float in [-1,1]:
			var axis: Vector2=Vector2(0,direction).rotated(-bridge["yaw"])
			var start: Vector2=bridge["p"]-axis*(bridge["span"]/2+3)
			actor.teleport(Vector3(start.x,session.world.height_at(start)+0.1,start.y))
			actor.move_input=axis
			for step in range(450):
				actor.simulate(1.0/60)
				if step%60==0: await physics_frame
				if (Vector2(actor.position.x,actor.position.z)-bridge["p"]).dot(axis)>bridge["span"]/2+1: break
			var progress: float=(Vector2(actor.position.x,actor.position.z)-bridge["p"]).dot(axis)
			var ok: bool=progress>bridge["span"]/2
			print("PASS " if ok else "FAIL ","walk bridge ",bridge["id"]," direction=",direction," progress=",progress)
			if not ok: failures+=1
			if not ok and actor.get_slide_collision_count()>0:
				var hit: KinematicCollision3D=actor.get_slide_collision(0)
				print("BLOCKED_AT ",actor.position," by ",hit.get_collider()," normal=",hit.get_normal())
	# The native doorway remains a real opening in its mesh collision, rather than a solid box.
	var town: Vector2=Vector2(-108,142)
	var h: float=session.world.height_at(town)
	var query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(Vector3(town.x-1,h+1,town.y+4),Vector3(town.x-1,h+1,town.y),4)
	var hit: Dictionary=session.world.get_world_3d().direct_space_state.intersect_ray(query)
	print("DOOR_RAY ",hit)
	print("TRAVERSAL_CHECK_COMPLETE failures=",failures)
	session.stop(false); quit(1 if failures else 0)
