extends Node3D
## Visual mirror of world_store's data.dropped -- a small billboard icon per pickup,
## replicated the same way as tamed animals and farmland. Any nearby player can collect
## one; the authority resolves the actual pickup in world_store.tick_drops().
const Items = preload("res://Adventure/items.gd")
var drops: Dictionary = {}
var _nodes: Dictionary = {}

func apply_state(records: Dictionary) -> void:
	drops = records
	var wanted: Dictionary = {}
	for id: String in records:
		wanted[id] = true
		var record: Dictionary = records[id]
		var p: Vector3 = Vector3(record.p[0], record.p[1], record.p[2])
		if not _nodes.has(id):
			_nodes[id] = _make_marker(str(record.get("item", "")), int(record.get("amount", 1)))
			add_child(_nodes[id])
		_nodes[id].position = p
	for id: String in _nodes.keys():
		if not wanted.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)

func _make_marker(item: String, amount: int) -> Node3D:
	var root: Node3D = Node3D.new()
	var sprite: Sprite3D = Sprite3D.new()
	sprite.texture = Items.icon(item)
	sprite.pixel_size = 0.01
	sprite.position.y = 0.35
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = false
	sprite.double_sided = true
	root.add_child(sprite)
	if amount > 1:
		var label: Label3D = Label3D.new()
		label.text = "x" + str(amount)
		label.font_size = 42
		label.outline_size = 8
		label.position.y = 0.02
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(label)
	return root

func nearest(p: Vector3, max_distance: float = 3.0) -> String:
	var result: String = ""
	var distance: float = max_distance
	for id: String in drops:
		var record: Dictionary = drops[id]
		var d: float = p.distance_to(Vector3(record.p[0], record.p[1], record.p[2]))
		if d < distance:
			result = id
			distance = d
	return result
