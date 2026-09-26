extends Node3D
## Visual mirror of world_store's data.farmland, replicated like wildlife/tamed state.
## Growth and moisture are computed only on the authority; clients just render the numbers.
const Visual = preload("res://Adventure/farming/plot_visual.gd")
var plots: Dictionary = {}
var _nodes: Dictionary = {}

func apply_state(records: Dictionary, now: float) -> void:
	plots = records
	var wanted: Dictionary = {}
	for id: String in records:
		wanted[id] = true
		var record: Dictionary = records[id]
		var p: Vector3 = Vector3(record.p[0], record.p[1], record.p[2])
		if not _nodes.has(id):
			var node: Node3D = Node3D.new()
			node.set_script(Visual)
			node.position = p
			add_child(node)
			_nodes[id] = node
		_nodes[id].apply(record, now)
	for id: String in _nodes.keys():
		if not wanted.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)

## Nearest plot to a world position, within reach; "" if none.
func nearest(p: Vector3, max_distance: float = 3.5) -> String:
	var result: String = ""
	var distance: float = max_distance
	for id: String in plots:
		var record: Dictionary = plots[id]
		var d: float = p.distance_to(Vector3(record.p[0], record.p[1], record.p[2]))
		if d < distance:
			result = id
			distance = d
	return result
