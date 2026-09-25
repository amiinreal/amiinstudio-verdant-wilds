extends VBoxContainer
## Catalog presentation only. Selection never changes inventory or world state.
## Item art (thumbnails, resource icons) is untouched -- this file only reshapes the
## chrome around it: toolbar, card layout, and afford/can't-afford states.
const Modules = preload("res://Adventure/modules.gd")
const Items = preload("res://Adventure/items.gd")
var hud: CanvasLayer
var category: String = "All"
var subcategory: String = "All"
var search: String = ""
var favorites: PackedStringArray = PackedStringArray()
var grid: GridContainer
var count_label: Label
var filter: OptionButton
var cards: Array[Dictionary] = []
var refresh: float = 0

func setup(owner_hud: CanvasLayer) -> void:
	hud=owner_hud
	Modules.refresh_catalog()
	var config: ConfigFile=ConfigFile.new()
	if config.load("user://build_favorites.cfg")==OK: favorites=config.get_value("catalog","favorites",PackedStringArray())
	add_theme_constant_override("separation",14)

	var header: HBoxContainer=HBoxContainer.new(); add_child(header)
	var heading: VBoxContainer=VBoxContainer.new(); heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(heading)
	heading.add_child(hud.label("BUILD CATALOG",13,Color("d9a441")))
	count_label=hud.label("",12,Color("8fa38f")); heading.add_child(count_label)
	heading.add_child(hud.label("Select to preview · R rotate · Left click place · Right click catalog · B exit",12,Color("8fa38f")))

	var toolbar: HBoxContainer=HBoxContainer.new(); toolbar.add_theme_constant_override("separation",8); add_child(toolbar)
	var edit: LineEdit=LineEdit.new(); edit.placeholder_text="Search building pieces…"; edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	edit.add_theme_stylebox_override("normal",hud.style(Color(0.06,0.1,0.09,0.9),9)); edit.add_theme_stylebox_override("focus",hud.style(Color(0.08,0.14,0.12,0.95),9))
	toolbar.add_child(edit)
	edit.text_changed.connect(func(value: String) -> void: search=value; rebuild())
	var categories: OptionButton=_pill_dropdown(toolbar)
	var names: Array[String]=["All","Favorites"]
	for def: Dictionary in Modules.catalog().values():
		if def.data.category not in names: names.append(def.data.category)
	for value: String in names: categories.add_item(value)
	categories.item_selected.connect(func(index: int) -> void: category=names[index]; rebuild())
	filter=_pill_dropdown(toolbar); filter.add_item("All")
	var subs: Array[String]=["All"]
	for def: Dictionary in Modules.catalog().values():
		if def.data.subcategory not in subs: subs.append(def.data.subcategory); filter.add_item(def.data.subcategory)
	filter.item_selected.connect(func(index: int) -> void: subcategory=subs[index]; rebuild())

	grid=GridContainer.new(); grid.columns=3; grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",12); add_child(grid)
	rebuild()

func _pill_dropdown(parent: Container) -> OptionButton:
	var node: OptionButton=OptionButton.new(); node.custom_minimum_size=Vector2(120,0); node.focus_mode=Control.FOCUS_NONE
	node.add_theme_stylebox_override("normal",hud.style(Color(0.06,0.1,0.09,0.9),8))
	node.add_theme_stylebox_override("hover",hud.style(Color(0.09,0.15,0.13,0.95),8))
	parent.add_child(node)
	return node

func rebuild() -> void:
	cards.clear()
	for child: Node in grid.get_children(): grid.remove_child(child); child.queue_free()
	var ids: Array=Modules.catalog().keys()
	var shown: int=0
	for id: String in ids:
		var def: Dictionary=Modules.definition(id)
		if category=="Favorites" and id not in favorites: continue
		if category not in ["All","Favorites"] and def.data.category!=category: continue
		if subcategory!="All" and def.data.subcategory!=subcategory: continue
		if not search.is_empty() and not (def.label+" "+def.data.subcategory).to_lower().contains(search.to_lower()): continue
		shown+=1
		var panel: PanelContainer=PanelContainer.new(); panel.custom_minimum_size=Vector2(236,268)
		panel.add_theme_stylebox_override("panel",hud.style(Color(0.09,0.17,0.14,0.92),12)); grid.add_child(panel)
		var box: VBoxContainer=VBoxContainer.new(); box.add_theme_constant_override("separation",8); panel.add_child(box)

		var head: HBoxContainer=HBoxContainer.new(); box.add_child(head)
		var name: Label=hud.label(def.label,14,Color("f2ecdd")); name.size_flags_horizontal=Control.SIZE_EXPAND_FILL; name.clip_text=true; head.add_child(name)
		var favorite: Button=Button.new(); favorite.text="★" if id in favorites else "☆"; favorite.custom_minimum_size=Vector2(28,28); favorite.focus_mode=Control.FOCUS_NONE
		favorite.add_theme_font_size_override("font_size",15); favorite.add_theme_color_override("font_color",Color("d9a441") if id in favorites else Color("8fa38f"))
		favorite.add_theme_stylebox_override("normal",hud.style(Color(0,0,0,0),4)); favorite.add_theme_stylebox_override("hover",hud.style(Color(1,1,1,0.06),4))
		favorite.pressed.connect(func() -> void: toggle_favorite(id)); head.add_child(favorite)

		var tile: PanelContainer=PanelContainer.new(); tile.custom_minimum_size=Vector2(0,104)
		tile.add_theme_stylebox_override("panel",hud.style(Color(0.13,0.24,0.16,0.9),9)); box.add_child(tile)
		var image: TextureRect=TextureRect.new(); image.expand_mode=TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter=Control.MOUSE_FILTER_STOP; image.custom_minimum_size=Vector2(0,104); tile.add_child(image)
		image.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: hud.build_requested.emit(ids.find(id)))
		var path: String="res://Adventure/generated/thumbnails/"+id+".png"
		if ResourceLoader.exists(path): image.texture=load(path)
		elif def.data.thumbnail!=null: image.texture=def.data.thumbnail

		var cost_box: VBoxContainer=VBoxContainer.new(); cost_box.add_theme_constant_override("separation",3); box.add_child(cost_box)
		var resource_rows: Array[HBoxContainer]=[]
		for resource: String in def.cost:
			var line: HBoxContainer=HBoxContainer.new(); line.add_theme_constant_override("separation",6); cost_box.add_child(line); resource_rows.append(line)
			var icon: TextureRect=TextureRect.new(); icon.custom_minimum_size=Vector2(16,16); icon.expand_mode=TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.texture=Items.icon(resource); line.add_child(icon)
			var text: Label=hud.label(resource.capitalize(),12,Color("adc4b5")); text.size_flags_horizontal=Control.SIZE_EXPAND_FILL; line.add_child(text)
			var amount: Label=hud.label("",12,Color("adc4b5")); amount.name="amount"; line.add_child(amount)

		var select: Button=Button.new(); select.custom_minimum_size.y=36; select.focus_mode=Control.FOCUS_NONE
		select.pressed.connect(func() -> void: hud.build_requested.emit(ids.find(id)))
		select.tooltip_text="Preview "+def.label; box.add_child(select)
		cards.append({"id":id,"rows":resource_rows,"select":select})
	if grid.get_child_count()==0: grid.add_child(hud.label("No matching pieces.",16))
	count_label.text="%d piece%s" % [shown,"" if shown==1 else "s"]
	update_costs()

func toggle_favorite(id: String) -> void:
	if id in favorites: favorites.remove_at(favorites.find(id))
	else: favorites.append(id)
	var config: ConfigFile=ConfigFile.new(); config.set_value("catalog","favorites",favorites); config.save("user://build_favorites.cfg")
	rebuild()

func update_costs() -> void:
	var inv: Dictionary=hud.session.local_profile.get("inventory",{})
	var afford_color: Color=Color("8bbf4a")
	var short_color: Color=Color("e0847a")
	for card: Dictionary in cards:
		var enough: bool=true
		var resources: Array=Modules.definition(card.id).cost.keys()
		for i in range(card.rows.size()):
			var resource: String=resources[i]
			var needed: int=Modules.definition(card.id).cost[resource]; var held: int=int(inv.get(resource,0))
			var short: bool=held<needed
			if short: enough=false
			var amount: Label=card.rows[i].get_node("amount")
			amount.text="%d / %d" % [held,needed]
			amount.modulate=short_color if short else afford_color
		card.select.text="Build" if enough else "Not enough materials"
		card.select.add_theme_stylebox_override("normal",hud.style(Color(0.24,0.5,0.28,0.95) if enough else Color(1,1,1,0.05),8))
		card.select.add_theme_stylebox_override("hover",hud.style(Color(0.3,0.6,0.34,0.98) if enough else Color(1,1,1,0.08),8))
		card.select.add_theme_color_override("font_color",Color("173c26") if enough else Color("8fa38f"))
		card.select.add_theme_color_override("font_color_hover",Color("173c26") if enough else Color("8fa38f"))

func _process(delta: float) -> void:
	refresh+=delta
	if refresh>0.5: refresh=0; update_costs()
