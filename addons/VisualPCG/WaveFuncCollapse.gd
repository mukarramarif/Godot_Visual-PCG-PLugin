extends Node

class_name WaveFunctionCollapse

var tileset_data: Dictionary = {}
var grid: Array = []
var grid_size: Vector3i = Vector3i(20, 20, 3)
var tile_templates: Dictionary = {}
var grid_type: String = "square"  # "square" or "hex"
var tile_size: float = 2.0

signal generation_completed(grid_res: Array)
signal generation_failed(error: String)

const HEX_DIRECTIONS = ["ne", "e", "se", "sw", "w", "nw", "up", "down"]
const SQUARE_DIRECTIONS = ["north", "south", "east", "west", "up", "down"]

func run_wfc(tileset: Dictionary):
	print("Starting WFC Generation")
	tileset_data = tileset
	grid_type = tileset.get("grid_type", "square")
	tile_size = tileset.get("tile_size", 2.0)

	if not valid_tileset():
		emit_signal("generation_failed", "Invalid tileset data")
		return null

	prepare_tiles()
	init_grid(grid_size)

	var success = collapse_grid()

	if success:
		print("WFC Generation completed successfully")
		print_grid()
		emit_signal("generation_completed", grid)
		return grid
	else:
		emit_signal("generation_failed", "Collapse failed - contradiction")
		return null

func valid_tileset() -> bool:
	if not tileset_data.has("tiles"):
		return false
	return tileset_data["tiles"].size() > 0

func prepare_tiles():
	tile_templates.clear()
	for tile_id in tileset_data["tiles"]:
		var tile_data = tileset_data["tiles"][tile_id]
		tile_templates[tile_data["name"]] = {
			"id": tile_id,
			"name": tile_data["name"],
			"type": tile_data.get("type", "3d"),
			"weight": tile_data.get("weight", 1.0),
			"neighbors": tile_data.get("neighbors", {}),
			"file_path": tile_data.get("file_path", "")
		}
	print("Prepared %d tile templates" % tile_templates.size())

func init_grid(size: Vector3i):
	var effective_z = max(1, size.z)
	grid_size = Vector3i(size.x, size.y, effective_z)
	grid.clear()

	var all_tiles = tile_templates.keys()

	for z in range(effective_z):
		var layer = []
		for y in range(size.y):
			var row = []
			for x in range(size.x):
				row.append({
					"position": Vector3i(x, y, z),
					"collapsed": false,
					"possible_tiles": all_tiles.duplicate(),
					"tile": null,
				})
			layer.append(row)
		grid.append(layer)
	print("Grid initialized: %dx%dx%d (%s)" % [grid_size.x, grid_size.y, grid_size.z, grid_type])

func get_neighbors(pos: Vector3i) -> Array:
	var neighbors = []

	if grid_type == "hex":
		neighbors = get_hex_neighbors(pos)
	else:
		neighbors = get_square_neighbors(pos)

	# Vertical neighbors (same for both)
	if pos.z > 0:
		neighbors.append({"cell": grid[pos.z - 1][pos.y][pos.x], "direction": "down"})
	if pos.z < grid_size.z - 1:
		neighbors.append({"cell": grid[pos.z + 1][pos.y][pos.x], "direction": "up"})

	return neighbors

func get_square_neighbors(pos: Vector3i) -> Array:
	var neighbors = []
	if pos.y > 0:
		neighbors.append({"cell": grid[pos.z][pos.y - 1][pos.x], "direction": "north"})
	if pos.y < grid_size.y - 1:
		neighbors.append({"cell": grid[pos.z][pos.y + 1][pos.x], "direction": "south"})
	if pos.x > 0:
		neighbors.append({"cell": grid[pos.z][pos.y][pos.x - 1], "direction": "west"})
	if pos.x < grid_size.x - 1:
		neighbors.append({"cell": grid[pos.z][pos.y][pos.x + 1], "direction": "east"})
	return neighbors

func get_hex_neighbors(pos: Vector3i) -> Array:
	var neighbors = []
	var x = pos.x
	var y = pos.y
	var z = pos.z

	# Pointy-top hex: offset coordinates (odd-q)
	# Even columns vs odd columns have different neighbor offsets
	var is_odd_col = (x % 2) == 1

	# Hex neighbor offsets for pointy-top, odd-q layout
	var offsets: Array
	if is_odd_col:
		offsets = [
			{"dx": 1, "dy": 0, "dir": "e"},
			{"dx": -1, "dy": 0, "dir": "w"},
			{"dx": 0, "dy": -1, "dir": "nw"},
			{"dx": 1, "dy": -1, "dir": "ne"},
			{"dx": 0, "dy": 1, "dir": "sw"},
			{"dx": 1, "dy": 1, "dir": "se"},
		]
	else:
		offsets = [
			{"dx": 1, "dy": 0, "dir": "e"},
			{"dx": -1, "dy": 0, "dir": "w"},
			{"dx": -1, "dy": -1, "dir": "nw"},
			{"dx": 0, "dy": -1, "dir": "ne"},
			{"dx": -1, "dy": 1, "dir": "sw"},
			{"dx": 0, "dy": 1, "dir": "se"},
		]

	for offset in offsets:
		var nx = x + offset["dx"]
		var ny = y + offset["dy"]
		if nx >= 0 and nx < grid_size.x and ny >= 0 and ny < grid_size.y:
			neighbors.append({"cell": grid[z][ny][nx], "direction": offset["dir"]})

	return neighbors

func get_opposite_direction(direction: String) -> String:
	match direction:
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
		"ne": return "sw"
		"sw": return "ne"
		"e": return "w"
		"w": return "e"
		"se": return "nw"
		"nw": return "se"
		"up": return "down"
		"down": return "up"
	return direction

# Rest of collapse logic remains the same...
func collapse_grid() -> bool:
	var iterations = 0
	var total_cells = grid_size.x * grid_size.y * grid_size.z
	var max_iterations = total_cells * 10

	while not is_grid_fully_collapsed():
		iterations += 1
		if iterations > max_iterations:
			push_error("Max iterations reached")
			return false
		var cell = find_lowest_entropy_cell()
		if not cell:
			return false
		if not collapse_cell(cell):
			return false
		propagate_constraints(cell)
	return true

func find_lowest_entropy_cell():
	var min_entropy = INF
	var candidates = []
	for layer in grid:
		for row in layer:
			for cell in row:
				if cell["collapsed"]:
					continue
				var entropy = cell["possible_tiles"].size()
				if entropy == 0:
					return null
				if entropy < min_entropy:
					min_entropy = entropy
					candidates.clear()
					candidates.append(cell)
				elif entropy == min_entropy:
					candidates.append(cell)
	if candidates.size() > 0:
		return candidates[randi() % candidates.size()]
	return null

func collapse_cell(cell: Dictionary) -> bool:
	if cell["possible_tiles"].size() == 0:
		return false
	var chosen = select_weighted_tile(cell["possible_tiles"])
	cell["tile"] = chosen
	cell["collapsed"] = true
	cell["possible_tiles"] = [chosen]
	return true

func select_weighted_tile(possibilities: Array) -> String:
	var total_weight = 0.0
	for tile_name in possibilities:
		if tile_templates.has(tile_name):
			total_weight += tile_templates[tile_name]["weight"]
	var random_value = randf() * total_weight
	var cumulative = 0.0
	for tile_name in possibilities:
		if tile_templates.has(tile_name):
			cumulative += tile_templates[tile_name]["weight"]
			if random_value <= cumulative:
				return tile_name
	return possibilities[0]

func propagate_constraints(start_cell: Dictionary):
	var queue = [start_cell]
	var processed = {}
	while queue.size() > 0:
		var curr = queue.pop_front()
		var pos = curr["position"]
		var key = "%d,%d,%d" % [pos.x, pos.y, pos.z]
		if processed.has(key):
			continue
		processed[key] = true
		if not curr["collapsed"]:
			continue
		for neighbor in get_neighbors(pos):
			var neighbor_cell = neighbor["cell"]
			var direction = neighbor["direction"]
			if neighbor_cell["collapsed"]:
				continue
			var allowed = get_allowed_tiles(curr["tile"], direction)
			var new_possibilities = []
			for possible in neighbor_cell["possible_tiles"]:
				if possible in allowed:
					new_possibilities.append(possible)
			if new_possibilities.size() < neighbor_cell["possible_tiles"].size():
				neighbor_cell["possible_tiles"] = new_possibilities
				queue.append(neighbor_cell)

func get_allowed_tiles(tile_name: String, direction: String) -> Array:
	if not tile_templates.has(tile_name):
		return []
	var neighbors = tile_templates[tile_name]["neighbors"].get(direction, [])
	var allowed = []
	for conn in neighbors:
		if conn is Dictionary:
			allowed.append(conn["tile"])
		else:
			allowed.append(conn)
	return allowed

func is_grid_fully_collapsed() -> bool:
	for layer in grid:
		for row in layer:
			for cell in row:
				if not cell["collapsed"]:
					return false
	return true

func print_grid():
	print("\n=== WFC Result (%s) ===" % grid_type)
	for z in range(grid.size()):
		print("--- Layer Z=%d ---" % z)
		for row in grid[z]:
			var row_str = ""
			for cell in row:
				row_str += (cell["tile"][0] if cell["tile"] else "?") + " "
			print(row_str)

func get_collapse_progress() -> float:
	var total = grid_size.x * grid_size.y * grid_size.z
	return float(get_collapsed_count()) / float(total)

func get_collapsed_count() -> int:
	var count = 0
	for layer in grid:
		for row in layer:
			for cell in row:
				if cell["collapsed"]:
					count += 1
	return count

# ===== INSTANTIATE TILES =====

func instantiate_tiles_in_world(parent: Node3D, p_tile_size: float = 2.0, layer_height: float = 2.0):
	var use_size = tile_size if tile_size > 0 else p_tile_size

	for z in range(grid.size()):
		for y in range(grid[z].size()):
			for x in range(grid[z][y].size()):
				var cell = grid[z][y][x]
				if not cell["tile"]:
					continue

				var tile_name = cell["tile"]
				if not tile_templates.has(tile_name):
					continue

				var filepath = tile_templates[tile_name].get("file_path", "")
				if filepath.is_empty():
					continue

				var resource = load(filepath)
				var instance: Node3D = null

				if resource is PackedScene:
					instance = resource.instantiate()
				elif resource is Mesh:
					instance = MeshInstance3D.new()
					instance.mesh = resource
				else:
					continue

				# Position based on grid type
				var pos: Vector3
				if grid_type == "hex":
					pos = hex_to_world_position(x, y, z, use_size, layer_height)
				else:
					pos = Vector3(x * use_size, z * layer_height, y * use_size)

				instance.position = pos
				instance.name = "%s_%d_%d_%d" % [tile_name, x, y, z]
				parent.add_child(instance)
				instance.owner = parent
				_set_owner_recursive(instance, parent)

func hex_to_world_position(x: int, y: int, z: int, hex_size: float, layer_height: float) -> Vector3:
	# Pointy-top hex positioning
	# Width = size * 2
	# Height = size * sqrt(3)
	var hex_width = hex_size * sqrt(1.0)
	var hex_height = hex_size * 1.5

	# Horizontal spacing:
	var horiz_spacing = hex_width * 0.525

	# Vertical spacing: full height
	var vert_spacing = hex_height

	# Offset for odd columns
	var y_offset = 0.0
	if (x % 2) == 1:
		y_offset = hex_height * 0.5

	var world_x = x * horiz_spacing
	var world_y = z * layer_height
	var world_z = y * vert_spacing + y_offset

	return Vector3(world_x, world_y, world_z)

func _set_owner_recursive(node: Node, owner: Node):
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)
