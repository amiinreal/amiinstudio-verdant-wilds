extends CanvasLayer
signal solo_requested(seed_value: int,nickname: String,resume: bool)
signal host_requested(seed_value: int,port: int,nickname: String)
signal join_requested(address: String,port: int,nickname: String)
signal leave_requested
signal build_requested(index: int)
const Items = preload("res://Adventure/items.gd")
const Branding = preload("res://Adventure/branding.gd")
const HOTBAR: Array[String]=["axe","pickaxe","hammer","wood","stone","fiber","planks","rope"]
var _controls: PanelContainer
var _slot_numbers: Array[Label]=[]
var _slot_counts: Array[Label]=[]
var _slot_background: StyleBoxFlat
var _slot_selected: StyleBoxFlat
const Modules := preload("res://Adventure/modules.gd")
var session: Node3D
var game: Node3D
var menu_open: bool=true
var selected_slot: int=0
var page: String="Welcome"
var _root: Control
var _panel: PanelContainer
var _body: VBoxContainer
var _hotbar: HBoxContainer
var _slots: Array[Button]=[]
var _prompt: Label
var _notice: Label
var _notice_time: float=0
var _context_timer: float=0
var _context: String=""
var _name: LineEdit
var _seed: LineEdit
var _address: LineEdit
var _port: LineEdit
var _map: Control
var _scrim: ColorRect
var hotbar_enabled: bool = true
var _food_bar: ProgressBar
var _health_bar: ProgressBar
var inventory_category: String = "All"
var inventory_item: String = ""
var _inventory_hash: int = 0

func _ready() -> void:
	var preferences: ConfigFile = ConfigFile.new()
	if preferences.load("user://inventory_ui.cfg") == OK: hotbar_enabled = bool(preferences.get_value("ui", "hotbar", true))
	_root=Control.new(); _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _root.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(_root)
	_scrim=ColorRect.new(); _scrim.color=Color(0.02,0.045,0.045,0.6); _scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _scrim.mouse_filter=Control.MOUSE_FILTER_IGNORE; _scrim.hide(); _root.add_child(_scrim)
	_panel=PanelContainer.new(); _panel.add_theme_stylebox_override("panel",style(Color(0.035,0.095,0.11,0.95),26)); _root.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER); _panel.offset_left=-400; _panel.offset_right=400; _panel.offset_top=-300; _panel.offset_bottom=300
	_body=VBoxContainer.new(); _body.add_theme_constant_override("separation",12); _panel.add_child(_body)
	_hotbar=HBoxContainer.new(); _hotbar.add_theme_constant_override("separation",5); _root.add_child(_hotbar)
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); _hotbar.offset_left=-274; _hotbar.offset_right=274; _hotbar.offset_top=-86; _hotbar.offset_bottom=-15
	_slot_background=style(Color(0.018,0.05,0.06,0.94),6)
	_slot_selected=style(Color(0.19,0.24,0.17,0.96),6); _slot_selected.border_color=Color("f3b45d"); _slot_selected.set_border_width_all(2)
	for i in range(8):
		var button: Button=Button.new(); button.custom_minimum_size=Vector2(64,68); button.focus_mode=Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal",style(Color(0.018,0.05,0.06,0.94),7)); button.add_theme_font_size_override("font_size",12)
		button.pressed.connect(func() -> void:
			selected_slot=i
			if session!=null: session.equip(["axe","pickaxe","hammer","hand","hand","hand","hand","hand"][i]))
		_hotbar.add_child(button); _slots.append(button)
		button.icon=Items.icon(HOTBAR[i]); button.expand_icon=true; button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER; button.add_theme_constant_override("icon_max_width",46); button.tooltip_text=HOTBAR[i].capitalize()
		var number: Label=label(str(i+1),11,Color("e6dcc3")); number.position=Vector2(6,2); number.mouse_filter=Control.MOUSE_FILTER_IGNORE; button.add_child(number); _slot_numbers.append(number)
		var count: Label=label("",11); count.position=Vector2(38,49); count.mouse_filter=Control.MOUSE_FILTER_IGNORE; button.add_child(count); _slot_counts.append(count)
	var health_row: HBoxContainer = HBoxContainer.new(); health_row.add_theme_constant_override("separation", 8); _root.add_child(health_row)
	health_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); health_row.offset_left=-274; health_row.offset_right=274; health_row.offset_top=-128; health_row.offset_bottom=-110
	health_row.add_child(label("HEALTH", 11, Color("e0a9a4")))
	_health_bar = ProgressBar.new(); _health_bar.custom_minimum_size = Vector2(180, 12); _health_bar.show_percentage = false; _health_bar.min_value = 0; _health_bar.max_value = 100
	_health_bar.add_theme_stylebox_override("background", style(Color(0.03, 0.06, 0.06, 0.9), 4))
	_health_bar.add_theme_stylebox_override("fill", style(Color(0.82, 0.28, 0.3, 0.95), 4))
	health_row.add_child(_health_bar)
	var food_row: HBoxContainer = HBoxContainer.new(); food_row.add_theme_constant_override("separation", 8); _root.add_child(food_row)
	food_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); food_row.offset_left=-274; food_row.offset_right=274; food_row.offset_top=-108; food_row.offset_bottom=-90
	food_row.add_child(label("FOOD", 11, Color("d9c9a0")))
	_food_bar = ProgressBar.new(); _food_bar.custom_minimum_size = Vector2(180, 12); _food_bar.show_percentage = false; _food_bar.min_value = 0; _food_bar.max_value = 100
	_food_bar.add_theme_stylebox_override("background", style(Color(0.03, 0.06, 0.06, 0.9), 4))
	var food_fill: StyleBoxFlat = style(Color(0.62, 0.78, 0.34, 0.95), 4); _food_bar.add_theme_stylebox_override("fill", food_fill)
	food_row.add_child(_food_bar)
	_prompt=label("",15,Color("eee5c5")); _root.add_child(_prompt); _prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); _prompt.offset_left=-400; _prompt.offset_right=400; _prompt.offset_top=-188; _prompt.offset_bottom=-98
	_prompt.add_theme_color_override("font_outline_color",Color("142524")); _prompt.add_theme_constant_override("outline_size",5)
	_notice=label("",16,Color("f5dca6")); _root.add_child(_notice); _notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); _notice.offset_left=-400; _notice.offset_right=400; _notice.offset_top=30; _notice.offset_bottom=65
	_notice.add_theme_color_override("font_outline_color",Color("142524")); _notice.add_theme_constant_override("outline_size",5)
	_controls=PanelContainer.new(); _controls.add_theme_stylebox_override("panel",style(Color(0.018,0.05,0.06,0.88),12)); _root.add_child(_controls)
	_controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT); _controls.offset_left=16; _controls.offset_right=220; _controls.offset_top=-345; _controls.offset_bottom=-100; _controls.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_controls.add_child(label("W A S D   Move\nMouse     Look\nSpace     Jump / surface\nShift     Run / swim faster\nLMB / Q   Use tool\nT         Pet / feed animal\n1–8       Select item\nE         Inventory\nB         Build catalog\nC         Clear grass\nV         Flatten land\nEsc       Menu",12,Color("dddacb")))
	_controls.hide(); _hotbar.hide(); _prompt.hide()

func style(color: Color,padding: int=12) -> StyleBoxFlat:
	var box: StyleBoxFlat=StyleBoxFlat.new(); box.bg_color=color; box.set_corner_radius_all(9)
	box.border_color=Color("456965"); box.set_border_width_all(1)
	box.content_margin_left=padding; box.content_margin_right=padding; box.content_margin_top=padding; box.content_margin_bottom=padding
	return box

func label(text: String,size: int=16,color: Color=Color("e4e8dc")) -> Label:
	var node: Label=Label.new(); node.text=text; node.add_theme_font_size_override("font_size",size); node.add_theme_color_override("font_color",color); return node

func button(text: String, action: Callable, parent: Container) -> Button:
	var node: Button=Button.new(); node.text=text; node.custom_minimum_size.y=40; node.focus_mode=Control.FOCUS_NONE
	node.add_theme_stylebox_override("normal",style(Color("17383c"),9)); node.add_theme_stylebox_override("hover",style(Color("28595a"),9)); node.add_theme_stylebox_override("pressed",style(Color("d5833f"),9)); node.pressed.connect(action); parent.add_child(node); return node

func field(text: String,value: String,parent: Container) -> LineEdit:
	parent.add_child(label(text,12,Color("adc4b5"))); var edit: LineEdit=LineEdit.new(); edit.text=value; edit.custom_minimum_size.y=34; parent.add_child(edit); return edit

func bind_session(value: Node3D) -> void:
	session=value; open_page("Welcome")
	session.account_service.changed.connect(func() -> void:
		if menu_open and page == "Welcome": open_page("Welcome"))

func started() -> void:
	close_menu(); _hotbar.visible = hotbar_enabled; show_message("WASD move · Mouse look · Shift run · E/I inventory · H hotbar · Esc menu",8)

func stopped() -> void:
	_controls.hide(); _hotbar.hide(); _prompt.hide(); open_page("Welcome")

func blocks_movement() -> bool: return menu_open
func toggle_menu() -> void:
	if session==null or not session.running: return
	if menu_open: close_menu()
	else: open_page("Camp")
func close_menu() -> void:
	menu_open=false; _panel.hide(); _scrim.hide(); Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	_hotbar.visible = session != null and session.running and hotbar_enabled

func set_hotbar_visible(value: bool) -> void:
	hotbar_enabled = value
	_hotbar.visible = value and not menu_open and session.running
	var preferences: ConfigFile = ConfigFile.new()
	preferences.set_value("ui", "hotbar", value)
	preferences.save("user://inventory_ui.cfg")
func show_message(text: String,duration: float=4) -> void:
	_notice.text=text; _notice_time=duration

func open_page(value: String) -> void:
	page=value; menu_open=true; _panel.show(); _scrim.show(); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	_hotbar.hide()
	for child: Node in _body.get_children(): _body.remove_child(child); child.queue_free()
	_map=null
	var heading: HBoxContainer=HBoxContainer.new(); _body.add_child(heading)
	if page=="Welcome":
		var lockup: HBoxContainer=Branding.build_horizontal_lockup(40,30); lockup.size_flags_horizontal=Control.SIZE_EXPAND_FILL; heading.add_child(lockup)
	else:
		var title: Label=label(page.to_upper(),30,Color("f2e5c8")); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; heading.add_child(title)
	if page!="Welcome": button("Continue  [Esc]",close_menu,heading)
	if page=="Welcome": _welcome(); return
	if page=="Camp":
		_body.add_child(label("A home to return to. A world to discover.",15,Color("a9c5b9")))
		var grid: GridContainer=GridContainer.new(); grid.columns=3; grid.add_theme_constant_override("h_separation",10); grid.add_theme_constant_override("v_separation",10); _body.add_child(grid)
		for destination: String in ["Inventory","Crafting","Build","Map","Achievements","Players","Settings"]:
			var target: String=destination; var item: Button=button(target,func() -> void: open_page(target),grid); item.custom_minimum_size=Vector2(240,72)
		button("Leave world",func() -> void: leave_requested.emit(),_body)
		return
	var navigation: HBoxContainer=HBoxContainer.new(); _body.add_child(navigation)
	for destination: String in ["Inventory","Crafting","Build","Map","Achievements","Players","Settings"]:
		var target: String=destination; var item: Button=button(target,func() -> void: open_page(target),navigation); item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if page=="Map":
		_map=Control.new(); _map.set_script(preload("res://Adventure/mainland_map.gd")); _map.session=session; _map.custom_minimum_size=Vector2(470,430); _body.add_child(_map); return
	var scroll: ScrollContainer=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; _body.add_child(scroll)
	var content: VBoxContainer=VBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",10); scroll.add_child(content)
	var profile: Dictionary=session.local_profile
	if page=="Inventory":
		_inventory(content)
	elif page=="Crafting":
		content.add_child(label("Choose a recipe. Crafting takes time; move away to cancel.",14,Color("adc4b5")))
		content.add_child(label("Cooking: stand beside a village cooking fire, or build one from Crafting in the build catalog.", 14))
		for recipe: String in preload("res://Adventure/items.gd").recipes():
			var id: String=recipe
			var data: Resource=preload("res://Adventure/items.gd").recipes()[id].data
			button(("Cook " if data.required_station == "cooking_fire" else "Craft ")+data.display_name+" · "+str(data.ingredients)+" · "+str(data.craft_time)+" s"+(" · needs cooking fire" if data.required_station == "cooking_fire" else ""),func() -> void: session.craft(id); close_menu(),content)

	elif page=="Build":
		var catalog: VBoxContainer=VBoxContainer.new(); catalog.set_script(preload("res://Adventure/build_catalog.gd")); content.add_child(catalog); catalog.setup(self)
	elif page=="Achievements":
		content.add_child(label("YOUR JOURNEY",19,Color("d9c78e")))
		var stats: Dictionary=profile.get("stats",{})
		for id: String in stats:
			var value_text: String="%d min" % int(float(stats[id])/60) if id=="playtime" else str(snappedf(float(stats[id]),0.1))
			content.add_child(label(id.replace("_"," ").capitalize()+"     "+value_text,15))
		content.add_child(label("MILESTONES",19,Color("d9c78e")))
		for id: String in ["First Steps","Lumberjack","Stoneworker","First Shelter","Homesteader","Builder","Master Builder","Forest Wanderer","Explorer","World Traveler","Architect"]:
			content.add_child(label(("✓  " if id in profile.get("achievements",[]) else "○  ")+id,17))
	elif page=="Players":
		if not session.invite_code.is_empty():
			button("Copy invite code · " + session.invite_code, func() -> void: DisplayServer.clipboard_set(session.invite_code); show_message("Invite code copied"), content)
		content.add_child(label("%d / 6 explorers  ·  %s" % [session.players.size(),session.status],18))
		for id: int in session.players: content.add_child(label(session.players[id].nickname+("  (you)" if id==session.local_id() else ""),19))
	elif page=="Settings":
		content.add_child(label("Peaceful music (0 = mute)",18))
		var music_slider: HSlider=HSlider.new(); music_slider.min_value=0; music_slider.max_value=1; music_slider.step=.05; music_slider.value=game.music.level
		music_slider.value_changed.connect(func(v: float) -> void: game.music.set_level(v)); content.add_child(music_slider)
		content.add_child(label("Mouse sensitivity",18))
		var slider: HSlider=HSlider.new(); slider.min_value=0.001; slider.max_value=0.006; slider.step=0.0001; slider.value=game.sensitivity; slider.value_changed.connect(func(v: float) -> void: game.sensitivity=v); content.add_child(slider)
		content.add_child(label("Camera field of view",18))
		var fov: HSlider=HSlider.new(); fov.min_value=55; fov.max_value=90; fov.value=game.camera.fov; fov.value_changed.connect(func(v: float) -> void: game.camera.fov=v); content.add_child(fov)
		content.add_child(label("WASD move · Shift sprint · Space jump · E inventory\n1–8 hotbar · LMB/Q use tool · B build · M map\nThe multiplayer world keeps running while menus are open.",15,Color("adc4b5")))

func _welcome() -> void:
	if not session.account_service.account.is_empty() or session.account_service.build_version != "dev" or not OS.has_feature("editor"):
		_online_welcome(); return
	_body.add_child(label("Forge a home from the wild. Gather, craft, build, and explore together.",17,Color("b7d0bd")))
	_body.add_child(label("A survival-building adventure from Amiin Studio",13,Color("d9a66c")))
	_name=field("EXPLORER NAME","Traveler",_body)
	var row: HBoxContainer=HBoxContainer.new(); _body.add_child(row)
	var a: VBoxContainer=VBoxContainer.new(); a.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(a)
	var b: VBoxContainer=VBoxContainer.new(); b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(b)
	_seed=field("WORLD SEED","73129",a); _port=field("UDP PORT","27840",b)
	var choices: HBoxContainer=HBoxContainer.new(); _body.add_child(choices)
	button("Play solo",func() -> void: if _valid(): solo_requested.emit(int(_seed.text),_name.text,false),choices).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button("Continue",func() -> void: if _valid(): solo_requested.emit(int(_seed.text),_name.text,true),choices).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button("Host world · 1–6 players",func() -> void: if _valid(): host_requested.emit(int(_seed.text),int(_port.text),_name.text),_body)
	_address=field("HOST ADDRESS","127.0.0.1",_body)
	button("Join world",func() -> void: if _valid(): join_requested.emit(_address.text,int(_port.text),_name.text),_body)
	_body.add_child(label("LAN: host's IP address. Internet: a reachable host and forwarded UDP port.\nWorlds and progress are saved by the host.",12,Color("9fb5ae")))

func _online_welcome() -> void:
	var service: Node = session.account_service
	_body.add_child(label("AMIIN STUDIO  ·  ONLINE ADVENTURES", 16, Color("d9a66c")))
	if service.account.is_empty():
		_body.add_child(label(service.error, 18))
		_body.add_child(label("Create an account or sign in using Amiin Launcher, then press Play.", 16))
		return
	_body.add_child(label("Welcome, " + str(service.account.username) + "  ·  " + service.channel.capitalize(), 20))
	_seed = field("WORLD SEED", "73129", _body)
	button("Continue / play solo", func() -> void:
		if _seed.text.is_valid_int(): solo_requested.emit(int(_seed.text), str(service.account.username), true), _body)
	button("Host online world · 1–6 players", func() -> void:
		if _seed.text.is_valid_int(): session.host_online(int(_seed.text)), _body)
	_address = field("FRIEND'S INVITE CODE", "", _body)
	_address.max_length = 8; _address.placeholder_text = "Example: AB3D7FGH"
	button("Join friend", func() -> void: session.join_online(_address.text), _body)
	_body.add_child(label("Share your code from Esc → Players. No router setup needed.\nThe host keeps the world save and must remain in the game.", 14, Color("9fb5ae")))

func _valid() -> bool:
	if not _seed.text.is_valid_int() or not _port.text.is_valid_int() or int(_port.text)<1024 or int(_port.text)>65535:
		show_message("Enter a numeric seed and a port from 1024 to 65535."); return false
	return true

func _process(delta: float) -> void:
	_notice_time-=delta; _notice.visible=_notice_time>0
	if session==null or not session.running: return
	_hotbar.visible=not menu_open and hotbar_enabled
	if _food_bar:
		_food_bar.get_parent().visible = not menu_open and hotbar_enabled
		_food_bar.value = float(session.local_profile.get("fullness", 50))
		_food_bar.get_theme_stylebox("fill").bg_color = Color(0.78, 0.3, 0.28, 0.95) if _food_bar.value < 25 else Color(0.62, 0.78, 0.34, 0.95)
	if _health_bar:
		_health_bar.get_parent().visible = not menu_open and hotbar_enabled
		_health_bar.value = float(session.local_profile.get("health", 100))
	_controls.visible=not menu_open
	var inv: Dictionary=session.local_profile.get("inventory",{})
	if menu_open and page == "Inventory" and _inventory_hash != hash([inv, int(session.local_profile.get("fullness", 50)), int(session.local_profile.get("health", 100)), str(session.local_profile.get("equipped", "hand"))]):
		open_page("Inventory")
	var names: Array[String]=["Axe","Pickaxe","Hammer","Wood","Stone","Fiber","Planks","Rope"]
	for i in range(8):
		_slots[i].text=""
		_slot_counts[i].text=str(inv.get(HOTBAR[i],0)) if i>=3 else ""
		_slots[i].add_theme_stylebox_override("normal",_slot_selected if i==selected_slot else _slot_background)

	_context_timer+=delta
	if _context_timer>0.35 and not menu_open:
		_context_timer=0
		var id: String=session.nearest_resource(session.local_id(),false)
		_context=""
		var animal: Node3D = session.nearest_animal(session.local_id())
		if animal != null:
			_context = "LMB / Q · Hit " + animal.species + " · " + str(animal.health) + " health" + (" · yields meat" if animal.species == "cow" else "")
		elif not id.is_empty():
			var kind: String=session.world.resources[id].kind
			var selected: String=Items.tool(session.local_player().equipped_tool).get("resource","")
			_context=("LMB / Q · Gather "+kind) if kind==selected else ({"wood":"Tree · Select 1 Axe","stone":"Rock · Select 2 Pickaxe","fiber":"Plant · Select 6 Hands"}.get(kind,""))
	_prompt.text=session.build_hint if not session.build_hint.is_empty() else _context
	var actor: CharacterBody3D=session.local_player()
	if actor!=null and actor._action>0 and actor._action_name.begins_with("Craft"):
		_prompt.text="Crafting · %.1f s · Move away to cancel" % actor._action
	_prompt.visible=not menu_open and not _prompt.text.is_empty()
	if _map!=null and is_instance_valid(_map): _map.queue_redraw()

func _inventory(content: VBoxContainer) -> void:
	_inventory_hash = hash([session.local_profile.get("inventory", {}), int(session.local_profile.get("fullness", 50)), int(session.local_profile.get("health", 100)), str(session.local_profile.get("equipped", "hand"))])
	content.add_child(label("EQUIPMENT  ·  "+str(session.local_profile.get("equipped","hand")).capitalize(),18))
	content.add_child(label("E / I close inventory · H show / hide hotbar · Health " + str(int(session.local_profile.get("health", 100))) + " / 100 · Food " + str(int(session.local_profile.get("fullness", 50))) + " / 100", 14))
	var visibility: CheckButton = CheckButton.new()
	visibility.text = "Show hotbar while playing"
	visibility.button_pressed = hotbar_enabled
	visibility.toggled.connect(set_hotbar_visible)
	content.add_child(visibility)
	var categories: HBoxContainer=HBoxContainer.new(); content.add_child(categories)
	var grid: GridContainer=GridContainer.new(); grid.columns=4
	var info: Label=label("Select a stack to inspect it.",16)
	var selected_image: TextureRect=TextureRect.new(); selected_image.custom_minimum_size=Vector2(88,88); selected_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; selected_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var populate: Callable=func(category: String) -> void:
		inventory_category = category
		for child: Node in grid.get_children(): grid.remove_child(child); child.queue_free()
		var inventory: Dictionary=session.local_profile.get("inventory",{})
		for id: String in inventory:
			var kind: String = "Food" if id in ["meat", "cooked_meat", "bone"] else ("Tools" if id in ["axe","pickaxe","hammer"] else ("Crafting" if id in ["planks","rope"] else "Resources"))
			if category!="All" and kind!=category: continue
			var remaining: int=int(inventory[id])
			while remaining>0:
				var amount: int=mini(remaining,99); remaining-=amount
				var item: String=id; var count: int=amount
				var card: Button=button(item.capitalize()+"  ×"+str(count),func() -> void:
					inventory_item = item
					open_page("Inventory"),grid)
				card.custom_minimum_size=Vector2(175,76); card.icon=Items.icon(item); card.expand_icon=true; card.add_theme_constant_override("icon_max_width",42)
		if grid.get_child_count() == 0: grid.add_child(label("No items in this category.", 15))
	for category: String in ["All","Resources","Tools","Crafting","Food"]:
		button(category,func() -> void: populate.call(category),categories)
	content.add_child(grid)
	var detail: HBoxContainer=HBoxContainer.new(); content.add_child(detail); detail.add_child(selected_image); detail.add_child(info); populate.call(inventory_category)
	if int(session.local_profile.get("inventory", {}).get(inventory_item, 0)) > 0:
		selected_image.texture = Items.icon(inventory_item)
		info.text = inventory_item.capitalize() + " · " + str(session.local_profile.inventory[inventory_item]) + " owned\n" + ("Eat one to restore 40 food." if inventory_item == "cooked_meat" else ("Raw meat · cook with 1 wood at a cooking fire, or feed (T) to a cat or dog to tame it." if inventory_item == "meat" else ("Feed (T) to a cat or dog to tame it." if inventory_item == "bone" else "Remove one to discard it permanently.")))
		if Items.FOOD_MODELS.has(inventory_item):
			selected_image.hide()
			detail.add_child(Items.food_preview(inventory_item))
		var actions: HBoxContainer = HBoxContainer.new()
		content.add_child(actions)
		if inventory_item == "cooked_meat": button("Eat one", func() -> void: session.inventory_action(inventory_item, "eat"), actions)
		elif inventory_item == "meat": button("Cook at fire", func() -> void: session.craft("cooked_meat"); close_menu(), actions)
		if inventory_item in ["axe", "pickaxe", "hammer"]:
			var equipped: String = str(session.local_profile.get("equipped", "hand"))
			if equipped == inventory_item: button("Unequip (use hands)", func() -> void: session.equip("hand"), actions)
			else: button("Equip", func() -> void: session.equip(inventory_item), actions)
		button("Remove one", func() -> void: session.inventory_action(inventory_item, "discard"), actions)
	button("Back to game", close_menu, content)

func confirm_removal(id: String) -> void:
	open_page("Disassemble")
	var target: Dictionary={}
	for record: Dictionary in session.state.get("world_delta",{}).get("structures",[]):
		if record.id==id: target=record; break
	if target.is_empty(): close_menu(); return
	_body.add_child(label("Disassemble "+Modules.definition(target.module_id).label+"?",20))
	_body.add_child(label("Returns 50% of materials. Supporting pieces must be removed last.",14))
	button("Confirm disassembly",func() -> void: session.remove_structure(id); close_menu(),_body)
	button("Cancel",close_menu,_body)
