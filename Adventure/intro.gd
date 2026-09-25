extends CanvasLayer
## A short, skippable studio reveal before the playable title screen.
const Branding := preload("res://Adventure/branding.gd")
var root: Control
var card: Control
var completed: bool=false

func _ready() -> void:
	layer=90
	root=Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
	var backdrop: TextureRect=TextureRect.new(); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); backdrop.stretch_mode=TextureRect.STRETCH_SCALE; root.add_child(backdrop)
	var backdrop_grad: Gradient=Gradient.new(); backdrop_grad.set_color(0,Color("14351f")); backdrop_grad.set_color(1,Color("050f0a"))
	var backdrop_tex: GradientTexture2D=GradientTexture2D.new(); backdrop_tex.gradient=backdrop_grad; backdrop_tex.fill=GradientTexture2D.FILL_RADIAL
	backdrop_tex.fill_from=Vector2(0.5,0.32); backdrop_tex.fill_to=Vector2(0.5,1.05); backdrop_tex.width=512; backdrop_tex.height=512
	backdrop.texture=backdrop_tex
	var glow: TextureRect=TextureRect.new(); glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER); glow.position=Vector2(-420,-320); glow.size=Vector2(840,560); glow.stretch_mode=TextureRect.STRETCH_SCALE; root.add_child(glow)
	var glow_grad: Gradient=Gradient.new(); glow_grad.set_color(0,Color(0.85,0.64,0.29,0.16)); glow_grad.set_color(1,Color(0.85,0.64,0.29,0.0))
	var glow_tex: GradientTexture2D=GradientTexture2D.new(); glow_tex.gradient=glow_grad; glow_tex.fill=GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from=Vector2(0.5,0.5); glow_tex.fill_to=Vector2(0.5,1.0); glow_tex.width=512; glow_tex.height=512
	glow.texture=glow_tex

	var outer: PanelContainer=PanelContainer.new(); outer.add_theme_stylebox_override("panel",Branding.card_style(40))
	outer.set_anchors_and_offsets_preset(Control.PRESET_CENTER); outer.position=Vector2(-260,-220); outer.size=Vector2(520,440)
	root.add_child(outer)
	card=Branding.build_logo_card(108,34); outer.add_child(card)
	var emblem: Control=card.get_meta("emblem")
	var studio: Label=card.get_meta("kicker")
	var title: Label=card.get_meta("title")

	var subtitle: Label=Label.new(); subtitle.text="A world to gather, shape, and make your own."; subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD; subtitle.add_theme_font_size_override("font_size",17); subtitle.add_theme_color_override("font_color",Color("a9c6b1")); card.add_child(subtitle)
	var prompt: Label=Label.new(); prompt.text="CLICK OR PRESS ANY KEY TO ENTER"; prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; prompt.add_theme_font_size_override("font_size",13); prompt.add_theme_color_override("font_color",Color("ddb980")); card.add_child(prompt)
	card.add_theme_constant_override("separation",14)

	for node: CanvasItem in [emblem,studio,title,subtitle,prompt]: node.modulate=Color(1,1,1,0)
	var tween: Tween=create_tween(); tween.set_parallel(true)
	tween.tween_property(emblem,"modulate:a",1.0,0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(studio,"modulate:a",1.0,0.7).set_delay(.25)
	tween.tween_property(title,"modulate:a",1.0,0.8).set_delay(.55)
	tween.tween_property(subtitle,"modulate:a",1.0,0.8).set_delay(.75)
	tween.tween_property(prompt,"modulate:a",1.0,0.6).set_delay(1.1)
	outer.scale=Vector2(.92,.92); outer.pivot_offset=outer.size/2.0; tween.tween_property(outer,"scale",Vector2.ONE,1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if completed or not (event is InputEventKey or event is InputEventMouseButton): return
	if event is InputEventKey and not event.pressed: return
	if event is InputEventMouseButton and not event.pressed: return
	completed=true
	var tween: Tween=create_tween(); tween.tween_property(root,"modulate:a",0.0,.35); tween.tween_callback(queue_free)
