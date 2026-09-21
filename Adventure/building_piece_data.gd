class_name BuildingPieceData
extends Resource
@export var id: String = ""
@export var display_name: String = ""
@export var category: String = "Structure"
@export var subcategory: String = ""
@export var scene: PackedScene
@export var thumbnail: Texture2D
@export var resource_cost: Dictionary = {}
@export var snap_type: String = ""
@export var allowed_snap_targets: PackedStringArray = PackedStringArray(["foundation", "floor", "wall", "support"])
@export var rotation_step: float = 90.0
@export var placement_rules: Dictionary = {}
@export var collision_bounds: Vector3 = Vector3(2,3,2)
@export var footprint: Vector2i = Vector2i.ONE
@export var offset: Vector3 = Vector3.ZERO
@export var snap_points: Dictionary = {"north": Vector3(0,0,-1), "south": Vector3(0,0,1), "east": Vector3(1,0,0), "west": Vector3(-1,0,0)}

