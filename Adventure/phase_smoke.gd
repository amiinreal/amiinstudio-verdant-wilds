extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node3D=load("res://Adventure/main.tscn").instantiate(); root.add_child(game)
	game.session.save_enabled=false; game.session.start_solo(73129,"Smoke")
	await create_timer(0.5).timeout
	for page: String in ["Camp","Inventory","Crafting","Build","Map","Achievements","Players","Settings"]:
		game.hud.open_page(page); await process_frame
	game.hud.close_menu(); await create_timer(0.3).timeout
	var failures: int=0
	var inventory_key: InputEventKey=InputEventKey.new(); inventory_key.physical_keycode=KEY_E; inventory_key.pressed=true
	game._input(inventory_key)
	if game.hud.page!="Inventory" or not game.hud.menu_open: failures+=1
	game._input(inventory_key)
	if game.hud.menu_open: failures+=1
	for i in range(8):
		var key: InputEventKey=InputEventKey.new(); key.physical_keycode=KEY_1+i; key.pressed=true; game._unhandled_input(key)
		if game.hud.selected_slot!=i or game.hud._slots[i].icon==null: failures+=1
	game.hud.open_page("Build"); await process_frame
	var search: LineEdit=game.hud._body.find_children("*","LineEdit",true,false)[0]; search.grab_focus()
	var build_key: InputEventKey=InputEventKey.new(); build_key.physical_keycode=KEY_B; build_key.pressed=true; game._input(build_key)
	if not game.hud.menu_open: failures+=1
	print("UI_INPUT_CHECK failures=",failures)
	game.hud.close_menu()
	print("PHASE_SMOKE_COMPLETE players=",game.session.players.size()," music_state=",game.session.state.has("solved"))
	game.session.stop(false); quit(failures)
