extends CanvasLayer
## A short, skippable studio reveal before the playable title screen.
var root: Control
var card: Control
var completed: bool=false

func _ready() -> void:
	layer=90
	root=Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
	var backdrop: ColorRect=ColorRect.new(); backdrop.color=Color("071216"); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(backdrop)
	var glow: ColorRect=ColorRect.new(); glow.color=Color(0.95,0.10,0.02,0.06); glow.set_anchors_and_offsets_preset(Control.PRESET_CENTER); glow.position=Vector2(-360,-220); glow.size=Vector2(720,440); root.add_child(glow)
	card=VBoxContainer.new(); card.set_anchors_and_offsets_preset(Control.PRESET_CENTER); card.position=Vector2(-340,-180); card.size=Vector2(680,360); card.alignment=BoxContainer.ALIGNMENT_CENTER; card.add_theme_constant_override("separation",18); root.add_child(card)
	var image: TextureRect=TextureRect.new(); image.texture=load("res://Adventure/generated/amiin_studio_intro.png"); image.custom_minimum_size=Vector2(560,185); image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.modulate=Color(1,1,1,0); card.add_child(image)
	var studio: Label=Label.new(); studio.text="AMIIN STUDIO"; studio.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; studio.add_theme_font_size_override("font_size",17); studio.add_theme_color_override("font_color",Color("e9a05d")); studio.modulate=Color(1,1,1,0); card.add_child(studio)
	var line: HSeparator=HSeparator.new(); card.add_child(line)
	var title: Label=Label.new(); title.text="THE VERDANT WILDS"; title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",34); title.add_theme_color_override("font_color",Color("f3ead7")); title.modulate=Color(1,1,1,0); card.add_child(title)
	var subtitle: Label=Label.new(); subtitle.text="A world to gather, shape, and make your own."; subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; subtitle.add_theme_font_size_override("font_size",17); subtitle.add_theme_color_override("font_color",Color("a9c6b1")); subtitle.modulate=Color(1,1,1,0); card.add_child(subtitle)
	var prompt: Label=Label.new(); prompt.text="CLICK OR PRESS ANY KEY TO ENTER"; prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; prompt.add_theme_font_size_override("font_size",13); prompt.add_theme_color_override("font_color",Color("ddb980")); prompt.modulate=Color(1,1,1,0); card.add_child(prompt)
	var tween: Tween=create_tween(); tween.set_parallel(true)
	tween.tween_property(image,"modulate:a",1.0,0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(studio,"modulate:a",1.0,0.7).set_delay(.25)
	tween.tween_property(title,"modulate:a",1.0,0.8).set_delay(.55)
	tween.tween_property(subtitle,"modulate:a",1.0,0.8).set_delay(.75)
	tween.tween_property(prompt,"modulate:a",1.0,0.6).set_delay(1.1)
	card.scale=Vector2(.92,.92); tween.tween_property(card,"scale",Vector2.ONE,1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if completed or not (event is InputEventKey or event is InputEventMouseButton): return
	if event is InputEventKey and not event.pressed: return
	if event is InputEventMouseButton and not event.pressed: return
	completed=true
	var tween: Tween=create_tween(); tween.tween_property(root,"modulate:a",0.0,.35); tween.tween_callback(queue_free)
