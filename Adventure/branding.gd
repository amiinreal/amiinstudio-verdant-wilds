## Shared "Verdant Wilds" brand mark: a procedurally drawn emblem (no external
## render step, so it can never go missing) plus a helper that builds the
## logo card (background plate + emblem + wordmark) used by the intro and the
## main menu's Welcome page.
extends RefCounted

const GOLD := Color("d9b367")
const GOLD_DIM := Color("9c7c42")
const SAGE := Color("7fae86")
const CANOPY := Color("4f8f5c")
const CANOPY_DARK := Color("336142")
const CARD_BG := Color(0.023, 0.06, 0.055, 0.97)
const CARD_BORDER := Color("2c4a41")


class Emblem extends Control:
	func _draw() -> void:
		var s: float = size.x
		var center := Vector2(s * 0.5, s * 0.5)
		# Ring.
		draw_arc(center, s * 0.46, 0, TAU, 64, GOLD_DIM, s * 0.028, true)
		# Canopy: three overlapping soft blobs.
		var canopy_center := center + Vector2(0, -s * 0.06)
		draw_circle(canopy_center + Vector2(-s * 0.14, s * 0.02), s * 0.16, CANOPY_DARK)
		draw_circle(canopy_center + Vector2(s * 0.14, s * 0.02), s * 0.16, CANOPY_DARK)
		draw_circle(canopy_center + Vector2(0, -s * 0.10), s * 0.19, CANOPY)
		# Trunk.
		var trunk_top := center + Vector2(0, s * 0.06)
		var trunk_width := s * 0.06
		draw_rect(Rect2(trunk_top - Vector2(trunk_width * 0.5, 0), Vector2(trunk_width, s * 0.28)), GOLD_DIM, true)
		# Three little "invite" dots under the tree, echoing multiplayer/co-op.
		for offset in [-s * 0.11, 0.0, s * 0.11]:
			draw_circle(center + Vector2(offset, s * 0.34), s * 0.02, SAGE)


static func make_emblem(px: float) -> Emblem:
	var emblem := Emblem.new()
	emblem.custom_minimum_size = Vector2(px, px)
	emblem.size = Vector2(px, px)
	return emblem


static func card_style(padding: int = 28) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = CARD_BG
	box.set_corner_radius_all(20)
	box.border_color = CARD_BORDER
	box.set_border_width_all(1)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box


## Builds a self-contained logo lockup: card background, emblem, "AMIIN STUDIO"
## kicker and "THE VERDANT WILDS" wordmark. Returns the outer card control;
## callers can still reach the emblem/labels through the returned node's
## metadata if they need to animate them individually (see intro.gd).
static func build_logo_card(emblem_px: float = 96, title_size: int = 34) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 10)

	var emblem := make_emblem(emblem_px)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(emblem)
	card.set_meta("emblem", emblem)

	var kicker := Label.new()
	kicker.text = "AMIIN STUDIO"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.add_theme_color_override("font_color", GOLD)
	kicker.add_theme_constant_override("outline_size", 0)
	card.add_child(kicker)
	card.set_meta("kicker", kicker)

	var title := Label.new()
	title.text = "THE VERDANT WILDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", title_size)
	title.add_theme_color_override("font_color", Color("f3ead7"))
	card.add_child(title)
	card.set_meta("title", title)

	return card


## Compact horizontal lockup (small emblem beside the wordmark) for places the
## full vertical card is too tall for, e.g. a page heading row.
static func build_horizontal_lockup(emblem_px: float = 40, title_size: int = 30) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var emblem := make_emblem(emblem_px)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(emblem)
	var title := Label.new()
	title.text = "THE VERDANT WILDS"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", title_size)
	title.add_theme_color_override("font_color", Color("f2e5c8"))
	row.add_child(title)
	return row
