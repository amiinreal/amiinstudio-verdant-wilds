extends Control
const Rules := preload("res://Adventure/rules.gd")
var session: Node3D

func _point(p: Vector2) -> Vector2:
	return Vector2(size.x / 2 + p.x * size.x / 235.0, 42 + (p.y + 268) * (size.y - 84) / 300.0)

func _draw() -> void:
	if session == null:
		return
	for edge: Vector3i in Rules.EDGES:
		var active: bool = session.state["solved"][edge.z]
		draw_line(_point(Rules.CENTERS[edge.x]), _point(Rules.CENTERS[edge.y]), Color("afd6a0") if active else Color("3c5254"), 4 if active else 2, true)
	for i in range(7):
		var p: Vector2 = _point(Rules.CENTERS[i])
		draw_circle(p, 20, Color("355b50"))
		draw_arc(p, 21, 0, TAU, 32, Color("e4d4a6") if session.state["solved"][i] else Color("759186"), 2, true)
		draw_string(ThemeDB.fallback_font, p + Vector2(-5, 6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("ece9d5"))
	for id: int in session.players:
		var body: CharacterBody3D = session.players[id]
		draw_circle(_point(Vector2(body.position.x, body.position.z)), 5, Color("ffe092") if id == session.local_id() else Color("83ddea"))
