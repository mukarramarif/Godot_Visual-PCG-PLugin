extends Node3D

class_name PCGNode
@export var map_detail:JSON
@export var grid_size:Vector3i = Vector3i(10, 10, 1) # size of the grid to generate
@export var tile_size:float = 2.0 # size of each tile in world units
@export var iteration:int = 0 # number of backtracking attempts
@onready var wfc: = preload("res://addons/VisualPCG/WaveFuncCollapse.gd")

func _ready():
	_run_wfc()
func _run_wfc():
	var wfc_instance = wfc.new()
	wfc_instance.grid_size = grid_size
	var tileSet: Dictionary = map_detail.data as Dictionary
	wfc_instance.tile_size = tile_size
	var grid = wfc_instance.run_wfc(tileSet)
	if grid != null:
		wfc_instance.instantiate_tiles_in_world(self)
