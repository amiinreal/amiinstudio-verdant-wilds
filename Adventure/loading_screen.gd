extends RefCounted
## Stage progress is rendered even while deterministic generation occupies the main thread.
static var layer: CanvasLayer
static var caption: Label
static var bar: ProgressBar
static var history: Array[float]=[]
static func show_progress(percent: float,text: String) -> void:
	history.append(percent)
	if DisplayServer.get_name()=="headless": return
	if not is_instance_valid(layer):
		layer=CanvasLayer.new(); layer.layer=100
		(Engine.get_main_loop() as SceneTree).root.add_child(layer)
		var background: ColorRect=ColorRect.new(); background.color=Color("101e23"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(background)
		var panel: Control=Control.new(); background.add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER); panel.position-=Vector2(280,100); panel.size=Vector2(560,200)
		var title: Label=Label.new(); title.text="THE VERDANT WILDS"; title.add_theme_font_size_override("font_size",30); title.position=Vector2(0,0); panel.add_child(title)
		caption=Label.new(); caption.position=Vector2(0,62); caption.add_theme_font_size_override("font_size",18); panel.add_child(caption)
		bar=ProgressBar.new(); bar.position=Vector2(0,106); bar.size=Vector2(560,28); panel.add_child(bar)
		var track: StyleBoxFlat=StyleBoxFlat.new(); track.bg_color=Color("263b40"); track.set_corner_radius_all(6); bar.add_theme_stylebox_override("background",track)
		var fill: StyleBoxFlat=StyleBoxFlat.new(); fill.bg_color=Color("709c69"); fill.set_corner_radius_all(6); bar.add_theme_stylebox_override("fill",fill)
		var tip: Label=Label.new(); tip.text="Build your own roof with slope, corner and flat panels."; tip.position=Vector2(0,154); tip.modulate=Color("a4bca9"); panel.add_child(tip)
	caption.text=text; bar.value=percent
	RenderingServer.force_draw(false)

static func finish() -> void:
	show_progress(100,"Ready to explore")
	if is_instance_valid(layer): layer.get_parent().remove_child(layer); layer.queue_free()
	layer=null
