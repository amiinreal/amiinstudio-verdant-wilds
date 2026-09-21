extends CanvasLayer
signal solo_requested(seed_value: int, nickname: String, resume: bool)
signal host_requested(seed_value: int, port: int, nickname: String)
signal join_requested(address: String, port: int, nickname: String)
signal note_requested(note: int)
signal leave_requested
signal next_requested
signal mute_requested
const Rules := preload("res://Adventure/rules.gd")
const Map := preload("res://Adventure/mainland_map.gd")
var session: Node3D
var menu: PanelContainer
var notebook: PanelContainer
var map_panel: PanelContainer
var menu_open: bool = true
var _root: Control
var _game_ui: Control
var _name: LineEdit
var _seed: LineEdit
var _address: LineEdit
var _port: LineEdit
var _toast: Label
var _quest: Label
var _region: Label
var _stats: Label
var _phrase: Label
var _party: Label
var _book_text: Label
var _map: Control
var _hint: Label
var _victory: PanelContainer
var _continue: Button
var _resume_game: Button
var _toast_timer: float = 0
var _completion_shown: bool = false
var _buttons: Array[Button] = []

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_menu()
	_build_game_ui()
	_build_book()
	_build_map()
	_build_victory()
	_toast = _label("", 16, Color("ffe0a0"))
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-450, 22)
	_toast.custom_minimum_size = Vector2(900, 65)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_toast)
	_toast.offset_left = -450
	_toast.offset_right = 450
	_toast.offset_top = 155
	_toast.offset_bottom = 220
	_toast.add_theme_color_override("font_outline_color", Color("112522"))
	_toast.add_theme_constant_override("outline_size", 6)

func _style(bg: Color = Color(0.035, 0.072, 0.08, 0.96)) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color("647e72")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _panel(parent: Control, p: Vector2, dimensions: Vector2) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = p
	panel.custom_minimum_size = dimensions
	panel.add_theme_stylebox_override("panel", _style())
	parent.add_child(panel)
	return panel

func _label(text_value: String, font_size: int = 16, color: Color = Color("e7e5d0")) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text_value: String, action: Callable, parent: Container) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 40
	button.add_theme_font_size_override("font_size", 15)
	var normal_style: StyleBoxFlat = _style(Color("263f3d"))
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8
	var hover_style: StyleBoxFlat = _style(Color("426354"))
	hover_style.content_margin_top = 8
	hover_style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.pressed.connect(action)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button

func _field(parent: Container, caption: String, value: String, length: int) -> LineEdit:
	parent.add_child(_label(caption, 12, Color("a6bca7")))
	var field: LineEdit = LineEdit.new()
	field.text = value
	field.max_length = length
	field.custom_minimum_size.y = 36
	parent.add_child(field)
	return field

func _build_menu() -> void:
	menu = _panel(_root, Vector2(34, 30), Vector2(435, 0))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	menu.add_child(box)
	box.add_child(_label("A   C O O P E R A T I V E   M U S I C   A D V E N T U R E", 11, Color("a6c5ad")))
	box.add_child(_label("THE RESONANT\nWILDS", 40))
	var intro: Label = _label("Follow rivers, forest trails and distant peaks.\nGather, build and make a home with friends.\nDiscover the melodies of a continuous world.", 16, Color("b6c8b9"))
	box.add_child(intro)
	_name = _field(box, "TRAVELER NAME", "Traveler", 20)
	var fields: HBoxContainer = HBoxContainer.new()
	box.add_child(fields)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_child(left)
	_seed = _field(left, "WORLD SEED", "73129", 9)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_child(right)
	_port = _field(right, "UDP PORT", "27840", 5)
	var solo_row: HBoxContainer = HBoxContainer.new()
	box.add_child(solo_row)
	var solo: Button = _button("Begin solo", func() -> void: _start_solo(false), solo_row)
	solo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continue = _button("Continue save", func() -> void: _start_solo(true), solo_row)
	_continue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button("Host an expedition  ·  1–6 players", _host, box)
	_address = _field(box, "HOST ADDRESS  ·  IP OR HOSTNAME", "127.0.0.1", 120)
	_button("Join expedition", _join, box)
	box.add_child(_label("Same PC: 127.0.0.1  ·  LAN: host's local IP\nInternet: reachable host + forwarded UDP port\nDirect connection; no account or matchmaking required.", 11, Color("a5b4af")))
	_resume_game = _button("Return to adventure  [Esc]", toggle_menu, box)
	_resume_game.visible = false
	_button("Music on / off", func() -> void: mute_requested.emit(), box)

func _valid_fields() -> bool:
	if not _seed.text.is_valid_int() or not _port.text.is_valid_int() or int(_port.text) < 1024 or int(_port.text) > 65535:
		show_message("Enter an integer seed and a port from 1024 to 65535.")
		return false
	return true

func _start_solo(resume: bool) -> void:
	if _valid_fields():
		solo_requested.emit(int(_seed.text), _name.text, resume)

func _host() -> void:
	if _valid_fields():
		host_requested.emit(int(_seed.text), int(_port.text), _name.text)

func _join() -> void:
	if _valid_fields() and not _address.text.strip_edges().is_empty():
		join_requested.emit(_address.text, int(_port.text), _name.text)

func _build_game_ui() -> void:
	_game_ui = Control.new()
	_game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_game_ui)
	_game_ui.visible = false
	var header: PanelContainer = _panel(_game_ui, Vector2(22, 20), Vector2(350, 0))
	var box: VBoxContainer = VBoxContainer.new()
	header.add_child(box)
	box.add_child(_label("T H E   R E S O N A N T   W I L D S", 11, Color("a4c498")))
	_region = _label("Firstlight Camp", 23)
	box.add_child(_region)
	_stats = _label("", 13, Color("e4d19b"))
	box.add_child(_stats)
	var party: PanelContainer = _panel(_game_ui, Vector2.ZERO, Vector2(230, 0))
	party.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	party.offset_left = -294
	party.offset_right = -22
	party.offset_top = 20
	party.offset_bottom = 145
	var party_box: VBoxContainer = VBoxContainer.new()
	party.add_child(party_box)
	_party = _label("", 13, Color("b5d0bd"))
	party_box.add_child(_party)
	_button("World map [M]", toggle_map, party_box)
	_button("Journal [J]", toggle_book, party_box)
	var quest_panel: PanelContainer = _panel(_game_ui, Vector2.ZERO, Vector2(410, 0))
	quest_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	quest_panel.offset_left = 22
	quest_panel.offset_right = 432
	quest_panel.offset_top = -245
	quest_panel.offset_bottom = -22
	var quest_box: VBoxContainer = VBoxContainer.new()
	quest_panel.add_child(quest_box)
	quest_box.add_child(_label("EXPLORE · GATHER · BUILD", 11, Color("a4c498")))
	_quest = _label("", 16)
	_quest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest.custom_minimum_size.x = 365
	quest_box.add_child(_quest)
	_hint = _label("G Gather   B Build   C Planks   V Rope\nQ Listen   E Inspect   R Echo   H Recall\nWASD Move   Space Jump   M Map   J Journal", 12, Color("a7bcb0"))
	quest_box.add_child(_hint)
	var notes_panel: PanelContainer = _panel(_game_ui, Vector2.ZERO, Vector2(0, 0))
	notes_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	notes_panel.offset_left = -635
	notes_panel.offset_right = -22
	notes_panel.offset_top = -164
	notes_panel.offset_bottom = -22
	var note_box: VBoxContainer = VBoxContainer.new()
	notes_panel.add_child(note_box)
	_phrase = _label("PLAY THE WORLD  ·  keys 1–5", 14, Color("e9d89e"))
	note_box.add_child(_phrase)
	var keys: HBoxContainer = HBoxContainer.new()
	keys.add_theme_constant_override("separation", 8)
	note_box.add_child(keys)
	for i in range(5):
		var button: Button = _button("%d\n%s" % [i + 1, Rules.NOTES[i]], func() -> void: note_requested.emit(i), keys)
		button.custom_minimum_size = Vector2(98, 62)
		button.add_theme_color_override("font_color", Rules.COLORS[i])
		_buttons.append(button)

func _build_book() -> void:
	notebook = _panel(_root, Vector2.ZERO, Vector2(650, 570))
	notebook.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	notebook.offset_left = -325
	notebook.offset_right = 325
	notebook.offset_top = -285
	notebook.offset_bottom = 285
	var box: VBoxContainer = VBoxContainer.new()
	notebook.add_child(box)
	box.add_child(_label("The traveler's journal", 27))
	_book_text = _label("", 15)
	_book_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_book_text.custom_minimum_size = Vector2(610, 420)
	box.add_child(_book_text)
	_button("Close [J]", toggle_book, box)
	notebook.visible = false

func _build_map() -> void:
	map_panel = _panel(_root, Vector2.ZERO, Vector2(510, 640))
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	map_panel.offset_left = -255
	map_panel.offset_right = 255
	map_panel.offset_top = -320
	map_panel.offset_bottom = 320
	var box: VBoxContainer = VBoxContainer.new()
	map_panel.add_child(box)
	box.add_child(_label("The Resonant Wilds", 27))
	_map = Control.new()
	_map.set_script(Map)
	_map.custom_minimum_size = Vector2(470, 430)
	box.add_child(_map)
	box.add_child(_label("Ochre: roads · dotted: trails · blue: rivers\nWhite: landmarks · squares: settlements\nGold: you · cyan: friends · brown: player buildings", 13, Color("b7cabb")))
	_button("Close [M]", toggle_map, box)
	map_panel.visible = false

func _build_victory() -> void:
	_victory = _panel(_root, Vector2.ZERO, Vector2(580, 250))
	_victory.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_victory.offset_left = -290
	_victory.offset_right = 290
	_victory.offset_top = -125
	_victory.offset_bottom = 125
	var box: VBoxContainer = VBoxContainer.new()
	_victory.add_child(box)
	box.add_child(_label("THE WORLD REMEMBERS", 29, Color("ffe09f")))
	box.add_child(_label("Seven voices, one living song.\nYou restored every crossing and the Heart.\nA new expedition brings new melodies and landscapes.", 16))
	_button("Begin the next expedition  ·  host / solo", func() -> void: next_requested.emit(), box)
	_button("Keep exploring", func() -> void: _victory.hide(); Input.mouse_mode = Input.MOUSE_MODE_CAPTURED, box)
	_victory.hide()

func bind_session(value: Node3D) -> void:
	session = value
	_map.session = session
	_continue.disabled = session.load_save().is_empty()

func started() -> void:
	_completion_shown = false
	menu_open = false
	menu.hide()
	_game_ui.show()
	_victory.hide()
	_resume_game.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func stopped() -> void:
	menu_open = true
	menu.show()
	_game_ui.hide()
	_victory.hide()
	_resume_game.hide()
	notebook.hide()
	map_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func toggle_menu() -> void:
	if session == null or not session.running:
		return
	menu_open = not menu_open
	menu.visible = menu_open
	notebook.hide()
	map_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED

func toggle_book() -> void:
	if session == null or not session.running:
		return
	notebook.visible = not notebook.visible
	map_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if notebook.visible else Input.MOUSE_MODE_CAPTURED
	_refresh_book()

func toggle_map() -> void:
	if session == null or not session.running:
		return
	map_panel.visible = not map_panel.visible
	notebook.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_panel.visible else Input.MOUSE_MODE_CAPTURED

func blocks_movement() -> bool:
	return menu_open or notebook.visible or map_panel.visible or _victory.visible

func show_message(text: String) -> void:
	_toast.text = text
	_toast_timer = 6.0

func flash_note(note: int) -> void:
	_buttons[note].modulate = Color(1.8, 1.8, 1.8)
	create_tween().tween_property(_buttons[note], "modulate", Color.WHITE, 0.35)

func refreshed() -> void:
	_refresh_book()

func _refresh_book() -> void:
	if session==null: return
	var p: Dictionary=session.local_profile
	var s: Dictionary=p.get("stats",{})
	var text_value: String="A continuous world. Every bridge and road is open.\nG gathers nearby trees, rocks and bushes. C makes planks; V makes rope.\nB build · Z/X choose · T rotate · PgUp/Dn storey · F place.\nFoundations → walls / doorway → roof. Costs appear during placement.\n\nYOUR JOURNEY (saved by the host)\n"
	text_value+="Playtime %d min · Sessions %d · Distance %.0f m\n" % [int(s.get("playtime",0)/60),int(s.get("sessions",0)),float(s.get("distance",0))]
	text_value+="Regions %d/7 · Landmarks %d/11 · Hidden %d · Exploration %.0f%%\n" % [int(s.get("regions_discovered",0)),int(s.get("landmarks_discovered",0)),int(s.get("hidden_locations_discovered",0)),float(s.get("exploration_percentage",0))]
	text_value+="Gathered %d · Wood %d · Stone %d · Fiber %d\n" % [int(s.get("resources_gathered",0)),int(s.get("wood_gathered",0)),int(s.get("stone_gathered",0)),int(s.get("fiber_gathered",0))]
	text_value+="Crafted %d · Components %d · Homes %d · Bridges %d · Structures %d\n" % [int(s.get("items_crafted",0)),int(s.get("components_placed",0)),int(s.get("buildings_completed",0)),int(s.get("bridges_discovered",0)),int(s.get("structures_discovered",0))]
	text_value+="Achievements: "+(", ".join(p.get("achievements",[])) if not p.get("achievements",[]).is_empty() else "Your story is just beginning.")+"\n\nOPTIONAL MELODIES · Q listen · keys 1–5 play · R echo\n"
	for i in range(4):
		text_value+=(Rules.SPELL_NAMES[i]+"  "+Rules.phrase_text(Rules.SPELLS[i]) if session.state["solved"][i] else "Discover the melody in "+Rules.NAMES[i])+"\n"
	_book_text.text=text_value

func _process(delta: float) -> void:
	_toast_timer-=delta
	_toast.visible=_toast_timer>0 and not notebook.visible and not map_panel.visible
	if session==null or not session.running: return
	var body: CharacterBody3D=session.local_player()
	if body==null: return
	_region.text=Rules.NAMES[session.world.nearest_island(Vector2(body.position.x,body.position.z))]
	var inv: Dictionary=session.local_profile.get("inventory",{})
	_stats.text="Wood %d · Stone %d · Fiber %d\nPlanks %d · Rope %d · Melodies %d/7" % [int(inv.get("wood",0)),int(inv.get("stone",0)),int(inv.get("fiber",0)),int(inv.get("planks",0)),int(inv.get("rope",0)),session.state["solved"].count(true)]
	_party.text=session.status+"\n%d / 6 travelers · Seed %d" % [session.players.size(),session.state["seed"]]
	var site: int=session.nearest_site(session.local_id())
	if not session.build_hint.is_empty(): _quest.text=session.build_hint
	elif site>=0 and not session.state["solved"][site]: _quest.text=Rules.DESCRIPTIONS[site]
	else: _quest.text="Follow a trail, river or distant landmark.\nGather materials and choose a place to call home."
	_phrase.text="OPTIONAL MELODY  "+Rules.phrase_text(Rules.melodies(session.state["seed"])[site])+"  [%d]" % session.progress[site] if site>=0 else "PLAY THE WORLD · keys 1–5 · melodies in [J]"
	if map_panel.visible: _map.queue_redraw()