extends SceneTree
var failures: int=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	print("PASS " if ok else "FAIL ",text)
	if not ok: failures+=1
func run() -> void:
	var game: Node3D=load("res://Adventure/main.tscn").instantiate(); root.add_child(game)
	root.size=Vector2i(1280,800)
	await create_timer(1.5).timeout
	var intro: CanvasLayer=null
	for child: Node in game.get_children():
		if child is CanvasLayer and child.get_script()==preload("res://Adventure/intro.gd"): intro=child
	check(intro!=null,"studio intro is present at startup")
	check(ResourceLoader.exists("res://Adventure/generated/amiin_studio_intro.png"),"Blender logo render is available to the intro")
	check(game.hud.page=="Welcome" and game.hud.menu_open,"title menu remains ready behind intro")
	if intro!=null:
		var key: InputEventKey=InputEventKey.new(); key.pressed=true; key.keycode=KEY_ENTER
		intro._unhandled_input(key)
		await create_timer(.5).timeout
		check(not is_instance_valid(intro),"intro skips cleanly to title menu")
	if DisplayServer.get_name()!="headless":
		var game2: Node3D=load("res://Adventure/main.tscn").instantiate(); root.add_child(game2)
		await create_timer(1.4).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Adventure/qa/intro-ui.png")
		game2.queue_free()
	var panel_style: StyleBoxFlat=game.hud._panel.get_theme_stylebox("panel") as StyleBoxFlat
	check(panel_style!=null and panel_style.bg_color.get_luminance()<0.10,"title UI uses the refreshed dark woodland panel style")
	print("INTRO_UI_CHECK_COMPLETE failures=",failures)
	game.queue_free(); quit(failures)
