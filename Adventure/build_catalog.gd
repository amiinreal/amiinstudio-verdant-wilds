extends VBoxContainer
## Catalog presentation only. Selection never changes inventory or world state.
const Modules = preload("res://Adventure/modules.gd")
var hud: CanvasLayer
var category: String = "All"
var subcategory: String = "All"
var search: String = ""
var favorites: PackedStringArray = PackedStringArray()
var grid: GridContainer
var filter: OptionButton
var cards: Array[Dictionary] = []
var refresh: float = 0

func setup(owner_hud: CanvasLayer) -> void:
	hud=owner_hud
	Modules.refresh_catalog()
	var config: ConfigFile=ConfigFile.new()
	if config.load("user://build_favorites.cfg")==OK: favorites=config.get_value("catalog","favorites",PackedStringArray())
	var row: HBoxContainer=HBoxContainer.new(); add_child(row)
	var edit: LineEdit=LineEdit.new(); edit.placeholder_text="Search building pieces…"; edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(edit)
	edit.text_changed.connect(func(value: String) -> void: search=value; rebuild())
	var categories: OptionButton=OptionButton.new(); row.add_child(categories)
	var names: Array[String]=["All","Favorites"]
	for def: Dictionary in Modules.catalog().values():
		if def.data.category not in names: names.append(def.data.category)
	for value: String in names: categories.add_item(value)
	categories.item_selected.connect(func(index: int) -> void: category=names[index]; rebuild())
	filter=OptionButton.new(); row.add_child(filter); filter.add_item("All")
	var subs: Array[String]=["All"]
	for def: Dictionary in Modules.catalog().values():
		if def.data.subcategory not in subs: subs.append(def.data.subcategory); filter.add_item(def.data.subcategory)
	filter.item_selected.connect(func(index: int) -> void: subcategory=subs[index]; rebuild())
	add_child(hud.label("Select to preview · R rotate · Left click place · Right click catalog · B exit",13))
	grid=GridContainer.new(); grid.columns=3; grid.add_theme_constant_override("h_separation",10); grid.add_theme_constant_override("v_separation",10); add_child(grid)
	rebuild()

func rebuild() -> void:
	cards.clear()
	for child: Node in grid.get_children(): grid.remove_child(child); child.queue_free()
	var ids: Array=Modules.catalog().keys()
	for id: String in ids:
		var def: Dictionary=Modules.definition(id)
		if category=="Favorites" and id not in favorites: continue
		if category not in ["All","Favorites"] and def.data.category!=category: continue
		if subcategory!="All" and def.data.subcategory!=subcategory: continue
		if not search.is_empty() and not (def.label+" "+def.data.subcategory).to_lower().contains(search.to_lower()): continue
		var panel: PanelContainer=PanelContainer.new(); panel.custom_minimum_size=Vector2(231,200); panel.add_theme_stylebox_override("panel",hud.style(Color(0.08,0.18,0.19,0.88),10)); grid.add_child(panel)
		var box: VBoxContainer=VBoxContainer.new(); panel.add_child(box)
		var select: Button=hud.button(def.label,func() -> void: hud.build_requested.emit(ids.find(id)),box)
		select.tooltip_text="Preview "+def.label
		var image: TextureRect=TextureRect.new(); image.custom_minimum_size=Vector2(205,90); image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.mouse_filter=Control.MOUSE_FILTER_STOP; box.add_child(image)
		image.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: hud.build_requested.emit(ids.find(id)))
		var path: String="res://Adventure/generated/thumbnails/"+id+".png"
		if ResourceLoader.exists(path): image.texture=load(path)
		elif def.data.thumbnail!=null: image.texture=def.data.thumbnail
		var cost: Label=hud.label("",12); box.add_child(cost)
		var favorite: Button=hud.button("★ Favorite" if id in favorites else "☆ Favorite",func() -> void: toggle_favorite(id),box)
		favorite.custom_minimum_size.y=26
		cards.append({"id":id,"cost":cost,"select":select})
	if cards.is_empty(): grid.add_child(hud.label("No matching pieces.",16))
	update_costs()

func toggle_favorite(id: String) -> void:
	if id in favorites: favorites.remove_at(favorites.find(id))
	else: favorites.append(id)
	var config: ConfigFile=ConfigFile.new(); config.set_value("catalog","favorites",favorites); config.save("user://build_favorites.cfg")
	rebuild()

func update_costs() -> void:
	var inv: Dictionary=hud.session.local_profile.get("inventory",{})
	for card: Dictionary in cards:
		var lines: PackedStringArray=[]; var enough: bool=true
		for resource: String in Modules.definition(card.id).cost:
			var needed: int=Modules.definition(card.id).cost[resource]; var held: int=int(inv.get(resource,0))
			lines.append("%s %d / %d%s" % [resource.capitalize(),held,needed," · missing "+str(needed-held) if held<needed else ""])
			if held<needed: enough=false
		card.cost.text="\n".join(lines)
		card.cost.modulate=Color("d4dfce") if enough else Color("e5a59a")
		card.select.modulate=Color.WHITE if enough else Color(0.7,0.7,0.7)

func _process(delta: float) -> void:
	refresh+=delta
	if refresh>0.5: refresh=0; update_costs()
