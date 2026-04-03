extends Node3D

class_name PCGNode
## JSON file containing tile definitions and adjacency rules generated through the PCG Panel
@export var map_detail:JSON
## size of the grid to generate
@export var grid_size:Vector3i = Vector3i(10, 10, 1)
## size of each tile in world units
@export var tile_size:float = 2.0
## number of backtracking attempts
@export var max_retries:int = 10
## number of backtracking steps before giving up
@export var back_tracks:int = 100
@onready var wfc: = preload("res://addons/VisualPCG/WaveFuncCollapse.gd")
## whether to add collision shapes to the generated tiles
@export var Collision: bool = false
func _ready():
	_run_wfc()
func _run_wfc():
	var wfc_instance = wfc.new()
	wfc_instance.grid_size = grid_size
	var tileSet: Dictionary = map_detail.data as Dictionary
	wfc_instance.tile_size = tile_size
	var grid = wfc_instance.run_wfc(tileSet)
	if grid != null:
		if Collision:
			wfc_instance.instantiate_tiles_in_world(self)
			for child in get_children():
				_create_collision_for_node(child)
		else:
			wfc_instance.instantiate_tiles_in_world(self)

func _create_collision_for_node(node: Node):
	if node is MeshInstance3D:
		node.create_trimesh_collision()
	for c in node.get_children():
		_create_collision_for_node(c)
